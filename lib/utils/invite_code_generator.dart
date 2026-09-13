import 'dart:math';

class InviteCodeGenerator {
  InviteCodeGenerator._();

  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// Generates a code like "RB-X7K2PQ" (6 chars after the prefix).
  static String generate({String prefix = 'RB', int length = 6}) {
    final rand = Random.secure();
    final code = List.generate(
      length,
      (_) => _chars[rand.nextInt(_chars.length)],
    ).join();
    return '$prefix-$code';
  }
}
