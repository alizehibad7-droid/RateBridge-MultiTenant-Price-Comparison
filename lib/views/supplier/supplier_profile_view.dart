// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../constants/app_colors.dart';

class SupplierProfileView extends StatefulWidget {
  const SupplierProfileView({super.key});

  @override
  State<SupplierProfileView> createState() => _SupplierProfileViewState();
}

class _SupplierProfileViewState extends State<SupplierProfileView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;
  late TextEditingController _addressController;
  late TextEditingController _cnicController;
  late TextEditingController _businessTypeController;

  @override
  void initState() {
    super.initState();
    final profile = context.read<SupplierViewModel>().profile;
    _nameController = TextEditingController(text: profile?.name);
    _phoneController = TextEditingController(text: profile?.phone);
    _cityController = TextEditingController(text: profile?.city);
    _addressController = TextEditingController(text: profile?.address);
    _cnicController = TextEditingController(text: profile?.cnic);
    _businessTypeController = TextEditingController(text: profile?.businessType);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _cnicController.dispose();
    _businessTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      // Logic to upload in ViewModel
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SupplierViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.surface,
                      backgroundImage: viewModel.profile?.profileImageUrl != null
                          ? NetworkImage(viewModel.profile!.profileImageUrl!)
                          : null,
                      child: viewModel.profile?.profileImageUrl == null
                          ? const Icon(Icons.person, size: 50, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickProfileImage,
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.primary,
                          child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(viewModel.profile?.name ?? 'Business Name',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Text(viewModel.profile?.city ?? 'City',
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Business Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _cnicController,
                decoration: const InputDecoration(labelText: 'CNIC / Registration #'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _businessTypeController,
                decoration: const InputDecoration(labelText: 'Business Type'),
              ),
              const SizedBox(height: 40),
              
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await viewModel.updateProfile({
                      'name': _nameController.text,
                      'phone': _phoneController.text,
                      'city': _cityController.text,
                      'address': _addressController.text,
                      'cnic': _cnicController.text,
                      'businessType': _businessTypeController.text,
                    });
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully')));
                    }
                  }
                },
                child: const Text('SAVE PROFILE'),
              ),
              const SizedBox(height: 24),
              
              OutlinedButton(
                onPressed: () async {
                  await authVM.signOut();
                },
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('SIGN OUT'),
              ),
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () => _confirmDeleteAccount(authVM),
                child: const Text('Delete Account', style: TextStyle(color: Colors.red)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount(AuthViewModel authVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account?'),
        content: const Text('This action is permanent and will remove all your data from RateBridge.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await authVM.deleteAccount();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
  }
}
