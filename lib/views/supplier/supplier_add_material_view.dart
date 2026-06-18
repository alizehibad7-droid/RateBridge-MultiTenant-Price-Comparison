// MVVM: View — no business logic
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/material_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../constants/app_colors.dart';

class SupplierAddMaterialView extends StatefulWidget {
  const SupplierAddMaterialView({super.key});

  @override
  State<SupplierAddMaterialView> createState() => _SupplierAddMaterialViewState();
}

class _SupplierAddMaterialViewState extends State<SupplierAddMaterialView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _brandController = TextEditingController();
  final _gradeController = TextEditingController();
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MaterialViewModel>().loadCategories();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _brandController.dispose();
    _gradeController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _imageFile = File(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final materialVM = Provider.of<MaterialViewModel>(context);
    final authVM = Provider.of<AuthViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Material', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Category Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              items: materialVM.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
              onChanged: (val) {
                if (val != null) materialVM.onCategorySelected(val);
              },
              validator: (v) => v == null ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            // Material Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Material Name', hintText: 'e.g. Mughal Steel 40 Grade'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Price
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price', prefixText: 'Rs. '),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Unit (Readonly, filled by category)
            TextFormField(
              initialValue: materialVM.selectedCategory?.unit ?? '',
              key: ValueKey(materialVM.selectedCategory?.unit),
              decoration: const InputDecoration(labelText: 'Unit', filled: true, fillColor: AppColors.surface),
              readOnly: true,
            ),
            const SizedBox(height: 16),

            // Brand & Grade
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandController,
                    decoration: const InputDecoration(labelText: 'Brand'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _gradeController,
                    decoration: const InputDecoration(labelText: 'Grade'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            // Photo Picker
            const Text('PHOTO (OPTIONAL)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                ),
                child: _imageFile == null
                    ? const Icon(Icons.add_a_photo_outlined, color: Colors.grey)
                    : ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_imageFile!, fit: BoxFit.cover)),
              ),
            ),
            const SizedBox(height: 48),

            ElevatedButton(
              onPressed: materialVM.isLoading ? null : () async {
                if (_formKey.currentState!.validate()) {
                  await materialVM.addMaterial(
                    {
                      'name': _nameController.text,
                      'price': _priceController.text,
                      'brand': _brandController.text,
                      'grade': _gradeController.text,
                      'supplierName': authVM.user?.name ?? '',
                    },
                    _imageFile,
                    authVM.user?.companyId ?? '',
                    authVM.user?.uid ?? '',
                  );
                  if (materialVM.isSuccess && mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: materialVM.isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('SAVE MATERIAL'),
            ),
          ],
        ),
      ),
    );
  }
}
