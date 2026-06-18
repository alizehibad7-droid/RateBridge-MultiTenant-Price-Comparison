// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../constants/app_colors.dart';
import '../../constants/route_names.dart';

class SupplierCompanyOnboardingView extends StatefulWidget {
  final String companyId;
  final String companyName;

  const SupplierCompanyOnboardingView({
    super.key,
    required this.companyId,
    required this.companyName,
  });

  @override
  State<SupplierCompanyOnboardingView> createState() => _SupplierCompanyOnboardingViewState();
}

class _SupplierCompanyOnboardingViewState extends State<SupplierCompanyOnboardingView> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _contactNameController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _introController;
  
  String _selectedPaymentTerm = 'Cash';
  final List<String> _paymentTerms = ['Cash', '3-day credit', '7-day credit', '30-day credit'];
  
  final List<String> _selectedCities = [];
  final List<String> _availableCities = ['Lahore', 'Karachi', 'Islamabad', 'Faisalabad', 'Multan', 'Rawalpindi'];

  @override
  void initState() {
    super.initState();
    final profile = context.read<SupplierViewModel>().profile;
    _contactNameController = TextEditingController(text: profile?.name);
    _contactPhoneController = TextEditingController(text: profile?.phone);
    _introController = TextEditingController();
  }

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _introController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SupplierViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Setup for ${widget.companyName}', style: const TextStyle(fontWeight: FontWeight.w800)),
        automaticallyImplyLeading: false, // No back arrow as per prompt
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Complete your profile for this specific company to start receiving orders.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            
            TextFormField(
              controller: _contactNameController,
              decoration: const InputDecoration(labelText: 'Contact Person Name'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _contactPhoneController,
              decoration: const InputDecoration(labelText: 'Contact Phone'),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),

            const Text('DELIVERY CITIES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _availableCities.map((city) {
                final isSelected = _selectedCities.contains(city);
                return FilterChip(
                  label: Text(city),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCities.add(city);
                      } else {
                        _selectedCities.remove(city);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            DropdownButtonFormField<String>(
              value: _selectedPaymentTerm,
              decoration: const InputDecoration(labelText: 'Payment Terms'),
              items: _paymentTerms.map((term) => DropdownMenuItem(value: term, child: Text(term))).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPaymentTerm = val);
              },
            ),
            const SizedBox(height: 24),

            TextFormField(
              controller: _introController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Introduction / Note (Optional)',
                hintText: 'Briefly describe your services to this company...',
              ),
            ),
            const SizedBox(height: 48),

            ElevatedButton(
              onPressed: viewModel.isLoading ? null : () async {
                if (_formKey.currentState!.validate()) {
                  if (_selectedCities.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one delivery city'))
                    );
                    return;
                  }
                  
                  await viewModel.completeCompanyOnboarding(widget.companyId, {
                    'contactName': _contactNameController.text,
                    'contactPhone': _contactPhoneController.text,
                    'deliveryCities': _selectedCities,
                    'paymentTerms': _selectedPaymentTerm,
                    'introNote': _introController.text,
                  });
                  
                  if (mounted && viewModel.error == null) {
                    context.go(RouteNames.supplierDashboard);
                  }
                }
              },
              child: viewModel.isLoading 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text('COMPLETE SETUP'),
            ),
          ],
        ),
      ),
    );
  }
}
