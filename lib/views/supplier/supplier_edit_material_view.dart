// MVVM: View — no business logic
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../models/material_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/chat_image_utils.dart';
import '../../utils/material_form_defaults.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/material_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';

class SupplierEditMaterialView extends StatefulWidget {
  final MaterialModel material;

  const SupplierEditMaterialView({super.key, required this.material});

  @override
  State<SupplierEditMaterialView> createState() =>
      _SupplierEditMaterialViewState();
}

class _SupplierEditMaterialViewState extends State<SupplierEditMaterialView> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _brandController;
  late final TextEditingController _gradeController;
  late final TextEditingController _minOrderController;

  String? _selectedBrand;
  String? _selectedGrade;
  late String _stockStatus;
  String? _deliveryTime;
  XFile? _imageXFile;
  Uint8List? _imagePreviewBytes;
  bool _categoriesLoaded = false;

  List<String> get _deliveryOptions {
    final options = [...MaterialFormDefaults.deliveryTimes];
    final current = _deliveryTime;
    if (current != null &&
        current.isNotEmpty &&
        !options.contains(current)) {
      options.add(current);
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _nameController = TextEditingController(text: material.name);
    _priceController =
        TextEditingController(text: material.pricePerUnit.toString());
    _brandController = TextEditingController(text: material.brand ?? '');
    _gradeController = TextEditingController(text: material.grade);
    _minOrderController = TextEditingController(
      text: material.minOrderQuantity?.toString() ?? '',
    );
    _stockStatus = MaterialFormDefaults.stockStatuses.contains(material.stockStatus)
        ? material.stockStatus!
        : 'Available';
    _deliveryTime =
        MaterialFormDefaults.canonicalDeliveryTime(material.deliveryTime);
    _selectedBrand = material.brand;
    _selectedGrade = material.grade;

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategory());
  }

  Future<void> _loadCategory() async {
    final materialVM = context.read<MaterialViewModel>();
    await materialVM.loadCategories();
    materialVM.selectCategoryByName(widget.material.category);
    if (!mounted) return;
    setState(() => _categoriesLoaded = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _brandController.dispose();
    _gradeController.dispose();
    _minOrderController.dispose();
    super.dispose();
  }

  String? get _brandValue {
    if (_selectedBrand != null && _selectedBrand!.isNotEmpty) {
      return _selectedBrand;
    }
    final text = _brandController.text.trim();
    return text.isEmpty ? null : text;
  }

  String? get _gradeValue {
    if (_selectedGrade != null && _selectedGrade!.isNotEmpty) {
      return _selectedGrade;
    }
    final text = _gradeController.text.trim();
    return text.isEmpty ? null : text;
  }

  Future<void> _pickImage() async {
    final source = await ChatImageUtils.showSourceSheet(context);
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    setState(() {
      _imageXFile = picked;
      _imagePreviewBytes = bytes;
    });
  }

  @override
  Widget build(BuildContext context) {
    final materialVM = context.watch<MaterialViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final category = materialVM.selectedCategory;
    final brands = MaterialFormDefaults.uniqueOptions(category?.brands ?? const <String>[]);
    final grades = MaterialFormDefaults.uniqueOptions(category?.grades ?? const <String>[]);

    if (!_categoriesLoaded && materialVM.isLoading) {
      return Scaffold(
        backgroundColor: FieldColors.screenBackground,
        appBar: const SupplierAppBar(title: 'Edit Material'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Edit Material'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              initialValue: widget.material.category,
              decoration: const InputDecoration(
                labelText: 'Category (Locked)',
                filled: true,
                fillColor: FieldColors.screenBackground,
              ),
              readOnly: true,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            if (brands.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Brand'),
                value: brands.contains(_selectedBrand) ? _selectedBrand : null,
                items: brands
                    .map(
                      (b) => DropdownMenuItem(
                        value: b,
                        child: Text(b, style: AppTextStyles.body),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedBrand = val),
              )
            else
              TextFormField(
                controller: _brandController,
                decoration: const InputDecoration(labelText: 'Brand'),
                style: AppTextStyles.body,
              ),
            const SizedBox(height: 16),
            if (grades.isNotEmpty)
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Grade'),
                value: grades.contains(_selectedGrade) ? _selectedGrade : null,
                items: grades
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(g, style: AppTextStyles.body),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedGrade = val),
              )
            else
              TextFormField(
                controller: _gradeController,
                decoration: const InputDecoration(labelText: 'Grade'),
                style: AppTextStyles.body,
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Material Name'),
              style: AppTextStyles.body,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Price',
                prefixText: 'Rs. ',
              ),
              style: AppTextStyles.body,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: widget.material.unit,
              decoration: const InputDecoration(
                labelText: 'Unit (Locked)',
                filled: true,
                fillColor: FieldColors.screenBackground,
              ),
              readOnly: true,
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Stock Status'),
              value: MaterialFormDefaults.stockStatuses.contains(_stockStatus)
                  ? _stockStatus
                  : 'Available',
              items: MaterialFormDefaults.stockStatuses
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(s, style: AppTextStyles.body),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _stockStatus = val);
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minOrderController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimum Order Quantity (optional)',
              ),
              style: AppTextStyles.body,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Delivery Time (optional)',
              ),
              value: _deliveryOptions.contains(_deliveryTime)
                  ? _deliveryTime
                  : null,
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('Not specified', style: AppTextStyles.bodyMuted),
                ),
                ..._deliveryOptions.map(
                  (d) => DropdownMenuItem(
                    value: d,
                    child: Text(d, style: AppTextStyles.body),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _deliveryTime = val),
            ),
            const SizedBox(height: 32),
            Text('UPDATE PHOTO', style: AppTextStyles.label),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickImage,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: FieldColors.screenBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: FieldColors.borderSubtle),
                ),
                child: _imagePreviewBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.memory(
                          _imagePreviewBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 120,
                          gaplessPlayback: true,
                        ),
                      )
                    : widget.material.profileImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              widget.material.profileImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: 120,
                            ),
                          )
                        : const Icon(
                            Icons.add_a_photo_outlined,
                            color: FieldColors.textSecondary,
                          ),
              ),
            ),
            if (materialVM.error != null) ...[
              const SizedBox(height: 16),
              Text(
                materialVM.error!,
                style: AppTextStyles.body.copyWith(color: FieldColors.statusDanger),
              ),
            ],
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: materialVM.isLoading
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;

                      final supplierVM = context.read<SupplierViewModel>();
                      final companyId = supplierVM.selectedCompanyId ?? '';
                      if (companyId.isEmpty) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Select a company before updating materials.'),
                          ),
                        );
                        return;
                      }

                      materialVM.resetSuccess();
                      await materialVM.updateMaterial(
                        widget.material.id,
                        {
                          'name': _nameController.text.trim(),
                          'price': _priceController.text.trim(),
                          'brand': _brandValue ?? '',
                          'grade': _gradeValue ?? '',
                          'stockStatus': _stockStatus,
                          'minOrderQuantity': _minOrderController.text.trim(),
                          'deliveryTime': _deliveryTime,
                        },
                        _imageXFile,
                        companyId,
                        authVM.user?.uid ?? '',
                      );
                      if (!mounted) return;
                      if (materialVM.isSuccess) {
                        Navigator.pop(context);
                      }
                    },
              child: materialVM.isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Text('UPDATE MATERIAL'),
            ),
          ],
        ),
      ),
    );
  }
}
