import 'dart:convert';

import 'package:crypto/crypto.dart';

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

String? validateRequired(String? value, String field) =>
    (value == null || value.trim().isEmpty) ? '$field is required' : null;

String? validateEmail(String? value) {
  final required = validateRequired(value, 'Email');
  if (required != null) return required;
  return _emailPattern.hasMatch(value!.trim()) ? null : 'Invalid email format';
}

String? validatePassword(String? value) {
  final required = validateRequired(value, 'Password');
  if (required != null) return required;
  return value!.length < 6 ? 'Password must be at least 6 characters' : null;
}

String? validateConfirmPassword(String? value, String password) {
  final required = validateRequired(value, 'Confirm Password');
  if (required != null) return required;
  return value == password ? null : 'Passwords do not match';
}

String? validatePrice(String? value) {
  final required = validateRequired(value, 'Price');
  if (required != null) return required;
  final price = double.tryParse(value!.trim());
  if (price == null) return 'Price must be a number';
  return price <= 0 ? 'Price must be greater than 0' : null;
}

String hashPassword(String password) =>
    sha256.convert(utf8.encode(password)).toString();

/// Affiliate commission in percent of the sale, from 0 to 50.
String? validateCommission(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Commission is required';
  }
  final rate = double.tryParse(value.trim());
  if (rate == null) return 'Commission must be a number';
  return rate < 0 || rate > 50 ? 'Commission must be from 0 to 50%' : null;
}

/// A percent without a needless ".0": 5 -> "5", 2.5 -> "2.5".
String formatRate(double rate) =>
    rate == rate.roundToDouble() ? rate.toStringAsFixed(0) : '$rate';
