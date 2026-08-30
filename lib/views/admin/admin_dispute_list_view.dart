import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dispute_model.dart';
import '../../theme/admin_theme.dart';
import '../../utils/app_exception.dart';
import '../../utils/chat_image_utils.dart';
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

  void _showDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _DisputeDetailsDialog(dispute: dispute),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusStyle = _getStatusStyle(dispute.status);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AdminColors.border),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AdminColors.navy.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Icon(_getIconForType(dispute.type.label), color: AdminColors.navy, size: 24),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                dispute.type.label,
                style: AdminTheme.titleStyle(size: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  'Order #${dispute.orderId.substring(dispute.orderId.length - 8)}',
                  style: GoogleFonts.jetBrainsMono(fontSize: 12, fontWeight: FontWeight.w600, color: AdminColors.navy),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline_rounded, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Raised by ${dispute.raisedByName?.isNotEmpty == true ? dispute.raisedByName : dispute.raisedByRole}',
                    style: AdminTheme.mutedStyle(size: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM dd, yyyy · hh:mm a').format(dispute.createdAt),
                  style: AdminTheme.mutedStyle(size: 11),
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AdminColors.textGrey),
        onTap: () => _showDetails(context),
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
    switch (status) {
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
      default:
        return (
          bg: AdminColors.textGrey.withValues(alpha: 0.1),
          fg: AdminColors.textGrey,
        );
    }
  }
}

class _DisputeDetailsDialog extends StatefulWidget {
  final DisputeModel dispute;
  const _DisputeDetailsDialog({required this.dispute});

  @override
  State<_DisputeDetailsDialog> createState() => _DisputeDetailsDialogState();
}

class _DisputeDetailsDialogState extends State<_DisputeDetailsDialog> {
  final _notesController = TextEditingController();
  String _status = 'under_review';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _notesController.text = widget.dispute.resolutionNotes ?? '';
    _status =
        widget.dispute.status == 'open'
            ? 'under_review'
            : widget.dispute.status;
  }

  Future<void> _update() async {
    final notes = _notesController.text.trim();
    if (_status == 'resolved' && notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Resolution notes are required to resolve a dispute.'),
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
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Dispute record updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = error is AppException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(behavior: SnackBarBehavior.floating, content: Text('Error: $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.gavel_rounded, color: AdminColors.navy),
          const SizedBox(width: 10),
          const Text('Review Dispute'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Text(
                  'TYPE: ${widget.dispute.type.label.toUpperCase()}',
                  style: AdminTheme.sectionHeaderStyle(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminColors.screenBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.dispute.description,
                style: GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.5, color: AdminColors.navy),
              ),
            ),
            if (widget.dispute.photoUrl != null &&
                widget.dispute.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap:
                    () => ChatImageUtils.showFullscreen(
                      context,
                      imageUrl: widget.dispute.photoUrl,
                    ),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        widget.dispute.photoUrl!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder:
                            (context, child, progress) =>
                                progress == null
                                    ? child
                                    : const SizedBox(
                                      height: 200,
                                      child: Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                        errorBuilder:
                            (_, __, ___) => const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined, size: 40, color: AdminColors.textGrey),
                              ),
                            ),
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.all(8),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Divider(height: 1),
            ),
            Row(
              children: [
                const Icon(Icons.update_rounded, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Text('CURRENT ACTION', style: AdminTheme.sectionHeaderStyle()),
              ],
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: AdminTheme.inputDecoration(isDense: true),
              items: const [
                DropdownMenuItem(
                  value: 'under_review',
                  child: Text('Keep Under Review'),
                ),
                DropdownMenuItem(value: 'resolved', child: Text('Mark as Resolved')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.notes_rounded, size: 14, color: AdminColors.textGrey),
                const SizedBox(width: 6),
                Text('RESOLUTION NOTES', style: AdminTheme.sectionHeaderStyle()),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 4,
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: AdminTheme.inputDecoration(
                hintText: 'Describe investigation steps or final resolution...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('CANCEL'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _update,
          icon: _isSaving ? const SizedBox.shrink() : const Icon(Icons.save_rounded, size: 18),
          label:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                  : const Text('SAVE RESOLUTION'),
          style: AdminTheme.primaryButtonStyle(height: 44).copyWith(
            minimumSize: WidgetStateProperty.all(const Size(160, 44)),
          ),
        ),
      ],
    );
  }
}
