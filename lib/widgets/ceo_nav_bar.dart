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
    '/ceo/profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) {
          if (i == currentIndex) return;
          context.go(_routes[i]);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store_outlined),
            activeIcon: Icon(Icons.store_rounded),
            label: 'Suppliers',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_add_outlined),
            activeIcon: Icon(Icons.person_add_rounded),
            label: 'Invite',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.group_outlined),
            activeIcon: Icon(Icons.group_rounded),
            label: 'Field Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
