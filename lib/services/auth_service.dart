import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  final ApiService _api;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  static const _tokenKey = 'access_token';
  static const _rememberKey = 'remember_session';

  AuthService(this._api);

  Future<void> init() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      _api.setToken(token);
    }
  }

  Future<bool> hasValidSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) return false;
    
    try {
      _api.setToken(token);
      await _api.get('/auth/me');
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<AuthResponse> registerCandidate({
    required String fullName,
    required String phone,
    String? email,
    required String password,
    String? desiredJobType,
  }) async {
    final response = await _api.post('/auth/register-candidate', {
      'fullName': fullName,
      'phone': phone,
      if (email != null && email.isNotEmpty) 'email': email,
      'password': password,
      if (desiredJobType != null) 'desiredJobType': desiredJobType,
    });

    final authResponse = AuthResponse.fromJson(response);
    await _saveToken(authResponse.accessToken, true);
    return authResponse;
  }

  Future<AuthResponse> login({
    required String identifier,
    required String password,
    bool rememberSession = false,
  }) async {
    final response = await _api.post('/auth/login', {
      'identifier': identifier,
      'password': password,
    });

    final authResponse = AuthResponse.fromJson(response);
    await _saveToken(authResponse.accessToken, rememberSession);
    return authResponse;
  }

  Future<Map<String, dynamic>> recoverAccess(String identifier) async {
    final response = await _api.post('/auth/recover-access', {
      'identifier': identifier,
    });
    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyCode({
    required String recoveryId,
    required String code,
  }) async {
    final response = await _api.post('/auth/verify-code', {
      'recoveryId': recoveryId,
      'code': code,
    });
    return response as Map<String, dynamic>;
  }

  Future<void> resetPassword({
    required String resetToken,
    required String newPassword,
  }) async {
    await _api.post('/auth/reset-password', {
      'resetToken': resetToken,
      'newPassword': newPassword,
    });
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _rememberKey);
    _api.setToken(null);
  }

  Future<void> _saveToken(String token, bool remember) async {
    _api.setToken(token);
    if (remember) {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _rememberKey, value: 'true');
    }
  }
}
