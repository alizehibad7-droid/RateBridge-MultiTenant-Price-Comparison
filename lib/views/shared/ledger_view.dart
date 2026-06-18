import 'package:flutter/material.dart';

class LedgerView extends StatelessWidget {
  const LedgerView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text("B2B Corporate Ledgers"), backgroundColor: const Color(0xFF1E293B)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildItem("PO-88129-LHE", "ASTM Grade 60 Rebars", "PKR 3,900,000", "Released"),
          _buildItem("PO-88132-RWP", "Fauji Cement Premium Slurry", "PKR 725,000", "Released"),
        ],
      ),
    );
  }

  Widget _buildItem(String tracking, String materialName, String volume, String status) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tracking, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(materialName, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(volume, style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold)),
              Text(status, style: const TextStyle(color: Colors.white30, fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }
}
