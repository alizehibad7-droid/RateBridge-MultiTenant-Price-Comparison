import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/audit_log_model.dart';
import '../../theme/admin_theme.dart';
import '../../services/firestore_service.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminAuditLogView extends StatefulWidget {
  const AdminAuditLogView({super.key});

  @override
  State<AdminAuditLogView> createState() => _AdminAuditLogViewState();
}

class _AdminAuditLogViewState extends State<AdminAuditLogView> {
  String _selectedActionType = 'all';

  static const _filters = <({String value, String label, IconData icon})>[
    (value: 'all', label: 'All Activity', icon: Icons.history_rounded),
    (value: 'approve_ceo', label: 'Approve CEO', icon: Icons.person_add_rounded),
    (value: 'reject_ceo', label: 'Reject CEO', icon: Icons.person_remove_rounded),
    (value: 'approve_supplier', label: 'Approve Supplier', icon: Icons.store_rounded),
    (value: 'reject_supplier', label: 'Reject Supplier', icon: Icons.store_rounded),
    (value: 'ban_company', label: 'Ban Company', icon: Icons.block_rounded),
    (value: 'reactivate_company', label: 'Restore Company', icon: Icons.settings_backup_restore_rounded),
    (value: 'ban_supplier', label: 'Ban Supplier', icon: Icons.no_accounts_rounded),
    (value: 'reactivate_supplier', label: 'Restore Supplier', icon: Icons.person_add_alt_1_rounded),
    (value: 'resolve_dispute', label: 'Disputes', icon: Icons.gavel_rounded),
    (value: 'settle_commission', label: 'Commissions', icon: Icons.payments_rounded),
    (value: 'restrict_supplier_commission', label: 'Restrictions', icon: Icons.money_off_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: const AdminAppBar(title: 'System Activity Log'),
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
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AdminColors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Could not load activity log: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: AdminTheme.mutedStyle(),
                          ),
                        ],
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
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AdminColors.navy.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.history_edu_rounded, size: 64, color: AdminColors.textGrey),
                        ),
                        const SizedBox(height: 24),
                        Text('No activity recorded yet', style: AdminTheme.titleStyle(size: 20)),
                        Text('System actions will appear here', style: AdminTheme.mutedStyle()),
                      ],
                    ),
                  );
                }

                if (logs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.filter_list_off_rounded, size: 64, color: AdminColors.textGrey),
                        const SizedBox(height: 16),
                        Text(
                          'No entries for this action',
                          style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.textGrey),
                        ),
                        TextButton(
                          onPressed: () => setState(() => _selectedActionType = 'all'),
                          child: const Text('Clear Filter'),
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: _filters
              .map(
                (filter) => _FilterChip(
                  icon: filter.icon,
                  label: filter.label,
                  value: filter.value,
                  selected: _selectedActionType == filter.value,
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
  final IconData icon;
  final String label;
  final String value;
  final bool selected;
  final Function(String) onSelect;
  const _FilterChip({required this.icon, required this.label, required this.value, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 14, color: selected ? AdminColors.amber : AdminColors.textGrey),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelect(value),
        selectedColor: AdminColors.amber.withValues(alpha: 0.1),
        checkmarkColor: AdminColors.amber,
        backgroundColor: AdminColors.screenBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: selected ? AdminColors.amber : AdminColors.border),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AdminColors.darkAmber : AdminColors.navy,
        ),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.border),
      ),
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AdminColors.navy.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_getIcon(log.actionType), size: 22, color: AdminColors.navy),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.description,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AdminColors.navy,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 12, color: AdminColors.textGrey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'By ${log.actorName}',
                              style: AdminTheme.mutedStyle(size: 12).copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 12, color: AdminColors.textGrey),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('MMM dd, yyyy · hh:mm a').format(log.timestamp),
                            style: AdminTheme.mutedStyle(size: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (log.reason != null && log.reason!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.screenBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notes_rounded, size: 12, color: AdminColors.textGrey),
                        const SizedBox(width: 6),
                        Text('NOTES / REASON', style: AdminTheme.sectionHeaderStyle().copyWith(fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(log.reason!, style: GoogleFonts.plusJakartaSans(fontSize: 13, color: AdminColors.navy, height: 1.4)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AdminColors.navy.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.track_changes_rounded, size: 12, color: AdminColors.textGrey),
                  const SizedBox(width: 6),
                  Text(
                    'Target: ${log.targetType.toUpperCase()}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.w700, color: AdminColors.textGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String type) {
    if (type.contains('approve') || type.contains('reactivate') || type.contains('activate')) {
      return Icons.check_circle_rounded;
    }
    if (type.contains('reject')) return Icons.cancel_rounded;
    if (type.contains('ban') || type.contains('suspend')) return Icons.block_rounded;
    if (type.contains('category')) return Icons.category_rounded;
    if (type.contains('transaction') || type.contains('commission')) {
      return Icons.receipt_long_rounded;
    }
    if (type.contains('dispute')) return Icons.gavel_rounded;
    return Icons.info_outline_rounded;
  }
}
