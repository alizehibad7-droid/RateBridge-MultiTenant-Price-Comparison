import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../theme/admin_theme.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';
import '../../models/admin_payment_record.dart';

class AdminPaymentQueueView extends StatefulWidget {
  final bool embedded;

  const AdminPaymentQueueView({this.embedded = false, super.key});

  @override
  State<AdminPaymentQueueView> createState() => _AdminPaymentQueueViewState();
}

class _AdminPaymentQueueViewState extends State<AdminPaymentQueueView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _roleFilter = 'all';
  String _statusFilter = 'all';

  bool get _isDesktop => MediaQuery.of(context).size.width >= 1024;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().loadPaymentQueue();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<AdminPaymentRecord> _filter(List<AdminPaymentRecord> input) {
    return input.where((r) {
      if (_roleFilter == 'ceo' && !r.isCeo) return false;
      if (_roleFilter == 'supplier' && !r.isSupplier) return false;
      if (_statusFilter != 'all' && r.status != _statusFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final allPayments = _filter(adminVM.successfulPaymentRecords);
    final issues = _filter(adminVM.incompletePaymentRecords);

    Widget content = Column(
      children: [
        Container(
          color: Colors.white,
          child: Material(
            type: MaterialType.transparency,
            child: TabBar(
              controller: _tabController,
              labelColor: AdminColors.navy,
              unselectedLabelColor: AdminColors.textGrey,
              indicatorColor: AdminColors.amber,
              indicatorWeight: 3,
              tabs: const [
                Tab(icon: Icon(Icons.payments_rounded, size: 20), text: 'All Payments'),
                Tab(icon: Icon(Icons.error_outline_rounded, size: 20), text: 'Failed / Incomplete'),
              ],
            ),
          ),
        ),
        _buildFilters(),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildList(allPayments, adminVM, emptyTitle: 'No Stripe payments yet', emptySubtitle: 'CEO subscriptions and supplier commission settlements appear here after successful checkout.'),
              _buildList(issues, adminVM, emptyTitle: 'No failed or incomplete payments', emptySubtitle: 'Checkout errors or in-progress Stripe jobs will appear here.'),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return Material(
        color: AdminColors.screenBg,
        child: content,
      );
    }

    return Scaffold(
      appBar: const AdminAppBar(title: 'Payments'),
      backgroundColor: AdminColors.screenBg,
      body: content,
    );
  }

  Widget _buildFilters() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      color: Colors.white,
      child: Material(
        type: MaterialType.transparency,
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Payer', style: AdminTheme.mutedStyle(size: 11)),
            _chip('All', _roleFilter == 'all', () => setState(() => _roleFilter = 'all')),
            _chip('CEO', _roleFilter == 'ceo', () => setState(() => _roleFilter = 'ceo')),
            _chip('Supplier', _roleFilter == 'supplier', () => setState(() => _roleFilter = 'supplier')),
            const SizedBox(width: 8),
            Text('Status', style: AdminTheme.mutedStyle(size: 11)),
            _chip('All', _statusFilter == 'all', () => setState(() => _statusFilter = 'all')),
            _chip('Success', _statusFilter == 'success', () => setState(() => _statusFilter = 'success')),
            _chip('Pending', _statusFilter == 'pending', () => setState(() => _statusFilter = 'pending')),
            _chip('Failed', _statusFilter == 'failed', () => setState(() => _statusFilter = 'failed')),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AdminColors.navy.withValues(alpha: 0.12),
      checkmarkColor: AdminColors.navy,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: selected ? AdminColors.navy : AdminColors.textGrey,
      ),
      side: BorderSide(color: selected ? AdminColors.navy : AdminColors.border),
    );
  }

  Widget _buildList(
    List<AdminPaymentRecord> payments,
    AdminViewModel vm, {
    required String emptyTitle,
    required String emptySubtitle,
  }) {
    if (vm.isLoading && payments.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (payments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_wallet_outlined, size: 64, color: AdminColors.textGrey.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text(emptyTitle, style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.textGrey)),
              const SizedBox(height: 8),
              Text(emptySubtitle, textAlign: TextAlign.center, style: AdminTheme.mutedStyle()),
            ],
          ),
        ),
      );
    }

    if (_isDesktop) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: AdminCard(
          padding: EdgeInsets.zero,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AdminColors.navy.withValues(alpha: 0.03)),
              columns: [
                DataColumn(label: Text('Payer', style: AdminTheme.sectionHeaderStyle())),
                DataColumn(label: Text('Type', style: AdminTheme.sectionHeaderStyle())),
                DataColumn(label: Text('Related', style: AdminTheme.sectionHeaderStyle())),
                DataColumn(label: Text('Amount', style: AdminTheme.sectionHeaderStyle())),
                DataColumn(label: Text('Date', style: AdminTheme.sectionHeaderStyle())),
                DataColumn(label: Text('Status', style: AdminTheme.sectionHeaderStyle())),
              ],
              rows: payments.map((p) => DataRow(cells: [
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.payerName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                    Text('${p.payerRole}${p.companyName.isNotEmpty ? ' · ${p.companyName}' : ''}', style: AdminTheme.mutedStyle(size: 10)),
                  ],
                )),
                DataCell(Text(p.type.toUpperCase())),
                DataCell(SizedBox(width: 160, child: Text(p.relatedLabel, maxLines: 2, overflow: TextOverflow.ellipsis))),
                DataCell(Text('Rs ${p.amount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700))),
                DataCell(Text(DateFormat('MMM dd, yyyy').format(p.date))),
                DataCell(StatusChip(status: p.status)),
              ])).toList(),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => vm.loadPaymentQueue(),
      color: AdminColors.amber,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _PaymentTile(payments[i]),
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  final AdminPaymentRecord payment;

  const _PaymentTile(this.payment);

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(payment.payerName, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AdminColors.navy)),
                    Text('${payment.payerRole} · ${payment.type.toUpperCase()}', style: AdminTheme.mutedStyle(size: 11)),
                  ],
                ),
              ),
              Text('Rs ${payment.amount.toStringAsFixed(0)}', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17)),
            ],
          ),
          const SizedBox(height: 12),
          Text(payment.relatedLabel, style: AdminTheme.bodyStyle(size: 13)),
          if (payment.companyName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(payment.companyName, style: AdminTheme.mutedStyle(size: 12)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              StatusChip(status: payment.status),
              const Spacer(),
              Text(DateFormat('MMM dd, yyyy · HH:mm').format(payment.date), style: AdminTheme.mutedStyle(size: 11)),
            ],
          ),
          if (payment.stripeRef != null && payment.stripeRef!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Stripe ref: ${payment.stripeRef}', style: AdminTheme.mutedStyle(size: 10)),
          ],
        ],
      ),
    );
  }
}
