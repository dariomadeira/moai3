/// Un banco o billetera de MODO que el usuario puede marcar como suyo.
class DiscountBank {
  const DiscountBank({required this.id, required this.name, this.imageUrl});

  final String id;
  final String name;
  final String? imageUrl;

  factory DiscountBank.fromJson(Map<String, dynamic> json) => DiscountBank(
    id: json['id']?.toString() ?? '',
    name: (json['name']?.toString() ?? '').trim(),
    imageUrl: json['image']?.toString(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (imageUrl != null) 'image': imageUrl,
  };
}

/// Cada cuánto se renueva el tope de reintegro.
enum DiscountCapPeriod { day, week, month, none }

/// Una promo de MODO en un comercio: cuánto, cuándo, con qué bancos y medios.
class Discount {
  const Discount({
    required this.id,
    required this.merchant,
    required this.benefit,
    this.percent,
    this.installments = 0,
    this.cap,
    this.capPeriod = DiscountCapPeriod.none,
    this.weekdays = const {},
    this.start,
    this.stop,
    this.bankIds = const {},
    this.bankLabel = '',
    this.cardBrands = const [],
    this.instore = true,
    this.online = false,
  });

  final String id;

  /// Dónde vale ("Coto", "Supermercados TODO").
  final String merchant;

  /// Cómo lo dice MODO ("20% de reintegro", "10% y 3 cuotas").
  final String benefit;

  /// Porcentaje de reintegro o descuento, si lo hay.
  final double? percent;

  /// Cuotas sin interés (0: ninguna).
  final int installments;

  /// Tope de reintegro en pesos (null: sin tope informado).
  final double? cap;
  final DiscountCapPeriod capPeriod;

  /// Días de la semana en que vale (1 = lunes … 7 = domingo); vacío: todos.
  final Set<int> weekdays;

  /// Vigencia, por día (inclusive). null: sin límite de ese lado.
  final DateTime? start;
  final DateTime? stop;

  /// Bancos con los que vale (ids de MODO); vacío: cualquiera.
  final Set<String> bankIds;

  /// Cómo lo muestra MODO ("BNA", "Bancos adheridos").
  final String bankLabel;

  /// Marcas de tarjeta que acepta ("Mastercard", "Visa"…), sin repetir.
  final List<String> cardBrands;

  /// Vale en el local y/o en compras en línea.
  final bool instore;
  final bool online;

  /// Vale ese día (fecha y día de la semana).
  bool validOn(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (start != null && d.isBefore(start!)) return false;
    if (stop != null && d.isAfter(stop!)) return false;
    return weekdays.isEmpty || weekdays.contains(d.weekday);
  }

  /// Sirve con alguno de [banks] (o con cualquiera, si no pide uno).
  bool acceptsAny(Set<String> banks) =>
      bankIds.isEmpty || bankIds.any(banks.contains);

  /// De una tarjeta de la API de MODO (`/v2/filter`). null si no se entiende.
  static Discount? fromModoCard(Map<String, dynamic> json) {
    try {
      final card = _map(json['card']);
      final benefit = _map(json['benefit']);
      final offer = _map(json['offer']);
      final conditions = _map(benefit['conditions']);
      final schedule = _map(conditions['schedule']);
      final outcomes = _map(offer['outcomes']);
      final cashback = _map(outcomes['cashback']);
      final financing = _map(outcomes['financing']);
      final limits = _map(offer['limits']);
      final periodCap = _map(limits['period_cap']);
      final requirements = _map(offer['requirements']);

      final merchant = (card['validity_place']?.toString() ?? '').trim();
      final text = (card['benefit']?.toString() ?? '').trim();
      if (merchant.isEmpty || text.isEmpty) return null;

      double? percent;
      if (cashback['amount_type'] == 'percent') {
        percent = (cashback['amount'] as num?)?.toDouble();
      }
      percent ??= double.tryParse(
        RegExp(
              r'(\d+(?:[.,]\d+)?)\s*%',
            ).firstMatch(text)?.group(1)?.replaceAll(',', '.') ??
            '',
      );

      // Cuotas sin interés: la mayor cantidad que ofrece.
      final installments = [
        for (final i in (financing['installments'] as List? ?? const []))
          if (i is Map && i['type'] == 'sin_interes')
            (i['number'] as num?)?.toInt() ?? 0,
      ].fold<int>(0, (a, b) => b > a ? b : a);

      final capValue =
          (periodCap['amount_by_period'] as num?)?.toDouble() ??
          double.tryParse(card['cashback_cap']?.toString() ?? '');

      final brands = <String>{};
      final methods = _map(conditions['payment_methods'])['methods'];
      for (final m in (methods as List? ?? const [])) {
        if (m is Map && m['issuer'] != null) {
          brands.add(_brand(m['issuer'].toString()));
        }
      }
      final flows =
          (_map(conditions['payment_flow'])['flows'] as List? ?? const [])
              .map((f) => f.toString())
              .toSet();

      return Discount(
        id:
            json['card_id']?.toString() ??
            benefit['id']?.toString() ??
            merchant,
        merchant: merchant,
        benefit: text,
        percent: percent,
        installments: installments,
        cap: capValue != null && capValue > 0 ? capValue : null,
        capPeriod: switch (periodCap['reset_by']) {
          'day' => DiscountCapPeriod.day,
          'week' => DiscountCapPeriod.week,
          'month' => DiscountCapPeriod.month,
          _ => DiscountCapPeriod.none,
        },
        weekdays: {
          for (final d in (schedule['days_of_week'] as List? ?? const []))
            ?_weekday(d.toString()),
        },
        start: _date(schedule['start_date']),
        stop: _date(schedule['stop_date']),
        bankIds: {
          for (final b
              in (_map(requirements['banks'])['list'] as List? ?? const []))
            b.toString(),
        },
        bankLabel: (card['participating_bank']?.toString() ?? '').trim(),
        cardBrands: brands.toList()..sort(),
        instore: flows.isEmpty || flows.contains('instore'),
        online: flows.contains('online'),
      );
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'merchant': merchant,
    'benefit': benefit,
    if (percent != null) 'percent': percent,
    if (installments > 0) 'installments': installments,
    if (cap != null) 'cap': cap,
    'capPeriod': capPeriod.name,
    'weekdays': weekdays.toList()..sort(),
    if (start != null) 'start': start!.toIso8601String(),
    if (stop != null) 'stop': stop!.toIso8601String(),
    'banks': bankIds.toList(),
    'bankLabel': bankLabel,
    'brands': cardBrands,
    'instore': instore,
    'online': online,
  };

  factory Discount.fromJson(Map<String, dynamic> json) => Discount(
    id: json['id']?.toString() ?? '',
    merchant: json['merchant']?.toString() ?? '',
    benefit: json['benefit']?.toString() ?? '',
    percent: (json['percent'] as num?)?.toDouble(),
    installments: (json['installments'] as num?)?.toInt() ?? 0,
    cap: (json['cap'] as num?)?.toDouble(),
    capPeriod: DiscountCapPeriod.values.firstWhere(
      (p) => p.name == json['capPeriod'],
      orElse: () => DiscountCapPeriod.none,
    ),
    weekdays: {
      for (final d in (json['weekdays'] as List? ?? const []))
        if (d is num) d.toInt(),
    },
    start: DateTime.tryParse(json['start']?.toString() ?? ''),
    stop: DateTime.tryParse(json['stop']?.toString() ?? ''),
    bankIds: {
      for (final b in (json['banks'] as List? ?? const [])) b.toString(),
    },
    bankLabel: json['bankLabel']?.toString() ?? '',
    cardBrands: [
      for (final b in (json['brands'] as List? ?? const [])) b.toString(),
    ],
    instore: json['instore'] as bool? ?? true,
    online: json['online'] as bool? ?? false,
  );

  static Map<String, dynamic> _map(Object? o) =>
      o is Map<String, dynamic> ? o : const {};

  static DateTime? _date(Object? raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '');
    return d == null ? null : DateTime(d.year, d.month, d.day);
  }

  static int? _weekday(String name) => switch (name.toLowerCase()) {
    'monday' => DateTime.monday,
    'tuesday' => DateTime.tuesday,
    'wednesday' => DateTime.wednesday,
    'thursday' => DateTime.thursday,
    'friday' => DateTime.friday,
    'saturday' => DateTime.saturday,
    'sunday' => DateTime.sunday,
    _ => null,
  };

  static String _brand(String issuer) => switch (issuer.toLowerCase()) {
    'master' || 'mastercard' => 'Mastercard',
    'amex' || 'american_express' => 'American Express',
    'dinners_club' || 'diners_club' => 'Diners Club',
    // "patagonia_365" → "Patagonia 365".
    _ => issuer
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' '),
  };
}

/// Los descuentos de un día, el mejor primero.
class DayDiscounts {
  const DayDiscounts({required this.day, required this.discounts});

  final DateTime day;
  final List<Discount> discounts;

  Discount? get best => discounts.isEmpty ? null : discounts.first;
}
