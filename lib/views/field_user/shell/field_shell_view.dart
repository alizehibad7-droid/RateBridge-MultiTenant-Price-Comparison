import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../theme/field_theme.dart';
import '../../../widgets/ai_assistant_sheet.dart';
import '../../../viewmodels/auth_viewmodel.dart';
import '../../../viewmodels/field_user/field_chat_viewmodel.dart';
import '../../../viewmodels/field_user/field_session_viewmodel.dart';
import '../../../viewmodels/field_user/field_notifications_viewmodel.dart';
import '../chat/field_chat_list_view.dart';
import '../home/field_home_view.dart';
import '../notifications/field_notifications_view.dart';
import '../orders/field_orders_view.dart';
import '../profile/field_profile_view.dart';
import '../widgets/field_async_states.dart';

/// Root navigation shell for the Field User Panel.
class FieldShellView extends StatefulWidget {
  final int initialTabIndex;

  const FieldShellView({super.key, this.initialTabIndex = 0});

  @override
  State<FieldShellView> createState() => _FieldShellViewState();
}

class _FieldShellViewState extends State<FieldShellView> {
  static const _tabTransition = Duration(milliseconds: 150);

  late int _currentIndex;

  static const _tabs = [
    _ShellTab(
      label: 'Home',
      outlinedIcon: Icons.home_outlined,
      filledIcon: Icons.home_rounded,
    ),
    _ShellTab(
      label: 'Orders',
      outlinedIcon: Icons.receipt_long_outlined,
      filledIcon: Icons.receipt_long_rounded,
    ),
    _ShellTab(
      label: 'Messages',
      outlinedIcon: Icons.chat_bubble_outline_rounded,
      filledIcon: Icons.chat_bubble_rounded,
    ),
    _ShellTab(
      label: 'Notifications',
      outlinedIcon: Icons.notifications_none_outlined,
      filledIcon: Icons.notifications_rounded,
    ),
    _ShellTab(
      label: 'Profile',
      outlinedIcon: Icons.person_outline_rounded,
      filledIcon: Icons.person_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTabIndex.clamp(0, _tabs.length - 1);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrapSession());
  }

  void _bootstrapSession() {
    if (!mounted) return;

    final auth = context.read<AuthViewModel>();
    final session = context.read<FieldSessionViewModel>();
    session.updateAuth(auth);

    final uid = auth.user?.uid;
    final companyId = session.companyId;
    if (uid == null) return;

    context.read<FieldNotificationsViewModel>().watchNotifications(uid);

    if (companyId != null) {
      context.read<FieldChatViewModel>().watchConversations(companyId, uid);
    }
  }

  void _onTabSelected(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  void _openAiAssistant(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => const AiAssistantSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthViewModel>().user;
    final unreadNotifications =
        context.watch<FieldNotificationsViewModel>().unreadCount;
    final unreadMessages =
        context.watch<FieldChatViewModel>().unreadMessageCount;

    if (user == null) {
      return Theme(
        data: FieldTheme.theme,
        child: const Scaffold(
          backgroundColor: FieldColors.screenBackground,
          body: FieldLoadingState(message: 'Loading…'),
        ),
      );
    }

    final badgeCounts = List<int>.filled(_tabs.length, 0);
    badgeCounts[FieldShellScope.messagesTabIndex] = unreadMessages;
    badgeCounts[FieldShellScope.notificationsTabIndex] = unreadNotifications;

    return Theme(
      data: FieldTheme.theme,
      child: Scaffold(
        backgroundColor: FieldColors.screenBackground,
        body: Stack(
          children: [
            Positioned.fill(
              child: FieldShellScope(
                switchTab: _onTabSelected,
                child: IndexedStack(
                  index: _currentIndex,
                  children: const [
                    FieldHomeView(),
                    FieldOrdersView(),
                    FieldChatListView(),
                    FieldNotificationsView(),
                    FieldProfileView(),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 72,
              child: _AiFloatingButton(
                onTap: () => _openAiAssistant(context),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _FieldBottomNavBar(
          tabs: _tabs,
          currentIndex: _currentIndex,
          badgeCounts: badgeCounts,
          onTabSelected: _onTabSelected,
        ),
      ),
    );
  }
}

/// Lets nested field screens switch bottom-nav tabs (e.g. Home → Orders).
class FieldShellScope extends InheritedWidget {
  final void Function(int tabIndex) switchTab;

  static const int ordersTabIndex = 1;
  static const int messagesTabIndex = 2;
  static const int notificationsTabIndex = 3;
  static const int profileTabIndex = 4;

  const FieldShellScope({
    super.key,
    required this.switchTab,
    required super.child,
  });

  static FieldShellScope? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<FieldShellScope>();
  }

  @override
  bool updateShouldNotify(FieldShellScope oldWidget) => false;
}

class _ShellTab {
  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;

  const _ShellTab({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
  });
}

class _FieldBottomNavBar extends StatelessWidget {
  final List<_ShellTab> tabs;
  final int currentIndex;
  final List<int> badgeCounts;
  final ValueChanged<int> onTabSelected;

  const _FieldBottomNavBar({
    required this.tabs,
    required this.currentIndex,
    required this.badgeCounts,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: FieldColors.surfaceWhite,
        border: Border(
          top: BorderSide(color: FieldColors.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: FieldSpacing.sm,
            vertical: FieldSpacing.sm,
          ),
          child: Row(
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              return Expanded(
                child: _FieldNavItem(
                  label: tab.label,
                  outlinedIcon: tab.outlinedIcon,
                  filledIcon: tab.filledIcon,
                  isSelected: currentIndex == index,
                  badgeCount: index < badgeCounts.length ? badgeCounts[index] : 0,
                  onTap: () => onTabSelected(index),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _FieldNavItem extends StatelessWidget {
  final String label;
  final IconData outlinedIcon;
  final IconData filledIcon;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  const _FieldNavItem({
    required this.label,
    required this.outlinedIcon,
    required this.filledIcon,
    required this.isSelected,
    required this.badgeCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor =
        isSelected ? FieldColors.accentAmber : FieldColors.textMuted;
    final labelColor =
        isSelected ? FieldColors.primaryNavy : FieldColors.textMuted;
    final labelWeight = isSelected ? FontWeight.w600 : FontWeight.w400;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(FieldRadius.button),
        splashColor: FieldColors.accentAmber.withValues(alpha: 0.12),
        highlightColor: FieldColors.accentAmber.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: FieldSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: _FieldShellViewState._tabTransition,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _NavIcon(
                  key: ValueKey('$label-$isSelected'),
                  icon: isSelected ? filledIcon : outlinedIcon,
                  color: iconColor,
                  badgeCount: badgeCount,
                ),
              ),
              const SizedBox(height: FieldSpacing.xs),
              AnimatedDefaultTextStyle(
                duration: _FieldShellViewState._tabTransition,
                curve: Curves.easeInOut,
                style: FieldTypography.labelSmall.copyWith(
                  color: labelColor,
                  fontWeight: labelWeight,
                  letterSpacing: 0.2,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int badgeCount;

  const _NavIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, size: 24, color: color),
        if (badgeCount > 0)
          Positioned(
            right: -10,
            top: -5,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: FieldColors.statusDanger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: FieldColors.surfaceWhite,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: FieldTypography.labelSmall.copyWith(
                  color: FieldColors.surfaceWhite,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AiFloatingButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AiFloatingButton({required this.onTap});

  @override
  State<_AiFloatingButton> createState() => _AiFloatingButtonState();
}

class _AiFloatingButtonState extends State<_AiFloatingButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ScaleTransition(
        scale: _scale,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            customBorder: const CircleBorder(),
            child: Ink(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FieldColors.accentAmber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: FieldColors.primaryNavy.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
