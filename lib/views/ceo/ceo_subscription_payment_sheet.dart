import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../models/payment_details_config.dart';
import '../../models/subscription_model.dart';
import '../../repositories/company_repository.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/subscription_viewmodel.dart';

/// Bottom sheet for CEO manual subscription payment submission.
class CeoSubscriptionPaymentSheet extends StatefulWidget {
  final PlanDefinition plan;

  const CeoSubscriptionPaymentSheet({super.key, required this.plan});

  static Future<void> show(BuildContext context, PlanDefinition plan) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CeoSubscriptionPaymentSheet(plan: plan),
    );
  }

  @override
  State<CeoSubscriptionPaymentSheet> createState() =>
      _CeoSubscriptionPaymentSheetState();
}

class _CeoSubscriptionPaymentSheetState
    extends State<CeoSubscriptionPaymentSheet> {
  final _imagePicker = ImagePicker();
  File? _proofFile;
  bool _submitting = false;

  Future<void> _pickProof(ImageSource source) async {
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked != null && mounted) {
      setState(() => _proofFile = File(picked.path));
    }
  }

  Future<void> _showImageSourceSheet() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pickProof(source);
  }

  Future<void> _submit() async {
    if (_proofFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload a payment screenshot')),
      );
      return;
    }

    final auth = context.read<AuthViewModel>();
    final companyId = auth.user?.companyId ?? '';
    final ceoUid = auth.user?.uid ?? '';
    if (companyId.isEmpty || ceoUid.isEmpty) return;

    setState(() => _submitting = true);

    final company =
        await context.read<CompanyRepository>().getCompanyById(companyId);
    final companyName = company?.name ?? 'Company';

    if (!mounted) return;
    await context.read<SubscriptionViewModel>().submitManualPayment(
          companyId: companyId,
          companyName: companyName,
          ceoUid: ceoUid,
          plan: widget.plan,
          proofFile: _proofFile!,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    final vm = context.read<SubscriptionViewModel>();
    if (vm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(vm.error!)),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(vm.successMessage ?? 'Payment submitted'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final details = context.watch<SubscriptionViewModel>().paymentDetails;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pay for ${widget.plan.name}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                'Rs. ${widget.plan.priceRs}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pay outside the app via JazzCash or bank transfer, then upload your payment screenshot.',
                style: TextStyle(color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              _PaymentDetailsCard(details: details),
              const SizedBox(height: 20),
              if (_proofFile == null)
                OutlinedButton.icon(
                  onPressed: _submitting ? null : _showImageSourceSheet,
                  icon: const Icon(Icons.upload_file_outlined, size: 18),
                  label: const Text('Upload payment screenshot'),
                )
              else
                _ProofPreview(
                  file: _proofFile!,
                  onRemove: _submitting
                      ? null
                      : () => setState(() => _proofFile = null),
                  onReplace: _submitting ? null : _showImageSourceSheet,
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitting || _proofFile == null ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit payment for review',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentDetailsCard extends StatelessWidget {
  final PaymentDetailsConfig details;

  const _PaymentDetailsCard({required this.details});

  @override
  Widget build(BuildContext context) {
    if (!details.isConfigured) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: const Text(
          'Payment details are not configured yet. Please contact support.',
          style: TextStyle(fontSize: 13),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment details',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          if (details.jazzCashNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('JazzCash', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(details.jazzCashNumber, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (details.bankName.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Bank', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text(details.bankName, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
          if (details.accountTitle.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Account title: ${details.accountTitle}'),
          ],
          if (details.bankAccountNumber.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('Account #: ${details.bankAccountNumber}'),
          ],
        ],
      ),
    );
  }
}

class _ProofPreview extends StatelessWidget {
  final File file;
  final VoidCallback? onRemove;
  final VoidCallback? onReplace;

  const _ProofPreview({
    required this.file,
    required this.onRemove,
    required this.onReplace,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(file, height: 160, width: double.infinity, fit: BoxFit.cover),
        ),
        if (onRemove != null)
          Positioned(
            top: 8,
            right: 8,
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                onPressed: onRemove,
                icon: const Icon(Icons.close),
              ),
            ),
          ),
      ],
    );
  }
}
