import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moai3/models/discount_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Descuentos en supermercados pagando con MODO, filtrados por los bancos y
/// billeteras que el usuario marca como suyos.
///
/// Fuente: la API que usa la página pública modo.com.ar/promos. No es una
/// API oficial: puede cambiar sin aviso. Por eso se consulta una vez por
/// día, se guarda en el TV y, si falla, se sigue mostrando lo último bajado.
class DiscountsService extends ChangeNotifier {
  DiscountsService._();

  static final DiscountsService instance = DiscountsService._();

  static const _base = 'https://www.modo.com.ar/promos/api/rewards';
  static const _slot = 'web-modo-hub-supermercados';
  static const _pageSize = 100;
  static const _maxPages = 10;
  static const _prefsBanks = 'discount_bank_ids';
  static const _cacheFile = 'discounts.json';

  /// Las páginas de MODO esperan un navegador.
  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (Linux; Android 10; TV) AppleWebKit/537.36',
    'Accept': 'application/json',
  };

  http.Client _client = http.Client();
  Directory? _directoryOverride;

  List<DiscountBank> _banks = const [];
  List<Discount> _discounts = const [];
  Set<String> _selected = const {};
  DateTime? _fetchedAt;
  bool _loading = false;
  Future<void>? _loaded;

  /// Bancos y billeteras que se pueden elegir (los que MODO muestra).
  List<DiscountBank> get banks => _banks;

  /// Los que eligió el usuario.
  Set<String> get selectedBankIds => _selected;
  bool get hasSelectedBanks => _selected.isNotEmpty;

  /// Cuándo se bajaron las promos (null: nunca).
  DateTime? get fetchedAt => _fetchedAt;
  bool get isLoading => _loading;

  /// Lee lo guardado y, si es de otro día, actualiza en segundo plano.
  Future<void> ensureLoaded() => _loaded ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selected = (prefs.getStringList(_prefsBanks) ?? const []).toSet();
      await _readCache();
    } catch (e) {
      debugPrint('[Descuentos] No se pudo leer lo guardado: $e');
    }
    notifyListeners();
    unawaited(refresh());
  }

  /// Baja bancos y promos si lo guardado no es de hoy (o con [force]).
  Future<void> refresh({bool force = false}) async {
    final last = _fetchedAt;
    final now = DateTime.now();
    if (!force &&
        last != null &&
        last.year == now.year &&
        last.month == now.month &&
        last.day == now.day) {
      return;
    }
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      final banks = await _fetchBanks();
      final bodies = <String>[];
      for (var page = 1; page <= _maxPages; page++) {
        final body = await _get(
          '$_base/v2/filter?slot_ids=$_slot&limit=$_pageSize&page=$page'
          '&source=web_modo&origin=WEB_MODO',
        );
        bodies.add(body);
        final pages = (jsonDecode(body) as Map)['pagination']?['total_pages'];
        if (pages is! num || page >= pages) break;
      }
      // Cientos de KB: se arman en otro hilo.
      final discounts = await Isolate.run(() => parseModoPages(bodies));
      if (discounts.isNotEmpty) {
        _banks = banks;
        _discounts = discounts;
        _fetchedAt = now;
        await _writeCache();
      }
      debugPrint(
        '[Descuentos] ${discounts.length} promos de supermercados, '
        '${banks.length} bancos',
      );
    } catch (e) {
      // Sigue lo último guardado.
      debugPrint('[Descuentos] No se pudo actualizar: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<String> _get(String url) async {
    final res = await _client
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    }
    return utf8.decode(res.bodyBytes);
  }

  Future<List<DiscountBank>> _fetchBanks() async {
    final list = jsonDecode(await _get('$_base/banks?source=app_modo'));
    if (list is! List) return _banks;
    return [
      for (final b in list)
        if (b is Map<String, dynamic> && b['on_hub_list'].toString() == 'true')
          DiscountBank.fromJson(b),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Marca o desmarca un banco o billetera como propio.
  Future<void> toggleBank(String id) async {
    final next = {..._selected};
    if (!next.remove(id)) next.add(id);
    _selected = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsBanks, next.toList());
  }

  /// Los descuentos de [day] con los bancos elegidos: el mejor primero, uno
  /// por comercio.
  List<Discount> discountsOn(DateTime day) =>
      bestPerMerchant(_discounts, day, _selected);

  /// Los próximos [days] días desde [from] (hoy, mañana…).
  List<DayDiscounts> week(DateTime from, {int days = 7}) => [
    for (var i = 0; i < days; i++)
      () {
        final day = DateTime(from.year, from.month, from.day + i);
        return DayDiscounts(day: day, discounts: discountsOn(day));
      }(),
  ];

  /// Los de [day] con alguno de [banks], ordenados por porcentaje (y tope),
  /// quedándose con el mejor de cada comercio.
  @visibleForTesting
  static List<Discount> bestPerMerchant(
    List<Discount> all,
    DateTime day,
    Set<String> banks,
  ) {
    if (banks.isEmpty) return const [];
    final valid = [
      for (final d in all)
        if (d.validOn(day) && d.acceptsAny(banks)) d,
    ]..sort(_better);
    final seen = <String>{};
    return [
      for (final d in valid)
        if (seen.add(d.merchant.toLowerCase())) d,
    ];
  }

  static int _better(Discount a, Discount b) {
    final byPercent = (b.percent ?? 0).compareTo(a.percent ?? 0);
    if (byPercent != 0) return byPercent;
    return (b.cap ?? double.infinity).compareTo(a.cap ?? double.infinity);
  }

  // --- Guardado en el TV ---

  Future<File> _file() async {
    final dir = _directoryOverride ?? await getApplicationSupportDirectory();
    return File('${dir.path}/$_cacheFile');
  }

  Future<void> _readCache() async {
    final file = await _file();
    if (!file.existsSync()) return;
    final path = file.path;
    final data = await Isolate.run(
      () => jsonDecode(File(path).readAsStringSync()),
    );
    if (data is! Map<String, dynamic>) return;
    _fetchedAt = DateTime.tryParse(data['fetchedAt']?.toString() ?? '');
    _banks = [
      for (final b in (data['banks'] as List? ?? const []))
        if (b is Map<String, dynamic>) DiscountBank.fromJson(b),
    ];
    _discounts = [
      for (final d in (data['discounts'] as List? ?? const []))
        if (d is Map<String, dynamic>) Discount.fromJson(d),
    ];
  }

  Future<void> _writeCache() async {
    final file = await _file();
    final data = {
      'fetchedAt': _fetchedAt?.toIso8601String(),
      'banks': [for (final b in _banks) b.toJson()],
      'discounts': [for (final d in _discounts) d.toJson()],
    };
    final path = file.path;
    await Isolate.run(
      () => File(path).writeAsStringSync(jsonEncode(data), flush: true),
    );
  }

  /// Sólo para tests: promos ya cargadas, sin red.
  @visibleForTesting
  void debugSetDiscounts(List<Discount> discounts) {
    _discounts = discounts;
    notifyListeners();
  }

  /// Sólo para tests: cliente HTTP falso, carpeta y estado de cero.
  @visibleForTesting
  void resetForTest({http.Client? client, Directory? directory}) {
    _client = client ?? http.Client();
    _directoryOverride = directory;
    _banks = const [];
    _discounts = const [];
    _selected = const {};
    _fetchedAt = null;
    _loading = false;
    _loaded = null;
  }
}

/// Arma las promos de las páginas de `/v2/filter` (una por respuesta).
/// Pura: corre en otro hilo.
List<Discount> parseModoPages(List<String> bodies) {
  final out = <Discount>[];
  final ids = <String>{};
  for (final body in bodies) {
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) continue;
    for (final card in (data['cards'] as List? ?? const [])) {
      if (card is! Map<String, dynamic>) continue;
      final d = Discount.fromModoCard(card);
      if (d != null && ids.add(d.id)) out.add(d);
    }
  }
  return out;
}
