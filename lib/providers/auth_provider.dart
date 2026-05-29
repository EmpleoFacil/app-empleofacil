import 'package:flutter/foundation.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  
  User? _user;
  bool _isLoading = false;
  String? _error;
  String? _selectedJobCategory;

  AuthProvider(ApiService apiService) : _authService = AuthService(apiService);

  User? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _user != null;
  String? get selectedJobCategory => _selectedJobCategory;

  void setSelectedJobCategory(String? category) {
    _selectedJobCategory = category;
    notifyListeners();
  }

  Future<void> init() async {
    await _authService.init();
  }

  Future<bool> checkSession() async {
    return await _authService.hasValidSession();
  }

  Future<bool> register({
    required String fullName,
    required String phone,
    String? email,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.registerCandidate(
        fullName: fullName,
        phone: phone,
        email: email,
        password: password,
        desiredJobType: _selectedJobCategory,
      );
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String identifier,
    required String password,
    bool rememberSession = false,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.login(
        identifier: identifier,
        password: password,
        rememberSession: rememberSession,
      );
      _user = response.user;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>?> recoverAccess(String identifier) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.recoverAccess(identifier);
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifyCode({
    required String recoveryId,
    required String code,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _authService.verifyCode(
        recoveryId: recoveryId,
        code: code,
      );
      _isLoading = false;
      notifyListeners();
      return response;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _authService.resetPassword(
        resetToken: resetToken,
        newPassword: newPassword,
      );
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    _user = null;
    _selectedJobCategory = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
