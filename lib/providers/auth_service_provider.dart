import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:damma_school_management_system/core/services/auth_service.dart';

/// Global instance of AuthService for app-wide authentication state.
/// 
/// This follows the Service Pattern for managing application-level state.
/// All pages should receive this instance via constructor injection.
/// 
/// Usage:
/// ```dart
/// final authService = AuthService(database: database);
/// runApp(MyApp(auth: authService));
/// ```
class AuthServiceProvider {
  static late AuthService _instance;
  
  /// Initialize the AuthService instance (called once at app startup)
  static Future<void> initialize(Database database) async {
    _instance = AuthService(database: database);
  }
  
  /// Get the current AuthService instance
  static AuthService get instance => _instance;
}
