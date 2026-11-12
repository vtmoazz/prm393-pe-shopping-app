import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/app_database.dart';
import '../models/models.dart';
import '../utils/validators.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._db, this._prefs);

  static const _rememberKey = 'remember_me_email';

  final AppDatabase _db;
  final SharedPreferences _prefs;

  AppUser? _user;
  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;

  /// Email saved by "Remember Me", used to prefill the login form.
  String? get rememberedEmail => _prefs.getString(_rememberKey);

  /// Restores the session when "Remember Me" was ticked on the last login.
  Future<void> tryAutoLogin() async {
    final email = rememberedEmail;
    if (email == null) return;
    _user = await _db.findUserByEmail(email);
    if (_user == null) await _prefs.remove(_rememberKey);
    notifyListeners();
  }

  /// Returns an error message, or null on success.
  Future<String?> register(
    String fullName,
    String email,
    String password,
  ) async {
    final normalized = email.trim().toLowerCase();
    if (await _db.findUserByEmail(normalized) != null) {
      return 'This email is already registered';
    }
    await _db.insertUser(
      AppUser(
        fullName: fullName.trim(),
        email: normalized,
        passwordHash: hashPassword(password),
      ),
    );
    return null;
  }

  /// Returns an error message, or null on success.
  Future<String?> login(
    String email,
    String password, {
    required bool rememberMe,
  }) async {
    final user = await _db.findUserByEmail(email);
    if (user == null || user.passwordHash != hashPassword(password)) {
      return 'Incorrect email or password';
    }
    _user = user;
    if (rememberMe) {
      await _prefs.setString(_rememberKey, user.email);
    } else {
      await _prefs.remove(_rememberKey);
    }
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    _user = null;
    await _prefs.remove(_rememberKey);
    notifyListeners();
  }
}
