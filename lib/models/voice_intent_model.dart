// MVVM: Model — pure Dart
class VoiceIntentModel {
  final String? material;
  final String action; // compare | order | trend | navigate | call
  final Map<String, dynamic> filters; // sort, city, priceMax
  final int? quantity;

  VoiceIntentModel({
    this.material,
    required this.action,
    required this.filters,
    this.quantity,
  });

  factory VoiceIntentModel.fromMap(Map<String, dynamic> map) => VoiceIntentModel(
    material: map['material'],
    action: map['action'] ?? 'compare',
    filters: Map<String, dynamic>.from(map['filters'] ?? {}),
    quantity: map['quantity'] != null ? (map['quantity'] as num).toInt() : null,
  );
}
