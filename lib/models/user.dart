class User {
  final String id;
  final String? email;
  final String? phone;
  final String role;
  final String? candidateId;
  final String? companyId;

  User({
    required this.id,
    this.email,
    this.phone,
    required this.role,
    this.candidateId,
    this.companyId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      candidateId: json['candidateId'] as String?,
      companyId: json['companyId'] as String?,
    );
  }
}

class AuthResponse {
  final String accessToken;
  final User user;

  AuthResponse({
    required this.accessToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['accessToken'] as String,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
