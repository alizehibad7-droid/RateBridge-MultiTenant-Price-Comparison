import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';

/// Full-width primary button with built-in loading spinner state.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;

  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.color = AppColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.2,
                ),
              )
            : Text(label, style: AppTextStyles.button),
      ),
    );
  }
}

/// Small rounded "Step X of Y" pill shown in form headers.
class StepBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StepBadge({super.key, required this.label, this.color = AppColors.amber});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        style: AppTextStyles.caption.copyWith(
          color: color == AppColors.amber ? AppColors.navy : color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// "Icon + bold title + grey subtitle" trust row used below auth forms.
class TrustInfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const TrustInfoRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = AppColors.amber,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.navy, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.h3.copyWith(fontSize: 14)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared "© year RateBridge — Privacy | Terms" footer.
class AuthFooter extends StatelessWidget {
  const AuthFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '© ${DateTime.now().year} RateBridge. All rights reserved.',
          style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: () {},
              child: Text(
                'Privacy Policy',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ),
            Text('|',
                style: AppTextStyles.bodyMuted.copyWith(fontSize: 12)),
            TextButton(
              onPressed: () {},
              child: Text(
                'Terms of Service',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
