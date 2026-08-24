import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_colors.dart';
import '../../theme/admin_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/payment_proof_model.dart';
import '../../services/cloudinary_service.dart';

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
  final _txController = TextEditingController();

  final Map<String, Map<String, String>> _accounts = {
    'easypaisa': {'name': 'RateBridge Official', 'number': '0300-1234567'},
    'jazzcash': {'name': 'RateBridge Official', 'number': '0345-7654321'},
    'bank': {'name': 'RateBridge Private Ltd', 'number': 'PK70BAHL000123456789', 'bank': 'Bank Al Habib'},
  };

  @override
  void dispose() {
    _txController.dispose();
    super.dispose();
  }

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
    if (_txController.text.trim().isEmpty) {
      _showPopup(title: 'Required', message: 'Please enter the Transaction ID from your receipt.', isError: true);
      return;
    }
    
    setState(() {
      _isUploading = true;
      _statusMessage = 'Uploading screenshot...';
    });

    try {
      final auth = context.read<AuthViewModel>();
      final user = auth.user;
      
      if (user == null) {
        throw Exception('User session not found. Please log in again.');
      }
      
      final uid = user.uid;
      
      // 1. Upload to Cloudinary
      final uploadFolder = 'ratebridge/payments/$uid';
      final bytes = await _pickedFile!.readAsBytes();
      
      final downloadUrl = await CloudinaryService.uploadImageBytes(
        bytes: bytes.toList(),
        folder: uploadFolder,
        filename: 'proof_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      if (downloadUrl == null) {
        throw Exception('Failed to upload image to server. Please check your internet connection.');
      }

      // 2. Save Record to Firestore
      setState(() => _statusMessage = 'Submitting for Admin Review...');
      await FirebaseFirestore.instance.collection('payment_proofs').add({
        'payerId': uid,
        'payerName': user.name,
        'payerRole': user.role, 
        'amountExpected': widget.amount,
        'amountDetected': widget.amount, 
        'transactionIdDetected': _txController.text.trim(),
        'method': widget.method,
        'screenshotUrl': downloadUrl,
        'status': 'pending', // Corrected status: pending
        'type': widget.type.name,
        'planKey': widget.planKey,
        'relatedTransactions': widget.relatedTransactionIds,
        'isAiVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showPopup(
          title: '✅ Submitted', 
          message: 'Your payment proof has been sent. Admin will review and approve it shortly.', 
          isError: false
        );
      }
    } catch (e) {
      if (mounted) {
        _showPopup(title: 'Upload Failed', message: e.toString(), isError: true);
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
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
                // Return to dashboard/earnings
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
            const SizedBox(height: 24),
            const Text('Payment Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _txController,
              decoration: InputDecoration(
                labelText: 'Transaction ID / Reference #',
                hintText: 'Enter the ID from your receipt',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.receipt_long),
              ),
            ),
            const SizedBox(height: 24),
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
                    : kIsWeb 
                        ? Image.network(_pickedFile!.path, fit: BoxFit.cover)
                        : Image.file(File(_pickedFile!.path), fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 40),
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
