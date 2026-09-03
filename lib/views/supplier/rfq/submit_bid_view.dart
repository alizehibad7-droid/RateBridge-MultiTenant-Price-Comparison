import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../models/rfq_model.dart';
import '../../../theme/supplier_theme.dart';
import '../../../viewmodels/supplier_viewmodel.dart';

class SubmitBidView extends StatefulWidget {
  final String rfqId;
  final FirebaseFirestore? debugFirestore;

  const SubmitBidView({
    super.key,
    required this.rfqId,
    @visibleForTesting this.debugFirestore,
  });

  @override
  State<SubmitBidView> createState() => _SubmitBidViewState();
}

class _SubmitBidViewState extends State<SubmitBidView> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _noteController = TextEditingController();

  RfqModel? _rfq;
  bool _loading = true;
  bool _hasExistingBid = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final vm = context.read<SupplierViewModel>();
    final db = widget.debugFirestore ?? FirebaseFirestore.instance;
    final rfqDoc = await db.collection('rfqs').doc(widget.rfqId).get();
    if (rfqDoc.exists) {
      _rfq = RfqModel.fromMap(rfqDoc.id, rfqDoc.data()!);
      // Check if existing bid
      final myBid = await vm.getMyBid(widget.rfqId);
      if (myBid != null) {
        _hasExistingBid = true;
        _priceController.text = myBid.bidPrice.toString();
        _deliveryController.text = myBid.estimatedDeliveryTime;
        _noteController.text = myBid.note ?? '';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _priceController.dispose();
    _deliveryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final vm = context.read<SupplierViewModel>();
    await vm.submitRfqBid(
      rfqId: widget.rfqId,
      bidPrice: double.parse(_priceController.text.trim()),
      deliveryTime: _deliveryController.text.trim(),
      note: _noteController.text.trim(),
    );

    if (mounted) {
      if (vm.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.error!),
            backgroundColor: FieldColors.statusDanger,
          ),
        );
      } else {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(vm.successMessage ?? 'Bid submitted successfully.'),
            backgroundColor: FieldColors.statusSuccess,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_rfq == null) {
      return const Scaffold(body: Center(child: Text('Request not found')));
    }

    final supplierVM = context.watch<SupplierViewModel>();
    final isOpen = _rfq!.status == 'open';

    return Scaffold(
      backgroundColor: FieldColors.screenBackground,
      appBar: const SupplierAppBar(title: 'Submit Bid'),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _buildRfqSummary(),
            if (!isOpen) ...[
              const SizedBox(height: 16),
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: FieldColors.statusDanger),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This quote request is closed and no longer accepts bids.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: SupplierTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your Bid Details', style: FieldTypography.titleMedium),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: SupplierTheme.fieldDecoration(
                      labelText: 'Unit Price (PKR)',
                      hintText: 'e.g. 1200',
                    ),
                    validator: (v) {
                      final value = double.tryParse(v ?? '');
                      return value == null || value <= 0
                          ? 'Enter a price greater than zero'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _deliveryController,
                    decoration: SupplierTheme.fieldDecoration(
                      labelText: 'Estimated Delivery Time',
                      hintText: 'e.g. 24-48 hours',
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _noteController,
                    maxLines: 3,
                    decoration: SupplierTheme.fieldDecoration(
                      labelText: 'Notes to Buyer (Optional)',
                      hintText: 'Any specific terms or quality notes...',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: supplierVM.isLoading || !isOpen ? null : _submit,
              child:
                  supplierVM.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_hasExistingBid ? 'UPDATE BID' : 'SUBMIT BID'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRfqSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: SupplierTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_rfq!.category.toUpperCase(), style: FieldTypography.labelSmall),
          const SizedBox(height: 4),
          Text(_rfq!.materialDescription, style: FieldTypography.titleMedium),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryItem(
                label: 'Quantity',
                value: '${_rfq!.quantity} ${_rfq!.unit}',
              ),
              _SummaryItem(label: 'Location', value: _rfq!.city),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: FieldTypography.labelSmall),
        Text(
          value,
          style: FieldTypography.bodyLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
