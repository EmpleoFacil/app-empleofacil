import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'message_realtime_service.dart';

class AuthService {
  final ApiService _api;
  final MessageRealtimeService _realtime;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const _tokenKey = 'access_token';
  static const _rememberKey = 'remember_session';

  AuthService(this._api, this._realtime);

  Future<void> init() async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      _api.setToken(token);
    }
  }

  Future<User?> restoreSession() async {
    final token = await _storage.read(key: _tokenKey);
    if (token == null) {
      _api.setToken(null);
      _realtime.disconnect();
      return null;
    }

    try {
      _api.setToken(token);
      final user = await getCurrentUser();
      _realtime.connect();
      return user;
    } catch (_) {
      await logout();
      return null;
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
      if (email?.isNotEmpty ?? false) 'email': email,
      'password': password,
      if (desiredJobType?.isNotEmpty ?? false) 'desiredJobType': desiredJobType,
    });

    final authResponse = AuthResponse.fromJson(response);
    await _saveToken(authResponse.accessToken, true);
    _realtime.connect();
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
    _realtime.connect();
    return authResponse;
  }

  Future<User> getCurrentUser() async {
    final response = await _api.get('/auth/me') as Map<String, dynamic>;
    return _mapCurrentUser(response);
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
    _realtime.disconnect();
  }

  Future<void> _saveToken(String token, bool remember) async {
    _api.setToken(token);
    if (remember) {
      await _storage.write(key: _tokenKey, value: token);
      await _storage.write(key: _rememberKey, value: 'true');
    } else {
      await _storage.delete(key: _tokenKey);
      await _storage.delete(key: _rememberKey);
    }
  }

  User _mapCurrentUser(Map<String, dynamic> json) {
    final candidate = json['candidateProfile'] as Map<String, dynamic>?;
    final companyUsers = json['companyUsers'] as List?;
    final companyUser = companyUsers != null && companyUsers.isNotEmpty
        ? companyUsers.first as Map<String, dynamic>
        : null;

    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      candidateId: candidate?['id'] as String?,
      companyId: companyUser?['companyId'] as String?,
    );
  }
}
