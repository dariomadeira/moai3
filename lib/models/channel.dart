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
  });

  /// Primera URL del catálogo (puede ser no reproducible; usar helpers en playback).
  String get url => fallbackUrls.isNotEmpty ? fallbackUrls.first : '';

  /// Un canal-plugin no tiene URL estática: la resuelve el plugin en runtime.
  bool get isPluginChannel => pluginId != null && pluginChannelId != null;

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
      country: json['country'] as String? ?? 'General',
      category: json['category'] as String? ?? 'General',
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
    };
  }
}

