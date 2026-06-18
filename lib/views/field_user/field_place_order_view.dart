import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../models/material_listing.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/field_user_viewmodel.dart';

class FieldPlaceOrderView extends StatefulWidget {
  final MaterialListing material;

  const FieldPlaceOrderView({super.key, required this.material});

  @override
  State<FieldPlaceOrderView> createState() => _FieldPlaceOrderViewState();
}

class _FieldPlaceOrderViewState extends State<FieldPlaceOrderView> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime? _requiredDate;

  @override
  void dispose() {
    _quantityController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _quantity => double.tryParse(_quantityController.text.trim()) ?? 0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) setState(() => _requiredDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_requiredDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a required delivery date'), backgroundColor: Colors.red),
      );
      return;
    }

    final fieldVm = context.read<FieldUserViewModel>();
    
    final success = await fieldVm.placeOrder(
      materialId: widget.material.id,
      materialName: widget.material.materialName,
      supplierId: widget.material.supplierId,
      supplierName: widget.material.supplierName,
      unit: widget.material.unit,
      unitPrice: widget.material.pricePerUnit,
      quantity: _quantity,
      siteLocation: _locationController.text,
      requiredDate: _requiredDate!,
      notes: _noteController.text,
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order sent for CEO approval'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop();
    } else if (fieldVm.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fieldVm.error!), backgroundColor: Colors.red),
      );
      fieldVm.clearError();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldVm = context.watch<FieldUserViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('Place Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(widget.material.materialName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(labelText: 'Quantity (${widget.material.unit})'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(labelText: 'Site Location'),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(_requiredDate == null ? 'Select Delivery Date' : 'Delivery: ${_requiredDate.toString().split(' ')[0]}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Notes (Optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: fieldVm.isLoading ? null : _submit,
                child: fieldVm.isLoading ? const CircularProgressIndicator() : const Text('Send for Approval'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
