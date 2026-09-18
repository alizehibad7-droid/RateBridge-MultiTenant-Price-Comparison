import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../viewmodels/notification_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../widgets/notification_badge_icon.dart';
import '../constants/route_names.dart';
import '../utils/app_navigation.dart';

/// RateBridge design system for the Admin panel.
class AdminColors {
  AdminColors._();

  static const navy = Color(0xFF1E326E); // Synchronized with other panels
  static const primary = Color(0xFF1E326E);
  static const amber = Color(0xFFF59E0B);
  static const darkAmber = Color(0xFFD97706);
  static const screenBg = Color(0xFFF8FAFC);
  static const border = Color(0xFFE2E8F0);
  static const textGrey = Color(0xFF64748B);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF4444);
  static const purple = Color(0xFF8B5CF6);
}

class AdminTheme {
  AdminTheme._();

  static TextStyle get _base => GoogleFonts.plusJakartaSans();

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor ?? AdminColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      );

  static TextStyle sectionHeaderStyle({double size = 11}) => _base.copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AdminColors.textGrey,
      );

  static TextStyle titleStyle({double size = 18}) => _base.copyWith(
        fontSize: size,
        fontWeight: FontWeight.w700,
        color: AdminColors.navy,
        letterSpacing: -0.5,
      );

  static TextStyle bodyStyle({Color? color, double? size, FontWeight? weight}) => _base.copyWith(
        fontSize: size ?? 13,
        color: color ?? AdminColors.navy,
        fontWeight: weight ?? FontWeight.w500,
      );

  static TextStyle mutedStyle({double size = 12, FontWeight? weight}) => _base.copyWith(
        fontSize: size,
        color: AdminColors.textGrey,
        fontWeight: weight ?? FontWeight.w500,
      );

  static ({Color bg, Color fg}) statusColors(String status) {
    final s = status.toLowerCase().replaceAll('_', '');
    switch (s) {
      case 'pending':
        return (
          bg: AdminColors.amber.withValues(alpha: 0.1),
          fg: AdminColors.darkAmber,
        );
      case 'active':
      case 'confirmed':
      case 'approved':
        return (
          bg: AdminColors.green.withValues(alpha: 0.1),
          fg: AdminColors.green,
        );
      case 'settled':
        return (
          bg: AdminColors.purple.withValues(alpha: 0.1),
          fg: AdminColors.purple,
        );
      case 'rejected':
      case 'failed':
        return (
          bg: AdminColors.red.withValues(alpha: 0.1),
          fg: AdminColors.red,
        );
      case 'suspended':
        return (
          bg: AdminColors.textGrey.withValues(alpha: 0.1),
          fg: AdminColors.textGrey,
        );
      default:
        return (
          bg: AdminColors.textGrey.withValues(alpha: 0.1),
          fg: AdminColors.textGrey,
        );
    }
  }

  static InputDecorationThemeData get inputDecorationThemeData {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AdminColors.border, width: 1),
    );
    return InputDecorationThemeData(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AdminColors.navy,
      ),
      hintStyle: _base.copyWith(fontSize: 13, color: AdminColors.textGrey),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
      ),
    );
  }

  static InputDecoration inputDecoration({
    String? labelText,
    String? hintText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDense = true,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AdminColors.border, width: 1),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: isDense,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: _base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AdminColors.navy,
      ),
      hintStyle: _base.copyWith(fontSize: 13, color: AdminColors.textGrey),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
      ),
    );
  }

  static ButtonStyle primaryButtonStyle({double? width, double height = 40}) =>
      ElevatedButton.styleFrom(
        backgroundColor: AdminColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: Size(width ?? 64, height),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      );

  static ButtonStyle secondaryButtonStyle({double? width, double height = 40}) =>
      OutlinedButton.styleFrom(
        foregroundColor: AdminColors.navy,
        side: const BorderSide(color: AdminColors.border, width: 1.5),
        minimumSize: Size(width ?? 64, height),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      );

  static ButtonStyle destructiveButtonStyle({double? width, double height = 40}) =>
      OutlinedButton.styleFrom(
        foregroundColor: AdminColors.red,
        side: const BorderSide(color: AdminColors.red, width: 1.2),
        minimumSize: Size(width ?? 64, height),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: _base.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      );

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
        scaffoldBackgroundColor: AdminColors.screenBg,
        splashColor: Colors.transparent,
        highlightColor: AdminColors.primary.withValues(alpha: 0.05),
        colorScheme: const ColorScheme.light(
          primary: AdminColors.primary,
          onPrimary: Colors.white,
          secondary: AdminColors.amber,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: AdminColors.navy,
          error: AdminColors.red,
          outline: AdminColors.border,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: AdminColors.navy,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AdminColors.navy,
          ),
          iconTheme: const IconThemeData(color: AdminColors.navy),
          actionsIconTheme: const IconThemeData(color: AdminColors.navy),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AdminColors.border, width: 1),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AdminColors.border,
          thickness: 1,
          space: 1,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: primaryButtonStyle(width: null),
        ),
        filledButtonTheme: FilledButtonThemeData(style: primaryButtonStyle(width: null)),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: secondaryButtonStyle(width: null),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AdminColors.primary,
            textStyle: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        inputDecorationTheme: inputDecorationThemeData,
        tabBarTheme: TabBarThemeData(
          labelColor: AdminColors.primary,
          unselectedLabelColor: AdminColors.textGrey,
          indicatorColor: AdminColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AdminColors.primary,
          strokeWidth: 2.5,
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: AdminColors.navy,
        ),
        dialogTheme: DialogThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          titleTextStyle: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AdminColors.navy,
          ),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AdminColors.primary,
          unselectedItemColor: AdminColors.textGrey,
          type: BottomNavigationBarType.fixed,
          elevation: 10,
          selectedLabelStyle: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500),
        ),
        textTheme: TextTheme(
          headlineMedium: titleStyle(size: 24),
          titleLarge: titleStyle(size: 18),
          titleMedium: titleStyle(size: 15),
          bodyLarge: bodyStyle(),
          bodyMedium: bodyStyle(color: AdminColors.textGrey),
          labelLarge: _base.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AdminColors.navy,
          ),
        ),
      );

  static Widget wrap(Widget child) => Theme(data: theme, child: child);
}

/// Professional AppBar with integrated progress loading.
class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final bool showNotificationIcon;
  final Widget? leading;

  const AdminAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.showNotificationIcon = true,
    this.leading,
  }) : assert(title != null || titleWidget != null);

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final allActions = [...?actions];

    if (showNotificationIcon) {
      final notifVm = context.watch<NotificationViewModel>();
      final authVm = context.read<AuthViewModel>();
      final isAdmin = authVm.user?.role.toLowerCase().contains('admin') ?? false;

      allActions.add(
        NotificationBadgeIcon(
          unreadCount: notifVm.unreadCount,
          iconColor: AdminColors.navy,
          onPressed: () => context.push(
            isAdmin ? RouteNames.adminNotifications : RouteNames.ceoNotifications,
          ),
        ),
      );
      allActions.add(const SizedBox(width: 12));
    }

    return AppBar(
      automaticallyImplyLeading: false,
      leading: leading ??
          (automaticallyImplyLeading
              ? AppNavigation.leading(context, color: AdminColors.navy)
              : null),
      title: titleWidget ?? (title != null ? Text(title!) : null),
      actions: allActions,
      bottom: bottom,
    );
  }
}

class AdminSectionLabel extends StatelessWidget {
  final String text;

  const AdminSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AdminTheme.sectionHeaderStyle());
  }
}
