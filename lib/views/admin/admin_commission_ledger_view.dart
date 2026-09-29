import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../theme/admin_theme.dart';
import '../../models/transaction_model.dart';
import '../../models/admin_payment_record.dart';
import '../../repositories/transaction_repository.dart';
import '../../viewmodels/admin_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminCommissionLedgerView extends StatefulWidget {
  const AdminCommissionLedgerView({super.key});

  @override
  State<AdminCommissionLedgerView> createState() =>
      _AdminCommissionLedgerViewState();
}

class _AdminCommissionLedgerViewState extends State<AdminCommissionLedgerView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0);
  Stream<CommissionLedgerSnapshot>? _ledgerStream;

  bool _checkIsDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1024;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdminViewModel>().loadPaymentQueue();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ledgerStream ??=
        context.read<TransactionRepository>().watchCommissionLedger();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final adminVM = context.watch<AdminViewModel>();
    final settled = adminVM.commissionSettlementRecords;

    return Column(
      children: [
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AdminColors.navy,
            unselectedLabelColor: AdminColors.textGrey,
            indicatorColor: AdminColors.navy,
            indicatorWeight: 3,
            tabs: const [
              Tab(
                icon: Icon(Icons.account_balance_wallet_rounded, size: 20),
                text: 'Active Ledger',
              ),
              Tab(
                icon: Icon(Icons.history_rounded, size: 20),
                text: 'Stripe Settlements',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildLedgerTab(adminVM),
              _buildSettledTab(settled, adminVM),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLedgerTab(AdminViewModel adminVM) {
    final isDesktop = _checkIsDesktop(context);
    return StreamBuilder<CommissionLedgerSnapshot>(
      stream: _ledgerStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final ledger = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () => adminVM.loadPaymentQueue(),
          color: AdminColors.amber,
          child: ListView(
            padding: EdgeInsets.all(isDesktop ? 32 : 16),
            children: [
              _SummaryStrip(
                outstanding: ledger.outstandingThisMonth,
                collected: ledger.collectedThisMonth,
                grandTotal: ledger.grandTotalCollected,
                currency: _currency,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  const Icon(Icons.store_rounded,
                      color: AdminColors.navy, size: 18),
                  const SizedBox(width: 8),
                  const AdminSectionLabel('Supplier Balances (unsettled)'),
                ],
              ),
              const SizedBox(height: 12),
              if (ledger.suppliers.isEmpty)
                AdminCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Column(
                        children: [
                          Icon(Icons.check_circle_outline_rounded,
                              color: AdminColors.green.withValues(alpha: 0.5),
                              size: 64),
                          const SizedBox(height: 16),
                          const Text(
                            'No outstanding commissions.',
                            style: TextStyle(
                              color: AdminColors.textGrey,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Suppliers pay via Stripe; settled amounts move to Stripe Settlements.',
                            textAlign: TextAlign.center,
                            style: AdminTheme.mutedStyle(size: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (isDesktop)
                _buildSupplierBalancesTable(ledger.suppliers)
              else
                ...ledger.suppliers.map(
                  (s) => _SupplierBalanceTile(supplier: s, currency: _currency),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupplierBalancesTable(List<SupplierUnsettledSummary> suppliers) {
    return AdminCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor:
              WidgetStateProperty.all(AdminColors.navy.withValues(alpha: 0.03)),
          columns: [
            DataColumn(
                label: Text('Supplier',
                    style: AdminTheme.sectionHeaderStyle())),
            DataColumn(
                label: Text('Pending Orders',
                    style: AdminTheme.sectionHeaderStyle())),
            DataColumn(
                label: Text('Outstanding',
                    style: AdminTheme.sectionHeaderStyle())),
          ],
          rows: suppliers
              .map((s) => DataRow(cells: [
                    DataCell(Text(s.supplierName,
                        style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700))),
                    DataCell(Text('${s.orderCount}')),
                    DataCell(Text(_currency.format(s.unsettledAmount),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AdminColors.red))),
                  ]))
              .toList(),
        ),
      ),
    );
  }

  Widget _buildSettledTab(
      List<AdminPaymentRecord> settled, AdminViewModel adminVM) {
    if (adminVM.isLoading && settled.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (settled.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.history_rounded,
                size: 64, color: AdminColors.textGrey),
            const SizedBox(height: 16),
            Text('No Stripe settlements yet',
                style: AdminTheme.titleStyle(size: 18)
                    .copyWith(color: AdminColors.textGrey)),
            const SizedBox(height: 8),
            Text('Supplier commission payments via Stripe appear here.',
                style: AdminTheme.mutedStyle()),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: settled.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = settled[i];
        return AdminCard(
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(p.payerName,
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700, color: AdminColors.navy)),
            subtitle: Text(
              '${p.relatedLabel}\n${DateFormat('MMM dd, yyyy').format(p.date)}',
              style: AdminTheme.mutedStyle(size: 12),
            ),
            isThreeLine: true,
            trailing: Text(
              'Rs ${p.amount.toStringAsFixed(0)}',
              style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ),
        );
      },
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  final double outstanding;
  final double collected;
  final double grandTotal;
  final NumberFormat currency;
  final bool isDesktop;

  const _SummaryStrip({
    required this.outstanding,
    required this.collected,
    required this.grandTotal,
    required this.currency,
    required this.isDesktop,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _StatBox(
          label: 'Outstanding (unsettled)',
          value: currency.format(outstanding),
          color: AdminColors.red,
          wide: isDesktop,
        ),
        _StatBox(
          label: 'Collected this month',
          value: currency.format(collected),
          color: AdminColors.green,
          wide: isDesktop,
        ),
        _StatBox(
          label: 'Total collected (Stripe)',
          value: currency.format(grandTotal),
          color: AdminColors.navy,
          wide: isDesktop,
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool wide;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
    required this.wide,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: wide ? 220 : double.infinity,
      child: AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AdminTheme.mutedStyle(size: 11)),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierBalanceTile extends StatelessWidget {
  final SupplierUnsettledSummary supplier;
  final NumberFormat currency;

  const _SupplierBalanceTile({
    required this.supplier,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(supplier.supplierName,
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
        subtitle: Text('${supplier.orderCount} pending order(s)'),
        trailing: Text(
          currency.format(supplier.unsettledAmount),
          style: const TextStyle(
              fontWeight: FontWeight.w800, color: AdminColors.red),
        ),
      ),
    );
  }
}
