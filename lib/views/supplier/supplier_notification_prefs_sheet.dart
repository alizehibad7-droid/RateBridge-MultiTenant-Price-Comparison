import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme/supplier_theme.dart';
import '../../utils/app_theme.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../viewmodels/supplier_viewmodel.dart';

Future<void> showSupplierNotificationPrefsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const SupplierNotificationPrefsSheet(),
  );
}

class SupplierNotificationPrefsSheet extends StatefulWidget {
  const SupplierNotificationPrefsSheet({super.key});

  @override
  State<SupplierNotificationPrefsSheet> createState() =>
      _SupplierNotificationPrefsSheetState();
}

class _SupplierNotificationPrefsSheetState
    extends State<SupplierNotificationPrefsSheet> {
  late Map<String, bool> _prefs;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPrefs());
  }

  Future<void> _loadPrefs() async {
    final vm = context.read<SupplierViewModel>();
    if (!vm.notificationPrefsLoaded) {
      await vm.loadNotificationPreferences();
    }
    if (!mounted) return;
    setState(() {
      _prefs = Map<String, bool>.from(vm.notificationPrefs);
      _initialized = true;
    });
  }

  Future<void> _onToggle(String key, bool value) async {
    final previous = Map<String, bool>.from(_prefs);
    final updated = Map<String, bool>.from(_prefs)..[key] = value;
    final vm = context.read<SupplierViewModel>();
    final auth = context.read<AuthViewModel>();
    final messenger = ScaffoldMessenger.of(context);
    final uid = vm.supplierUid;

    if (key == 'pushEnabled' && value && uid != null) {
      await auth.updateFcmToken(uid);
    } else if (key == 'pushEnabled' && !value && uid != null) {
      await auth.clearFcmToken(uid);
    }

    if (!mounted) return;
    setState(() => _prefs = updated);

    final error = await vm.saveNotificationPreferences(updated);
    if (!mounted) return;

    if (error != null) {
      setState(() => _prefs = previous);
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: FieldColors.statusDanger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SupplierViewModel>();
    final saving = vm.notificationPrefsSaving;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: BoxDecoration(
        color: FieldColors.surfaceWhite,
        borderRadius: BorderRadius.circular(FieldRadius.card),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FieldColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notification Preferences',
                      style: AppTextStyles.h3.copyWith(
                        color: FieldColors.primaryNavy,
                      ),
                    ),
                  ),
                  if (saving)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Choose which alerts you receive on this device.',
                style: AppTextStyles.caption.copyWith(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            if (!_initialized)
              const Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              )
            else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                  children: [
                    _PrefTile(
                      icon: Icons.notifications_active_outlined,
                      title: 'Push notifications',
                      subtitle: 'Master switch for all mobile alerts',
                      value: _prefs['pushEnabled'] ?? true,
                      enabled: !saving,
                      onChanged: (v) => _onToggle('pushEnabled', v),
                    ),
                    const Divider(height: 1, indent: 56),
                    _PrefTile(
                      icon: Icons.shopping_bag_outlined,
                      title: 'New orders',
                      subtitle: 'When a buyer places a new order',
                      value: _prefs['newOrders'] ?? true,
                      enabled: !saving && (_prefs['pushEnabled'] ?? true),
                      onChanged: (v) => _onToggle('newOrders', v),
                    ),
                    _PrefTile(
                      icon: Icons.local_shipping_outlined,
                      title: 'Order updates',
                      subtitle: 'Acceptance, delivery, and completion',
                      value: _prefs['orderUpdates'] ?? true,
                      enabled: !saving && (_prefs['pushEnabled'] ?? true),
                      onChanged: (v) => _onToggle('orderUpdates', v),
                    ),
                    _PrefTile(
                      icon: Icons.chat_bubble_outline,
                      title: 'Chat messages',
                      subtitle: 'Messages from field users',
                      value: _prefs['chatMessages'] ?? true,
                      enabled: !saving && (_prefs['pushEnabled'] ?? true),
                      onChanged: (v) => _onToggle('chatMessages', v),
                    ),
                    _PrefTile(
                      icon: Icons.star_outline,
                      title: 'Ratings & reviews',
                      subtitle: 'When you receive a new rating',
                      value: _prefs['ratings'] ?? true,
                      enabled: !saving && (_prefs['pushEnabled'] ?? true),
                      onChanged: (v) => _onToggle('ratings', v),
                    ),
                    _PrefTile(
                      icon: Icons.payments_outlined,
                      title: 'Earnings & payouts',
                      subtitle: 'Commission and settlement alerts',
                      value: _prefs['earnings'] ?? true,
                      enabled: !saving && (_prefs['pushEnabled'] ?? true),
                      onChanged: (v) => _onToggle('earnings', v),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: FieldColors.primaryNavy.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: FieldColors.primaryNavy),
      ),
      title: Text(
        title,
        style: AppTextStyles.body.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: FieldColors.primaryNavy,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTextStyles.caption.copyWith(fontSize: 11),
      ),
      value: value,
      onChanged: enabled ? onChanged : null,
      activeThumbColor: FieldColors.accentAmber,
      activeTrackColor: FieldColors.accentAmber.withValues(alpha: 0.45),
    );
  }
}
