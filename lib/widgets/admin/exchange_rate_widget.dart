import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../theme/admin_theme.dart';

class ExchangeRateSettingWidget extends StatefulWidget {
  const ExchangeRateSettingWidget({super.key});

  @override
  State<ExchangeRateSettingWidget> createState() => _ExchangeRateSettingWidgetState();
}

class _ExchangeRateSettingWidgetState extends State<ExchangeRateSettingWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("settings")
          .doc("exchangeRate")
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        final currentRate = data?['usdToPkr']?.toString() ?? 'Not set';

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.currency_exchange_rounded, color: AdminColors.navy),
                    const SizedBox(width: 10),
                    const Text(
                      "Exchange Rate (Commission)",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Current rate: 1 USD = $currentRate PKR",
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "New Rate (PKR per 1 USD)",
                    hintText: "e.g. 285",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _updateRate,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text("Update Exchange Rate"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _updateRate() async {
    final value = double.tryParse(_controller.text);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid rate")),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable('updateExchangeRate');
      await callable.call({'usdToPkr': value});
      _controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Exchange rate updated successfully")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to update rate: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
