// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E326E), Color(0xFF0F1D42)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
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
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.construction,
                              color: Color(0xFF1E326E),
                              size: 52,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: Text(
                            'RateBridge',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          'Smart Material Procurement',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: FadeTransition(
                opacity: _loaderFade,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 2,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(1),
                        child: const LinearProgressIndicator(
                          color: Color(0xFFFBB03C),
                          backgroundColor: Color(0x33FFFFFF),
                          minHeight: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Pakistan\'s B2B Construction Platform',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFBB03C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'v1.0',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
