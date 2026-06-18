// MVVM: View — no business logic
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../viewmodels/material_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/material_model.dart';
import '../../constants/app_colors.dart';

class SupplierEditMaterialView extends StatefulWidget {
  final MaterialModel material;
  const SupplierEditMaterialView({super.key, required this.material});

  @override
  State<SupplierEditMaterialView> createState() => _SupplierEditMaterialViewState();
}

class _SupplierEditMaterialViewState extends State<SupplierEditMaterialView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _brandController;
  late TextEditingController _gradeController;
  File? _imageFile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.material.name);
    _priceController = TextEditingController(text: widget.material.pricePerUnit.toString());
    _brandController = TextEditingController(text: widget.material.brand);
    _gradeController = TextEditingController(text: widget.material.grade);
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
        title: const Text('Edit Material', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              initialValue: widget.material.category,
              decoration: const InputDecoration(labelText: 'Category (Locked)', filled: true, fillColor: AppColors.surface),
              readOnly: true,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Material Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Price', prefixText: 'Rs. '),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.material.unit,
              decoration: const InputDecoration(labelText: 'Unit (Locked)', filled: true, fillColor: AppColors.surface),
              readOnly: true,
            ),
            const SizedBox(height: 16),
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
            const Text('UPDATE PHOTO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
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
                child: _imageFile != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(_imageFile!, fit: BoxFit.cover))
                    : (widget.material.profileImageUrl != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network(widget.material.profileImageUrl!, fit: BoxFit.cover))
                        : const Icon(Icons.add_a_photo_outlined, color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: materialVM.isLoading ? null : () async {
                if (_formKey.currentState!.validate()) {
                  await materialVM.updateMaterial(
                    widget.material.id,
                    {
                      'name': _nameController.text,
                      'price': _priceController.text,
                      'brand': _brandController.text,
                      'grade': _gradeController.text,
                    },
                    _imageFile,
                    authVM.user?.companyId ?? '',
                  );
                  if (materialVM.isSuccess && mounted) {
                    Navigator.pop(context);
                  }
                }
              },
              child: materialVM.isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('UPDATE MATERIAL'),
            ),
          ],
        ),
      ),
    );
  }
}
