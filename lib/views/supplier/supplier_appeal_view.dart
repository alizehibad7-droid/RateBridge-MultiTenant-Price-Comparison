// MVVM: View — no business logic
import 'dart:io';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../theme/supplier_theme.dart';

class SupplierAppealView extends StatefulWidget {
  const SupplierAppealView({super.key});

  @override
  State<SupplierAppealView> createState() => _SupplierAppealViewState();
}

class _SupplierAppealViewState extends State<SupplierAppealView> {
  final _formKey = GlobalKey<FormState>();
  final _messageController = TextEditingController();
  final _phoneController = TextEditingController();
  File? _selectedFile;
  Uint8List? _webImage;

  Future<void> _pickDocument() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        setState(() {
          _webImage = bytes;
          _selectedFile = null;
        });
      } else {
        setState(() {
          _selectedFile = File(image.path);
          _webImage = null;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SupplierViewModel>(context, listen: false).clearAppealState();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SupplierViewModel>(context);

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Submit Appeal'),
      body: viewModel.appealSubmitted 
        ? _buildSuccessCard()
        : Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  decoration: SupplierTheme.cardDecoration(),
                  child: const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: FieldColors.primaryNavy),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'One appeal per rejection cycle only. Please provide clear evidence or clarification regarding your business registration.',
                            style: TextStyle(fontSize: 13, color: FieldColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _messageController,
                  maxLines: 6,
                  enabled: !viewModel.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Appeal Message',
                    hintText: 'Describe why your account should be reconsidered...',
                    alignLabelWithHint: true,
                  ),
                  validator: (v) => (v == null || v.length < 50) ? 'Please enter at least 50 characters' : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _phoneController,
                  enabled: !viewModel.isLoading,
                  decoration: const InputDecoration(
                    labelText: 'Contact Phone (Optional)',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 32),
                Text('SUPPORTING DOCUMENT', style: FieldTypography.labelSmall),
                const SizedBox(height: 12),
                InkWell(
                  onTap: viewModel.isLoading ? null : _pickDocument,
                  child: Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: FieldColors.borderSubtle, style: BorderStyle.solid),
                    ),
                    child: (_selectedFile == null && _webImage == null)
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined, size: 40, color: FieldColors.textMuted),
                              SizedBox(height: 8),
                              Text('Tap to upload proof/license', style: TextStyle(color: FieldColors.textMuted)),
                            ],
                          )
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: kIsWeb
                                  ? Image.memory(_webImage!, fit: BoxFit.cover)
                                  : Image.file(_selectedFile!, fit: BoxFit.cover),
                              ),
                              if (!viewModel.isLoading)
                                Positioned(
                                  right: 8,
                                  top: 8,
                                  child: CircleAvatar(
                                    backgroundColor: FieldColors.statusDanger,
                                    radius: 14,
                                    child: IconButton(
                                      icon: const Icon(Icons.close, size: 14, color: Colors.white),
                                      onPressed: () => setState(() {
                                        _selectedFile = null;
                                        _webImage = null;
                                      }),
                                    ),
                                  ),
                                )
                            ],
                          ),
                  ),
                ),
                if (viewModel.error != null) ...[
                  const SizedBox(height: 20),
                  Text(
                    viewModel.error!,
                    style: const TextStyle(color: FieldColors.statusDanger, fontSize: 14, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: viewModel.isLoading ? null : () async {
                    developer.log('[UI] Supplier Appeal: Submit button pressed');
                    if (_formKey.currentState!.validate()) {
                      developer.log('[UI] Supplier Appeal: Validation passed');
                      await viewModel.submitAppeal(
                        _messageController.text,
                        _selectedFile,
                        _phoneController.text.isEmpty ? null : _phoneController.text,
                        webBytes: _webImage,
                      );
                    }
                  },
                  child: viewModel.isLoading 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('SUBMIT APPEAL'),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildSuccessCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, size: 80, color: FieldColors.statusSuccess),
            const SizedBox(height: 24),
            const Text(
              'Appeal Submitted',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Your appeal has been received and added to our review queue. We will notify you once a decision is made.',
              textAlign: TextAlign.center,
              style: TextStyle(color: FieldColors.textSecondary, fontSize: 16),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('BACK TO STATUS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
