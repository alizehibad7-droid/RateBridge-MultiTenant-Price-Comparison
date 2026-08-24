import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/audit_log_model.dart';
import '../../theme/admin_theme.dart';
import '../../services/firestore_service.dart';

class AdminAuditLogView extends StatefulWidget {
  const AdminAuditLogView({super.key});

  @override
  State<AdminAuditLogView> createState() => _AdminAuditLogViewState();
}

class _AdminAuditLogViewState extends State<AdminAuditLogView> {
  String _selectedActionType = 'all';

  static const _filters = <({String value, String label})>[
    (value: 'all', label: 'All'),
    (value: 'approve_ceo', label: 'Approve CEO'),
    (value: 'reject_ceo', label: 'Reject CEO'),
    (value: 'approve_supplier', label: 'Approve Supplier'),
    (value: 'reject_supplier', label: 'Reject Supplier'),
    (value: 'ban_company', label: 'Ban Company'),
    (value: 'reactivate_company', label: 'Reactivate Company'),
    (value: 'ban_supplier', label: 'Ban Supplier'),
    (value: 'reactivate_supplier', label: 'Reactivate Supplier'),
    (value: 'resolve_dispute', label: 'Resolve Dispute'),
    (value: 'settle_commission', label: 'Settle Commission'),
    (value: 'restrict_supplier_commission', label: 'Restrict Commission'),
    (value: 'lift_commission_restriction', label: 'Lift Commission Restriction'),
    (value: 'update_commission_settings', label: 'Commission Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: const AdminAppBar(title: 'Admin Activity Log'),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<AuditLogModel>>(
              stream: firestoreService.streamAuditLogs(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load activity log: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final allLogs = snapshot.data ?? [];
                final logs = _filteredLogs(allLogs);

                if (allLogs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_edu_outlined, size: 64, color: AdminColors.textGrey),
                        const SizedBox(height: 16),
                        Text('No activity recorded yet', style: AdminTheme.titleStyle()),
                      ],
                    ),
                  );
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.filter_alt_off_outlined, size: 64, color: AdminColors.textGrey),
                        const SizedBox(height: 16),
                        Text(
                          'No entries for this action type',
                          style: AdminTheme.titleStyle(),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => _AuditLogTile(log: logs[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<AuditLogModel> _filteredLogs(List<AuditLogModel> logs) {
    if (_selectedActionType == 'all') return logs;
    final matches = AuditLogModel.matchingActionTypes(_selectedActionType);
    return logs.where((log) => matches.contains(log.actionType)).toList();
  }

  Widget _buildFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filters
              .map(
                (type) => _FilterChip(
                  label: type.label,
                  value: type.value,
                  selected: _selectedActionType == type.value,
                  onSelect: (v) => setState(() => _selectedActionType = v),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final Function(String) onSelect;
  const _FilterChip({required this.label, required this.value, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: const TextStyle(fontSize: 10)),
        selected: selected,
        onSelected: (_) => onSelect(value),
        selectedColor: AdminColors.amber.withValues(alpha: 0.2),
        checkmarkColor: AdminColors.amber,
      ),
    );
  }
}

class _AuditLogTile extends StatelessWidget {
  final AuditLogModel log;
  const _AuditLogTile({required this.log});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AdminColors.navy.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_getIcon(log.actionType), size: 20, color: AdminColors.navy),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.description,
                        style: AdminTheme.titleStyle(size: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'By ${log.actorName} (${log.actorId})',
                        style: AdminTheme.mutedStyle(size: 12),
                      ),
                      Text(
                        DateFormat('MMM dd, yyyy - hh:mm a').format(log.timestamp),
                        style: AdminTheme.mutedStyle(size: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (log.reason != null && log.reason!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.screenBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('REASON / NOTES', style: AdminTheme.sectionHeaderStyle()),
                    const SizedBox(height: 4),
                    Text(log.reason!, style: AdminTheme.bodyStyle(color: AdminColors.textGrey)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Target: ${log.targetType.toUpperCase()} (${log.targetId})',
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 10, color: AdminColors.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    if (type.contains('approve') || type.contains('reactivate') || type.contains('activate')) {
      return Icons.check_circle_outline;
    }
    if (type.contains('reject')) return Icons.cancel_outlined;
    if (type.contains('ban') || type.contains('suspend')) return Icons.block;
    if (type.contains('category')) return Icons.category_outlined;
    if (type.contains('transaction') || type.contains('commission')) {
      return Icons.receipt_long;
    }
    if (type.contains('dispute')) return Icons.gavel;
    return Icons.info_outline;
  }
}
