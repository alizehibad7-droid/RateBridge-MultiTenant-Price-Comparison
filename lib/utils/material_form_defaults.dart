/// Default grade/type options when admin has not defined grades for a category.
class MaterialFormDefaults {
  MaterialFormDefaults._();

  static const otherBrandLabel = 'Other';

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
