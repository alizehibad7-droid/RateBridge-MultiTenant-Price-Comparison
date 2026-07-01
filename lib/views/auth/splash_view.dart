// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SplashView extends StatefulWidget {
  const SplashView({super.key});

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleFade;
  late final Animation<double> _taglineFade;
  late final Animation<double> _loaderFade;
  late final Animation<Offset> _titleSlide;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeIn),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.6, curve: Curves.easeIn),
      ),
    );

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.8, curve: Curves.easeIn),
      ),
    );

    _loaderFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.7, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    // Step 1: hold on the splash long enough for the animation + branding
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    // Step 2: resolve auth state
    final authVm = context.read<AuthViewModel>();
    await authVm.checkAuthState();

    if (!mounted) return;

    _routeByAuthState(authVm);
  }

  void _routeByAuthState(AuthViewModel authVm) {
    if (authVm.user == null) {
      context.go(RouteNames.login);
      return;
    }

    // Normalize role string to handle variations like 'field_user' vs 'fielduser'
    final role = authVm.user?.role.toLowerCase().replaceAll(' ', '').replaceAll('_', '');
    final status = (authVm.user?.status ?? 'pending').toLowerCase();

    switch (role) {
      case 'admin':
      case 'administrator':
        context.go(RouteNames.adminDashboard);
        break;

      case 'ceo':
        if (status == 'active') {
          context.go(RouteNames.ceoDashboard);
        } else {
          context.go(RouteNames.ceoPending);
        }
        break;

      case 'supplier':
        if (status == 'active') {
          context.go(RouteNames.supplierDashboard);
        } else {
          context.go(RouteNames.supplierPending);
        }
        break;

      case 'fielduser':
        switch (status) {
          case 'active':
            context.go(RouteNames.fieldHome);
            break;
          case 'pending':
            context.go(RouteNames.pendingApproval);
            break;
          case 'rejected':
            context.go(RouteNames.rejected);
            break;
          case 'suspended':
          case 'deactivated':
            context.go(RouteNames.suspended);
            break;
          default:
            context.go(RouteNames.login);
        }
        break;

      default:
        context.go(RouteNames.login);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background image of a construction site
          Image.asset(
            'assets/images/construction_bg.jpg',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.primaryDark, Color(0xFF060D1A)],
                ),
              ),
            ),
          ),

          // Dark overlay for text contrast
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
            ),
          ),

          // Subtle gradient toward bottom for extra depth
          Container(
            decoration: const BoxDecoration(
              gradient: AppColors.heroOverlay,
            ),
          ),

          // Centered animated content
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1.2,
                            ),
                          ),
                          child: const Icon(
                            Icons.architecture,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeTransition(
                      opacity: _titleFade,
                      child: SlideTransition(
                        position: _titleSlide,
                        child: const Text(
                          'RateBridge',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _taglineFade,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          'Smart Procurement. Real-time Prices.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.75),
                            letterSpacing: 0.4,
                            fontFamily: 'Inter',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 48),
                    FadeTransition(
                      opacity: _loaderFade,
                      child: const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Bottom version / branding strip
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _loaderFade,
              child: Center(
                child: Text(
                  'Built for Pakistan\'s construction industry',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 0.6,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
