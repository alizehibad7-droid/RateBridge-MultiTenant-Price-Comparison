import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/dispute_model.dart';
import '../../theme/ceo_theme.dart';
import '../../theme/field_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/dispute_viewmodel.dart';
import '../../widgets/app_network_image.dart';

enum DisputeDetailAudience { field, ceo }

class DisputeRecordDetailView extends StatelessWidget {
  final String disputeId;
  final DisputeDetailAudience audience;

  const DisputeRecordDetailView({
    super.key,
    required this.disputeId,
    required this.audience,
  });

  bool get _ceo => audience == DisputeDetailAudience.ceo;

  @override
  Widget build(BuildContext context) {
    final vm = context.read<DisputeViewModel>();
    final uid = context.watch<AuthViewModel>().user?.uid ?? '';
    return Scaffold(
      backgroundColor: _ceo ? CeoColors.screenBg : FieldColors.screenBackground,
      appBar: AppBar(
        title: Text(_ceo ? 'Reported issue' : 'Dispute details'),
        backgroundColor: _ceo ? CeoColors.navy : FieldColors.primaryNavy,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<DisputeModel?>(
        stream: vm.watchDispute(disputeId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dispute = snapshot.data;
          if (dispute == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'This dispute could not be found.',
                  textAlign: TextAlign.center,
                  style: _ceo
                      ? CeoTheme.mutedStyle()
                      : FieldTypography.bodyMedium,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _Hero(dispute: dispute, ceo: _ceo),
              const SizedBox(height: 16),
              _InfoCard(
                ceo: _ceo,
                children: [
                  _Row(
                    label: 'Material / order',
                    value: _materialOrderLabel(dispute),
                    ceo: _ceo,
                  ),
                  _Row(label: 'Type', value: dispute.type.label, ceo: _ceo),
                  _Row(
                    label: 'Status',
                    value: _statusLabel(dispute.status),
                    ceo: _ceo,
                  ),
                  if (_ceo)
                    _Row(
                      label: 'Raised by',
                      value: _raisedByLabel(dispute),
                      ceo: _ceo,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Section(
                title: 'Description',
                ceo: _ceo,
                child: Text(
                  dispute.description.isEmpty
                      ? 'No description provided.'
                      : dispute.description,
                  style: _ceo
                      ? GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          height: 1.5,
                          color: CeoColors.navy,
                        )
                      : FieldTypography.bodyMedium.copyWith(height: 1.5),
                ),
              ),
              if (dispute.photoUrl != null && dispute.photoUrl!.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AppNetworkImage(
                    url: dispute.photoUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    fallback: SizedBox(
                      height: 180,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: _ceo
                            ? CeoColors.textGrey
                            : FieldColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ],
              if (_showNotes(dispute)) ...[
                const SizedBox(height: 16),
                _Section(
                  title: 'Resolution notes',
                  ceo: _ceo,
                  child: Text(
                    dispute.resolutionNotes!,
                    style: _ceo
                        ? GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            height: 1.5,
                            color: CeoColors.green,
                            fontWeight: FontWeight.w600,
                          )
                        : FieldTypography.bodyMedium.copyWith(
                            color: FieldColors.statusSuccess,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                  ),
                ),
              ],
              if (dispute.status == 'open' &&
                  uid.isNotEmpty &&
                  dispute.raisedByUid == uid) ...[
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => _withdraw(context, dispute),
                  child: const Text('Withdraw dispute'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, DisputeModel dispute) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Withdraw this dispute?'),
        content: const Text(
          'Admins will stop reviewing this report. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep open'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final uid = context.read<AuthViewModel>().user?.uid;
    if (uid == null) return;
    try {
      await context.read<DisputeViewModel>().withdrawDispute(
        uid: uid,
        disputeId: dispute.id,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dispute withdrawn')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  static bool _showNotes(DisputeModel dispute) {
    final notes = dispute.resolutionNotes?.trim() ?? '';
    if (notes.isEmpty) return false;
    return dispute.status == 'resolved' || dispute.status == 'rejected';
  }

  static String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return 'Open';
      case 'under_review':
        return 'Under review';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      case 'withdrawn':
        return 'Withdrawn';
      default:
        return status.replaceAll('_', ' ');
    }
  }

  static String _materialOrderLabel(DisputeModel dispute) {
    final material = dispute.materialName?.trim() ?? '';
    final id = dispute.orderId.trim();
    final short = id.isEmpty
        ? ''
        : (id.length <= 8 ? id : id.substring(id.length - 8));
    if (material.isNotEmpty && short.isNotEmpty) {
      return '$material · Order #$short';
    }
    if (material.isNotEmpty) return material;
    if (short.isNotEmpty) return 'Order #$short';
    return 'Order';
  }

  static String _raisedByLabel(DisputeModel dispute) {
    final name = dispute.raisedByName?.trim() ?? '';
    final role = dispute.raisedByRole.replaceAll('_', ' ');
    if (name.isEmpty) return role;
    return '$name ($role)';
  }
}

class _Hero extends StatelessWidget {
  final DisputeModel dispute;
  final bool ceo;

  const _Hero({required this.dispute, required this.ceo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ceo ? CeoColors.navy : FieldColors.primaryNavy,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dispute.type.label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('MMM d, yyyy · h:mm a').format(dispute.createdAt),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final bool ceo;
  final List<Widget> children;

  const _InfoCard({required this.ceo, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ceo ? CeoColors.navy.withValues(alpha: 0.08) : FieldColors.borderSubtle,
        ),
      ),
      child: Column(children: children),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool ceo;

  const _Row({required this.label, required this.value, required this.ceo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: ceo ? CeoColors.textGrey : FieldColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ceo ? CeoColors.navy : FieldColors.primaryNavy,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final bool ceo;
  final Widget child;

  const _Section({
    required this.title,
    required this.ceo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: ceo ? CeoColors.navy.withValues(alpha: 0.08) : FieldColors.borderSubtle,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: ceo ? CeoColors.textGrey : FieldColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
