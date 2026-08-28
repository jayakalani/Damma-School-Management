import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../models/database_models.dart';
import '../security/password_hasher.dart';
import '../users/user_repository.dart';

class AuthSession {
  const AuthSession({required this.userId, required this.fullName, required this.username, required this.role});

  final int userId;
  final String fullName;
  final String username;
  final String role;

  bool get isAdmin => role == 'admin';
  bool get isStaff => role == 'staff';

  factory AuthSession.fromUser(User user) => AuthSession(
        userId: user.id!, fullName: user.fullName, username: user.username, role: user.role,
      );
}

class AuthService {
    AuthService({required this._database, UserRepository? users, PasswordHasher? passwordHasher})
        : _users = users ?? UserRepository(),
        _passwordHasher = passwordHasher ?? const PasswordHasher();

  final Database _database;
  final UserRepository _users;
  final PasswordHasher _passwordHasher;
  AuthSession? _session;

  AuthSession? get currentSession => _session;
  bool get isAuthenticated => _session != null;

  Future<AuthSession> login({required String username, required String password}) async {
    final user = await _users.findByUsername(database: _database, username: username);
    if (user == null) {
      throw const AuthenticationException('Invalid username or password.');
    }
    if (user.status != 'active') {
      throw const AuthenticationException(
        'Your account is inactive. Please contact the administrator.',
      );
    }
    if (!_passwordHasher.verify(password, user.passwordHash)) {
      throw const AuthenticationException('Invalid username or password.');
    }
    if (user.role != 'admin' && user.role != 'staff') {
      throw const AuthenticationException('Invalid username or password.');
    }
    _session = AuthSession.fromUser(user);
    return _session!;
  }

  void logout() => _session = null;

  bool canAccess({required String role}) => _session?.role == role;

  void requireRole(String role) {
    if (!canAccess(role: role)) throw const AuthorizationException();
  }
}

class AuthenticationException implements Exception {
  const AuthenticationException(this.message);
  final String message;
}

class AuthorizationException implements Exception {
  const AuthorizationException();
}