// MVVM: View — no business logic
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../theme/supplier_theme.dart';
import '../../utils/app_theme.dart';
import '../../utils/chat_image_utils.dart';
import '../../utils/material_form_defaults.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/material_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../views/field_user/widgets/field_material_card.dart';

class SupplierAddMaterialView extends StatefulWidget {
  const SupplierAddMaterialView({super.key});

  @override
  State<SupplierAddMaterialView> createState() =>
      _SupplierAddMaterialViewState();
}

class _SupplierAddMaterialViewState extends State<SupplierAddMaterialView> {
  static const _otherBrandValue = '__other_brand__';
  static const _otherGradeValue = '__other_grade__';

  static const _stockStatuses = [
    'Available',
    'Limited Stock',
    'Out of Stock',
  ];

  static const _deliveryTimes = [
    'Same Day',
    'Next Day',
    '2-3 Days',
    'Within a Week',
  ];

  static const _deliveryChargeOptions = [
    'Free Delivery',
    'Charged Separately',
    'Included in Price',
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _brandController = TextEditingController();
  final _otherBrandController = TextEditingController();
  final _otherGradeController = TextEditingController();
  final _minOrderController = TextEditingController();
  final _bulkDiscountDetailsController = TextEditingController();
  final _deliveryCoverageController = TextEditingController();

  String? _selectedCategoryId;
  String? _selectedBrand;
  String? _selectedGrade;
  String _stockStatus = 'Available';
  String? _deliveryTime;
  String? _deliveryCharges;
  bool _bulkDiscountAvailable = false;
  XFile? _imageXFile;
  Uint8List? _imagePreviewBytes;
  String? _photoError;
  bool _nameManuallyEdited = false;
  bool _categoriesLoaded = false;

  InputDecoration get _fieldDecoration => SupplierTheme.fieldDecoration();

  bool get _brandIsOther => _selectedBrand == _otherBrandValue;

  bool get _gradeIsOther => _selectedGrade == _otherGradeValue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCategories());
  }

  Future<void> _loadCategories() async {
    final materialVM = context.read<MaterialViewModel>();
    materialVM.resetAddMaterialForm();
    setState(() {
      _selectedCategoryId = null;
      _categoriesLoaded = false;
    });
    await materialVM.loadCategories();
    if (!mounted) return;
    setState(() => _categoriesLoaded = true);
  }

  void _onCategoryChanged(String? categoryId, MaterialViewModel materialVM) {
    if (categoryId == null) return;
    setState(() {
      _selectedCategoryId = categoryId;
      _selectedBrand = null;
      _selectedGrade = null;
      _brandController.clear();
      _otherBrandController.clear();
      _otherGradeController.clear();
      _nameManuallyEdited = false;
      _nameController.clear();
    });
    materialVM.onCategorySelected(categoryId);
    _updateAutoName(materialVM);
  }

  List<String> _gradeOptions(CategoryModel? category) {
    if (category == null || category.grades.isEmpty) return const [];
    return [...category.grades, MaterialFormDefaults.otherBrandLabel];
  }

  List<String> _brandOptions(List<String> adminBrands) {
    if (adminBrands.isEmpty) return const [];
    return [...adminBrands, MaterialFormDefaults.otherBrandLabel];
  }

  String? _resolvedBrand() {
    if (_brandIsOther) {
      final other = _otherBrandController.text.trim();
      return other.isEmpty ? null : other;
    }
    if (_selectedBrand != null &&
        _selectedBrand!.isNotEmpty &&
        _selectedBrand != _otherBrandValue) {
      return _selectedBrand;
    }
    final typed = _brandController.text.trim();
    return typed.isEmpty ? null : typed;
  }

  String? _resolvedGrade() {
    if (_gradeIsOther) {
      final other = _otherGradeController.text.trim();
      return other.isEmpty ? null : other;
    }
    return _selectedGrade;
  }

  void _updateAutoName(MaterialViewModel materialVM) {
    if (_nameManuallyEdited) return;
    final category = materialVM.selectedCategory;
    if (category == null) return;

    final parts = <String>[
      if (_resolvedBrand() != null) _resolvedBrand()!,
      category.name,
      if (_resolvedGrade() != null) _resolvedGrade()!,
    ];
    _nameController.text = parts.join(' ');
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
      _photoError = null;
    });
  }

  String? _validateBrand(List<String> adminBrands) {
    if (adminBrands.isNotEmpty) {
      if (_selectedBrand == null) return 'Please select a brand';
      if (_brandIsOther && _otherBrandController.text.trim().isEmpty) {
        return 'Please enter your brand name';
      }
      return null;
    }
    if (_brandController.text.trim().isEmpty) {
      return 'Brand is required';
    }
    return null;
  }

  Future<void> _submit(
    MaterialViewModel materialVM,
    AuthViewModel authVM,
    SupplierViewModel supplierVM,
  ) async {
    setState(() {
      _photoError =
          _imageXFile == null ? 'Material photo is required' : null;
    });

    final category = materialVM.selectedCategory;
    final adminBrands = category?.brands ?? const <String>[];
    final brandError = _validateBrand(adminBrands);

    if (!_formKey.currentState!.validate() ||
        _photoError != null ||
        brandError != null) {
      return;
    }

    final companyId = supplierVM.selectedCompanyId ?? '';
    if (companyId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Select a company before adding materials. Accept a company invitation if you have not yet.',
          ),
        ),
      );
      return;
    }

    materialVM.resetSuccess();
    await materialVM.addMaterial(
      {
        'name': _nameController.text.trim(),
        'price': _priceController.text.trim(),
        'brand': _resolvedBrand() ?? '',
        'grade': _resolvedGrade() ?? '',
        'description': _descriptionController.text.trim(),
        'stockStatus': _stockStatus,
        'minOrderQuantity': _minOrderController.text.trim(),
        'deliveryTime': _deliveryTime,
        'deliveryCoverageArea': _deliveryCoverageController.text.trim(),
        'deliveryCharges': _deliveryCharges,
        'bulkDiscountAvailable': _bulkDiscountAvailable,
        'bulkDiscountDetails': _bulkDiscountDetailsController.text.trim(),
        'supplierName': authVM.user?.name ?? '',
      },
      _imageXFile,
      companyId,
      authVM.user?.uid ?? '',
    );
    if (!mounted) return;
    if (materialVM.isSuccess) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _brandController.dispose();
    _otherBrandController.dispose();
    _otherGradeController.dispose();
    _minOrderController.dispose();
    _bulkDiscountDetailsController.dispose();
    _deliveryCoverageController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: AppTextStyles.h3.copyWith(
          color: FieldColors.primaryNavy,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: SupplierTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(MaterialViewModel materialVM) {
    if (!_categoriesLoaded || materialVM.isLoadingCategories) {
      return Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(width: 16),
          Text('Loading categories…', style: AppTextStyles.bodyMuted),
        ],
      );
    }

    if (materialVM.categories.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.category_outlined, color: FieldColors.statusWarning),
          const SizedBox(height: 12),
          Text(
            'No categories available',
            style: AppTextStyles.h3.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Please ask admin to add active categories first.',
            style: AppTextStyles.bodyMuted,
          ),
        ],
      );
    }

    final validValue = _selectedCategoryId != null &&
            materialVM.categories.any((c) => c.id == _selectedCategoryId)
        ? _selectedCategoryId
        : null;

    return DropdownButtonFormField<String>(
      decoration: _fieldDecoration.copyWith(labelText: 'Category *'),
      isExpanded: true,
      value: validValue,
      hint: Text('Select a category', style: AppTextStyles.bodyMuted),
      items: materialVM.categories
          .map(
            (category) => DropdownMenuItem<String>(
              value: category.id,
              child: Row(
                children: [
                  Icon(
                    fieldMaterialCategoryIcon(category.name),
                    size: 20,
                    color: FieldColors.primaryNavy,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      category.name,
                      style: AppTextStyles.body,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      validator: (v) => v == null ? 'Category is required' : null,
      onChanged: (value) => _onCategoryChanged(value, materialVM),
    );
  }

  Widget _buildUnitField(CategoryModel? category) {
    final hasCategory = category != null && category.unit.isNotEmpty;

    return TextFormField(
      key: ValueKey('unit-${category?.id ?? 'none'}'),
      initialValue: hasCategory ? category.unit : null,
      readOnly: true,
      enabled: hasCategory,
      enableInteractiveSelection: false,
      decoration: _fieldDecoration.copyWith(
        labelText: 'Unit',
        hintText: 'Select category first',
        filled: true,
        fillColor: hasCategory
            ? FieldColors.screenBackground
            : FieldColors.screenBackground.withValues(alpha: 0.65),
        suffixIcon: hasCategory
            ? const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.lock_outline,
                  size: 18,
                  color: FieldColors.textMuted,
                ),
              )
            : null,
        suffixIconConstraints:
            const BoxConstraints(minHeight: 36, minWidth: 36),
        helperText: hasCategory ? 'Fixed by platform for this category' : null,
      ),
      style: AppTextStyles.body.copyWith(
        color:
            hasCategory ? FieldColors.textPrimary : FieldColors.textMuted,
      ),
    );
  }

  Widget _buildBrandField(
    MaterialViewModel materialVM,
    List<String> adminBrands,
  ) {
    if (adminBrands.isNotEmpty) {
      final options = _brandOptions(adminBrands);
      final validBrand = _selectedBrand != null &&
              (_selectedBrand == _otherBrandValue ||
                  adminBrands.contains(_selectedBrand))
          ? _selectedBrand
          : null;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            decoration: _fieldDecoration.copyWith(labelText: 'Brand *'),
            isExpanded: true,
            value: validBrand,
            hint: Text('Select brand', style: AppTextStyles.bodyMuted),
            items: options
                .map(
                  (b) => DropdownMenuItem(
                    value: b == MaterialFormDefaults.otherBrandLabel
                        ? _otherBrandValue
                        : b,
                    child: Text(b, style: AppTextStyles.body),
                  ),
                )
                .toList(),
            validator: (_) => _validateBrand(adminBrands),
            onChanged: (val) {
              setState(() => _selectedBrand = val);
              _updateAutoName(materialVM);
            },
          ),
          if (_brandIsOther) ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: _otherBrandController,
              decoration: _fieldDecoration.copyWith(
                labelText: 'Other brand name *',
                hintText: 'Enter brand name',
              ),
              style: AppTextStyles.body,
              validator: (v) {
                if (!_brandIsOther) return null;
                if (v == null || v.trim().isEmpty) {
                  return 'Please enter your brand name';
                }
                return null;
              },
              onChanged: (_) => _updateAutoName(materialVM),
            ),
          ],
        ],
      );
    }

    return TextFormField(
      controller: _brandController,
      decoration: _fieldDecoration.copyWith(
        labelText: 'Brand *',
        hintText: 'e.g. DG Khan, Ittefaq',
      ),
      style: AppTextStyles.body,
      validator: (v) =>
          v == null || v.trim().isEmpty ? 'Brand is required' : null,
      onChanged: (_) => _updateAutoName(materialVM),
    );
  }

  Widget _buildGradeField(
    MaterialViewModel materialVM,
    List<String> gradeOptions,
  ) {
    if (gradeOptions.isEmpty) return const SizedBox.shrink();

    final seededGrades = gradeOptions
        .where((g) => g != MaterialFormDefaults.otherBrandLabel)
        .toList();
    final validGrade = _gradeIsOther
        ? _otherGradeValue
        : (_selectedGrade != null && seededGrades.contains(_selectedGrade)
            ? _selectedGrade
            : null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          decoration: _fieldDecoration.copyWith(labelText: 'Grade / Type'),
          isExpanded: true,
          value: validGrade,
          hint: Text('Select grade or type', style: AppTextStyles.bodyMuted),
          items: gradeOptions
              .map(
                (g) => DropdownMenuItem(
                  value: g == MaterialFormDefaults.otherBrandLabel
                      ? _otherGradeValue
                      : g,
                  child: Text(g, style: AppTextStyles.body),
                ),
              )
              .toList(),
          onChanged: (val) {
            setState(() => _selectedGrade = val);
            _updateAutoName(materialVM);
          },
        ),
        if (_gradeIsOther) ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _otherGradeController,
            decoration: _fieldDecoration.copyWith(
              labelText: 'Other grade / type',
              hintText: 'Enter grade or type',
            ),
            style: AppTextStyles.body,
            onChanged: (_) => _updateAutoName(materialVM),
          ),
        ],
      ],
    );
  }

  Widget _buildPhotoPicker() {
    final hasPhoto = _imagePreviewBytes != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: FieldColors.screenBackground,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: _photoError != null
                    ? FieldColors.statusDanger
                    : FieldColors.borderSubtle,
              ),
            ),
            child: hasPhoto
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Image.memory(
                          _imagePreviewBytes!,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Change',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 36,
                        color: FieldColors.textMuted.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Add Photo *',
                        style: AppTextStyles.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: FieldColors.primaryNavy,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Show buyers the actual material or packaging',
                        style: AppTextStyles.caption,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
          ),
        ),
        if (_photoError != null) ...[
          const SizedBox(height: 6),
          Text(
            _photoError!,
            style: AppTextStyles.caption.copyWith(
              color: FieldColors.statusDanger,
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final materialVM = context.watch<MaterialViewModel>();
    final authVM = context.watch<AuthViewModel>();
    final supplierVM = context.watch<SupplierViewModel>();
    final category = materialVM.selectedCategory;
    final adminBrands = category?.brands ?? const <String>[];
    final gradeOptions = _gradeOptions(category);
    final hasCategory = category != null;
    final canSubmit =
        !materialVM.isLoading && materialVM.categories.isNotEmpty;

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Add Material'),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          children: [
            _sectionTitle('Category & Classification'),
            _sectionCard(
              children: [
                _buildCategoryDropdown(materialVM),
                _buildUnitField(category),
                if (hasCategory) _buildBrandField(materialVM, adminBrands),
                if (hasCategory)
                  _buildGradeField(materialVM, gradeOptions),
              ],
            ),
            _sectionTitle('Material Identity'),
            _sectionCard(
              children: [
                TextFormField(
                  controller: _nameController,
                  readOnly: !hasCategory,
                  decoration: _fieldDecoration.copyWith(
                    labelText: 'Material Name *',
                    hintText: hasCategory
                        ? 'e.g. DG Khan Cement OPC 50kg'
                        : 'Select a category first',
                    fillColor: hasCategory
                        ? FieldColors.surfaceWhite
                        : FieldColors.screenBackground,
                  ),
                  style: AppTextStyles.body,
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Material name is required'
                      : null,
                  onChanged: (_) => _nameManuallyEdited = true,
                ),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: _fieldDecoration.copyWith(
                    labelText: 'Description (optional)',
                    hintText:
                        'Additional details about quality, packaging, or specifications',
                    alignLabelWithHint: true,
                  ),
                  style: AppTextStyles.body,
                ),
                _buildPhotoPicker(),
              ],
            ),
            _sectionTitle('Pricing & Quantity'),
            _sectionCard(
              children: [
                TextFormField(
                  controller: _priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _fieldDecoration.copyWith(
                    labelText: 'Price per unit *',
                    prefixText: 'Rs. ',
                  ),
                  style: AppTextStyles.body,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Price is required';
                    }
                    final price = double.tryParse(v.trim());
                    if (price == null || price <= 0) {
                      return 'Price must be greater than 0';
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _minOrderController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: _fieldDecoration.copyWith(
                    labelText: 'Minimum Order Quantity *',
                    hintText: hasCategory
                        ? 'e.g. 50 ${category.unit} minimum'
                        : 'e.g. 50 bags minimum',
                  ),
                  style: AppTextStyles.body,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Minimum order quantity is required';
                    }
                    final qty = double.tryParse(v.trim());
                    if (qty == null || qty < 1) {
                      return 'Minimum order must be at least 1';
                    }
                    return null;
                  },
                ),
                DropdownButtonFormField<String>(
                  decoration:
                      _fieldDecoration.copyWith(labelText: 'Stock Status'),
                  isExpanded: true,
                  value: _stockStatus,
                  items: _stockStatuses
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
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Bulk discount available',
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Offer better rates for large orders',
                    style: AppTextStyles.caption,
                  ),
                  value: _bulkDiscountAvailable,
                  activeThumbColor: FieldColors.accentAmber,
                  onChanged: (val) {
                    setState(() {
                      _bulkDiscountAvailable = val;
                      if (!val) _bulkDiscountDetailsController.clear();
                    });
                  },
                ),
                if (_bulkDiscountAvailable)
                  TextFormField(
                    controller: _bulkDiscountDetailsController,
                    decoration: _fieldDecoration.copyWith(
                      labelText: 'Discount details',
                      hintText: 'e.g. 5% off orders above 200 bags',
                    ),
                    style: AppTextStyles.body,
                  ),
              ],
            ),
            _sectionTitle('Delivery Information'),
            _sectionCard(
              children: [
                DropdownButtonFormField<String>(
                  decoration:
                      _fieldDecoration.copyWith(labelText: 'Delivery Time *'),
                  isExpanded: true,
                  value: _deliveryTime,
                  hint: Text('Select delivery time', style: AppTextStyles.bodyMuted),
                  items: _deliveryTimes
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(d, style: AppTextStyles.body),
                        ),
                      )
                      .toList(),
                  validator: (v) =>
                      v == null ? 'Delivery time is required' : null,
                  onChanged: (val) => setState(() => _deliveryTime = val),
                ),
                TextFormField(
                  controller: _deliveryCoverageController,
                  decoration: _fieldDecoration.copyWith(
                    labelText: 'Delivery Coverage Area',
                    hintText: 'e.g. Rawalpindi, Islamabad',
                  ),
                  style: AppTextStyles.body,
                ),
                DropdownButtonFormField<String>(
                  decoration:
                      _fieldDecoration.copyWith(labelText: 'Delivery Charges'),
                  isExpanded: true,
                  value: _deliveryCharges,
                  hint:
                      Text('Select charge type', style: AppTextStyles.bodyMuted),
                  items: _deliveryChargeOptions
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(d, style: AppTextStyles.body),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _deliveryCharges = val),
                ),
              ],
            ),
            if (materialVM.error != null) ...[
              Text(
                materialVM.error!,
                style: AppTextStyles.body.copyWith(
                  color: FieldColors.statusDanger,
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canSubmit
                    ? () => _submit(materialVM, authVM, supplierVM)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FieldColors.accentAmber,
                  foregroundColor: FieldColors.primaryNavy,
                  disabledBackgroundColor:
                      FieldColors.borderSubtle.withValues(alpha: 0.6),
                ),
                child: materialVM.isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: FieldColors.primaryNavy,
                        ),
                      )
                    : const Text(
                        'Add Material',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
          ],
        ),
      ),
    );
  }
}
