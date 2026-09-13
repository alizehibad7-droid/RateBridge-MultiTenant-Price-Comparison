import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/field_theme.dart';
import 'app_network_image.dart';

BoxDecoration profileSectionDecoration() {
  return BoxDecoration(
    color: FieldColors.surfaceWhite,
    borderRadius: BorderRadius.circular(FieldRadius.card),
    border: Border.all(color: FieldColors.borderSubtle),
    boxShadow: [
      BoxShadow(
        color: FieldColors.primaryNavy.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

class ProfileHeroHeader extends StatelessWidget {
  final double topPadding;
  final String initials;
  final String name;
  final String? subtitle;
  final String? imageUrl;
  final bool isUploadingImage;
  final VoidCallback onPickImage;

  const ProfileHeroHeader({
    super.key,
    required this.topPadding,
    required this.initials,
    required this.name,
    this.subtitle,
    this.imageUrl,
    required this.isUploadingImage,
    required this.onPickImage,
  });

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [FieldColors.primaryNavy, FieldColors.primaryNavyDark],
  );

  @override
  Widget build(BuildContext context) {
    const gradientHeight = 140.0;
    const avatarOverlap = 48.0;

    return Column(
      children: [
        SizedBox(
          height: topPadding + gradientHeight + avatarOverlap,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topPadding + gradientHeight,
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: _gradient),
                ),
              ),
              Positioned(
                top: topPadding + gradientHeight - avatarOverlap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: FieldColors.surfaceWhite,
                        border: Border.all(
                          color: FieldColors.surfaceWhite,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: AppNetworkImage(
                          url: imageUrl,
                          fit: BoxFit.cover,
                          width: 96,
                          height: 96,
                          debugLabel: 'profile-avatar',
                          loading: _initialsAvatar(),
                          fallback: _initialsAvatar(),
                        ),
                      ),
                    ),
                    if (isUploadingImage)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (!isUploadingImage)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: onPickImage,
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              color: FieldColors.accentAmber,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 14,
                              color: FieldColors.primaryNavy,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          name,
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: FieldColors.primaryNavy,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: FieldColors.accentAmber.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              subtitle!,
              style: GoogleFonts.plusJakartaSans(
                color: FieldColors.primaryNavy,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _initialsAvatar() {
    return Container(
      color: FieldColors.accentAmber,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: FieldColors.primaryNavy,
        ),
      ),
    );
  }
}

class ProfileSectionCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  const ProfileSectionCard({
    super.key,
    this.title,
    required this.children,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: profileSectionDecoration(),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: FieldColors.primaryNavy,
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...children,
        ],
      ),
    );
  }
}

class ProfileDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const ProfileDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: FieldColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    color: FieldColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: FieldColors.primaryNavy,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileSignOutCard extends StatelessWidget {
  final String label;
  final VoidCallback onSignOut;

  const ProfileSignOutCard({
    super.key,
    required this.onSignOut,
    this.label = 'Sign Out',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: FieldColors.surfaceWhite,
        borderRadius: BorderRadius.circular(FieldRadius.card),
        border: Border.all(color: FieldColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onSignOut,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: FieldColors.statusDanger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.logout,
                        size: 18,
                        color: FieldColors.statusDanger,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      label,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: FieldColors.statusDanger,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: SizedBox(
              width: 3,
              child: ColoredBox(color: FieldColors.statusDanger),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileVersionFooter extends StatelessWidget {
  final String caption;

  const ProfileVersionFooter({
    super.key,
    this.caption = 'Company Portal',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'RateBridge v1.0.0',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: FieldColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          caption,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            color: FieldColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
