import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../theme/ceo_theme.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/user_model.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/ceo/ceo_widgets.dart';

class CeoFieldUsersView extends StatefulWidget {
  const CeoFieldUsersView({super.key});

  @override
  State<CeoFieldUsersView> createState() => _CeoFieldUsersViewState();
}

class _CeoFieldUsersViewState extends State<CeoFieldUsersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Set<String> _selectedUserUids = {};
  bool _isBulkProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() => _selectedUserUids.clear());
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _bulkDeactivate(CeoViewModel vm) async {
    if (_selectedUserUids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: CeoColors.red),
            const SizedBox(width: 10),
            const Text('Bulk Deactivation'),
          ],
        ),
        content: Text('They will lose access to the app immediately. Total: ${_selectedUserUids.length} users.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: CeoColors.red),
            icon: const Icon(Icons.block_rounded, size: 18),
            label: const Text('DEACTIVATE ALL'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isBulkProcessing = true);
    try {
      for (final uid in _selectedUserUids) {
        await vm.deactivateFieldUser(uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Successfully deactivated ${_selectedUserUids.length} users'),
              ],
            ),
          ),
        );
        setState(() => _selectedUserUids.clear());
      }
    } finally {
      if (mounted) setState(() => _isBulkProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyId = context.read<AuthViewModel>().user?.companyId ?? '';

    return Scaffold(
      backgroundColor: CeoColors.screenBg,
      appBar: CeoAppBar(
        title: 'User Management',
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Invite Users',
            onPressed: () => _showInviteCodeSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: CeoColors.amber,
          indicatorWeight: 3,
          labelColor: CeoColors.navy,
          unselectedLabelColor: CeoColors.textGrey,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(icon: Icon(Icons.pending_actions_rounded, size: 20), text: 'Pending'),
            Tab(icon: Icon(Icons.verified_user_rounded, size: 20), text: 'Active'),
            Tab(icon: Icon(Icons.person_off_rounded, size: 20), text: 'Deactivated'),
          ],
        ),
      ),
      body: Consumer<CeoViewModel>(
        builder: (context, vm, _) {
          final filters = ['pending', 'active', 'deactivated'];
          return TabBarView(
            controller: _tabController,
            children: List.generate(3, (i) {
              return StreamBuilder<List<UserModel>>(
                stream: vm.watchFieldUsers(companyId, filters[i]),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final users = snap.data ?? [];
                  if (users.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: CeoColors.navy.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _emptyIcon(filters[i]),
                              size: 48, 
                              color: CeoColors.textGrey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No ${filters[i]} field users found',
                            style: CeoTheme.titleStyle(size: 16).copyWith(color: CeoColors.textGrey),
                          ),
                          if (i == 0) ...[
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () => _showInviteCodeSheet(context),
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: const Text('Share invite code'),
                              style: CeoTheme.primaryButtonStyle(height: 48),
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, idx) =>
                        _userCard(context, vm, users[idx], filters[i]),
                  );
                },
              );
            }),
          );
        },
      ),
      floatingActionButton: (_tabController.index == 1 && _selectedUserUids.isNotEmpty)
          ? FloatingActionButton.extended(
              onPressed: _isBulkProcessing ? null : () {
                final vm = context.read<CeoViewModel>();
                _bulkDeactivate(vm);
              },
              backgroundColor: CeoColors.red,
              elevation: 4,
              label: _isBulkProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Deactivate (${_selectedUserUids.length})', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              icon: const Icon(Icons.block_rounded, color: Colors.white),
            )
          : null,
      bottomNavigationBar: const CeoNavBar(currentIndex: 3),
    );
  }

  IconData _emptyIcon(String status) {
    switch (status) {
      case 'pending': return Icons.person_search_rounded;
      case 'active': return Icons.groups_rounded;
      default: return Icons.person_off_rounded;
    }
  }

  Widget _userCard(BuildContext context, CeoViewModel vm, UserModel user,
      String filter) {
    final isSelected = _selectedUserUids.contains(user.uid);
    final canSelect = filter == 'active';

    return AdminCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (canSelect)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedUserUids.add(user.uid);
                          } else {
                            _selectedUserUids.remove(user.uid);
                          }
                        });
                      },
                      activeColor: CeoColors.amber,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _statusColor(filter).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: user.profileImageUrl != null
                    ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(user.profileImageUrl!))
                    : Text(
                        user.name.isNotEmpty ? user.name[0].toUpperCase() : 'F',
                        style: GoogleFonts.plusJakartaSans(
                          color: _statusColor(filter),
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: CeoColors.navy,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 12, color: CeoColors.textGrey),
                        const SizedBox(width: 4),
                        Text(user.phone, style: CeoTheme.mutedStyle(size: 12)),
                      ],
                    ),
                  ],
                ),
              ),
              CeoStatusBadge(status: filter),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.event_available_rounded, size: 12, color: CeoColors.textGrey),
              const SizedBox(width: 6),
              Text(
                'Member since ${_fmtDate(user.createdAt)}',
                style: CeoTheme.mutedStyle(size: 11),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: _buildActions(context, vm, user, filter),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, CeoViewModel vm,
      UserModel user, String filter) {
    if (filter == 'pending') {
      return [
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: () => vm.approveFieldUser(user.uid),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Approve'),
            style: CeoTheme.primaryButtonStyle(height: 44),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showRejectDialog(context, vm, user.uid),
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Reject'),
            style: CeoTheme.destructiveButtonStyle(height: 44),
          ),
        ),
      ];
    }

    if (filter == 'active') {
      return [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _confirmAction(
              context,
              title: 'Deactivate Access',
              body: 'Are you sure you want to deactivate ${user.name}? They will lose dashboard access immediately.',
              confirmLabel: 'Deactivate',
              confirmIcon: Icons.block_rounded,
              isDestructive: false,
              useAmber: true,
              onConfirm: () => vm.deactivateFieldUser(user.uid),
            ),
            icon: const Icon(Icons.person_remove_rounded, size: 16),
            label: const Text('Deactivate User'),
            style: OutlinedButton.styleFrom(
              foregroundColor: CeoColors.darkAmber,
              side: const BorderSide(color: CeoColors.darkAmber),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ];
    }

    return [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _confirmAction(
            context,
            title: 'Restore Access',
            body: 'Reactivate ${user.name}? They will be able to place orders and manage sites again.',
            confirmLabel: 'Restore Access',
            confirmIcon: Icons.check_circle_rounded,
            onConfirm: () => vm.reactivateFieldUser(user.uid),
          ),
          icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
          label: const Text('Reactivate User'),
          style: CeoTheme.primaryButtonStyle(height: 44),
        ),
      ),
    ];
  }

  void _showRejectDialog(
      BuildContext context, CeoViewModel vm, String uid) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.person_remove_rounded, color: CeoColors.red),
            const SizedBox(width: 10),
            const Text('Reject Applicant'),
          ],
        ),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          decoration: CeoTheme.inputDecoration(
            labelText: 'Reason for rejection',
            hintText: 'e.g. Identity not verified, project cancelled...',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          OutlinedButton.icon(
            style: CeoTheme.destructiveButtonStyle(height: 40),
            onPressed: () {
              vm.rejectFieldUser(uid, reasonCtrl.text.trim());
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.close_rounded, size: 18),
            label: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }

  void _confirmAction(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
    required IconData confirmIcon,
    required VoidCallback onConfirm,
    bool isDestructive = false,
    bool useAmber = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(confirmIcon, color: useAmber ? CeoColors.amber : (isDestructive ? CeoColors.red : CeoColors.navy)),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          if (isDestructive)
            OutlinedButton.icon(
              style: CeoTheme.destructiveButtonStyle(height: 40),
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
              icon: Icon(confirmIcon, size: 18),
              label: Text(confirmLabel),
            )
          else
            ElevatedButton.icon(
              style: useAmber
                  ? ElevatedButton.styleFrom(
                      backgroundColor: CeoColors.darkAmber,
                      foregroundColor: Colors.white,
                    )
                  : CeoTheme.primaryButtonStyle(height: 40),
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
              icon: Icon(confirmIcon, size: 18),
              label: Text(confirmLabel),
            ),
        ],
      ),
    );
  }

  void _showInviteCodeSheet(BuildContext context) {
    final vm = context.read<CeoViewModel>();
    final code = vm.company?.inviteCode ?? 'RB-XXXXXX';

    showModalBottomSheet(
      context: context,
      backgroundColor: CeoColors.screenBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: CeoColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_add_rounded, color: CeoColors.navy, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Invite Team Members',
                  style: CeoTheme.titleStyle(size: 20),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Share this unique code with your field engineers. They can enter it during registration to join your workspace.',
              style: CeoTheme.mutedStyle(size: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CeoColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                        color: CeoColors.navy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Container(
                    width: 1, height: 32, color: CeoColors.border, margin: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  IconButton(
                    icon: const Icon(Icons.content_copy_rounded, color: CeoColors.navy),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text('Invite code copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                          'Join our construction workspace on RateBridge!\n\n'
                          'Register as a Field User and enter this invite code: $code');
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share Code'),
                    style: CeoTheme.primaryButtonStyle(height: 52),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmRegenerate(ctx, vm),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Regenerate'),
                    style: CeoTheme.destructiveButtonStyle(height: 52),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, color: CeoColors.amber, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Regenerating invalidates the current code. Existing members are not affected.',
                    style: CeoTheme.mutedStyle(size: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmRegenerate(BuildContext ctx, CeoViewModel vm) {
    showDialog(
      context: ctx,
      builder: (dlg) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: CeoColors.amber),
            const SizedBox(width: 10),
            const Text('New Code?'),
          ],
        ),
        content: const Text(
            'The old code will stop working immediately. '
            'New field users must use the new code to register.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlg),
              child: const Text('Cancel')),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: CeoColors.darkAmber,
                foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(dlg);
              vm.regenerateInviteCode();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String filter) {
    switch (filter) {
      case 'active':
        return CeoColors.green;
      case 'deactivated':
        return CeoColors.red;
      default:
        return CeoColors.amber;
    }
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
