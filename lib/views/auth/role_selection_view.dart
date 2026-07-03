// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/route_names.dart';

class _RoleOption {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconBackground;
  final Color iconColor;
  final String route;

  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconBackground,
    required this.iconColor,
    required this.route,
  });
}

const _navy = Color(0xFF1E326E);
const _amber = Color(0xFFFBB03C);
const _green = Color(0xFF1D9E75);
const _screenBg = Color(0xFFF5F6FA);

const _roles = <_RoleOption>[
  _RoleOption(
    icon: Icons.store_outlined,
    title: 'Material Supplier',
    subtitle:
        'List and sell construction materials to verified companies',
    iconBackground: Color(0x26FBB03C),
    iconColor: _amber,
    route: RouteNames.registerSupplier,
  ),
  _RoleOption(
    icon: Icons.business_outlined,
    title: 'Company / CEO',
    subtitle: 'Register your company and manage procurement',
    iconBackground: Color(0x1A1E326E),
    iconColor: _navy,
    route: RouteNames.registerCEO,
  ),
  _RoleOption(
    icon: Icons.engineering_outlined,
    title: 'Field Employee',
    subtitle: 'Join your company using an invite code from your CEO',
    iconBackground: Color(0x1A1D9E75),
    iconColor: _green,
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

  void _onBack() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _screenBg,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: 220,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1E326E), Color(0xFF0F1D42)],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Stack(
                      children: [
                        Positioned(
                          left: 4,
                          top: 0,
                          child: IconButton(
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            onPressed: _onBack,
                          ),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 96,
                                  height: 96,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Icon(
                                    Icons.construction,
                                    color: _navy,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Welcome to RateBridge',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Select how you want to continue',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
            ],
          ),
          Positioned(
            top: 200,
            left: 0,
            right: 0,
            bottom: 0,
            child: SingleChildScrollView(
              child: Container(
                decoration: const BoxDecoration(
                  color: _screenBg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FadeTransition(
                      opacity: _fade(0),
                      child: Text(
                        'I am a...',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (var i = 0; i < _roles.length; i++) ...[
                      FadeTransition(
                        opacity: _fade(i + 1),
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(_fade(i + 1)),
                          child: _RoleCard(
                            option: _roles[i],
                            onTap: () => context.push(_roles[i].route),
                          ),
                        ),
                      ),
                      if (i < _roles.length - 1) const SizedBox(height: 14),
                    ],
                    const SizedBox(height: 32),
                    FadeTransition(
                      opacity: _fade(_roles.length + 1),
                      child: Column(
                        children: [
                          Text(
                            'Already have an account?',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => context.push(RouteNames.login),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _navy,
                                side: const BorderSide(color: _navy, width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Sign In',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'By continuing you agree to RateBridge\'s',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            'Terms of Service & Privacy Policy',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: _amber,
                              decoration: TextDecoration.underline,
                              decorationColor: _amber,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
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
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: option.iconBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        option.icon,
                        color: option.iconColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: _navy,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            option.subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey.shade400,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
