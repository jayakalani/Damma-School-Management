# Input Validation & Sanitization Guide

This guide explains how to use the comprehensive input validation and sanitization system in your application.

## 📋 Overview

The validation system consists of three main components:

1. **InputValidator** - Validates user input against business rules
2. **InputSanitizer** - Removes/escapes harmful content before storage
3. **Extension Methods** - Convenient validation on String objects

## 🔍 Validation vs Sanitization

| Aspect | Validation | Sanitization |
|--------|-----------|---------------|
| **Purpose** | Check if input meets requirements | Clean/escape harmful content |
| **Action** | Reject invalid input, show errors | Transform input to safe format |
| **Timing** | Before processing | Before storage in database |
| **Example** | Email format check | Trim whitespace, lowercase |

## 📚 Using InputValidator

### Text Validation

```dart
import 'package:damma_school_management_system/core/utils/validators.dart';

// Simple required text validation
String? error = InputValidator.requiredText('John', fieldName: 'Full Name');
// Returns: null (valid)

String? error = InputValidator.requiredText('', fieldName: 'Full Name');
// Returns: 'Full Name is required'

// Text length validation
String? error = InputValidator.textLength(
  'Jo',
  minLength: 2,
  maxLength: 50,
  fieldName: 'Name',
);
// Returns: null (valid)

// Alphanumeric only
String? error = InputValidator.alphanumericOnly('John-Doe', fieldName: 'Name');
// Returns: null (valid - hyphens allowed)

String? error = InputValidator.alphanumericOnly('John@Doe', fieldName: 'Name');
// Returns: 'Name can only contain letters, numbers, spaces, hyphens and periods'
```

### Personal Information Validation

```dart
// Validate NIC (Sri Lankan)
String? error = InputValidator.nic('123456789V');  // Old format
// Returns: null (valid)

String? error = InputValidator.nic('123456789012');  // New format
// Returns: null (valid)

// Validate phone number
String? error = InputValidator.phone('0771234567');  // Sri Lankan
// Returns: null (valid)

String? error = InputValidator.phone('+94771234567');  // International
// Returns: null (valid)

// Validate email
String? error = InputValidator.email('john@example.com');
// Returns: null (valid)

// Validate date of birth (must be valid date in past)
String? error = InputValidator.dateOfBirth('2000-05-15');
// Returns: null (valid)

String? error = InputValidator.dateOfBirth('2030-05-15');  // Future date
// Returns: 'Date of birth must be in the past'
```

### Credentials Validation

```dart
// Validate username (3-20 chars, letters/numbers/dots/underscores/hyphens)
String? error = InputValidator.username('john.doe_2024');
// Returns: null (valid)

String? error = InputValidator.username('jo');  // Too short
// Returns: 'Username must be 3-20 characters'

// Validate password strength
// Requirements: 8+ chars, uppercase, lowercase, digit, special char
String? error = InputValidator.password('SecurePass123!');
// Returns: null (valid)

String? error = InputValidator.password('weak');  // Too short, no special char
// Returns: 'Password must be at least 8 characters'
```

### Academic Data Validation

```dart
// Validate batch name (e.g., "2024A", "G10-2024")
String? error = InputValidator.batchName('2024A');
// Returns: null (valid)

// Validate grade
String? error = InputValidator.grade('Grade 10');
// Returns: null (valid)

String? error = InputValidator.grade('G10');  // Wrong format
// Returns: 'Use format like "Grade 10" or "Grade 6A"'
```

### Composite Validators

Validate entire records at once:

```dart
// Validate student
List<String> errors = InputValidator.validateStudent(
  fullName: 'John Doe',
  studentId: 'STU001',
  batch: '2024A',
  dateOfBirth: '2008-05-15',
  phone: '0771234567',
);

if (errors.isNotEmpty) {
  // Show all errors to user
  for (final error in errors) {
    print('Error: $error');
  }
} else {
  // All validations passed
}

// Validate teacher
List<String> errors = InputValidator.validateTeacher(
  fullName: 'Jane Smith',
  email: 'jane@school.com',
  phone: '0771234567',
  nic: '123456789V',
);

// Validate user account
List<String> errors = InputValidator.validateUserAccount(
  fullName: 'Admin User',
  username: 'admin.user',
  password: 'SecurePass123!',
  role: 'admin',
);
```

## 🛡️ Using InputSanitizer

Sanitize inputs before storing in database:

```dart
import 'package:damma_school_management_system/core/utils/validators.dart';

// Generic text sanitization (trim, remove null bytes, normalize spaces)
String sanitized = InputSanitizer.sanitizeText('  John   Doe  ');
// Returns: 'John Doe'

// Sanitize numeric input
String sanitized = InputSanitizer.sanitizeNumeric('0771-234-567');
// Returns: '0771234567'

// Sanitize phone (keep digits and +)
String sanitized = InputSanitizer.sanitizePhone('+94 77 123 4567');
// Returns: '+94771234567'

// Sanitize email (lowercase and trim)
String sanitized = InputSanitizer.sanitizeEmail('  JOHN@EXAMPLE.COM  ');
// Returns: 'john@example.com'

// Sanitize username (lowercase and remove invalid chars)
String sanitized = InputSanitizer.sanitizeUsername('John.Doe@2024');
// Returns: 'john.doe2024' (@ removed)

// Sanitize for database search (escape SQL wildcards)
String sanitized = InputSanitizer.sanitizeForSearch('100%_match');
// Returns: '100\\%\\_match'

// Limit text length
String limited = InputSanitizer.limitLength('Very long text...', 10);
// Returns: 'Very long '
```

## ✨ Extension Methods (Convenient Syntax)

Use extension methods for cleaner code:

```dart
// String extensions
String email = '  JOHN@EXAMPLE.COM  '.sanitized;
// Returns: 'john@example.com'

String? error = 'john.doe'.validateUsername();
// Returns: null (valid)

String? error = 'weak'.validatePassword();
// Returns: 'Password must be at least 8 characters'

String? error = 'john@example.com'.validateEmail();
// Returns: null (valid)
```

## 🏗️ Integration Patterns

### Pattern 1: Form Validation (UI)

```dart
class CreateStudentPageState extends State<CreateStudentPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
            validator: (value) => InputValidator.textLength(
              value,
              minLength: 2,
              maxLength: 150,
              fieldName: 'Full Name',
            ),
          ),
          TextFormField(
            controller: _idController,
            decoration: const InputDecoration(labelText: 'Student ID'),
            validator: (value) => InputValidator.requiredText(
              value,
              fieldName: 'Student ID',
            ),
          ),
          ElevatedButton(
            onPressed: _handleSubmit,
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validation passed, now sanitize and save
    final sanitizedName = InputSanitizer.sanitizeText(_nameController.text);
    final sanitizedId = InputSanitizer.sanitizeText(_idController.text);
    
    await _repository.createStudent(
      widget.database,
      fullName: sanitizedName,
      studentId: sanitizedId,
    );
  }
}
```

### Pattern 2: Repository Validation (Data Layer)

```dart
class StudentRepository {
  Future<void> createStudent(
    Database db, {
    required String fullName,
    required String studentId,
    required String batch,
  }) async {
    // Validate
    final errors = InputValidator.validateStudent(
      fullName: fullName,
      studentId: studentId,
      batch: batch,
    );
    
    if (errors.isNotEmpty) {
      throw ValidationError(
        field: 'student',
        message: errors.join('; '),
      );
    }
    
    // Sanitize before storage
    final sanitizedName = InputSanitizer.sanitizeText(fullName);
    final sanitizedId = InputSanitizer.sanitizeText(studentId);
    
    await db.insert('students', {
      'full_name': sanitizedName,
      'student_id': sanitizedId,
      'batch': batch,
    });
  }
}
```

### Pattern 3: Comprehensive Validation Flow

```dart
Future<void> createUserAccount({
  required String fullName,
  required String username,
  required String password,
  required String role,
}) async {
  // Step 1: Validate all inputs
  final errors = InputValidator.validateUserAccount(
    fullName: fullName,
    username: username,
    password: password,
    role: role,
  );
  
  if (errors.isNotEmpty) {
    throw ValidationError(field: 'user', message: errors.join('; '));
  }
  
  // Step 2: Sanitize inputs
  final sanitizedName = InputSanitizer.sanitizeText(fullName);
  final sanitizedUsername = InputSanitizer.sanitizeUsername(username);
  
  // Step 3: Check for duplicates (only after validation)
  final existing = await db.query(
    'users',
    where: 'username = ?',
    whereArgs: [sanitizedUsername],
  );
  
  if (existing.isNotEmpty) {
    throw StateError('Username already exists');
  }
  
  // Step 4: Hash password and store
  final passwordHash = await _hashPassword(password);
  
  await db.insert('users', {
    'full_name': sanitizedName,
    'username': sanitizedUsername,
    'password_hash': passwordHash,
    'role': role,
    'status': 'active',
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });
}
```

## ⚠️ Common Security Mistakes to Avoid

```dart
// ❌ DON'T: Skip validation
await db.insert('students', {
  'full_name': userInput,  // Direct user input!
  'email': emailInput,      // No sanitization!
});

// ✅ DO: Validate and sanitize
final errors = InputValidator.validateStudent(
  fullName: userInput,
  studentId: studentInput,
  batch: batchInput,
);
if (errors.isNotEmpty) throw ValidationError(field: 'student', message: errors.join('; '));

final sanitizedName = InputSanitizer.sanitizeText(userInput);
await db.insert('students', {
  'full_name': sanitizedName,
  'student_id': InputSanitizer.sanitizeText(studentInput),
});

// ❌ DON'T: Use string interpolation for database queries
await db.rawQuery('SELECT * FROM students WHERE name = "$userInput"');  // SQL injection!

// ✅ DO: Use parameterized queries
await db.query(
  'students',
  where: 'name = ?',
  whereArgs: [userInput],
);

// ❌ DON'T: Trust any input for search
await db.query(
  'students',
  where: 'name LIKE "%$userInput%"',  // SQL injection possible
);

// ✅ DO: Sanitize search input
final sanitized = InputSanitizer.sanitizeForSearch(userInput);
await db.query(
  'students',
  where: 'name LIKE ?',
  whereArgs: ['%$sanitized%'],
);
```

## 🧪 Testing Validators

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:damma_school_management_system/core/utils/validators.dart';

void main() {
  group('InputValidator', () {
    test('accepts valid email', () {
      expect(InputValidator.email('test@example.com'), isNull);
    });
    
    test('rejects invalid email', () {
      expect(InputValidator.email('invalid.email'), isNotNull);
    });
    
    test('validates student record', () {
      final errors = InputValidator.validateStudent(
        fullName: 'John Doe',
        studentId: 'STU001',
        batch: '2024A',
      );
      expect(errors, isEmpty);
    });
    
    test('detects validation errors', () {
      final errors = InputValidator.validateStudent(
        fullName: '',  // Invalid: empty
        studentId: 'STU001',
        batch: '2024A',
      );
      expect(errors, isNotEmpty);
    });
  });
  
  group('InputSanitizer', () {
    test('trims and normalizes spaces', () {
      expect(
        InputSanitizer.sanitizeText('  John   Doe  '),
        equals('John Doe'),
      );
    });
    
    test('lowercases email', () {
      expect(
        InputSanitizer.sanitizeEmail('JOHN@EXAMPLE.COM'),
        equals('john@example.com'),
      );
    });
  });
}
```

## 📋 Validation Checklist

When implementing a new feature, ensure:

- [ ] All user inputs are validated
- [ ] Validation errors are shown to user
- [ ] Inputs are sanitized before database storage
- [ ] Parameterized queries are used (not string interpolation)
- [ ] Search inputs are properly escaped
- [ ] Sensitive data like passwords use strong validation
- [ ] Date fields are validated for reasonable values
- [ ] Email/phone are validated with regex
- [ ] Tests include validation and sanitization
- [ ] Documentation explains validation rules

## 📚 Related Files

- [validators.dart](validators.dart) - Main implementation
- [app_validators.dart](app_validators.dart) - Legacy validators (consider migrating)
- [base_repository.dart](../../../providers/base_repository.dart) - Repository patterns
