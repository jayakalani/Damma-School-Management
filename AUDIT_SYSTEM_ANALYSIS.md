# Audit Logging System Analysis

## 1. Core Repository Structure

### File: [lib/core/audit/audit_log_repository.dart](lib/core/audit/audit_log_repository.dart)

**Key Methods:**

- **`record()`** - Main method to create audit log entries
  - Validates user is active before logging
  - Stores: `user_id`, `action`, `module`, `entity_type`, `entity_id`, `description`, `created_at`
  - Uses UTC ISO 8601 timestamps

- **`listForAdmin()`** - Retrieves audit logs with admin-only access
  - Full-text search across username, full_name, action, module, description
  - Filters by: userId, module, date range (startDate/endDate)
  - Joins with users table to get actor details
  - Returns sorted by created_at DESC, id DESC

- **`listUsersForFilter()`** - Gets users for audit log filtering (admin only)

- **`listModulesForFilter()`** - Gets distinct modules from audit logs (admin only)

- **`logActivity()`** - Adapter method that parses userId string and calls `record()`

**Access Control:**
- `_requireAdmin()` ensures only active admins can view audit logs
- Throws `StateError` if non-admin attempts access
- Audit log creation requires active user status

---

## 2. Database Schema

### Audit Logs Table (from [lib/core/database/database_schema.dart](lib/core/database/database_schema.dart))

```sql
CREATE TABLE audit_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  module TEXT NOT NULL,
  entity_type TEXT,
  entity_id INTEGER,
  description TEXT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE
)
```

**Indexes Created:**
```sql
CREATE INDEX idx_audit_logs_user ON audit_logs(user_id)
CREATE INDEX idx_audit_logs_created ON audit_logs(created_at)
```

**Field Purposes:**
| Field | Type | Purpose |
|-------|------|---------|
| id | INTEGER | Primary key |
| user_id | INTEGER | FK to users table (who performed action) |
| action | TEXT | Action type (e.g., 'created', 'updated', 'deleted') |
| module | TEXT | Feature module (e.g., 'students', 'teachers', 'batch_management') |
| entity_type | TEXT | Type of resource affected (optional) |
| entity_id | INTEGER | ID of affected resource (optional) |
| description | TEXT | Human-readable description of action |
| created_at | TEXT | UTC ISO 8601 timestamp |

---

## 3. Audit Logging Calls Throughout Codebase

### A. User Management ([lib/core/users/user_repository.dart](lib/core/users/user_repository.dart))
```dart
// Staff creation
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.staffCreated,
  module: 'staff_management',
  entityType: 'user',
  entityId: staffId,
  description: 'Admin created staff member ${username.trim()}.',
);

// Staff update
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.staffUpdated,
  module: 'staff_management',
  entityType: 'user',
  entityId: staffId,
  description: 'Admin updated staff member ${username.trim()}.',
);

// Status changes
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.staffStatusChanged,
  module: 'staff_management',
  entityType: 'user',
  entityId: staffId,
  description: 'Admin ${active ? 'activated' : 'deactivated'} staff member.',
);

// Password resets
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.staffPasswordReset,
  module: 'staff_management',
  entityType: 'user',
  entityId: staffId,
  description: 'Admin reset staff member password.',
);
```

### B. Teacher Management ([lib/core/teachers/teacher_repository.dart](lib/core/teachers/teacher_repository.dart))
```dart
// Teacher creation
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.teacherCreated,
  module: 'teacher_management',
  entityType: 'teacher',
  entityId: teacherId,
  description: 'Admin created teacher ${details['full_name']}.',
);

// Teacher update
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.teacherUpdated,
  module: 'teacher_management',
  entityType: 'teacher',
  entityId: teacherId,
  description: 'Admin updated teacher ${details['full_name']}.',
);
```

### C. Student Management ([lib/core/students/student_repository.dart](lib/core/students/student_repository.dart))
```dart
// Student creation
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.studentAdded,
  module: 'student_management',
  entityType: 'student',
  entityId: id,
  description: 'Admin registered student ${details['full_name']}.',
);

// Student update
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.studentUpdated,
  module: 'student_management',
  entityType: 'student',
  entityId: studentId,
  description: 'Admin updated student ${details['full_name']}.',
);

// Batch management
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.studentAdded,
  module: 'batch_management',
  entityType: 'student',
  entityId: studentId,
  description: 'Admin added student to batch.',
);

// Conversion to past pupil
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.studentPastPupil,
  module: 'student_management',
  entityType: 'student',
  entityId: studentId,
  description: 'Admin converted student to past pupil.',
);

// Bulk conversion
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.studentsBulkPastPupil,
  module: 'student_management',
  entityType: 'batch',
  entityId: batchId,
  description: 'Admin converted $count current batch students to past pupils.',
);
```

### D. Batch Management ([lib/core/batches/batch_repository.dart](lib/core/batches/batch_repository.dart))
```dart
// Batch creation
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.batchCreated,
  module: 'batch_management',
  entityType: 'batch',
  entityId: batchId,
  description: 'Admin created batch ${name.trim()}.',
);
```

### E. Examination Management ([lib/core/examinations/examination_repository.dart](lib/core/examinations/examination_repository.dart))
```dart
// Examination creation
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.examinationCreated,
  module: 'examination_management',
  entityType: 'examination',
  entityId: id,
  description: 'Admin created examination ${name.trim()}.',
);

// Exam results update
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.examinationResultsUpdated,
  module: 'examination_management',
  entityType: 'examination',
  entityId: examinationId,
  description: 'Admin updated examination marks and attendance.',
);
```

### F. Past Pupils Management ([lib/core/past_pupils/past_pupil_repository.dart](lib/core/past_pupils/past_pupil_repository.dart))
```dart
// Past pupil batch creation
await _auditLogs.record(
  database: transaction,
  userId: adminId,
  action: AuditActions.pastPupilBatchCreated,
  module: 'past_pupil_management',
  entityType: 'past_pupil_batch',
  entityId: id,
  description: 'Admin created legacy past pupil batch ${name.trim()}.',
);
```

### G. Backup Operations ([lib/core/backup/backup_service_io.dart](lib/core/backup/backup_service_io.dart))
```dart
// Backup creation
await _auditLogs.record(
  database: database,
  userId: adminId,
  action: AuditActions.backupCreated,
  module: 'backup_management',
  entityType: 'database',
  description: 'User created a database backup.',
);
```

### H. Alternative Logging via BaseRepository ([lib/providers/base_repository.dart](lib/providers/base_repository.dart))
```dart
// Direct insert method (used in some repositories)
final auditLog = {
  'user_id': int.parse(userId),
  'action': action,
  'module': module,
  'description': description,
  'created_at': DateTime.now().toUtc().toIso8601String(),
};
await db.insert('audit_logs', auditLog);
```

---

## 4. Sensitive Fields Identified

### In Users Table
- **password_hash** - Hashed passwords using PBKDF2-SHA256 (NOT plaintext)
- username - Could be sensitive for privacy
- full_name - PII
- role - Access level information
- status - Account status

### In Teachers Table
- **bank_account_number** - CRITICAL: Banking information
- **bank_name** - Banking information
- **bank_branch** - Banking information
- nic - National ID (personal identifier)
- phone_number - Contact information (PII)
- address - Address information (PII)
- date_of_birth - Personal information

### In Students Table
- **nic** - National ID (personal identifier) - CRITICAL PII
- **phone_number** - Contact information
- **address** - Address information
- **date_of_birth** - Personal information
- full_name - Name (PII)

### In Exam Results
- marks - Could be sensitive student performance data
- attendance_status - Student attendance pattern

### In Audit Logs
- **description field** - May contain sensitive information about WHAT was changed
  - Example: "Admin updated student John Doe" exposes student name
  - Example: "Admin updated teacher bank account" exposes sensitive operations

---

## 5. Existing Encryption & Security Utilities

### A. Password Hashing: [lib/core/security/password_hasher.dart](lib/core/security/password_hasher.dart)

```dart
class PasswordHasher {
  const PasswordHasher({this.iterations = 210000, this.saltLength = 16});

  static const _algorithm = 'pbkdf2_sha256';
  final int iterations;
  final int saltLength;

  String hash(String password) {
    final salt = List<int>.generate(
      saltLength,
      (_) => Random.secure().nextInt(256),
    );
    final derivedKey = _deriveKey(utf8.encode(password), salt, iterations);
    return [
      _algorithm,
      iterations.toString(),
      base64Url.encode(salt),
      base64Url.encode(derivedKey),
    ].join(r'$');
  }

  bool verify(String password, String encodedHash) {
    // Constant-time comparison to prevent timing attacks
    return _constantTimeEquals(actual, expected);
  }
}
```

**Security Features:**
- ✅ PBKDF2-SHA256 with 210,000 iterations (strong)
- ✅ 16-byte random salt per password
- ✅ Constant-time comparison (`_constantTimeEquals()`)
- ✅ Passwords never stored plaintext
- ✅ Format includes algorithm, iterations, salt, and derived key

### B. Authentication Service: [lib/core/services/auth_service.dart](lib/core/services/auth_service.dart)

**Security Controls:**
```dart
// Active user check
if (user.status != 'active') {
  throw const AuthenticationException(
    'Your account is inactive. Please contact the administrator.',
  );
}

// Role validation
if (user.role != 'admin' && user.role != 'staff') {
  throw const AuthenticationException('Invalid username or password.');
}

// Password verification
if (!_passwordHasher.verify(password, user.passwordHash)) {
  throw const AuthenticationException('Invalid username or password.');
}
```

**Access Control:**
- Role-based authorization checks (`canAccess(role:)`, `requireRole()`)
- Session management with `AuthSession` class
- In-memory session storage (cleared on logout)

### C. Database-Level Constraints

**Foreign Key Enforcement:**
```sql
FOREIGN KEY (user_id) REFERENCES users(id) 
  ON DELETE RESTRICT ON UPDATE CASCADE
```
Prevents orphaned audit records and maintains referential integrity

**Check Constraints:**
- Users: `role IN ('admin', 'staff')`
- Users: `status IN ('active', 'inactive')`
- Teachers: `status IN ('active', 'inactive')`
- Students: `status IN ('student', 'past_pupil')`

---

## 6. Security Findings & Observations

### ✅ Strengths
1. **Strong Password Hashing** - PBKDF2-SHA256 with 210k iterations
2. **Admin-Only Access** - Audit log viewing restricted to active admins
3. **Transaction Support** - Audit logs created within transactions
4. **Comprehensive Tracking** - All critical operations logged
5. **Constant-Time Comparison** - Protects against timing attacks
6. **UTC Timestamps** - Standardized timestamp format

### ⚠️ Potential Concerns

1. **Audit Log Descriptions May Contain PII**
   - Names are logged in descriptions (e.g., "Admin registered student John Doe")
   - Bank account operations are logged (e.g., "Admin updated teacher bank account")
   - **Recommendation**: Redact or hash sensitive data in descriptions

2. **No Encryption at Rest**
   - Sensitive fields (NIC, phone, address, bank info) stored as plaintext TEXT
   - Audit logs stored plaintext (including descriptions mentioning sensitive operations)
   - **Recommendation**: Encrypt sensitive fields using database encryption or field-level encryption

3. **No Audit Log Immutability**
   - Audit logs can theoretically be deleted via ON DELETE RESTRICT (only prevents orphaning)
   - No write-once/append-only mechanism
   - **Recommendation**: Add audit log archival and tamper-detection

4. **Limited Audit Detail**
   - No "before/after" values captured for data changes
   - No IP address or session tracking
   - No failed operation attempts logged
   - **Recommendation**: Enhanced audit trail with change tracking

5. **Session Token Storage**
   - In-memory sessions not persisted (good for security, but lost on crash)
   - No token expiration mechanism
   - **Recommendation**: Add session timeout and refresh mechanism

---

## 7. AuditLog Model: [lib/models/database_models.dart](lib/models/database_models.dart)

```dart
class AuditLog {
  const AuditLog({
    this.id,
    required this.userId,
    required this.action,
    required this.module,
    this.entityType,
    this.entityId,
    required this.description,
    required this.createdAt,
  });
  
  final int? id, userId, entityId;
  final String action, module, description, createdAt;
  final String? entityType;

  factory AuditLog.fromMap(Map<String, Object?> m) => AuditLog(
    id: m['id'] as int?,
    userId: m['user_id']! as int,
    action: m['action']! as String,
    module: m['module']! as String,
    entityType: m['entity_type'] as String?,
    entityId: m['entity_id'] as int?,
    description: m['description']! as String,
    createdAt: m['created_at']! as String,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'user_id': userId,
    'action': action,
    'module': module,
    'entity_type': entityType,
    'entity_id': entityId,
    'description': description,
    'created_at': createdAt,
  };
}
```

---

## 8. Audit UI: [lib/features/admin/audit_logs_page.dart](lib/features/admin/audit_logs_page.dart)

**Filtering Capabilities:**
- Free-text search (username, full_name, action, module, description)
- Filter by actor (user)
- Filter by module
- Filter by date range (from/to)
- Clear filters button

**Display:**
- DataTable showing: Date/Time, User, Action, Module, Description
- Sorted by created_at DESC, then id DESC
- Admin-only access enforced

---

## Summary Table

| Component | Location | Security Level | Notes |
|-----------|----------|-----------------|-------|
| Audit Repository | `lib/core/audit/audit_log_repository.dart` | ✅ Good | Admin access control enforced |
| Password Hashing | `lib/core/security/password_hasher.dart` | ✅ Excellent | PBKDF2-SHA256, 210k iterations |
| Auth Service | `lib/core/services/auth_service.dart` | ✅ Good | Status & role checks implemented |
| Audit UI | `lib/features/admin/audit_logs_page.dart` | ✅ Good | Admin-only access |
| Data Encryption | ❌ None | ⚠️ Concern | Sensitive fields stored plaintext |
| Audit Immutability | ❌ None | ⚠️ Concern | No append-only mechanism |
| Change Tracking | ❌ Partial | ⚠️ Concern | No before/after values |
