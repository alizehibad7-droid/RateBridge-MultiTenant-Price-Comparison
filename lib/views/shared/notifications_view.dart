import 'package:flutter/material.dart';

class SharedNotificationsView extends StatelessWidget {
  const SharedNotificationsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Universal Announcements")),
      body: const Center(
        child: Text("All security updates and platform notices will show here."),
      ),
    );
  }
}
