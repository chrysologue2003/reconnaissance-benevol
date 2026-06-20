class BadgeModel {
  final String badgeId;
  final String name;
  final String icon;
  final String description;
  final String condition;
  final int requiredPoints;

  BadgeModel({
    required this.badgeId,
    required this.name,
    required this.icon,
    required this.description,
    required this.condition,
    required this.requiredPoints,
  });

  factory BadgeModel.fromMap(Map<String, dynamic> data, String id) {
    return BadgeModel(
      badgeId: id,
      name: data['nom'] as String? ?? '',
      icon: data['icone'] as String? ?? 'emoji_events',
      description: data['description'] as String? ?? '',
      condition: data['condition'] as String? ?? '',
      requiredPoints: (data['points requis'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nom': name,
      'icone': icon,
      'description': description,
      'condition': condition,
      'points requis': requiredPoints,
    };
  }
}
