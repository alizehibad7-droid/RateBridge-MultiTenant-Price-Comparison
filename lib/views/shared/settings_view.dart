import 'package:flutter/material.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System configurations")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            ListTile(
              title: const Text("Language Dialect"),
              subtitle: const Text("Urdu / English"),
              trailing: Switch(value: true, onChanged: (b) {}),
            ),
            ListTile(
              title: const Text("Device Biometrics"),
              trailing: Switch(value: false, onChanged: (b) {}),
            )
          ],
        ),
      ),
    );
  }
}
