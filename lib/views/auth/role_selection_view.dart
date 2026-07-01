// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';

class _RoleOption {
  final IconData icon;
  final String title;
  final String description;
  final String image;
  final Color accent;
  final String route;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.image,
    required this.accent,
    required this.route,
  });
}

const _roles = <_RoleOption>[
  _RoleOption(
    icon: Icons.architecture,
    title: 'I am a CEO',
    description:
        'Manage company and procurement operations at the highest level.',
    image: 'assets/images/ceo_bg.jpg',
    accent: AppColors.ceoAccent,
    route: RouteNames.registerCEO,
  ),
  _RoleOption(
    icon: Icons.inventory_2_outlined,
    title: 'I am a Supplier',
    description:
        'Sell construction materials and manage global distribution logistics.',
    image: 'assets/images/supplier_bg.jpg',
    accent: AppColors.supplierAccent,
    route: RouteNames.registerSupplier,
  ),
  _RoleOption(
    icon: Icons.group_outlined,
    title: 'I am a Field User',
    description:
        'Join my company team to manage site deliveries and inventory on-the-go.',
    image: 'assets/images/field_bg.jpg',
    accent: AppColors.fieldAccent,
    route: RouteNames.registerFieldUser,
  ),
];

class RoleSelectionView extends StatefulWidget {
  const RoleSelectionView({super.key});

  @override
  State<RoleSelectionView> createState() => _RoleSelectionViewState();
}

class _RoleSelectionViewState extends State<RoleSelectionView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Animation<double> _fade(int index) {
    final start = 0.08 * index;
    final end = (start + 0.55).clamp(0.0, 1.0);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, end, curve: Curves.easeOut),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go(RouteNames.login);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    FadeTransition(
                      opacity: _fade(0),
                      child: const Text(
                        'How will you use RateBridge?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: _fade(0),
                      child: Text(
                        'Select the profile that best describes your daily '
                        'activities to personalize your dashboard experience.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    for (var i = 0; i < _roles.length; i++) ...[
                      FadeTransition(
                        opacity: _fade(i + 1),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.12),
                            end: Offset.zero,
                          ).animate(_fade(i + 1)),
                          child: _RoleCard(
                            option: _roles[i],
                            onTap: () => context.push(_roles[i].route),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    FadeTransition(
                      opacity: _fade(_roles.length + 1),
                      child: Column(
                        children: [
                          Text(
                            'Not sure which one to pick?',
                            style: AppTextStyles.bodyMuted,
                          ),
                          TextButton(
                            onPressed: () {},
                            child: const Text(
                              'Contact Support',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final _RoleOption option;
  final VoidCallback onTap;

  const _RoleCard({required this.option, required this.onTap});

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final option = widget.option;
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: appCardDecoration(shadow: AppShadows.card),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Icon(option.icon, color: option.accent, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                option.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                option.description,
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMuted,
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.asset(
                  option.image,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 130,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          option.accent.withOpacity(0.18),
                          option.accent.withOpacity(0.45),
                        ],
                      ),
                    ),
                    child: Icon(
                      option.icon,
                      color: Colors.white.withOpacity(0.85),
                      size: 36,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
