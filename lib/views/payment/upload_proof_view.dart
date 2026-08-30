import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../theme/admin_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/payment_proof_model.dart';
import '../../models/subscription_model.dart';
import '../../viewmodels/subscription_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';

class UploadProofView extends StatefulWidget {
  final double amount;
  final PaymentType type;
  final String method;
  final String? planKey;
  final List<String>? relatedTransactionIds;

  const UploadProofView({
    super.key,
    required this.amount,
    required this.type,
    required this.method,
    this.planKey,
    this.relatedTransactionIds,
  });

  @override
  State<UploadProofView> createState() => _UploadProofViewState();
}

class _UploadProofViewState extends State<UploadProofView> {
  XFile? _pickedFile;

  final Map<String, Map<String, String>> _accounts = {
    'easypaisa': {'name': 'RateBridge Official', 'number': '0300-1234567'},
    'jazzcash': {'name': 'RateBridge Official', 'number': '0345-7654321'},
    'bank': {'name': 'RateBridge Private Ltd', 'number': 'PK70BAHL000123456789', 'bank': 'Bank Al Habib'},
  };

  Future<void> _pickScreenshot() async {
    final picker = ImagePicker();
    try {
      final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (file != null) {
        setState(() => _pickedFile = file);
      }
    } catch (e) {
      _showPopup(title: 'Error', message: 'Could not access gallery: $e', isError: true);
    }
  }

  Future<void> _submitProof() async {
    if (_pickedFile == null) return;
    
    final auth = context.read<AuthViewModel>();
    final user = auth.user;
    if (user == null) return;

    bool success = false;
    String? msg;
    String? err;

    if (widget.type == PaymentType.subscription) {
      // CEO Subscription Flow
      final subVM = context.read<SubscriptionViewModel>();
      final planDef = kPlans.firstWhere(
        (p) => p.planKey == widget.planKey, 
        orElse: () => kPlans.first
      );
      success = await subVM.submitPaymentProof(
        ceoId: user.uid,
        companyId: user.companyId,
        ceoName: user.name,
        plan: planDef,
        method: widget.method,
        amount: widget.amount,
        screenshotFile: _pickedFile!,
      );
      msg = subVM.successMessage;
      err = subVM.error;
    } else {
      // Supplier Commission Flow
      final supplierVM = context.read<SupplierViewModel>();
      success = await supplierVM.submitCommissionPayment(
        amount: widget.amount,
        method: widget.method,
        screenshotFile: _pickedFile!,
      );
      msg = supplierVM.successMessage;
      err = supplierVM.error;
    }

    if (success && mounted) {
      _showPopup(
        title: '✅ Submitted', 
        message: msg ?? 'Your payment proof has been sent. Admin will review and approve it shortly.', 
        isError: false
      );
    } else if (mounted) {
      _showPopup(title: 'Error', message: err ?? 'Failed to submit.', isError: true);
    }
  }

  void _showPopup({required String title, required String message, required bool isError}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: isError ? AppColors.error : AppColors.success),
          const SizedBox(width: 12),
          Text(title)
        ]),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Pop Dialog
              if (!isError) {
                // Stack for Subscription: Base View -> PaymentMethodView -> UploadProofView
                // Stack for Commission: Base View -> CommissionPaymentView -> PaymentMethodView -> UploadProofView
                Navigator.pop(context); // Pop UploadProofView
                Navigator.pop(context); // Pop PaymentMethodView
                
                if (widget.type == PaymentType.commission) {
                  Navigator.pop(context); // Pop CommissionPaymentView
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: isError ? AppColors.error : AppColors.success),
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final acc = _accounts[widget.method]!;
    final subLoading = context.watch<SubscriptionViewModel>().isLoading;
    final supplierLoading = context.watch<SupplierViewModel>().isLoading;
    final isLoading = subLoading || supplierLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Confirm Payment')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.navy.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Account Details:', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.navy)),
                  const SizedBox(height: 12),
                  _detailItem('Name', acc['name']!),
                  _detailItem('Number', acc['number']!),
                  if (acc.containsKey('bank')) _detailItem('Bank', acc['bank']!),
                  const Divider(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('Rs. ${widget.amount}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Upload Payment Screenshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Please upload a clear screenshot of your successful transaction.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            InkWell(
              onTap: isLoading ? null : _pickScreenshot,
              child: Container(
                height: 250, width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border, width: 2),
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.screenBg,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _pickedFile == null 
                    ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_photo_alternate, size: 40, color: AppColors.textSecondary), Text('Select Screenshot')]))
                    : kIsWeb 
                        ? Image.network(_pickedFile!.path, fit: BoxFit.cover)
                        : Image.file(File(_pickedFile!.path), fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 40),
            if (isLoading)
              const Center(child: Column(children: [CircularProgressIndicator(), const SizedBox(height: 16), Text('Processing...', style: TextStyle(fontWeight: FontWeight.w500))]))
            else
              ElevatedButton(
                onPressed: _pickedFile == null ? null : _submitProof,
                style: AdminTheme.primaryButtonStyle(height: 60),
                child: const Text('SUBMIT FOR APPROVAL'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [Text('$label: ', style: const TextStyle(color: AppColors.textSecondary)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}
