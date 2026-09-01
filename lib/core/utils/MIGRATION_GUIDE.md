# Input Validation Integration Guide

This guide shows how to integrate the new validation system into your existing repositories and pages.

## 🎯 Step-by-Step Migration

### Step 1: Update Imports

Add validation imports to your repository files:

```dart
import 'package:damma_school_management_system/core/utils/validators.dart';
```

### Step 2: Add Validation to Create Methods

**Before:**
```dart
Future<void> createStudent(Database db, String fullName, String studentId) async {
  if (fullName.isEmpty) throw ArgumentError('Name required');
  
  await db.insert('students', {
    'full_name': fullName.trim(),
    'student_id': studentId,
  });
}
```

**After:**
```dart
Future<void> createStudent(
  Database db,
  String userId, {
  required String fullName,
  required String studentId,
  required String batch,
}) async {
  // Step 1: Validate
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
  
  // Step 2: Sanitize
  final sanitizedName = InputSanitizer.sanitizeText(fullName);
  final sanitizedId = InputSanitizer.sanitizeText(studentId);
  
  // Step 3: Check duplicates
  final existing = await db.query(
    'students',
    where: 'student_id = ?',
    whereArgs: [sanitizedId],
    limit: 1,
  );
  
  if (existing.isNotEmpty) {
    throw StateError('Student ID already exists');
  }
  
  // Step 4: Insert
  await db.insert('students', {
    'full_name': sanitizedName,
    'student_id': sanitizedId,
    'batch': batch,
    'created_at': DateTime.now().toUtc().toIso8601String(),
  });
  
  // Step 5: Audit log
  await logActivity(
    db: db,
    userId: userId,
    action: 'created',
    module: 'students',
    description: 'Created student: $sanitizedName',
  );
}
```

### Step 3: Add Validation to Update Methods

```dart
Future<void> updateStudent(
  Database db,
  String userId, {
  required int studentId,
  String? fullName,
  String? batch,
}) async {
  // Validate only provided fields
  if (fullName != null) {
    final error = InputValidator.textLength(
      fullName,
      minLength: 2,
      maxLength: 150,
      fieldName: 'Full Name',
    );
    if (error != null) {
      throw ValidationError(field: 'fullName', message: error);
    }
  }
  
  // Build update map
  final updateMap = <String, Object?>{
    'updated_at': DateTime.now().toUtc().toIso8601String(),
  };
  
  if (fullName != null) {
    updateMap['full_name'] = InputSanitizer.sanitizeText(fullName);
  }
  if (batch != null) {
    updateMap['batch'] = batch;
  }
  
  await db.update(
    'students',
    updateMap,
    where: 'id = ?',
    whereArgs: [studentId],
  );
  
  await logActivity(
    db: db,
    userId: userId,
    action: 'updated',
    module: 'students',
    description: 'Updated student record',
  );
}
```

### Step 4: Update Search Methods

**Before:**
```dart
Future<List<Student>> search(Database db, String query) async {
  return db.query(
    'students',
    where: 'full_name LIKE "%$query%"',  // ❌ SQL Injection risk!
  );
}
```

**After:**
```dart
Future<List<Student>> search(Database db, String? query) async {
  final conditions = <String>[];
  final args = <Object?>[];
  
  if (query != null && query.isNotEmpty) {
    // Sanitize search input
    final sanitized = InputSanitizer.sanitizeForSearch(query);
    conditions.add('full_name LIKE ?');
    args.add('%$sanitized%');
  }
  
  final whereClause = conditions.isEmpty 
      ? '' 
      : 'WHERE ${conditions.join(" AND ")}';
  
  final results = await db.rawQuery(
    'SELECT * FROM students $whereClause ORDER BY full_name COLLATE NOCASE',
    args,
  );
  
  return results.map((r) => Student.fromJson(r)).toList();
}
```

### Step 5: Update Form Validators

**Before:**
```dart
TextFormField(
  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
),
```

**After:**
```dart
TextFormField(
  decoration: const InputDecoration(labelText: 'Email'),
  validator: (value) => InputValidator.email(value),
  onChanged: (value) {
    // Real-time validation feedback
  },
),

TextFormField(
  decoration: const InputDecoration(labelText: 'Phone'),
  validator: (value) => InputValidator.phone(value),
  inputFormatters: [
    // Auto-format phone number
  ],
),

TextFormField(
  decoration: const InputDecoration(labelText: 'Password'),
  validator: (value) => InputValidator.password(value),
  obscureText: true,
),
```

## 📋 Repository Migration Checklist

When migrating a repository, ensure:

- [ ] Add validation imports
- [ ] Add ValidationError exception handling
- [ ] Validate ALL inputs in create methods
- [ ] Validate optional fields in update methods
- [ ] Sanitize before database insert
- [ ] Use parameterized queries (not string interpolation)
- [ ] Sanitize search inputs
- [ ] Check for duplicates after sanitization
- [ ] Add audit logging
- [ ] Update tests with validation examples

## 🧪 Testing Your Changes

```dart
// test/student_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:damma_school_management_system/core/utils/validators.dart';

void main() {
  test('rejects invalid student data', () async {
    final repository = StudentRepository();
    final db = /* in-memory database */;
    
    expect(
      () => repository.createStudent(
        db,
        '1',
        fullName: '',  // Invalid: empty
        studentId: 'STU001',
        batch: '2024A',
      ),
      throwsA(isA<ValidationError>()),
    );
  });
  
  test('sanitizes student input', () async {
    final repository = StudentRepository();
    final db = /* in-memory database */;
    
    await repository.createStudent(
      db,
      '1',
      fullName: '  John   Doe  ',  // Extra spaces
      studentId: 'STU001',
      batch: '2024A',
    );
    
    final result = await db.query('students', limit: 1);
    expect(result.first['full_name'], 'John Doe');  // Normalized
  });
}
```

## 🔍 Validation Priority Order

When validating complex records, follow this order:

1. **Required fields** - Check if mandatory fields are provided
2. **Format validation** - Check if format is correct (email, phone, etc.)
3. **Business rules** - Check domain-specific rules (age range, batch exists, etc.)
4. **Duplicates** - Check for existing records (only after sanitization)
5. **Constraints** - Check database constraints (foreign keys, unique, etc.)

```dart
// Example: Correct order
Future<void> createTeacher(Database db, {required String email, required String nic}) async {
  // 1. Required
  if (email.isEmpty) throw ValidationError(field: 'email', message: 'Required');
  
  // 2. Format
  if (!email.contains('@')) throw ValidationError(field: 'email', message: 'Invalid format');
  
  // 3. Business rules
  if (email.length > 254) throw ValidationError(field: 'email', message: 'Too long');
  
  // 4. Duplicates (after sanitization)
  final sanitized = InputSanitizer.sanitizeEmail(email);
  final existing = await db.query('teachers', where: 'email = ?', whereArgs: [sanitized]);
  if (existing.isNotEmpty) throw ValidationError(field: 'email', message: 'Already exists');
  
  // 5. Insert
  await db.insert('teachers', {'email': sanitized});
}
```

## ⚠️ Common Mistakes to Avoid

```dart
// ❌ Mistake 1: Validating after sanitization in forms
TextFormField(
  validator: (value) => InputValidator.email(
    InputSanitizer.sanitizeEmail(value)  // Wrong: sanitize in display layer
  ),
),

// ✅ Correct: Validate raw input in form, sanitize in repository
TextFormField(
  validator: (value) => InputValidator.email(value),
),
// Then in repository:
final sanitized = InputSanitizer.sanitizeEmail(email);

// ❌ Mistake 2: Forgetting to escape in search
db.rawQuery('SELECT * WHERE name LIKE "%$userInput%"')

// ✅ Correct: Always use parameterized queries or escape
db.query(
  'table',
  where: 'name LIKE ?',
  whereArgs: ['%${InputSanitizer.sanitizeForSearch(userInput)}%'],
)

// ❌ Mistake 3: Only validating required fields
if (phone.isEmpty) throw 'Required';  // Skip format check if empty

// ✅ Correct: Validate format even if optional
if (phone.isNotEmpty && InputValidator.phone(phone) != null) {
  throw ValidationError(field: 'phone', message: 'Invalid format');
}

// ❌ Mistake 4: Losing validation errors
try {
  validate...();
} catch (e) {
  print('Error');  // Don't swallow the error!
}

// ✅ Correct: Propagate validation errors
try {
  validate...();
} catch (e) {
  rethrow;  // Let caller handle it
}
```

## 🚀 Rollout Plan

### Phase 1: Critical Repositories (Week 1)
- `UserRepository` - Handle auth and accounts
- `StudentRepository` - High-volume data
- `TeacherRepository` - High-volume data

### Phase 2: Support Repositories (Week 2)
- `BatchRepository`
- `ExaminationRepository`
- `PastPupilRepository`

### Phase 3: Forms & Pages (Week 3)
- Update all TextFormFields with new validators
- Add real-time validation feedback
- Update error messages

### Phase 4: Testing (Week 4)
- Add comprehensive validation tests
- Update existing tests with new patterns
- Verify all edge cases

## 📚 Related Documentation

- [validators.dart](validators.dart) - Implementation
- [VALIDATORS_GUIDE.md](VALIDATORS_GUIDE.md) - Complete guide
- [VALIDATION_EXAMPLES.dart](VALIDATION_EXAMPLES.dart) - Code examples
- [VALIDATION_QUICK_REF.md](VALIDATION_QUICK_REF.md) - Quick reference

---

**Start with:** [VALIDATORS_GUIDE.md](VALIDATORS_GUIDE.md)  
**Code patterns:** [VALIDATION_EXAMPLES.dart](VALIDATION_EXAMPLES.dart)  
**Quick lookup:** [VALIDATION_QUICK_REF.md](VALIDATION_QUICK_REF.md)
