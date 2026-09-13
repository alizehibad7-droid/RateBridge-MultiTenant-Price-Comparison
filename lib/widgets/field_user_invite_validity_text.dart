import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/ceo_theme.dart';
import '../utils/field_user_invite_code.dart';

/// Live remaining time / expired status for a field-user company invite code.
class FieldUserInviteValidityText extends StatefulWidget {
  final DateTime? generatedAt;
  final TextAlign textAlign;

  const FieldUserInviteValidityText({
    super.key,
    required this.generatedAt,
    this.textAlign = TextAlign.start,
  });

  @override
  State<FieldUserInviteValidityText> createState() =>
      _FieldUserInviteValidityTextState();
}

class _FieldUserInviteValidityTextState
    extends State<FieldUserInviteValidityText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _syncTimer();
  }

  @override
  void didUpdateWidget(FieldUserInviteValidityText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.generatedAt != widget.generatedAt) {
      _syncTimer();
    }
  }

  void _syncTimer() {
    _timer?.cancel();
    if (FieldUserInviteCode.isExpired(widget.generatedAt)) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (FieldUserInviteCode.isExpired(widget.generatedAt)) {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired = FieldUserInviteCode.isExpired(widget.generatedAt);
    return Text(
      FieldUserInviteCode.statusLabel(widget.generatedAt),
      textAlign: widget.textAlign,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: expired ? CeoColors.red : CeoColors.textGrey,
      ),
    );
  }
}
