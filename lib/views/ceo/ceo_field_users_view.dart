// MVVM: View — no business logic

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../utils/app_theme.dart';
import '../../viewmodels/ceo_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../models/user_model.dart';
import '../../widgets/ceo_nav_bar.dart';
import '../../widgets/app_text_field.dart';
import '../../constants/app_colors.dart';

class CeoFieldUsersView extends StatefulWidget {
  const CeoFieldUsersView({super.key});

  @override
  State<CeoFieldUsersView> createState() => _CeoFieldUsersViewState();
}

class _CeoFieldUsersViewState extends State<CeoFieldUsersView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final companyId = context.read<AuthViewModel>().user?.companyId ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Field Users'),
        actions: [
          IconButton(
            icon: const Icon(Icons.vpn_key_outlined),
            tooltip: 'Invite Code',
            onPressed: () => _showInviteCodeSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Active'),
            Tab(text: 'Deactivated'),
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
                          const Icon(Icons.engineering_outlined,
                              size: 40, color: AppColors.textMuted),
                          const SizedBox(height: 12),
                          Text(
                            'No ${filters[i]} field users',
                            style: AppTextStyles.bodyMuted,
                          ),
                          if (i == 0) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _showInviteCodeSheet(context),
                              icon: const Icon(Icons.vpn_key_outlined),
                              label: const Text('Share invite code'),
                            ),
                          ],
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) =>
                        _userCard(context, vm, users[idx], filters[i]),
                  );
                },
              );
            }),
          );
        },
      ),
      bottomNavigationBar: const CeoNavBar(currentIndex: 3),
    );
  }

  Widget _userCard(BuildContext context, CeoViewModel vm, UserModel user,
      String filter) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: _statusColor(filter).withOpacity(0.12),
                child: Text(
                  user.name.isNotEmpty
                      ? user.name[0].toUpperCase()
                      : 'F',
                  style: TextStyle(
                      color: _statusColor(filter),
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                    Text(user.phone,
                        style: AppTextStyles.bodyMuted),
                  ],
                ),
              ),
              _statusBadge(filter),
            ],
          ),
          if (user.createdAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Joined: ${_fmtDate(user.createdAt)}',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
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
          child: ElevatedButton(
            onPressed: () => vm.approveFieldUser(user.uid),
            child: const Text('Approve', style: AppTextStyles.button),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton(
            onPressed: () => _showRejectDialog(context, vm, user.uid),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger),
            child: const Text('Reject'),
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
              title: 'Deactivate ${user.name}?',
              body: 'They will lose access to the app immediately.',
              confirmLabel: 'Deactivate',
              confirmColor: AppColors.warning,
              onConfirm: () => vm.deactivateFieldUser(user.uid),
            ),
            icon: const Icon(Icons.block, size: 16),
            label: const Text('Deactivate'),
            style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warning,
                side: const BorderSide(color: AppColors.warning)),
          ),
        ),
      ];
    }

    // deactivated
    return [
      Expanded(
        child: ElevatedButton.icon(
          onPressed: () => _confirmAction(
            context,
            title: 'Reactivate ${user.name}?',
            body: 'They will regain full access to the field dashboard.',
            confirmLabel: 'Reactivate',
            confirmColor: AppColors.success,
            onConfirm: () => vm.reactivateFieldUser(user.uid),
          ),
          icon: const Icon(Icons.check_circle_outline, size: 16),
          label: const Text('Reactivate', style: AppTextStyles.button),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success),
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
        title: const Text('Reject field user'),
        content: AppTextField(
          label: 'REASON',
          controller: reasonCtrl,
          maxLines: 3,
          hint: 'Let them know why they were rejected...',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              vm.rejectFieldUser(uid, reasonCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Reject', style: AppTextStyles.button),
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
    required Color confirmColor,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(confirmLabel, style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  void _showInviteCodeSheet(BuildContext context) {
    final vm = context.read<CeoViewModel>();
    final code = vm.company?.inviteCode ?? 'Not generated yet';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Company Invite Code',
                style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 16),
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            const Text(
              'Share this code with your field users so they can '
              'register and join your team.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      code,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_outlined,
                        color: AppColors.primary),
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Invite code copied!')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Share.share(
                          'Join my company on RateBridge!\n'
                          'Use invite code: $code');
                    },
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('Share', style: AppTextStyles.button),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _confirmRegenerate(ctx, vm),
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Regenerate'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '⚠ Regenerating the code will invalidate the old one. '
              'Existing team members are not affected.',
              style: TextStyle(
                  fontSize: 11, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmRegenerate(BuildContext ctx, CeoViewModel vm) {
    showDialog(
      context: ctx,
      builder: (dlg) => AlertDialog(
        title: const Text('Regenerate invite code?'),
        content: const Text(
            'The old code will stop working immediately. '
            'New field users must use the new code to register.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dlg),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warning),
            onPressed: () {
              Navigator.pop(dlg);
              vm.regenerateInviteCode();
            },
            child: const Text('Regenerate', style: AppTextStyles.button),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String filter) {
    switch (filter) {
      case 'active':
        return AppColors.success;
      case 'deactivated':
        return AppColors.danger;
      default:
        return AppColors.warning;
    }
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);
    final label = status[0].toUpperCase() + status.substring(1);
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600)),
    );
  }

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
