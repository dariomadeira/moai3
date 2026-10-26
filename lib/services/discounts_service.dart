import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:moai3/models/discount_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Descuentos pagando con MODO en supermercados, mayoristas, farmacias y
/// combustible, filtrados por los bancos y billeteras del usuario, sus
/// comercios, los rubros que le interesan y su provincia.
///
/// Fuente: la API que usa la página pública modo.com.ar/promos. No es una
/// API oficial: puede cambiar sin aviso. Por eso se consulta una vez por
/// día, se guarda en el TV y, si falla, se sigue mostrando lo último bajado.
///
/// MODO no dice dónde vale cada promo: el lugar lo da el usuario marcando
/// sus comercios ("Mis comercios"). La provincia sólo descarta las pocas
/// promos que nombran otra ("Mi San Luis").
class DiscountsService extends ChangeNotifier {
  DiscountsService._();

  static final DiscountsService instance = DiscountsService._();

  static const _base = 'https://www.modo.com.ar/promos/api/rewards';
  static const _slot = 'web-modo-hub-supermercados';
  static const _pageSize = 100;
  static const _maxPages = 10;

  /// Rubros que no tienen carrusel propio: se buscan por texto y se quedan
  /// sólo las tarjetas de ese rubro.
  static const _searches = {
    DiscountRubro.farmacias: 'farmacia',
    DiscountRubro.combustible: 'combustible',
    DiscountRubro.mayoristas: 'mayorista',
  };
  static const _prefsBanks = 'discount_bank_ids';
  static const _prefsMerchants = 'discount_merchants';
  static const _prefsRubros = 'discount_rubros';
  static const _prefsOnlyMine = 'discount_only_mine';
  static const _cacheFile = 'discounts.json';

  /// Sube cuando cambia lo que se guarda o se descarta de cada promo (2:
  /// rubro y provincias; 3: sin beneficios corporativos).
  static const _cacheVersion = 3;

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
  Set<String> _merchants = const {};
  Set<DiscountRubro> _rubros = DiscountRubro.values.toSet();
  bool _onlyMine = true;
  String? _province;
  DateTime? _fetchedAt;
  bool _loading = false;
  Future<void>? _loaded;

  /// Bancos y billeteras que se pueden elegir (los que MODO muestra).
  List<DiscountBank> get banks => _banks;

  /// Los que eligió el usuario.
  Set<String> get selectedBankIds => _selected;
  bool get hasSelectedBanks => _selected.isNotEmpty;

  /// Mis comercios ([Discount.merchantKey]).
  Set<String> get selectedMerchantKeys => _merchants;
  bool get hasSelectedMerchants => _merchants.isNotEmpty;

  /// Rubros que le interesan al usuario (por defecto, todos).
  Set<DiscountRubro> get rubros => _rubros;

  /// Sólo Mis comercios (y las promos sin comercio puntual). Sin ninguno
  /// marcado se muestra todo.
  bool get onlyMine => _onlyMine;

  /// Provincia del usuario (la del clima), o null si no se sabe.
  String? get province => _province;
  set province(String? value) {
    if (value == _province) return;
    _province = value;
    notifyListeners();
  }

  /// Los comercios de las promos de los rubros elegidos que pueden valer en
  /// mi provincia, por nombre, para elegir "Mis comercios".
  List<DiscountMerchant> get merchants {
    final byKey = <String, DiscountMerchant>{};
    for (final d in _discounts) {
      if (d.isGeneric ||
          !_rubros.contains(d.rubro) ||
          !d.availableIn(_province)) {
        continue;
      }
      byKey.putIfAbsent(
        d.merchantKey,
        () => DiscountMerchant(
          key: d.merchantKey,
          name: d.merchant.trim(),
          rubro: d.rubro,
        ),
      );
    }
    return byKey.values.toList()..sort((a, b) => a.key.compareTo(b.key));
  }

  /// Cuándo se bajaron las promos (null: nunca).
  DateTime? get fetchedAt => _fetchedAt;
  bool get isLoading => _loading;

  /// Lee lo guardado y, si es de otro día, actualiza en segundo plano.
  Future<void> ensureLoaded() => _loaded ??= _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _selected = (prefs.getStringList(_prefsBanks) ?? const []).toSet();
      _merchants = (prefs.getStringList(_prefsMerchants) ?? const []).toSet();
      final rubros = prefs.getStringList(_prefsRubros);
      if (rubros != null) {
        _rubros = {
          for (final r in DiscountRubro.values)
            if (rubros.contains(r.name)) r,
        };
      }
      _onlyMine = prefs.getBool(_prefsOnlyMine) ?? true;
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
      final pages = <(DiscountRubro?, String)>[
        for (final body in await _fetchPages(
          '$_base/v2/filter?slot_ids=$_slot',
        ))
          (null, body),
      ];
      for (final e in _searches.entries) {
        try {
          for (final body in await _fetchPages(
            '$_base/v2/search?query=${e.value}',
          )) {
            pages.add((e.key, body));
          }
        } catch (err) {
          // Un rubro que falla no tira los demás.
          debugPrint('[Descuentos] No se pudo bajar ${e.value}: $err');
        }
      }
      // Cientos de KB: se arman en otro hilo.
      final discounts = await Isolate.run(() => parseModoRubroPages(pages));
      if (discounts.isNotEmpty) {
        _banks = banks;
        _discounts = discounts;
        _fetchedAt = now;
        await _writeCache();
      }
      debugPrint(
        '[Descuentos] ${discounts.length} promos, ${banks.length} bancos',
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

  /// Todas las páginas de [url] (`/v2/filter` o `/v2/search`).
  Future<List<String>> _fetchPages(String url) async {
    final bodies = <String>[];
    for (var page = 1; page <= _maxPages; page++) {
      final body = await _get(
        '$url&limit=$_pageSize&page=$page&source=web_modo&origin=WEB_MODO',
      );
      bodies.add(body);
      final pages = (jsonDecode(body) as Map)['pagination']?['total_pages'];
      if (pages is! num || page >= pages) break;
    }
    return bodies;
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

  /// Desmarca todos los bancos y billeteras.
  Future<void> clearBanks() async {
    if (_selected.isEmpty) return;
    _selected = const {};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsBanks, const []);
  }

  /// Marca o desmarca un comercio como propio.
  Future<void> toggleMerchant(String key) async {
    final next = {..._merchants};
    if (!next.remove(key)) next.add(key);
    _merchants = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsMerchants, next.toList());
  }

  /// Desmarca todos los comercios.
  Future<void> clearMerchants() async {
    if (_merchants.isEmpty) return;
    _merchants = const {};
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsMerchants, const []);
  }

  /// Prende o apaga un rubro.
  Future<void> toggleRubro(DiscountRubro rubro) async {
    final next = {..._rubros};
    if (!next.remove(rubro)) next.add(rubro);
    _rubros = next;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsRubros, [for (final r in next) r.name]);
  }

  /// Sólo Mis comercios o todos.
  Future<void> setOnlyMine(bool value) async {
    if (value == _onlyMine) return;
    _onlyMine = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsOnlyMine, value);
  }

  /// Se muestra con los filtros del usuario (rubro, provincia, comercios).
  /// Los bancos los filtra [bestPerMerchant].
  bool isVisible(Discount d) {
    if (!_rubros.contains(d.rubro) || !d.availableIn(_province)) return false;
    if (!_onlyMine || _merchants.isEmpty || d.isGeneric) return true;
    return _merchants.contains(d.merchantKey);
  }

  /// Los descuentos de [day] con los bancos elegidos y los filtros del
  /// usuario: el mejor primero, uno por comercio. Con [rubro], sólo ese.
  List<Discount> discountsOn(DateTime day, {DiscountRubro? rubro}) =>
      bestPerMerchant(
        [
          for (final d in _discounts)
            if (isVisible(d) && (rubro == null || d.rubro == rubro)) d,
        ],
        day,
        _selected,
      );

  /// Los próximos [days] días desde [from] (hoy, mañana…).
  List<DayDiscounts> week(
    DateTime from, {
    int days = 7,
    DiscountRubro? rubro,
  }) => [
    for (var i = 0; i < days; i++)
      () {
        final day = DateTime(from.year, from.month, from.day + i);
        return DayDiscounts(
          day: day,
          discounts: discountsOn(day, rubro: rubro),
        );
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
    // De otra versión (p. ej. sin rubros): se usa hasta bajar la nueva.
    _fetchedAt = data['version'] == _cacheVersion
        ? DateTime.tryParse(data['fetchedAt']?.toString() ?? '')
        : null;
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
      'version': _cacheVersion,
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
    _merchants = const {};
    _rubros = DiscountRubro.values.toSet();
    _onlyMine = true;
    _province = null;
    _fetchedAt = null;
    _loading = false;
    _loaded = null;
  }
}

/// Arma las promos de las páginas del carrusel de supermercados
/// (`/v2/filter`, una por respuesta). Pura: corre en otro hilo.
List<Discount> parseModoPages(List<String> bodies) =>
    parseModoRubroPages([for (final b in bodies) (null, b)]);

/// Arma las promos de páginas de MODO. Cada página va con el rubro que se
/// buscó: de una búsqueda (`/v2/search?query=farmacia`) sólo quedan las de
/// ese rubro; con `null` (el carrusel de supermercados) quedan todas, y las
/// que no dicen otro rubro son de supermercados. Pura: corre en otro hilo.
List<Discount> parseModoRubroPages(List<(DiscountRubro?, String)> pages) {
  final out = <Discount>[];
  final ids = <String>{};
  for (final (rubro, body) in pages) {
    final data = jsonDecode(body);
    if (data is! Map<String, dynamic>) continue;
    for (final card in (data['cards'] as List? ?? const [])) {
      if (card is! Map<String, dynamic>) continue;
      final d = Discount.fromModoCard(
        card,
        fallback: rubro == null ? DiscountRubro.supermercados : null,
      );
      if (d == null || (rubro != null && d.rubro != rubro)) continue;
      if (ids.add(d.id)) out.add(d);
    }
  }
  return out;
}
