import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dispute_model.dart';
import '../models/order_model.dart';
import '../theme/field_theme.dart';
import '../utils/app_theme.dart';
import '../utils/chat_image_utils.dart';
import '../views/field_user/orders/field_order_status.dart';
import '../services/cloudinary_service.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/dispute_viewmodel.dart';

class DisputeReportSheet extends StatefulWidget {
  final OrderModel order;
  const DisputeReportSheet({super.key, required this.order});

  static void show(BuildContext context, OrderModel order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DisputeReportSheet(order: order),
    );
  }

  static bool canReportOrder(OrderModel order) {
    final status = FieldOrderStatus.normalize(order.status);
    return status == 'delivered' || status == 'confirmed';
  }

  @override
  State<DisputeReportSheet> createState() => _DisputeReportSheetState();
}

class _DisputeReportSheetState extends State<DisputeReportSheet> {
  final _descController = TextEditingController();
  DisputeType _selectedType = DisputeType.wrongMaterial;
  Uint8List? _photoBytes;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final source = await ChatImageUtils.showSourceSheet(context);
    if (source == null) return;
    final picked = await ChatImageUtils.pickImage(source);
    if (picked != null) setState(() => _photoBytes = picked.bytes);
  }

  Future<void> _submit() async {
    final description = _descController.text.trim();
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please describe the issue')),
      );
      return;
    }
    if (description.length > 2000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Description must be 2000 characters or fewer.'),
        ),
      );
      return;
    }
    if (!DisputeReportSheet.canReportOrder(widget.order)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Issues can only be reported for delivered or confirmed orders.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      String? photoUrl;
      if (_photoBytes != null) {
        photoUrl = await CloudinaryService.uploadImageBytes(
          bytes: _photoBytes!,
          folder: 'ratebridge/disputes/${widget.order.orderId}',
          filename: 'evidence_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        if (photoUrl == null || photoUrl.isEmpty) {
          throw Exception(
            'Photo evidence could not be uploaded. Please try again.',
          );
        }
      }

      final auth = context.read<AuthViewModel>();
      final user = auth.user;
      if (user == null) {
        throw Exception('You must be signed in to report an issue.');
      }
      await context.read<DisputeViewModel>().raiseDispute(
        uid: user.uid,
        orderId: widget.order.orderId,
        companyId: widget.order.companyId,
        type: _selectedType,
        description: description,
        photoUrl: photoUrl,
        raisedByRole: user.role,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Issue reported successfully. Admin will review it.'),
            backgroundColor: FieldColors.statusSuccess,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Report an Issue', style: AppTextStyles.h2),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('ISSUE TYPE', style: AppTextStyles.label),
            const SizedBox(height: 8),
            DropdownButtonFormField<DisputeType>(
              value: _selectedType,
              items:
                  DisputeType.values
                      .map(
                        (t) => DropdownMenuItem(value: t, child: Text(t.label)),
                      )
                      .toList(),
              onChanged: (v) => setState(() => _selectedType = v!),
              decoration: const InputDecoration(
                filled: true,
                fillColor: FieldColors.screenBackground,
              ),
            ),
            const SizedBox(height: 24),
            Text('DESCRIPTION', style: AppTextStyles.label),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Describe what went wrong in detail...',
                filled: true,
                fillColor: FieldColors.screenBackground,
              ),
            ),
            const SizedBox(height: 24),
            Text('PHOTO EVIDENCE (OPTIONAL)', style: AppTextStyles.label),
            const SizedBox(height: 8),
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: FieldColors.screenBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: FieldColors.borderSubtle),
                ),
                child:
                    _photoBytes == null
                        ? const Icon(
                          Icons.add_a_photo_outlined,
                          color: FieldColors.textMuted,
                        )
                        : ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.memory(_photoBytes!, fit: BoxFit.cover),
                        ),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child:
                  _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('SUBMIT REPORT'),
            ),
          ],
        ),
      ),
    );
  }
}
