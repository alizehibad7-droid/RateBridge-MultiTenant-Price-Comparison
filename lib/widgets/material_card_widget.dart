import 'package:flutter/material.dart';
import '../models/material_model.dart';
import '../utils/currency_formatter.dart';

class MaterialCardWidget extends StatelessWidget {
  final MaterialModel material;
  final VoidCallback onTap;

  const MaterialCardWidget({super.key, required this.material, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      child: ListTile(
        onTap: onTap,
        title: Text(
          material.name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          "${material.category} • ${material.city}",
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
        trailing: Text(
          CurrencyFormatter.formatPKR(material.pricePerUnit),
          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 13),
        ),
      ),
    );
  }
}
