import 'package:flutter/material.dart';
import '../../widgets/order_status_stepper_widget.dart';
import '../../constants/app_colors.dart';

class FieldOrderDetailView extends StatelessWidget {
  final String orderId;

  const FieldOrderDetailView({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text("ORDER DETAILS", style: theme.textTheme.titleLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1.0)),
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Delivery Progress",
              style: theme.textTheme.displayLarge?.copyWith(fontSize: 22),
            ),
            const SizedBox(height: 8),
            Text(
              "Real-time fulfillment tracking for Cargo ID: ${orderId.toUpperCase()}",
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            
            // Floating Status Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const OrderStatusStepperWidget(status: "In Transit"),
            ),
            
            const SizedBox(height: 32),
            
            Text(
              "Shipment Information",
              style: theme.textTheme.titleLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                children: [
                  _DetailsCol("CARGO CODE", "HCS-PO-88219"),
                  _DetailsCol("COMMITTED WEIGHT", "15.0 Metric Tons"),
                  _DetailsCol("DESTINATION HUB", "DHA Block F Lahore"),
                  _DetailsCol("MERCHANT SELLER", "Amreli Steel Mill Distributor"),
                ],
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Action Button
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.support_agent_outlined, size: 20, weight: 300),
              label: const Text("CONTACT SUPPORT"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsCol extends StatelessWidget {
  final String metric;
  final String value;

  const _DetailsCol(this.metric, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            metric, 
            style: theme.textTheme.labelLarge?.copyWith(fontSize: 10, letterSpacing: 0.5),
          ),
          Text(
            value, 
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
