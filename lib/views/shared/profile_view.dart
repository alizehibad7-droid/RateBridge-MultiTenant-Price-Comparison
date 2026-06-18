import 'package:flutter/material.dart';

class SharedProfileView extends StatelessWidget {
  const SharedProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Platform Identity card")),
      body: const Padding(
        padding: EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(radius: 50, child: Icon(Icons.person, size: 50)),
            SizedBox(height: 16),
            Text("Verified RateBridge User Profile", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
