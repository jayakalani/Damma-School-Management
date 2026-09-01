# System Architecture: Input Validation & Sanitization

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        DAMMA SCHOOL APP                         │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
         ┌──────────▼─────────┐  ┌──────▼──────────────┐
         │  UI Layer (Forms)  │  │  Service Layer     │
         │                    │  │  (Business Logic)  │
         └────────┬───────────┘  └────────┬───────────┘
                  │                       │
        ┌─────────▼───────────┐           │
        │ Form Validation     │           │
        │ (TextFormField)     │           │
        │                     │           │
        │ Uses: InputValidator│           │
        │ - email()           │           │
        │ - phone()           │           │
        │ - requiredText()    │           │
        └─────────┬───────────┘           │
                  │                       │
                  │ ◀─────────────────────┘
                  │
         ┌────────▼──────────────────┐
         │   Repository Layer        │
         │   (Data Access)           │
         │                           │
         │ 1. Validate              │
         │    InputValidator.validate│
         │                           │
         │ 2. Sanitize              │
         │    InputSanitizer.sanitize
         │                           │
         │ 3. Check Duplicates      │
         │    (after sanitization)  │
         │                           │
         │ 4. Store in Database     │
         │    db.insert(...)        │
         │                           │
         │ 5. Audit Log             │
         │    logActivity(...)      │
         └────────┬──────────────────┘
                  │
         ┌────────▼──────────────────┐
         │    SQLite Database        │
         │                           │
         │ - Sanitized data stored  │
         │ - Audit trail logged     │
         └───────────────────────────┘
```

## 📊 Validation Flow

```
User Input
    │
    ▼
┌─────────────────────────┐
│ Frontend Validation     │  ◀─── InputValidator
│ (Form Field Validator)  │      • email()
└──────────┬──────────────┘      • phone()
           │                      • textLength()
           │ (If valid)           • dateOfBirth()
           ▼
┌─────────────────────────┐
│ Send to Backend/Service │
└──────────┬──────────────┘
           │
           ▼
┌─────────────────────────┐
│ Backend Validation      │  ◀─── InputValidator
│ (Repository Level)      │      • Comprehensive
└──────────┬──────────────┘      • Format checks
           │                      • Business rules
           │ (If valid)           • Duplicate checks
           ▼
┌─────────────────────────┐
│ Input Sanitization      │  ◀─── InputSanitizer
│ Before Storage          │      • sanitizeText()
└──────────┬──────────────┘      • sanitizeEmail()
           │                      • sanitizePhone()
           │ (Sanitized)          • sanitizeForSearch()
           ▼
┌─────────────────────────┐
│ Check Constraints       │
│ (Duplicates, etc)       │
└──────────┬──────────────┘
           │
           │ (If passes)
           ▼
┌─────────────────────────┐
│ Store in Database       │  ◀─── SQLite
│ Log Audit Trail         │
└─────────────────────────┘
```

## 🔄 Data Flow: Create Student Example

```
1. USER ENTERS DATA IN FORM
┌─────────────────────────┐
│ Name: "  John Doe  "    │
│ ID: "STU-001"           │
│ Batch: "2024A"          │
│ Phone: "077-1234567"    │
└─────────────────────────┘
         │
         ▼
2. FORM VALIDATION (UI)
┌─────────────────────────┐
│ InputValidator.textLength()    ✓
│ InputValidator.requiredText()  ✓
│ InputValidator.phone()         ✓
└─────────────────────────┘
         │ ✓ Passes
         ▼
3. REPOSITORY VALIDATION
┌─────────────────────────┐
│ InputValidator.validateStudent()
│ • fullName: "John Doe" ✓
│ • studentId: "STU-001" ✓
│ • batch: "2024A" ✓
│ • phone: "077-1234567" ✓
└─────────────────────────┘
         │ ✓ Passes
         ▼
4. SANITIZATION
┌─────────────────────────┐
│ fullName: "John Doe"           ◀─ trim + normalize spaces
│ studentId: "STU-001"           ◀─ trim
│ phone: "0771234567"            ◀─ keep digits only
└─────────────────────────┘
         │
         ▼
5. DUPLICATE CHECK
┌─────────────────────────┐
│ SELECT FROM students
│ WHERE student_id = ?
│ (using sanitized ID)
│ Result: Empty ✓
└─────────────────────────┘
         │ ✓ Unique
         ▼
6. DATABASE INSERT
┌─────────────────────────┐
│ students table:
│ {
│   full_name: "John Doe",
│   student_id: "STU-001",
│   batch: "2024A",
│   phone: "0771234567",
│   created_at: "2026-09-01T10:30:00Z"
│ }
└─────────────────────────┘
         │
         ▼
7. AUDIT LOG
┌─────────────────────────┐
│ audit_logs table:
│ {
│   user_id: 1,
│   action: "created",
│   module: "students",
│   description: "Created student: John Doe",
│   created_at: "2026-09-01T10:30:00Z"
│ }
└─────────────────────────┘
         │
         ▼
✓ SUCCESS
```

## 🎯 Validation Layers

```
Layer 1: FORM VALIDATION (Real-time Feedback)
┌────────────────────────────────────────┐
│ TextFormField(                         │
│   validator: (value) =>               │
│     InputValidator.email(value)       │
│ )                                      │
│                                        │
│ User sees: "Enter a valid email"      │
└────────────────────────────────────────┘
         │
         ▼
Layer 2: SERVICE VALIDATION (Business Rules)
┌────────────────────────────────────────┐
│ StudentService.registerStudent({      │
│   fullName, studentId, batch           │
│ })                                      │
│                                        │
│ Validates: Complete student record    │
│ Returns: List<ValidationError>         │
└────────────────────────────────────────┘
         │
         ▼
Layer 3: REPOSITORY VALIDATION (Data Integrity)
┌────────────────────────────────────────┐
│ StudentRepository.createStudent({      │
│   fullName, studentId, batch           │
│ })                                      │
│                                        │
│ Validates: Before insert               │
│ Sanitizes: All inputs                  │
│ Checks: Duplicates, constraints        │
└────────────────────────────────────────┘
         │
         ▼
Layer 4: DATABASE VALIDATION (Constraints)
┌────────────────────────────────────────┐
│ students (id PK, student_id UNIQUE)    │
│                                        │
│ Enforces: Data types, uniqueness       │
│ Rejects: Constraint violations         │
└────────────────────────────────────────┘
```

## 🛡️ Security Measures

```
┌─────────────────────────────────────────────────┐
│           INPUT SECURITY STRATEGY               │
└─────────────────────────────────────────────────┘

1. INPUT VALIDATION
   └─ Reject invalid data early
   └─ Format checking (email, phone, NIC)
   └─ Length constraints
   └─ Character whitelist validation

2. INPUT SANITIZATION
   ├─ Trim whitespace
   ├─ Normalize spaces
   ├─ Remove null bytes
   ├─ Lowercase sensitive fields
   └─ Escape SQL wildcards

3. SQL INJECTION PREVENTION
   ├─ Use parameterized queries ✓
   │  db.query('table', where: 'id = ?', whereArgs: [value])
   │
   └─ Avoid string interpolation ✗
      db.rawQuery("SELECT * FROM table WHERE id = '$value'")

4. DUPLICATE PREVENTION
   └─ Check after sanitization (not before)
   └─ Use UNIQUE constraints
   └─ Handle duplicate errors gracefully

5. AUDIT LOGGING
   └─ Log all important operations
   └─ Track who did what when
   └─ Enable security investigations

6. ERROR HANDLING
   └─ Don't expose system details
   └─ Use generic error messages for users
   └─ Log detailed errors for developers
```

## 📝 Validation Decision Tree

```
Is this a USER INPUT?
│
├─ YES ────────────────────────┐
│                              │
│  Is it in a FORM?           │
│  ├─ YES ────► Validate in TextFormField
│  │
│  └─ NO ─────► Validate in Repository
│                (before storage)
│
├─ Form shows error ◄─ real-time feedback
│
├─ Repository throws ValidationError
│                  │
│                  ├─ If from UI ────► Show all errors
│                  │
│                  └─ If from API ───► Log & respond
│
└─ NO ───────────────► No validation needed
```

## 🔀 Integration Points

```
┌─────────────────────┐
│  TextFormField      │
├─────────────────────┤
│ validator: (val) => │
│  InputValidator     │
│  .email(val)        │
└────────┬────────────┘
         │
         ▼
┌─────────────────────────────────────┐
│  Page/Form Handler                  │
├─────────────────────────────────────┤
│ if (!_formKey.currentState!         │
│     .validate()) return;            │
│                                     │
│ // All validations passed           │
│ // Now sanitize & save              │
└────────┬────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────────┐
│  Repository (e.g., StudentRepository)    │
├──────────────────────────────────────────┤
│ Future<void> createStudent({             │
│   required String fullName,              │
│   ...                                    │
│ }) async {                               │
│                                          │
│   // 1. Validate                         │
│   final errors =                         │
│     InputValidator.validateStudent(...) │
│   if (errors.isNotEmpty)                │
│     throw ValidationError(...)          │
│                                          │
│   // 2. Sanitize                         │
│   final safe = InputSanitizer           │
│     .sanitizeText(fullName)              │
│                                          │
│   // 3. Store                            │
│   await db.insert('students', {          │
│     'full_name': safe,                   │
│     ...                                  │
│   });                                    │
│ }                                        │
└──────────────────────────────────────────┘
```

## 📊 Validator Coverage Matrix

```
           │ Text │ Email │ Phone │ NIC │ Date │ Password │ Username │
──────────┼──────┼───────┼───────┼─────┼──────┼──────────┼──────────┤
Required  │  ✓   │   ✓   │   ✓   │  ✓  │  ✓   │    ✓     │    ✓     │
Length    │  ✓   │   ✓   │   ✓   │     │      │    ✓     │    ✓     │
Format    │      │   ✓   │   ✓   │  ✓  │  ✓   │    ✓     │          │
Range     │      │       │       │     │  ✓   │          │          │
Business  │      │       │       │     │  ✓   │    ✓     │    ✓     │
Optional  │  ✓   │   ✓   │   ✓   │  ✓  │  ✓   │          │          │
──────────┴──────┴───────┴───────┴─────┴──────┴──────────┴──────────┘
```

---

**File**: [lib/core/utils/README.md](README.md)  
**Last Updated**: 2026-09-01  
**Status**: ✅ Complete
