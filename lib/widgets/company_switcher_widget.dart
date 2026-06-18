import 'package:flutter/material.dart';

class CompanySwitcherWidget extends StatelessWidget {
  final String activeCompanyName;
  final VoidCallback onSwitch;

  const CompanySwitcherWidget({super.key, required this.activeCompanyName, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF0F172A),
      child: ListTile(
        title: Text(activeCompanyName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("Multi-tenant session active"),
        trailing: IconButton(icon: const Icon(Icons.swap_horiz), onPressed: onSwitch),
      ),
    );
  }
}
