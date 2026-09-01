// Comprehensive input validation and sanitization utilities
// 
// This module provides centralized validation and sanitization for all user inputs
// before they are stored in the database.
// 
// Usage:
// ```dart
// // Validate form inputs
// final errors = await InputValidator.validateStudent(
//   fullName: nameController.text,
//   studentId: idController.text,
//   batch: selectedBatch,
// );
// 
// if (errors.isNotEmpty) {
//   // Show errors to user
//   return;
// }
// 
// // Sanitize before storage
// final sanitized = InputSanitizer.sanitizeText(userInput);
// await db.insert('students', {'full_name': sanitized});
// ```

class ValidationError implements Exception {
  final String field;
  final String message;
  
  ValidationError({required this.field, required this.message});
  
  @override
  String toString() => 'ValidationError: $field - $message';
}

/// Input validation rules for different data types
class InputValidator {
  const InputValidator._();
  
  // ============================================================================
  // TEXT FIELD VALIDATORS
  // ============================================================================
  
  /// Validates required text field (non-empty)
  /// 
  /// Returns null if valid, error message if invalid
  static String? requiredText(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
  
  /// Validates text length
  /// 
  /// ```dart
  /// InputValidator.textLength('John', minLength: 2, maxLength: 50);
  /// ```
  static String? textLength(
    String? value, {
    required int minLength,
    required int maxLength,
    String fieldName = 'Text',
  }) {
    if (value == null || value.isEmpty) return null;
    
    final length = value.length;
    if (length < minLength) {
      return '$fieldName must be at least $minLength characters';
    }
    if (length > maxLength) {
      return '$fieldName must not exceed $maxLength characters';
    }
    return null;
  }
  
  /// Validates text contains only alphanumeric characters and spaces
  static String? alphanumericOnly(String? value, {String fieldName = 'Text'}) {
    if (value == null || value.isEmpty) return null;
    
    if (!RegExp(r'^[a-zA-Z0-9\s\-\.]+$').hasMatch(value)) {
      return '$fieldName can only contain letters, numbers, spaces, hyphens and periods';
    }
    return null;
  }
  
  // ============================================================================
  // IDENTITY & PERSONAL INFO VALIDATORS
  // ============================================================================
  
  /// Validates Sri Lankan National ID (NIC)
  /// Accepts: 9 digits + V/X (old format) or 12 digits (new format)
  /// 
  /// ```dart
  /// InputValidator.nic('123456789V'); // valid
  /// InputValidator.nic('123456789012'); // valid
  /// ```
  static String? nic(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final trimmed = value.trim();
    
    // Old format: 9 digits + V/X
    if (RegExp(r'^\d{9}[VvXx]$').hasMatch(trimmed)) {
      return null;
    }
    
    // New format: 12 digits
    if (RegExp(r'^\d{12}$').hasMatch(trimmed)) {
      return null;
    }
    
    return 'Invalid NIC format. Use 9 digits + V/X or 12 digits';
  }
  
  /// Validates phone number
  /// Accepts: 0XXXXXXXXX (Sri Lankan) or +94XXXXXXXXX
  static String? phone(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final trimmed = value.trim();
    
    // Sri Lankan format: 0XX XXX XXXX or 0XXXXXXXXX
    if (RegExp(r'^0\d{9}$').hasMatch(trimmed.replaceAll(' ', ''))) {
      return null;
    }
    
    // International format: +94XX XXX XXXX or +94XXXXXXXXX
    if (RegExp(r'^\+94\d{9}$').hasMatch(trimmed.replaceAll(' ', ''))) {
      return null;
    }
    
    return 'Invalid phone number. Use 0XXXXXXXXX or +94XXXXXXXXX';
  }
  
  /// Validates email address
  static String? email(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final trimmed = value.trim().toLowerCase();
    
    // Basic email validation
    if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    
    if (trimmed.length > 254) {
      return 'Email address is too long (max 254 characters)';
    }
    
    return null;
  }
  
  /// Validates date of birth (must be valid date and in the past)
  static String? dateOfBirth(String? value) {
    if (value == null || value.isEmpty) return null;
    
    final trimmed = value.trim();
    
    // Check format YYYY-MM-DD
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return 'Date must be in YYYY-MM-DD format';
    }
    
    final date = DateTime.tryParse(trimmed);
    if (date == null) {
      return 'Invalid date';
    }
    
    // Must be in the past
    if (date.isAfter(DateTime.now())) {
      return 'Date of birth must be in the past';
    }
    
    // Reasonable age check (0-150 years)
    final age = DateTime.now().year - date.year;
    if (age < 0 || age > 150) {
      return 'Invalid date of birth';
    }
    
    return null;
  }
  
  /// Validates date (must be valid date)
  static String? date(String? value, {String fieldName = 'Date'}) {
    if (value == null || value.isEmpty) return '$fieldName is required';
    
    final trimmed = value.trim();
    
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed)) {
      return '$fieldName must be in YYYY-MM-DD format';
    }
    
    if (DateTime.tryParse(trimmed) == null) {
      return 'Invalid $fieldName';
    }
    
    return null;
  }
  
  /// Validates optional date (if provided, must be valid)
  static String? optionalDate(String? value, {String fieldName = 'Date'}) {
    if (value == null || value.isEmpty) return null;
    return date(value, fieldName: fieldName);
  }
  
  // ============================================================================
  // NUMERIC VALIDATORS
  // ============================================================================
  
  /// Validates integer value within range
  static String? intRange(
    int? value, {
    required int min,
    required int max,
    String fieldName = 'Value',
  }) {
    if (value == null) return '$fieldName is required';
    
    if (value < min || value > max) {
      return '$fieldName must be between $min and $max';
    }
    
    return null;
  }
  
  /// Validates positive number
  static String? positiveNumber(double? value, {String fieldName = 'Value'}) {
    if (value == null || value <= 0) {
      return '$fieldName must be greater than 0';
    }
    return null;
  }
  
  // ============================================================================
  // CREDENTIAL VALIDATORS
  // ============================================================================
  
  /// Validates username
  /// Requirements:
  /// - 3-20 characters
  /// - Only letters, numbers, dots, underscores, hyphens
  /// - Case insensitive
  static String? username(String? value) {
    if (value == null || value.isEmpty) return 'Username is required';
    
    final trimmed = value.trim();
    
    if (trimmed.length < 3 || trimmed.length > 20) {
      return 'Username must be 3-20 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z0-9._\-]+$').hasMatch(trimmed)) {
      return 'Username can only contain letters, numbers, dots, underscores and hyphens';
    }
    
    return null;
  }
  
  /// Validates password strength
  /// Requirements:
  /// - Minimum 8 characters
  /// - At least 1 uppercase letter
  /// - At least 1 lowercase letter
  /// - At least 1 digit
  /// - At least 1 special character
  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    
    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }
    
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least 1 uppercase letter';
    }
    
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least 1 lowercase letter';
    }
    
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Password must contain at least 1 digit';
    }
    
    final specialCharPattern = RegExp(r'[!@#$%^&*_\-]');
    if (!specialCharPattern.hasMatch(value)) {
      return 'Password must contain at least 1 special character';
    }
    
    return null;
  }
  
  // ============================================================================
  // BATCH & ACADEMIC VALIDATORS
  // ============================================================================
  
  /// Validates batch name (e.g., "2024A", "G10-2024")
  static String? batchName(String? value) {
    if (value == null || value.isEmpty) return 'Batch name is required';
    
    final trimmed = value.trim().toUpperCase();
    
    // Allow formats like: 2024A, G10-2024, GR-11-2024
    if (!RegExp(r'^[A-Z0-9\-]+$').hasMatch(trimmed)) {
      return 'Batch name can only contain letters, numbers and hyphens';
    }
    
    if (trimmed.length > 20) {
      return 'Batch name must not exceed 20 characters';
    }
    
    return null;
  }
  
  /// Validates grade/class (e.g., "Grade 10", "Grade 6A")
  static String? grade(String? value) {
    if (value == null || value.isEmpty) return 'Grade is required';
    
    final trimmed = value.trim();
    
    if (!RegExp(r'^Grade\s+\d{1,2}[A-Z]?$', caseSensitive: false).hasMatch(trimmed)) {
      return 'Use format like "Grade 10" or "Grade 6A"';
    }
    
    return null;
  }
  
  // ============================================================================
  // COMPOSITE VALIDATORS (Multiple Fields)
  // ============================================================================
  
  /// Validates a student record
  /// 
  /// Returns list of validation errors (empty if valid)
  static List<String> validateStudent({
    required String fullName,
    required String studentId,
    required String batch,
    String? dateOfBirth,
    String? phone,
  }) {
    final errors = <String>[];
    
    if (requiredText(fullName, fieldName: 'Full Name') != null) {
      errors.add('Full Name: ${requiredText(fullName, fieldName: 'Full Name')}');
    }
    
    if (textLength(fullName, minLength: 2, maxLength: 150, fieldName: 'Full Name') != null) {
      errors.add('Full Name: ${textLength(fullName, minLength: 2, maxLength: 150, fieldName: 'Full Name')}');
    }
    
    if (requiredText(studentId, fieldName: 'Student ID') != null) {
      errors.add('Student ID: ${requiredText(studentId, fieldName: 'Student ID')}');
    }
    
    if (textLength(studentId, minLength: 2, maxLength: 50, fieldName: 'Student ID') != null) {
      errors.add('Student ID: ${textLength(studentId, minLength: 2, maxLength: 50, fieldName: 'Student ID')}');
    }
    
    if (requiredText(batch, fieldName: 'Batch') != null) {
      errors.add('Batch: ${requiredText(batch, fieldName: 'Batch')}');
    }
    
    if (dateOfBirth != null && dateOfBirth.isNotEmpty) {
      if (InputValidator.dateOfBirth(dateOfBirth) != null) {
        errors.add('Date of Birth: ${InputValidator.dateOfBirth(dateOfBirth)}');
      }
    }
    
    if (phone != null && phone.isNotEmpty) {
      if (InputValidator.phone(phone) != null) {
        errors.add('Phone: ${InputValidator.phone(phone)}');
      }
    }
    
    return errors;
  }
  
  /// Validates a teacher record
  static List<String> validateTeacher({
    required String fullName,
    required String email,
    String? phone,
    String? nic,
  }) {
    final errors = <String>[];
    
    if (requiredText(fullName, fieldName: 'Full Name') != null) {
      errors.add('Full Name is required');
    }
    
    if (textLength(fullName, minLength: 2, maxLength: 150, fieldName: 'Full Name') != null) {
      errors.add('Full Name must be 2-150 characters');
    }
    
    if (requiredText(email, fieldName: 'Email') != null) {
      errors.add('Email is required');
    } else if (InputValidator.email(email) != null) {
      errors.add('Email: ${InputValidator.email(email)}');
    }
    
    if (phone != null && phone.isNotEmpty) {
      if (InputValidator.phone(phone) != null) {
        errors.add('Phone: ${InputValidator.phone(phone)}');
      }
    }
    
    if (nic != null && nic.isNotEmpty) {
      if (InputValidator.nic(nic) != null) {
        errors.add('NIC: ${InputValidator.nic(nic)}');
      }
    }
    
    return errors;
  }
  
  /// Validates a staff/user account creation
  static List<String> validateUserAccount({
    required String fullName,
    required String username,
    required String password,
    required String role,
  }) {
    final errors = <String>[];
    
    if (requiredText(fullName, fieldName: 'Full Name') != null) {
      errors.add('Full Name is required');
    }
    
    if (InputValidator.username(username) != null) {
      errors.add('Username: ${InputValidator.username(username)}');
    }
    
    if (InputValidator.password(password) != null) {
      errors.add('Password: ${InputValidator.password(password)}');
    }
    
    if (!['admin', 'staff', 'teacher'].contains(role.toLowerCase())) {
      errors.add('Role must be admin, staff, or teacher');
    }
    
    return errors;
  }
}

/// Input sanitization utilities
/// Removes or escapes potentially harmful content before database storage
class InputSanitizer {
  const InputSanitizer._();
  
  /// Sanitize generic text input
  /// - Trims whitespace
  /// - Removes null bytes
  /// - Limits consecutive spaces to 1
  static String sanitizeText(String? input) {
    if (input == null || input.isEmpty) return '';
    
    // Remove null bytes
    String sanitized = input.replaceAll('\x00', '');
    
    // Trim whitespace
    sanitized = sanitized.trim();
    
    // Replace multiple spaces with single space
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), ' ');
    
    return sanitized;
  }
  
  /// Sanitize numeric input (remove non-numeric characters)
  static String sanitizeNumeric(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'[^0-9]'), '');
  }
  
  /// Sanitize phone number (keep only digits and +)
  static String sanitizePhone(String? input) {
    if (input == null) return '';
    return input.replaceAll(RegExp(r'[^0-9+]'), '');
  }
  
  /// Sanitize email (convert to lowercase, trim)
  static String sanitizeEmail(String? input) {
    if (input == null) return '';
    return sanitizeText(input).toLowerCase();
  }
  
  /// Sanitize username (lowercase, trim, remove invalid chars)
  static String sanitizeUsername(String? input) {
    if (input == null) return '';
    String sanitized = sanitizeText(input).toLowerCase();
    // Allow only alphanumeric, dots, underscores, hyphens
    sanitized = sanitized.replaceAll(RegExp(r'[^a-z0-9._\-]'), '');
    return sanitized;
  }
  
  /// Sanitize for database search (escape SQL wildcards)
  static String sanitizeForSearch(String? input) {
    if (input == null) return '';
    String sanitized = sanitizeText(input);
    // Escape SQL LIKE wildcards
    sanitized = sanitized.replaceAll('%', '\\%');
    sanitized = sanitized.replaceAll('_', '\\_');
    return sanitized;
  }
  
  /// Escape special characters for SQL (prepare for raw queries)
  /// Note: Use parameterized queries instead of this when possible
  static String escapeSqlString(String? input) {
    if (input == null) return '';
    // Escape single quotes by doubling them
    return input.replaceAll("'", "''");
  }
  
  /// Sanitize for display (remove potentially harmful characters)
  static String sanitizeForDisplay(String? input) {
    if (input == null) return '';
    String sanitized = sanitizeText(input);
    // Remove control characters
    sanitized = sanitized.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    return sanitized;
  }
  
  /// Limit text to maximum length
  static String limitLength(String? input, int maxLength) {
    if (input == null) return '';
    final sanitized = sanitizeText(input);
    return sanitized.length > maxLength 
        ? sanitized.substring(0, maxLength) 
        : sanitized;
  }
}

/// Extension methods for convenient validation
extension ValidationExtensions on String {
  /// Sanitize this string
  String get sanitized => InputSanitizer.sanitizeText(this);
  
  /// Sanitize and validate as required text
  String? validateRequired({String fieldName = 'Field'}) {
    return InputValidator.requiredText(this, fieldName: fieldName);
  }
  
  /// Validate as email
  String? validateEmail() => InputValidator.email(this);
  
  /// Validate as phone
  String? validatePhone() => InputValidator.phone(this);
  
  /// Validate as NIC
  String? validateNic() => InputValidator.nic(this);
  
  /// Validate as date of birth
  String? validateDateOfBirth() => InputValidator.dateOfBirth(this);
  
  /// Validate as username
  String? validateUsername() => InputValidator.username(this);
  
  /// Validate as password
  String? validatePassword() => InputValidator.password(this);
}
