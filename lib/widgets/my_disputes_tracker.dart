import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/dispute_model.dart';
import '../constants/route_names.dart';
import '../theme/field_theme.dart';
import '../viewmodels/dispute_viewmodel.dart';
import '../views/field_user/widgets/field_async_states.dart';

/// Live list of disputes raised by [uid], with Admin-style status chips.
class MyDisputesTracker extends StatefulWidget {
  final String uid;

  const MyDisputesTracker({super.key, required this.uid});

  @override
  State<MyDisputesTracker> createState() => _MyDisputesTrackerState();
}

class _MyDisputesTrackerState extends State<MyDisputesTracker> {
  String _selectedStatus = 'all';

  bool _matchesFilter(DisputeModel dispute) {
    switch (_selectedStatus) {
      case 'open':
        return dispute.status == 'open';
      case 'under_review':
        return dispute.status == 'under_review';
      case 'resolved':
        return dispute.status == 'resolved' ||
            dispute.status == 'rejected' ||
            dispute.status == 'withdrawn';
      default:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.uid.isEmpty) {
      return const FieldLoadingState(message: 'Loading your disputes…');
    }

    final disputeVM = context.read<DisputeViewModel>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FilterBar(
          selected: _selectedStatus,
          onSelect: (value) => setState(() => _selectedStatus = value),
        ),
        Expanded(
          child: StreamBuilder<List<DisputeModel>>(
            stream: disputeVM.watchMyDisputes(widget.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const FieldLoadingState();
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'Could not load your disputes.',
                      textAlign: TextAlign.center,
                      style: FieldTypography.bodyMedium,
                    ),
                  ),
                );
              }
              final disputes =
                  (snapshot.data ?? []).where(_matchesFilter).toList();
              if (disputes.isEmpty) {
                return FieldEmptyState(
                  icon: Icons.gavel_rounded,
                  title: 'No disputes yet',
                  subtitle: _selectedStatus == 'all'
                      ? 'Issues you report will show up here with live status updates.'
                      : 'Nothing in this category right now.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: disputes.length,
                itemBuilder: (context, index) =>
                    _MyDisputeCard(dispute: disputes[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _FilterBar({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: FieldColors.surfaceWhite,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            _Chip(
              label: 'All',
              value: 'all',
              selected: selected == 'all',
              onSelect: onSelect,
            ),
            _Chip(
              label: 'Open',
              value: 'open',
              selected: selected == 'open',
              onSelect: onSelect,
            ),
            _Chip(
              label: 'Reviewing',
              value: 'under_review',
              selected: selected == 'under_review',
              onSelect: onSelect,
            ),
            _Chip(
              label: 'Resolved',
              value: 'resolved',
              selected: selected == 'resolved',
              onSelect: onSelect,
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelect;

  const _Chip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelect(value),
        selectedColor: FieldColors.primaryNavy,
        labelStyle: FieldTypography.labelSmall.copyWith(
          color: selected ? Colors.white : FieldColors.primaryNavy,
          fontWeight: FontWeight.w700,
        ),
        backgroundColor: FieldColors.surfaceWhite,
        side: const BorderSide(color: FieldColors.borderSubtle),
        showCheckmark: false,
      ),
    );
  }
}

class _MyDisputeCard extends StatelessWidget {
  final DisputeModel dispute;

  const _MyDisputeCard({required this.dispute});

  String get _statusLabel {
    switch (dispute.status) {
      case 'open':
        return 'Open';
      case 'under_review':
        return 'Under Review';
      case 'resolved':
        return 'Resolved';
      case 'rejected':
        return 'Rejected';
      default:
        return dispute.status.replaceAll('_', ' ');
    }
  }

  Color get _statusColor {
    switch (dispute.status) {
      case 'open':
        return FieldColors.statusDanger;
      case 'under_review':
        return FieldColors.statusWarning;
      case 'resolved':
        return FieldColors.statusSuccess;
      case 'rejected':
        return FieldColors.statusMuted;
      default:
        return FieldColors.textSecondary;
    }
  }

  String get _orderLabel {
    final id = dispute.orderId.trim();
    if (id.isEmpty) return 'Order —';
    final short = id.length <= 8 ? id : id.substring(id.length - 8);
    return 'Order #$short';
  }

  bool get _showNotes {
    final notes = dispute.resolutionNotes?.trim() ?? '';
    if (notes.isEmpty) return false;
    return dispute.status == 'resolved' || dispute.status == 'rejected';
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(
          RouteNames.fieldDisputeDetail.replaceFirst(':disputeId', dispute.id),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: FieldTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: FieldColors.primaryNavy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.report_problem_rounded,
                  size: 18,
                  color: FieldColors.primaryNavy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  dispute.type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FieldTypography.titleMedium.copyWith(
                    color: FieldColors.primaryNavy,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel,
                  style: FieldTypography.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            dispute.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FieldTypography.bodyMedium.copyWith(
              color: FieldColors.textSecondary,
              height: 1.4,
            ),
          ),
          if (_showNotes) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FieldColors.statusSuccess.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'RESOLUTION',
                    style: FieldTypography.labelSmall.copyWith(
                      color: FieldColors.statusSuccess,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dispute.resolutionNotes!,
                    style: FieldTypography.bodyMedium.copyWith(
                      color: FieldColors.statusSuccess,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.receipt_long_rounded,
                size: 14,
                color: FieldColors.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _orderLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: FieldColors.textMuted,
                  ),
                ),
              ),
              const Icon(
                Icons.access_time_rounded,
                size: 14,
                color: FieldColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                DateFormat('MMM dd, yyyy').format(dispute.createdAt),
                style: FieldTypography.bodyMedium.copyWith(
                  fontSize: 11,
                  color: FieldColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}
