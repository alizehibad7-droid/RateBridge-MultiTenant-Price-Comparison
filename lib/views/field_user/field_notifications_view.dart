import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/notification_viewmodel.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/date_formatter.dart';
import '../../constants/app_colors.dart';
import 'package:ratebridge/l10n/app_localizations.dart';

class FieldNotificationsView extends StatefulWidget {
  const FieldNotificationsView({super.key});

  @override
  State<FieldNotificationsView> createState() => _FieldNotificationsViewState();
}

class _FieldNotificationsViewState extends State<FieldNotificationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVm = context.read<AuthViewModel>();
      if (authVm.user != null) {
        context.read<NotificationViewModel>().loadNotifications(authVm.user!.uid);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notificationVm = context.watch<NotificationViewModel>();
    final authVm = context.read<AuthViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          l10n.notifications, 
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 22, 
            fontWeight: FontWeight.w800, 
            letterSpacing: -0.8,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (notificationVm.notifications.isNotEmpty)
            TextButton(
              onPressed: () => notificationVm.markAllRead(authVm.user!.uid),
              child: Text(
                l10n.clear.toUpperCase(), 
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
              ),
            ),
          const SizedBox(width: 20),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: notificationVm.isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
          : notificationVm.notifications.isEmpty
              ? _buildEmptyState(l10n, theme)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                  itemCount: notificationVm.notifications.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final n = notificationVm.notifications[index];
                    return _PressableScale(
                      onTap: () {
                        notificationVm.markAsRead(authVm.user!.uid, n.notifId);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: n.isRead ? AppColors.border : AppColors.primary.withOpacity(0.3),
                            width: n.isRead ? 1 : 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 15,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(20),
                          leading: _getIcon(n.type),
                          title: Text(
                            n.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 15,
                              fontWeight: n.isRead ? FontWeight.w600 : FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text(
                                n.body, 
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                DateFormatter.timeAgo(n.createdAt).toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9, 
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          tileColor: n.isRead ? null : AppColors.primary.withOpacity(0.02),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.textSecondary.withOpacity(0.2), weight: 200),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.noData, 
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIcon(String type) {
    IconData icon;
    Color color;
    switch (type.toLowerCase()) {
      case 'orderupdate':
        icon = Icons.shopping_bag_outlined;
        color = AppColors.warning;
        break;
      case 'chat':
        icon = Icons.chat_bubble_outline_rounded;
        color = AppColors.primary;
        break;
      case 'delivery':
        icon = Icons.local_shipping_outlined;
        color = AppColors.success;
        break;
      default:
        icon = Icons.notifications_none_rounded;
        color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22, weight: 300),
    );
  }
}

class _PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _PressableScale({required this.child, required this.onTap});

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: widget.child,
      ),
    );
  }
}
