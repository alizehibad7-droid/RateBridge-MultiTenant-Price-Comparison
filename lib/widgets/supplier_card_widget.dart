import 'package:flutter/material.dart';
import '../models/supplier_model.dart';

class SupplierCardWidget extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onTap;

  const SupplierCardWidget({super.key, required this.supplier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF1E293B),
      child: ListTile(
        onTap: onTap,
        leading: const Icon(Icons.business, color: Color(0xFF06B6D4)),
        title: Text(supplier.name),
        subtitle: Text("${supplier.materialType} • ${supplier.city}"),
        trailing: Text("${supplier.rating} ★", style: const TextStyle(color: Colors.amber)),
      ),
    );
  }
}
