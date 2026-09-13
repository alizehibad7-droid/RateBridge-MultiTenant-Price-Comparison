import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the device phone dialer with a pre-filled number.
class PhoneLauncherUtils {
  PhoneLauncherUtils._();

  static Future<void> dial(BuildContext context, String? phone) async {
    final trimmed = phone?.trim() ?? '';
    if (trimmed.isEmpty) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not available')),
      );
      return;
    }

    final uri = Uri(scheme: 'tel', path: trimmed);
    if (!await launchUrl(uri) && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open phone dialer')),
      );
    }
  }
}
