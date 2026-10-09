class ArcadeRomItem {
  final String id;
  final String name;
  final String filename;
  final String system;
  final String year;
  final String company;
  final int sizeBytes;
  final String sizeLabel;
  final String url;
  final String description;
  final bool isInstalled;
  final String? localPath;
  final int? localSizeBytes;

  const ArcadeRomItem({
    required this.id,
    required this.name,
    required this.filename,
    this.system = 'CPS-2',
    this.year = '',
    this.company = 'Capcom',
    this.sizeBytes = 0,
    this.sizeLabel = '',
    required this.url,
    this.description = '',
    this.isInstalled = false,
    this.localPath,
    this.localSizeBytes,
  });

  factory ArcadeRomItem.fromJson(Map<String, dynamic> json, {bool isInstalled = false, String? localPath, int? localSizeBytes}) {
    final size = json['pesoBytes'] ?? json['sizeBytes'] ?? 0;
    final label = json['pesoLabel'] ?? json['sizeLabel'] ?? '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return ArcadeRomItem(
      id: json['id'] as String? ?? json['archivo'] ?? json['filename'] ?? '',
      name: json['nombre'] as String? ?? json['name'] as String? ?? 'Arcade Game',
      filename: json['archivo'] as String? ?? json['filename'] as String? ?? '',
      system: json['sistema'] as String? ?? json['system'] as String? ?? 'CPS-2',
      year: json['año'] as String? ?? json['year'] as String? ?? '',
      company: json['empresa'] as String? ?? json['company'] as String? ?? 'Capcom',
      sizeBytes: size is int ? size : int.tryParse(size.toString()) ?? 0,
      sizeLabel: label.toString(),
      url: json['url'] as String? ?? '',
      description: json['descripcion'] as String? ?? json['description'] as String? ?? '',
      isInstalled: isInstalled,
      localPath: localPath,
      localSizeBytes: localSizeBytes,
    );
  }

  ArcadeRomItem copyWith({
    bool? isInstalled,
    String? localPath,
    int? localSizeBytes,
    String? url,
  }) {
    return ArcadeRomItem(
      id: id,
      name: name,
      filename: filename,
      system: system,
      year: year,
      company: company,
      sizeBytes: sizeBytes,
      sizeLabel: sizeLabel,
      url: url ?? this.url,
      description: description,
      isInstalled: isInstalled ?? this.isInstalled,
      localPath: localPath ?? this.localPath,
      localSizeBytes: localSizeBytes ?? this.localSizeBytes,
    );
  }
}
