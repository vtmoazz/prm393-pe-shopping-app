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
