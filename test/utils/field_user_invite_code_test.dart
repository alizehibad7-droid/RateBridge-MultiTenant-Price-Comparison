import 'package:flutter_test/flutter_test.dart';
import 'package:ratebridge/utils/field_user_invite_code.dart';

void main() {
  final generated = DateTime.utc(2026, 9, 7, 12, 0);

  test('is expired at and after 30 minutes', () {
    expect(
      FieldUserInviteCode.isExpired(
        generated,
        now: generated.add(const Duration(minutes: 29, seconds: 59)),
      ),
      isFalse,
    );
    expect(
      FieldUserInviteCode.isExpired(
        generated,
        now: generated.add(const Duration(minutes: 30)),
      ),
      isTrue,
    );
  });

  test('missing timestamp is expired', () {
    expect(FieldUserInviteCode.isExpired(null), isTrue);
  });

  test('status label reports remaining minutes then expired', () {
    expect(
      FieldUserInviteCode.statusLabel(
        generated,
        now: generated.add(const Duration(minutes: 5, seconds: 4)),
      ),
      'Valid for 24m 56s',
    );
    expect(
      FieldUserInviteCode.statusLabel(
        generated,
        now: generated.add(const Duration(minutes: 31)),
      ),
      'Expired — regenerate a new code',
    );
  });
}
