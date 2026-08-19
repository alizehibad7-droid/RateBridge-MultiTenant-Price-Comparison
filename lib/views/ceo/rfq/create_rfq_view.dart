import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../constants/app_constants.dart';
import '../../../constants/pakistan_cities.dart';
import '../../../constants/route_names.dart';
import '../../../services/plan_limit_service.dart';
import '../../../theme/ceo_theme.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/ceo_viewmodel.dart';
import '../../../viewmodels/rfq_viewmodel.dart';

class CreateRfqView extends StatefulWidget {
  final bool fieldUser;

  const CreateRfqView({super.key, this.fieldUser = false});

  @override
  State<CreateRfqView> createState() => _CreateRfqViewState();
}

class _CreateRfqViewState extends State<CreateRfqView> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();

  String? _selectedCategory;
  String? _selectedCity;
  DateTime? _requiredDate;
  String? _checkedCompanyId;
  Future<bool>? _premiumAccess;

  @override
  void dispose() {
    _descController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _requiredDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _selectedCategory == null ||
        _selectedCity == null ||
        _requiredDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    final company = context.read<CeoViewModel>().company;
    final user = context.read<AuthViewModel>().user;
    final rfqVM = context.read<RfqViewModel>();
    final companyId = company?.id ?? user?.companyId ?? '';
    if (companyId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company account could not be resolved.')),
      );
      return;
    }

    await rfqVM.createRfq(
      companyId: companyId,
      companyName: company?.name ?? '',
      category: _selectedCategory!,
      materialDescription: _descController.text.trim(),
      quantity: double.parse(_quantityController.text.trim()),
      unit: _unitController.text.trim(),
      city: _selectedCity!,
      requiredByDate: _requiredDate!,
    );

    if (mounted) {
      if (rfqVM.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(rfqVM.error!), backgroundColor: CeoColors.red),
        );
      } else {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quote request published to suppliers!'),
            backgroundColor: CeoColors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rfqVM = context.watch<RfqViewModel>();
    final company = context.watch<CeoViewModel>().company;
    final user = context.watch<AuthViewModel>().user;
    final companyId = company?.id ?? user?.companyId ?? '';
    if (companyId.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_checkedCompanyId != companyId) {
      _checkedCompanyId = companyId;
      _premiumAccess = PlanLimitService.companyPlan(
        FirebaseFirestore.instance,
        companyId,
      ).then((plan) => plan.planKey == 'premium');
    }

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: const CeoAppBar(title: 'New Quote Request'),
      body: FutureBuilder<bool>(
        future: _premiumAccess,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.workspace_premium_outlined,
                      color: CeoColors.amber,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Premium plan required',
                      style: CeoTheme.titleStyle(size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.fieldUser
                          ? 'Bulk Quote Requests are only available on the Premium plan. Ask your CEO to upgrade the company plan.'
                          : 'Bulk Quote Requests are only available on the Premium plan.',
                      textAlign: TextAlign.center,
                      style: CeoTheme.mutedStyle(),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed:
                          widget.fieldUser
                              ? () => context.pop()
                              : () => context.go(RouteNames.ceoSubscription),
                      child: Text(widget.fieldUser ? 'GO BACK' : 'VIEW PLANS'),
                    ),
                  ],
                ),
              ),
            );
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: CeoTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CeoSectionLabel('What do you need?'),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        hint: const Text('Select Category'),
                        items:
                            AppConstants.defaultCategories
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v),
                        decoration: CeoTheme.inputDecoration(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        decoration: CeoTheme.inputDecoration(
                          labelText: 'Material Description',
                          hintText: 'e.g. 500 bags of OPC Lucky Cement',
                        ),
                        validator:
                            (v) =>
                                v?.isEmpty == true
                                    ? 'Description required'
                                    : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: CeoTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CeoSectionLabel('Quantity & Location'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: CeoTheme.inputDecoration(
                                labelText: 'Quantity',
                              ),
                              validator:
                                  (v) =>
                                      double.tryParse(v ?? '') == null
                                          ? 'Invalid'
                                          : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _unitController,
                              decoration: CeoTheme.inputDecoration(
                                labelText: 'Unit',
                                hintText: 'Bags/Tons',
                              ),
                              validator:
                                  (v) => v?.isEmpty == true ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedCity,
                        hint: const Text('City of Delivery'),
                        items:
                            kPakistanMajorCities
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(c),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) => setState(() => _selectedCity = v),
                        decoration: CeoTheme.inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: CeoTheme.cardDecoration(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CeoSectionLabel('Timeline'),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Required By Date'),
                        subtitle: Text(
                          _requiredDate == null
                              ? 'Not selected'
                              : DateFormat(
                                'MMM dd, yyyy',
                              ).format(_requiredDate!),
                        ),
                        trailing: const Icon(
                          Icons.calendar_today,
                          color: CeoColors.amber,
                        ),
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: rfqVM.isLoading ? null : _submit,
                  style: CeoTheme.primaryButtonStyle(height: 54),
                  child:
                      rfqVM.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('PUBLISH REQUEST'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
