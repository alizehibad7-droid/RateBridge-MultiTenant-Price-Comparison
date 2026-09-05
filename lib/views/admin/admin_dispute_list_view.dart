import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dispute_model.dart';
import '../../theme/admin_theme.dart';
import '../../utils/app_exception.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dispute_viewmodel.dart';
import '../../widgets/admin/admin_widgets.dart';

class AdminDisputeListView extends StatefulWidget {
  const AdminDisputeListView({super.key});

  @override
  State<AdminDisputeListView> createState() => _AdminDisputeListViewState();
}

class _AdminDisputeListViewState extends State<AdminDisputeListView> {
  String _selectedStatus = 'all';

  @override
  Widget build(BuildContext context) {
    final disputeVM = context.read<DisputeViewModel>();

    return Scaffold(
      backgroundColor: AdminColors.screenBg,
      appBar: const AdminAppBar(title: 'Dispute Resolution Center'),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: StreamBuilder<List<DisputeModel>>(
              key: ValueKey(_selectedStatus),
              stream: disputeVM.watchAllDisputes(status: _selectedStatus),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AdminColors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Could not load disputes: ${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: AdminTheme.mutedStyle(),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final disputes = snapshot.data ?? [];

                if (disputes.isEmpty) {
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
                          child: const Icon(
                            Icons.gavel_rounded,
                            size: 64,
                            color: AdminColors.textGrey,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No disputes found',
                          style: AdminTheme.titleStyle(size: 18).copyWith(color: AdminColors.textGrey),
                        ),
                        Text(
                          'Everything looks clear in this category',
                          style: AdminTheme.mutedStyle(),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: disputes.length,
                  itemBuilder:
                      (context, index) =>
                          _DisputeTile(dispute: disputes[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
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
          children: [
            _FilterChip(
              icon: Icons.list_rounded,
              label: 'All Disputes',
              value: 'all',
              selected: _selectedStatus == 'all',
              onSelect: (v) => setState(() => _selectedStatus = v),
            ),
            _FilterChip(
              icon: Icons.new_releases_rounded,
              label: 'Open',
              value: 'open',
              selected: _selectedStatus == 'open',
              onSelect: (v) => setState(() => _selectedStatus = v),
            ),
            _FilterChip(
              icon: Icons.rate_review_rounded,
              label: 'Reviewing',
              value: 'under_review',
              selected: _selectedStatus == 'under_review',
              onSelect: (v) => setState(() => _selectedStatus = v),
            ),
            _FilterChip(
              icon: Icons.check_circle_rounded,
              label: 'Resolved',
              value: 'resolved',
              selected: _selectedStatus == 'resolved',
              onSelect: (v) => setState(() => _selectedStatus = v),
            ),
            _FilterChip(
              icon: Icons.cancel_rounded,
              label: 'Rejected',
              value: 'rejected',
              selected: _selectedStatus == 'rejected',
              onSelect: (v) => setState(() => _selectedStatus = v),
            ),
          ],
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
  const _FilterChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        avatar: Icon(icon, size: 16, color: selected ? AdminColors.amber : AdminColors.textGrey),
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelect(value),
        selectedColor: AdminColors.amber.withValues(alpha: 0.1),
        checkmarkColor: AdminColors.amber,
        backgroundColor: AdminColors.screenBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: selected ? AdminColors.amber : AdminColors.border),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? AdminColors.darkAmber : AdminColors.navy,
        ),
      ),
    );
  }
}

class _DisputeTile extends StatelessWidget {
  final DisputeModel dispute;
  const _DisputeTile({required this.dispute});

  String _shortOrderId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '—';
    return trimmed.length <= 8
        ? trimmed
        : trimmed.substring(trimmed.length - 8);
  }

  Future<void> _showDetails(BuildContext context) async {
    debugPrint('AdminDisputeTile.onTap id=${dispute.id} status=${dispute.status}');
    if (!context.mounted) {
      debugPrint('AdminDisputeTile.onTap aborted: context unmounted');
      return;
    }

    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => _DisputeDetailsDialog(dispute: dispute),
      );
    } catch (error, stack) {
      debugPrint('AdminDisputeTile.showDialog failed: $error\n$stack');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Could not open dispute details: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _getStatusStyle(dispute.status);
    final raisedBy = dispute.raisedByName?.trim().isNotEmpty == true
        ? dispute.raisedByName!
        : dispute.raisedByRole;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.border),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showDetails(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AdminColors.navy.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForType(dispute.type.label),
                  color: AdminColors.navy,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            dispute.type.label,
                            style: AdminTheme.titleStyle(size: 16),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusStyle.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            dispute.status.toUpperCase().replaceAll('_', ' '),
                            style: TextStyle(
                              color: statusStyle.fg,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _MetaRow(
                      icon: Icons.receipt_long_rounded,
                      child: Text(
                        'Order #${_shortOrderId(dispute.orderId)}',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.navy,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _MetaRow(
                      icon: Icons.person_outline_rounded,
                      child: Text(
                        'Raised by $raisedBy',
                        style: AdminTheme.mutedStyle(size: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _MetaRow(
                      icon: Icons.access_time_rounded,
                      child: Text(
                        DateFormat('MMM dd, yyyy · hh:mm a')
                            .format(dispute.createdAt),
                        style: AdminTheme.mutedStyle(size: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, top: 4),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AdminColors.textGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String label) {
    final l = label.toLowerCase();
    if (l.contains('quality')) return Icons.high_quality_rounded;
    if (l.contains('delivery')) return Icons.local_shipping_rounded;
    if (l.contains('price')) return Icons.sell_rounded;
    if (l.contains('payment')) return Icons.payments_rounded;
    return Icons.report_problem_rounded;
  }

  ({Color bg, Color fg}) _getStatusStyle(String status) {
    switch (status.toLowerCase().replaceAll(' ', '_')) {
      case 'open':
        return (
          bg: AdminColors.red.withValues(alpha: 0.1),
          fg: AdminColors.red,
        );
      case 'under_review':
        return (
          bg: AdminColors.amber.withValues(alpha: 0.1),
          fg: AdminColors.darkAmber,
        );
      case 'resolved':
        return (
          bg: AdminColors.green.withValues(alpha: 0.1),
          fg: AdminColors.green,
        );
      case 'rejected':
        return (
          bg: AdminColors.red.withValues(alpha: 0.1),
          fg: AdminColors.red,
        );
      default:
        return (
          bg: AdminColors.textGrey.withValues(alpha: 0.1),
          fg: AdminColors.textGrey,
        );
    }
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final Widget child;

  const _MetaRow({required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AdminColors.textGrey),
        const SizedBox(width: 6),
        Expanded(child: child),
      ],
    );
  }
}

class _DisputeDetailsDialog extends StatefulWidget {
  final DisputeModel dispute;
  const _DisputeDetailsDialog({required this.dispute});

  @override
  State<_DisputeDetailsDialog> createState() => _DisputeDetailsDialogState();
}

class _DisputeDetailsDialogState extends State<_DisputeDetailsDialog> {
  static const _statusOptions = <String>[
    'under_review',
    'resolved',
    'rejected',
  ];

  final _notesController = TextEditingController();
  late String _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.dispute.resolutionNotes ?? '';
    _status = _selectableStatus(widget.dispute.status);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  String _normalizeStatus(String raw) {
    return raw.trim().toLowerCase().replaceAll(' ', '_');
  }

  String _selectableStatus(String raw) {
    final status = _normalizeStatus(raw);
    if (status == 'open') return 'under_review';
    if (_statusOptions.contains(status)) return status;
    return 'under_review';
  }

  String _shortOrderId(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '—';
    return trimmed.length <= 8
        ? trimmed
        : trimmed.substring(trimmed.length - 8);
  }

  Future<void> _update() async {
    final notes = _notesController.text.trim();
    if ((_status == 'resolved' || _status == 'rejected') && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(
            _status == 'rejected'
                ? 'Notes are required to reject a dispute.'
                : 'Resolution notes are required to resolve a dispute.',
          ),
        ),
      );
      return;
    }
    final adminUid = context.read<AuthViewModel>().user?.uid ?? '';
    if (adminUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error: You must be signed in as an administrator.'),
        ),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<DisputeViewModel>().resolveDispute(
        widget.dispute.id,
        _status,
        notes,
        adminUid: adminUid,
        raisedByUid: widget.dispute.raisedByUid,
        raisedByRole: widget.dispute.raisedByRole,
        orderId: widget.dispute.orderId,
        companyId: widget.dispute.companyId,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Dispute record updated successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = error is AppException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Error: $message'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispute = widget.dispute;
    final raisedBy = dispute.raisedByName?.trim().isNotEmpty == true
        ? dispute.raisedByName!
        : dispute.raisedByRole;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: const Row(
        children: [
          Icon(Icons.gavel_rounded, color: AdminColors.navy),
          SizedBox(width: 10),
          Expanded(
            child: Text('Review Dispute', overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('DISPUTE DETAILS', style: AdminTheme.sectionHeaderStyle()),
              const SizedBox(height: 10),
              _DetailLine(
                icon: Icons.category_outlined,
                label: 'Type',
                value: dispute.type.label,
              ),
              _DetailLine(
                icon: Icons.receipt_long_rounded,
                label: 'Order',
                value: '#${_shortOrderId(dispute.orderId)}',
              ),
              _DetailLine(
                icon: Icons.person_outline_rounded,
                label: 'Raised by',
                value: '$raisedBy (${dispute.raisedByRole})',
              ),
              _DetailLine(
                icon: Icons.flag_outlined,
                label: 'Status',
                value: dispute.status.replaceAll('_', ' '),
              ),
              const SizedBox(height: 16),
              Text('REASON / EVIDENCE', style: AdminTheme.sectionHeaderStyle()),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AdminColors.screenBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  dispute.description.isEmpty
                      ? 'No description provided.'
                      : dispute.description,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    height: 1.5,
                    color: AdminColors.navy,
                  ),
                ),
              ),
              if (dispute.photoUrl != null && dispute.photoUrl!.isNotEmpty) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => ChatImageUtils.showFullscreen(
                    context,
                    imageUrl: dispute.photoUrl,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      dispute.photoUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const SizedBox(
                                  height: 180,
                                  child: Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                      errorBuilder: (_, __, ___) => const SizedBox(
                        height: 120,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 40,
                            color: AdminColors.textGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(height: 1),
              ),
              Text('ADMIN ACTION', style: AdminTheme.sectionHeaderStyle()),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: AdminTheme.inputDecoration(isDense: true),
                items: const [
                  DropdownMenuItem(
                    value: 'under_review',
                    child: Text('Reviewing'),
                  ),
                  DropdownMenuItem(
                    value: 'resolved',
                    child: Text('Resolved'),
                  ),
                  DropdownMenuItem(
                    value: 'rejected',
                    child: Text('Rejected'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _status = v);
                },
              ),
              const SizedBox(height: 16),
              Text('RESOLUTION NOTES', style: AdminTheme.sectionHeaderStyle()),
              const SizedBox(height: 10),
              TextField(
                controller: _notesController,
                maxLines: 4,
                style: GoogleFonts.plusJakartaSans(fontSize: 14),
                decoration: AdminTheme.inputDecoration(
                  hintText:
                      'Describe investigation steps, resolution, or rejection reason...',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _update,
          icon: _isSaving
              ? const SizedBox.shrink()
              : const Icon(Icons.save_rounded, size: 18),
          label: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('SAVE RESOLUTION'),
          style: AdminTheme.primaryButtonStyle(height: 44).copyWith(
            minimumSize: WidgetStateProperty.all(const Size(0, 44)),
            padding: WidgetStateProperty.all(
              const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AdminColors.textGrey),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AdminTheme.mutedStyle(size: 13),
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: value,
                    style: AdminTheme.bodyStyle().copyWith(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
