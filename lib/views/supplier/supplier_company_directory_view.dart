// MVVM: View — no business logic
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/supplier_viewmodel.dart';
import '../../models/company_model.dart';
import '../../constants/app_colors.dart';
import 'dart:async';

class SupplierCompanyDirectoryView extends StatefulWidget {
  const SupplierCompanyDirectoryView({super.key});

  @override
  State<SupplierCompanyDirectoryView> createState() => _SupplierCompanyDirectoryViewState();
}

class _SupplierCompanyDirectoryViewState extends State<SupplierCompanyDirectoryView> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupplierViewModel>().loadCompanyDirectory();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      context.read<SupplierViewModel>().searchCompanies(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<SupplierViewModel>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Company Directory', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search companies...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: viewModel.isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: viewModel.companies.length,
                  itemBuilder: (context, index) {
                    final company = viewModel.companies[index];
                    return _buildCompanyCard(viewModel, company);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(SupplierViewModel viewModel, CompanyModel company) {
    // Check link status - this would ideally be in a stream or pre-loaded map
    bool isLinked = viewModel.companies.any((c) => c.id == company.id); // Placeholder logic
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.business)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(company.city, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Active since 2023', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text('Network: 50+ Suppliers', style: const TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusButton(viewModel, company),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusButton(SupplierViewModel viewModel, CompanyModel company) {
    // Real app would check a list of active links and pending requests
    return ElevatedButton(
      onPressed: () => _showRequestDialog(viewModel, company),
      style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
      child: const Text('SEND JOIN REQUEST'),
    );
  }

  void _showRequestDialog(SupplierViewModel viewModel, CompanyModel company) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Company'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Send a request to join ${company.name}\'s supplier network.'),
            const SizedBox(height: 16),
            TextField(controller: controller, decoration: const InputDecoration(hintText: 'Optional message...')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await viewModel.sendJoinRequest(company.id, controller.text);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request sent successfully')));
              }
            },
            child: const Text('SEND'),
          ),
        ],
      ),
    );
  }
}
