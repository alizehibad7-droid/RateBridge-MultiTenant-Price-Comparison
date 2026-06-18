import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../constants/route_names.dart';

class SupplierNavBar extends StatelessWidget {
  final int currentIndex;

  const SupplierNavBar({super.key, required this.currentIndex});

  static const _routes = [
    RouteNames.supplierDashboard,
    RouteNames.supplierMaterials,
    RouteNames.supplierOrders,
    RouteNames.supplierChat,
    RouteNames.supplierEarnings,
    RouteNames.supplierProfile,
  ];

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (i) {
        if (i == currentIndex) return;
        context.go(_routes[i]);
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
        NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined), label: 'Materials'),
        NavigationDestination(
            icon: Icon(Icons.receipt_outlined), label: 'Orders'),
        NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
        NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            label: 'Earnings'),
        NavigationDestination(
            icon: Icon(Icons.person_outline), label: 'Profile'),
      ],
    );
  }
}
