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

  /// Signs up a customer, or a seller with [shopName]. Admin accounts cannot
  /// be self-registered. Returns an error message, or null on success.
  Future<String?> register(
    String fullName,
    String email,
    String password, {
    UserRole role = UserRole.customer,
    String? shopName,
  }) async {
    if (role == UserRole.admin) return 'Admin accounts cannot be registered';
    final shop = shopName?.trim() ?? '';
    if (role == UserRole.seller && shop.isEmpty) return 'Shop name is required';
    final normalized = email.trim().toLowerCase();
    if (await _db.findUserByEmail(normalized) != null) {
      return 'This email is already registered';
    }
    await _db.insertUser(
      AppUser(
        fullName: fullName.trim(),
        email: normalized,
        passwordHash: hashPassword(password),
        role: role,
        shopName: role == UserRole.seller ? shop : null,
      ),
    );
    return null;
  }

  // ---------- Admin: accounts ----------

  Future<List<AppUser>> allUsers() {
    _requireAdmin();
    return _db.getUsers();
  }

  /// Changes another account's role. A new seller gets a default shop name.
  Future<void> setRole(AppUser target, UserRole role) async {
    _requireAdmin();
    if (target.id == _user!.id) {
      throw StateError('Admins cannot change their own role');
    }
    final shopName = role == UserRole.seller
        ? (target.shopName ?? "${target.fullName}'s Shop")
        : target.shopName;
    await _db.updateUserRole(target.id!, role, shopName);
  }

  void _requireAdmin() {
    if (_user?.isAdmin != true) throw StateError('Admin only');
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
