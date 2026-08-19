import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../services/cloud_function_service.dart';
import '../../theme/admin_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/payment_proof_model.dart';

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
  bool _isUploading = false;
  String _statusMessage = '';

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
    
    setState(() {
      _isUploading = true;
      _statusMessage = 'Uploading screenshot...';
    });

    try {
      final auth = context.read<AuthViewModel>();
      final uid = auth.user!.uid;
      
      // 1. Upload to Firebase Storage
      setState(() => _statusMessage = 'Uploading to Secure Storage...');
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('payment_proofs/${uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      if (kIsWeb) {
        await storageRef.putData(await _pickedFile!.readAsBytes()).timeout(const Duration(seconds: 40));
      } else {
        await storageRef.putFile(File(_pickedFile!.path)).timeout(const Duration(seconds: 40));
      }
      
      final downloadUrl = await storageRef.getDownloadURL();

      // 2. Call AI Verification Cloud Function
      setState(() => _statusMessage = 'AI is validating receipt...');
      final cloudService = context.read<CloudFunctionService>();
      
      final result = await cloudService.callFunction('verifyPaymentScreenshot', {
        'imageUrl': downloadUrl,
      }).timeout(const Duration(seconds: 60));

      final bool isVerified = result['verified'] ?? false;
      final bool isDuplicate = result['isDuplicate'] ?? false;
      final double detectedAmount = (result['amountDetected'] ?? 0.0).toDouble();
      final String transactionId = result['transactionId'] ?? 'NOT_FOUND';

      if (isDuplicate) {
        throw 'This Transaction ID ($transactionId) has already been approved. Please upload a valid receipt.';
      }

      // 3. Save Record to Firestore
      setState(() => _statusMessage = 'Saving final record...');
      await FirebaseFirestore.instance.collection('payment_proofs').add({
        'payerId': uid,
        'payerName': auth.user!.name,
        'payerRole': widget.type == PaymentType.subscription ? 'ceo' : 'supplier',
        'amountExpected': widget.amount,
        'amountDetected': detectedAmount,
        'transactionIdDetected': transactionId,
        'method': widget.method,
        'screenshotUrl': downloadUrl,
        'status': 'pending_review',
        'type': widget.type.name,
        'planKey': widget.planKey,
        'relatedTransactions': widget.relatedTransactionIds,
        'isAiVerified': isVerified,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _handleVerificationResult(isVerified, detectedAmount);
      }
    } catch (e) {
      if (mounted) {
        _showPopup(title: 'Upload Failed', message: e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _handleVerificationResult(bool isVerified, double detectedAmount) {
    if (isVerified) {
      _showPopup(
        title: '✅ AI Verified', 
        message: 'Your payment was successfully scanned. Admin will approve it shortly.', 
        isError: false
      );
    } else {
      _showPopup(
        title: '⏳ Manual Review Needed', 
        message: 'AI could not perfectly match the receipt details. Don\'t worry, Admin will check it manually and approve.', 
        isError: false
      );
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
              Navigator.pop(context);
              if (!isError) {
                // Return to dashboard
                Navigator.pop(context);
                Navigator.pop(context);
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
            const SizedBox(height: 32),
            const Text('Upload Screenshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _isUploading ? null : _pickScreenshot,
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
                    : Image.network(_pickedFile!.path, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 48),
            if (_isUploading)
              Center(child: Column(children: [const CircularProgressIndicator(), const SizedBox(height: 16), Text(_statusMessage, style: const TextStyle(fontWeight: FontWeight.w500))]))
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
