import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../constants/app_colors.dart';

/// Labeled text field used across all auth/registration forms.
class AuthTextField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? placeholder;
  final String? helperText;
  final IconData prefixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onUnfocus;
  final Widget? suffix;
  final bool enabled;
  final int maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;

  const AuthTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.prefixIcon,
    this.placeholder,
    this.helperText,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.onChanged,
    this.onUnfocus,
    this.suffix,
    this.enabled = true,
    this.maxLines = 1,
    this.inputFormatters,
    this.textInputAction,
    this.focusNode,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;
  final _fieldKey = GlobalKey<FormFieldState<String>>();
  bool _showErrors = false;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  void _handleFocusChange() {
    if (_focusNode.hasFocus) return;
    setState(() => _showErrors = true);
    _fieldKey.currentState?.validate();
    widget.onUnfocus?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: _fieldKey,
          focusNode: _focusNode,
          controller: widget.controller,
          obscureText: _obscured,
          keyboardType: widget.maxLines > 1 &&
                  widget.keyboardType == TextInputType.text
              ? TextInputType.multiline
              : widget.keyboardType,
          textInputAction: widget.textInputAction ??
              (widget.maxLines > 1
                  ? TextInputAction.newline
                  : TextInputAction.next),
          enabled: widget.enabled,
          autovalidateMode: _showErrors
              ? AutovalidateMode.always
              : AutovalidateMode.disabled,
          validator: widget.validator,
          onChanged: (value) {
            if (_showErrors) {
              _fieldKey.currentState?.validate();
            }
            widget.onChanged?.call(value);
          },
          onFieldSubmitted: (_) {
            setState(() => _showErrors = true);
            _fieldKey.currentState?.validate();
            widget.onUnfocus?.call(widget.controller.text);
          },
          maxLines: widget.maxLines,
          inputFormatters: widget.inputFormatters,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 15,
            color: AppColors.navy,
          ),
          decoration: InputDecoration(
            hintText: widget.placeholder,
            helperText: widget.helperText,
            hintStyle: GoogleFonts.plusJakartaSans(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              widget.prefixIcon,
              color: AppColors.textSecondary,
              size: 20,
            ),
            suffixIcon: widget.obscureText
                ? IconButton(
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  )
                : widget.suffix,
            filled: true,
            fillColor: Colors.white,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.border, width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.amber, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}
