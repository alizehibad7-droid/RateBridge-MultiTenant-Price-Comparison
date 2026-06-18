import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/order_model.dart';
import '../../constants/app_colors.dart';

class FieldRateSupplierView extends StatefulWidget {
  final OrderModel order;
  const FieldRateSupplierView({super.key, required this.order});

  @override
  State<FieldRateSupplierView> createState() => _FieldRateSupplierViewState();
}

class _FieldRateSupplierViewState extends State<FieldRateSupplierView> {
  int _overallRating = 0;
  int _qualityRating = 0;
  int _deliveryRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          "Review Experience", 
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800, 
            fontSize: 18, 
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vendor Context Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.business_outlined, color: AppColors.primary, size: 24, weight: 300),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.order.supplierName, 
                          style: theme.textTheme.titleLarge?.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Cargo ID: #${widget.order.orderId.substring(0, 8).toUpperCase()}", 
                          style: theme.textTheme.labelLarge?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            
            _buildSectionHeader("PERFORMANCE METRICS"),
            const SizedBox(height: 24),
            _buildRatingSection("Overall Integrity", _overallRating, (v) => setState(() => _overallRating = v)),
            _buildRatingSection("Resource Quality", _qualityRating, (v) => setState(() => _qualityRating = v)),
            _buildRatingSection("Dispatch Efficiency", _deliveryRating, (v) => setState(() => _deliveryRating = v)),
            
            const SizedBox(height: 16),
            _buildSectionHeader("QUALITATIVE FEEDBACK"),
            const SizedBox(height: 16),
            TextField(
              controller: _commentController,
              maxLines: 4,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(
                hintText: "Elaborate on material specifications, logistics handling, and merchant professionalism...",
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 48),
            
            SizedBox(
              width: double.infinity,
              child: _PressableScale(
                onTap: _isSubmitting ? () {} : _submitRating,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  child: _isSubmitting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                    : const Text("SUBMIT EVALUATION", style: TextStyle(letterSpacing: 0.5)),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title, 
      style: const TextStyle(
        color: AppColors.textSecondary, 
        fontSize: 10, 
        fontWeight: FontWeight.w800, 
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildRatingSection(String title, int currentRating, Function(int) onRatingChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title, 
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(5, (index) {
              final isSelected = index < currentRating;
              return _PressableScale(
                onTap: () => onRatingChanged(index + 1),
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected ? AppColors.warning : AppColors.border,
                    size: 40,
                    weight: 200,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _submitRating() async {
    if (_overallRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Incomplete evaluation. Please provide an integrity score."),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _isSubmitting = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.textPrimary, 
          content: const Text("Evaluation logged. Your feedback strengthens the procurement network."),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
