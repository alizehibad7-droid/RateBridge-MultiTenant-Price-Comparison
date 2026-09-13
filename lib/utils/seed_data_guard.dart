class SeedDataGuard {
  static bool isSeedId(String? id) {
    if (id == null || id.isEmpty) return false;
    return id.startsWith('seed_') || id.contains('_seed_');
  }
}
