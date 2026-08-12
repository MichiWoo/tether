class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken});

  factory AuthTokens.fromJson(Map<String, dynamic> json) => AuthTokens(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final String accessToken;
  final String refreshToken;
}

class User {
  const User({required this.id, required this.email, this.name});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        email: json['email'] as String,
        name: json['name'] as String?,
      );

  final String id;
  final String email;
  final String? name;

  String get displayName {
    final n = name;
    return (n != null && n.isNotEmpty) ? n : email.split('@').first;
  }
}

class AuthResult {
  const AuthResult({required this.tokens, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        tokens: AuthTokens.fromJson(json),
        user: User.fromJson(json['user'] as Map<String, dynamic>),
      );

  final AuthTokens tokens;
  final User user;
}
