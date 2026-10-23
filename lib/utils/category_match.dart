/// Normalized category matching for marketplace filters and compare lookups.
///
/// Handles case, whitespace, simple singular/plural, and known catalog aliases
/// so materials like "Brick" still appear under the "Bricks" chip.
String normalizeCategoryKey(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String canonicalCategoryKey(String value) {
  final key = normalizeCategoryKey(value);
  if (key.isEmpty) return '';

  const aliases = <String, String>{
    'brick': 'bricks',
    'bricks': 'bricks',
    'steel': 'steel',
    'tmt': 'steel',
    'tmt bars': 'steel',
    'steel / tmt bars': 'steel',
    'steel bars': 'steel',
    'pipe': 'pipes',
    'pipes': 'pipes',
    'pipes (pvc/gi)': 'pipes',
    'pvc': 'pipes',
    'timber': 'timber',
    'wood': 'timber',
    'timber / wood': 'timber',
    'crush': 'crush',
    'aggregate': 'crush',
    'aggregates': 'crush',
    'crush / aggregate': 'crush',
    'electrical': 'electrical',
    'electrical wire & cable': 'electrical',
    'wire': 'electrical',
    'cable': 'electrical',
    'sanitary': 'sanitary',
    'sanitary ware': 'sanitary',
  };

  if (aliases.containsKey(key)) return aliases[key]!;

  // "Steel / TMT Bars" → try first segment before slash/paren.
  final head = key.split(RegExp(r'[/(]')).first.trim();
  if (aliases.containsKey(head)) return aliases[head]!;

  // Simple English plural: brick ↔ bricks
  if (key.endsWith('s') && key.length > 1) {
    final singular = key.substring(0, key.length - 1);
    if (aliases.containsKey(singular)) return aliases[singular]!;
    return key;
  }
  final plural = '${key}s';
  if (aliases.containsKey(plural)) return aliases[plural]!;

  return key;
}

bool categoriesMatch(String a, String b) {
  final ca = canonicalCategoryKey(a);
  final cb = canonicalCategoryKey(b);
  if (ca.isEmpty || cb.isEmpty) return false;
  if (ca == cb) return true;

  // Allow "steel" filter to match "steel / tmt bars" style labels.
  final na = normalizeCategoryKey(a);
  final nb = normalizeCategoryKey(b);
  return na == nb ||
      na.startsWith('$nb ') ||
      nb.startsWith('$na ') ||
      na.startsWith('$nb/') ||
      nb.startsWith('$na/') ||
      na.contains(' $nb ') ||
      nb.contains(' $na ');
}
