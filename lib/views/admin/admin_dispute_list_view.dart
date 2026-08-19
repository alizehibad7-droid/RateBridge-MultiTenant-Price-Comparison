import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/dispute_model.dart';
import '../../theme/admin_theme.dart';
import '../../utils/app_exception.dart';
import '../../utils/chat_image_utils.dart';
import '../../viewmodels/dispute_viewmodel.dart';

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
      appBar: const AdminAppBar(title: 'Dispute Resolution'),
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
                    child: Text(
                      'Could not load disputes: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final disputes = snapshot.data ?? [];

                if (disputes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.gavel_outlined,
                          size: 64,
                          color: AdminColors.textGrey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No disputes found',
                          style: AdminTheme.titleStyle(),
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
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _FilterChip(
              label: 'All',
              value: 'all',
              selected: _selectedStatus == 'all',
              onSelect: (v) => setState(() => _selectedStatus = v),
            ),
            _FilterChip(
              label: 'Open',
              value: 'open',
              selected: _selectedStatus == 'open',
              onSelect: (v) => setState(() => _selectedStatus = v),
            ),
            _FilterChip(
              label: 'Reviewing',
              value: 'under_review',
              selected: _selectedStatus == 'under_review',
              onSelect: (v) => setState(() => _selectedStatus = v),
            ),
            _FilterChip(
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
  final String label;
  final String value;
  final bool selected;
  final Function(String) onSelect;
  const _FilterChip({
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
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelect(value),
        selectedColor: AdminColors.amber.withValues(alpha: 0.2),
        checkmarkColor: AdminColors.amber,
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
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Expanded(
              child: Text(
                dispute.type.label,
                style: AdminTheme.titleStyle(size: 16),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusStyle.bg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                dispute.status.toUpperCase(),
                style: TextStyle(
                  color: statusStyle.fg,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              'Order ID: ${dispute.orderId}',
              style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Raised by: ${dispute.raisedByName?.isNotEmpty == true ? dispute.raisedByName : dispute.raisedByRole} (${dispute.raisedByRole}) at ${DateFormat('MMM dd, hh:mm a').format(dispute.createdAt)}',
              style: AdminTheme.mutedStyle(),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showDetails(context),
      ),
    );
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
          fg: AdminColors.amber,
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
        const SnackBar(content: Text('Dispute updated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final message = error is AppException ? error.message : error.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update dispute: $message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resolve Dispute'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TYPE: ${widget.dispute.type.label}',
              style: AdminTheme.sectionHeaderStyle(),
            ),
            const SizedBox(height: 8),
            Text(widget.dispute.description),
            if (widget.dispute.photoUrl != null &&
                widget.dispute.photoUrl!.isNotEmpty) ...[
              const SizedBox(height: 16),
              InkWell(
                onTap:
                    () => ChatImageUtils.showFullscreen(
                      context,
                      imageUrl: widget.dispute.photoUrl,
                    ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
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
                            child: Icon(Icons.broken_image_outlined, size: 40),
                          ),
                        ),
                  ),
                ),
              ),
            ],
            const Divider(height: 32),
            Text('STATUS', style: AdminTheme.sectionHeaderStyle()),
            DropdownButtonFormField<String>(
              value: _status,
              items: const [
                DropdownMenuItem(
                  value: 'under_review',
                  child: Text('Under Review'),
                ),
                DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
              ],
              onChanged: (v) => setState(() => _status = v!),
            ),
            const SizedBox(height: 16),
            Text('RESOLUTION NOTES', style: AdminTheme.sectionHeaderStyle()),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter internal notes...',
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
        ElevatedButton(
          onPressed: _isSaving ? null : _update,
          child:
              _isSaving
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('UPDATE'),
        ),
      ],
    );
  }
}
