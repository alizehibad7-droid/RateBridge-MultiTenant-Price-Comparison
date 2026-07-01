import 'package:flutter/services.dart';

/// Validation helpers for Pakistan-specific registration fields.
class PakistanValidators {  PakistanValidators._();

  static String digitsOnly(String value) =>
      value.replaceAll(RegExp(r'\D'), '');

  static String? validateCnic(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'CNIC is required';
    }
    final digits = digitsOnly(value);
    if (digits.length != 13) {
      return 'CNIC must be 13 digits (e.g. 35202-1234567-1)';
    }
    return null;
  }

  static String formatCnic(String value) {
    final digits = digitsOnly(value);
    if (digits.length <= 5) return digits;
    if (digits.length <= 12) {
      return '${digits.substring(0, 5)}-${digits.substring(5)}';
    }
    return '${digits.substring(0, 5)}-${digits.substring(5, 12)}-${digits.substring(12)}';
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    var digits = digitsOnly(value);
    if (digits.startsWith('92') && digits.length == 12) {
      digits = '0${digits.substring(2)}';
    }
    if (digits.length == 10 && digits.startsWith('3')) {
      digits = '0$digits';
    }
    if (digits.length == 11 && digits.startsWith('03')) {
      return null;
    }
    return 'Enter a valid Pakistan mobile number (e.g. 0300 1234567)';
  }

  static String normalizePhone(String value) {
    var digits = digitsOnly(value);
    if (digits.startsWith('92') && digits.length == 12) {
      return '0${digits.substring(2)}';
    }
    if (digits.length == 10 && digits.startsWith('3')) {
      return '0$digits';
    }
    return digits;
  }
}

/// Formats CNIC input as 35202-1234567-1 while typing.
class CnicTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final formatted = PakistanValidators.formatCnic(newValue.text);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
