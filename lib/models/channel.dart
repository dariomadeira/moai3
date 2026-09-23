class Channel {
  final String id;
  final String name;
  final String logoUrl;
  final String country;
  final String category;
  final Map<String, String>? customHeaders;
  final List<String> fallbackUrls;

  /// Solo para canales aportados por un plugin `.dex`.
  final String? pluginId;
  final String? pluginChannelId;
  final String? pluginName;
  final String? pluginTag;

  Channel({
    required this.id,
    required this.name,
    required this.logoUrl,
    required this.fallbackUrls,
    this.country = 'General',
    this.category = 'General',
    this.customHeaders,
    this.pluginId,
    this.pluginChannelId,
    this.pluginName,
    this.pluginTag,
  });

  /// Primera URL del catálogo (puede ser no reproducible; usar helpers en playback).
  String get url => fallbackUrls.isNotEmpty ? fallbackUrls.first : '';

  /// Un canal-plugin no tiene URL estática: la resuelve el plugin en runtime.
  bool get isPluginChannel => pluginId != null && pluginChannelId != null;

  /// Indica si el canal corresponde a contenido para adultos sujeto a control parental.
  bool get isAdult {
    final cat = category.trim().toLowerCase();
    final cnt = country.trim().toLowerCase();
    final n = name.toLowerCase();
    return cat == 'adultos' ||
        cnt == 'adultos' ||
        n.contains('18+') ||
        n.contains('+18');
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    final urls = <String>[];

    if (json['fallbackUrls'] != null) {
      urls.addAll(
        (json['fallbackUrls'] as List).map((e) => e.toString()),
      );
    }

    final streamUrl = json['streamUrl'] as String?;
    if (streamUrl != null && streamUrl.isNotEmpty && !urls.contains(streamUrl)) {
      urls.insert(0, streamUrl);
    }

    final legacyUrl = json['url'] as String?;
    if (legacyUrl != null && legacyUrl.isNotEmpty && !urls.contains(legacyUrl)) {
      urls.add(legacyUrl);
    }

    return Channel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      logoUrl: json['logoUrl'] as String? ?? '',
      fallbackUrls: urls,
      country: (json['country'] as String?)?.trim().isNotEmpty == true
          ? (json['country'] as String).trim()
          : 'General',
      category: (json['category'] as String?)?.trim().isNotEmpty == true
          ? (json['category'] as String).trim()
          : 'General',
      pluginId: json['pluginId'] as String?,
      pluginChannelId: json['pluginChannelId'] as String?,
      pluginName: json['pluginName'] as String?,
      pluginTag: json['pluginTag'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'fallbackUrls': fallbackUrls,
      'logoUrl': logoUrl,
      'country': country,
      'category': category,
      if (pluginId != null) 'pluginId': pluginId,
      if (pluginChannelId != null) 'pluginChannelId': pluginChannelId,
      if (pluginName != null) 'pluginName': pluginName,
      if (pluginTag != null) 'pluginTag': pluginTag,
    };
  }
}

