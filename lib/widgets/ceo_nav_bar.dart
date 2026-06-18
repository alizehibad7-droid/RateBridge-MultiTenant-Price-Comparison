// Widget — atomic, reusable. No business logic.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CeoNavBar extends StatelessWidget {
  final int currentIndex;

  const CeoNavBar({super.key, required this.currentIndex});

  static const _routes = [
    '/ceo/dashboard',
    '/ceo/suppliers',
    '/ceo/invite',
    '/ceo/field-users',
    '/ceo/orders',
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
        NavigationDestination(
            icon: Icon(Icons.home_outlined), label: 'Dashboard'),
        NavigationDestination(
            icon: Icon(Icons.store_outlined), label: 'Suppliers'),
        NavigationDestination(
            icon: Icon(Icons.person_add_outlined), label: 'Invite'),
        NavigationDestination(
            icon: Icon(Icons.group_outlined), label: 'Field Users'),
        NavigationDestination(
            icon: Icon(Icons.receipt_outlined), label: 'Orders'),
      ],
    );
  }
}
