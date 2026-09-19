class ChannelGroup {
  final String id;
  final String name;
  final String icon;
  final String type;
  final List<String> channelIds;

  ChannelGroup({
    required this.id,
    required this.name,
    required this.icon,
    required this.type,
    required this.channelIds,
  });

  bool get isDeletable => type == 'custom' || id.startsWith('custom_');

  factory ChannelGroup.fromJson(Map<String, dynamic> json) {
    return ChannelGroup(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      icon: json['icon'] as String? ?? '',
      type: json['type'] as String? ?? '',
      channelIds:
          (json['channelIds'] as List?)?.map((e) => e.toString()).toList() ??
              [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'type': type,
      'channelIds': channelIds,
    };
  }
}

