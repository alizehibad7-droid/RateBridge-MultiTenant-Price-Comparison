import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';
import '../../viewmodels/auth_viewmodel.dart';

class SplashView extends StatefulWidget {
  final bool autoNavigate;

  const SplashView({super.key, this.autoNavigate = true});

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

    if (widget.autoNavigate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _init());
    }
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.navy, AppColors.navyDark],
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
                              color: AppColors.navy,
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
                            style: textTheme.displayMedium?.copyWith(
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
                          style: textTheme.bodyMedium?.copyWith(
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
                        child: LinearProgressIndicator(
                          color: AppColors.amber,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
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
                              style: textTheme.labelSmall?.copyWith(
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
                                  color: AppColors.amber,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'v1.0',
                                style: textTheme.labelSmall?.copyWith(
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
