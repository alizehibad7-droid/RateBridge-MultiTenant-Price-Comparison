/// Default grade/type options when admin has not defined grades for a category.
class MaterialFormDefaults {
  MaterialFormDefaults._();

  static const otherBrandLabel = 'Other';

  static const deliveryTimes = [
    'Same Day',
    'Next Day',
    '2-3 Days',
    'Within a Week',
  ];

  static const stockStatuses = [
    'Available',
    'Limited Stock',
    'Out of Stock',
  ];

  /// Maps stored delivery-time strings (including older labels) onto [deliveryTimes].
  static String? canonicalDeliveryTime(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    for (final option in deliveryTimes) {
      if (option.toLowerCase() == value.toLowerCase()) return option;
    }
    final lower = value.toLowerCase();
    if (lower == '24 hours' || lower == '24 hour' || lower == 'next-day') {
      return 'Next Day';
    }
    if (lower == '2-3 day') return '2-3 Days';
    if (lower.contains('week')) return 'Within a Week';
    if (lower.contains('same')) return 'Same Day';
    return value;
  }

  static List<String> uniqueOptions(List<String> items) {
    final seen = <String>{};
    final out = <String>[];
    for (final item in items) {
      if (seen.add(item)) out.add(item);
    }
    return out;
  }

  static List<String> gradesForCategory(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('cement')) {
      return const ['OPC', 'SRC', 'PPC'];
    }
    if (name.contains('steel')) {
      return const ['Grade 40', 'Grade 60'];
    }
    if (name.contains('brick')) {
      return const ['A-Class', 'B-Class'];
    }
    if (name.contains('sand') || name.contains('aggregate')) {
      return const ['Fine', 'Coarse'];
    }
    if (name.contains('paint')) {
      return const ['Interior', 'Exterior'];
    }
    if (name.contains('tile')) {
      return const ['Ceramic', 'Porcelain'];
    }
    return const [];
  }
}
