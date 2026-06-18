// MVVM: View — no business logic

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../../constants/app_colors.dart';
import 'field_marketplace_view.dart';
import 'field_orders_view.dart';
import 'field_profile_view.dart';

/// Top-level shell for the field user role. Bottom navigation between
/// Marketplace (Home), My Orders, and Profile. companyId is fixed at
/// signup — there is no company switcher anywhere in this shell.
class FieldShellView extends StatefulWidget {
  const FieldShellView({super.key});

  @override
  State<FieldShellView> createState() => _FieldShellViewState();
}

class _FieldShellViewState extends State<FieldShellView> {
  int _index = 0;

  static const _pages = [
    FieldMarketplaceView(),
    FieldOrdersView(),
    FieldProfileView(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.fieldAccent.withOpacity(0.12),
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined,
                color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.storefront, color: AppColors.fieldAccent),
            label: 'Marketplace',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined,
                color: AppColors.textSecondary),
            selectedIcon:
                Icon(Icons.receipt_long, color: AppColors.fieldAccent),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline, color: AppColors.textSecondary),
            selectedIcon: Icon(Icons.person, color: AppColors.fieldAccent),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
