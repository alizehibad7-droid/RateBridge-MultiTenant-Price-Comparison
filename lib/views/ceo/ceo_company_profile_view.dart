import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../constants/route_names.dart';
import '../../theme/ceo_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../widgets/ceo_nav_bar.dart';

class CeoCompanyProfileView extends StatelessWidget {
  const CeoCompanyProfileView({super.key});

  Future<void> _logout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, true),
            style: CeoTheme.destructiveButtonStyle(height: 40),
            child: const Text('Log out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    await context.read<AuthViewModel>().signOut();
    if (context.mounted) {
      context.go(RouteNames.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: const CeoAppBar(title: 'Profile'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: CeoTheme.cardDecoration(),
            child: ListTile(
              leading: const Icon(Icons.logout, color: CeoColors.red),
              title: Text(
                'Log out',
                style: GoogleFonts.plusJakartaSans(
                  color: CeoColors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => _logout(context),
            ),
          ),
        ],
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 5),
    );
  }
}
