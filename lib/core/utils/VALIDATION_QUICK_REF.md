# Input Validation - Quick Reference Card

## 📁 Files Created

| File | Purpose |
|------|---------|
| [validators.dart](validators.dart) | Main validation & sanitization implementation |
| [VALIDATORS_GUIDE.md](VALIDATORS_GUIDE.md) | Complete usage guide with examples |
| [VALIDATION_EXAMPLES.dart](VALIDATION_EXAMPLES.dart) | Repository & page examples |

## ⚡ 60-Second Quickstart

### Validate User Input
```dart
import 'package:damma_school_management_system/core/utils/validators.dart';

// In form validator
TextFormField(
  validator: (value) => InputValidator.requiredText(value, fieldName: 'Name'),
),

// Batch validate entire record
List<String> errors = InputValidator.validateStudent(
  fullName: nameValue,
  studentId: idValue,
  batch: batchValue,
);
```

### Sanitize Before Storage
```dart
// Sanitize text
String safe = InputSanitizer.sanitizeText(userInput);

// Before database insert
await db.insert('students', {
  'full_name': InputSanitizer.sanitizeText(fullName),
  'student_id': InputSanitizer.sanitizeText(studentId),
  'phone': InputSanitizer.sanitizePhone(phoneInput),
  'email': InputSanitizer.sanitizeEmail(emailInput),
});
```

## 📋 Validator Reference

| Validator | Usage | Example |
|-----------|-------|---------|
| `requiredText()` | Non-empty text | `requiredText('John', 'Name')` |
| `textLength()` | Min/max length | `textLength(val, min:2, max:50)` |
| `email()` | Email format | `email('john@example.com')` |
| `phone()` | Phone number | `phone('0771234567')` |
| `nic()` | NIC (Sri Lanka) | `nic('123456789V')` |
| `dateOfBirth()` | Date in past | `dateOfBirth('2000-05-15')` |
| `password()` | Strong password | `password('Secure123!')` |
| `username()` | Valid username | `username('john.doe_123')` |
| `batchName()` | Batch ID | `batchName('2024A')` |
| `grade()` | Grade format | `grade('Grade 10')` |

## 🛡️ Sanitizer Reference

| Sanitizer | Purpose | Example |
|-----------|---------|---------|
| `sanitizeText()` | Generic cleanup | Trims, normalizes spaces |
| `sanitizePhone()` | Phone numbers | Keep digits + |
| `sanitizeEmail()` | Emails | Lowercase, trim |
| `sanitizeUsername()` | Usernames | Lowercase, remove invalid |
| `sanitizeForSearch()` | Search queries | Escape SQL wildcards |
| `sanitizeNumeric()` | Numbers only | Keep 0-9 |
| `limitLength()` | Max length | Truncate safely |

## 🔗 Integration Pattern

```dart
// Step 1: Validate
List<String> errors = InputValidator.validateStudent(...);
if (errors.isNotEmpty) throw ValidationError(...);

// Step 2: Sanitize
final sanitized = InputSanitizer.sanitizeText(userInput);

// Step 3: Store
await db.insert('table', {'field': sanitized});
```

## ✨ Extension Methods (Shorter Syntax)

```dart
// Instead of:
InputValidator.validateEmail(email)

// Use:
email.validateEmail()
textValue.sanitized
username.validateUsername()
```

## 📊 Composite Validators (Entire Records)

```dart
// Validate student record
InputValidator.validateStudent(
  fullName: name,
  studentId: id,
  batch: batch,
  dateOfBirth: dob,
  phone: phone,
)

// Validate teacher record
InputValidator.validateTeacher(
  fullName: name,
  email: email,
  phone: phone,
  nic: nic,
)

// Validate user account
InputValidator.validateUserAccount(
  fullName: name,
  username: username,
  password: password,
  role: role,
)
```

## ❌ Security: What NOT to Do

```dart
// ❌ Skip validation
await db.insert('students', {'name': userInput});

// ❌ String interpolation in SQL
db.rawQuery("SELECT * WHERE name = '$userInput'")

// ❌ Unescaped search
db.query('table', where: "name LIKE '%$input%'")

// ❌ Trust frontend only
// Always validate on backend too!

// ❌ Store passwords unencrypted
await db.insert('users', {'password': plaintext})
```

## ✅ Security: What TO Do

```dart
// ✅ Validate first
List<String> errors = InputValidator.validate...();
if (errors.isNotEmpty) throw ValidationError(...);

// ✅ Sanitize before storage
final safe = InputSanitizer.sanitize...(input);

// ✅ Use parameterized queries
db.query('table', where: 'name = ?', whereArgs: [userInput])

// ✅ Validate on both frontend AND backend

// ✅ Hash passwords
final hash = await hashPassword(password);
```

## 🧪 Testing Example

```dart
test('validates required field', () {
  expect(
    InputValidator.requiredText('', fieldName: 'Name'),
    isNotNull,  // Should have error
  );
});

test('accepts valid email', () {
  expect(
    InputValidator.email('test@example.com'),
    isNull,  // No error
  );
});
```

## 📚 More Information

See [VALIDATORS_GUIDE.md](VALIDATORS_GUIDE.md) for:
- Complete API documentation
- Integration patterns
- Error handling
- Form validation examples
- Repository validation examples
- Security best practices
- Common mistakes to avoid

See [VALIDATION_EXAMPLES.dart](VALIDATION_EXAMPLES.dart) for:
- Real-world repository example
- Form implementation example
- Service layer example
- Error handling example

## 🚀 Next Steps

1. **Review** [validators.dart](validators.dart) implementation
2. **Read** [VALIDATORS_GUIDE.md](VALIDATORS_GUIDE.md) for patterns
3. **Integrate** validation in existing repositories
4. **Add** tests for validation logic
5. **Update** forms to use new validators

---

**Created**: 2026-09-01  
**Files**: validators.dart, VALIDATORS_GUIDE.md, VALIDATION_EXAMPLES.dart
