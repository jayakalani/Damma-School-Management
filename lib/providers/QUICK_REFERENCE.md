# State Management - Quick Reference

## 📖 Files in This Directory

| File | Purpose |
|------|---------|
| [README.md](README.md) | **START HERE** - Complete architecture overview and patterns |
| [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) | Step-by-step guide for adding new features |
| [auth_service_provider.dart](auth_service_provider.dart) | Global authentication state management |
| [repository_provider.dart](repository_provider.dart) | Factory methods for creating repositories |
| [base_repository.dart](base_repository.dart) | Abstract base class for all repositories |

## 🚀 Quick Start (5 min)

### Creating a New Repository

```dart
// File: lib/core/attendance/attendance_repository.dart

import 'package:sqflite/sqflite.dart';
import 'package:damma_school_management_system/providers/base_repository.dart';

class AttendanceRepository extends BaseRepository {
  Future<List<AttendanceRecord>> listForStudent(
    Database db,
    int studentId,
  ) async {
    validateNonNegative(studentId, 'studentId');
    
    final records = await db.query(
      'attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );
    
    return records.map((r) => AttendanceRecord.fromJson(r)).toList();
  }
}
```

### Creating a New Page

```dart
// File: lib/features/attendance/pages/attendance_page.dart

import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:damma_school_management_system/core/attendance/attendance_repository.dart';

class AttendancePage extends StatefulWidget {
  final Database database;
  final AuthService auth;
  
  const AttendancePage({
    required this.database,
    required this.auth,
  });
  
  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  late final AttendanceRepository _repo = AttendanceRepository();
  List<AttendanceRecord> _records = [];
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _load();
  }
  
  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      _records = await _repo.listForStudent(
        widget.database,
        widget.auth.currentSession!.userId,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(
        children: [
          for (final record in _records) 
            ListTile(title: Text(record.date.toString())),
        ],
      ),
    );
  }
}
```

### Adding Route

```dart
// File: lib/app/routes/app_routes.dart

// In AppRoutes class:
static const attendance = '/attendance';

// In app.dart onGenerateRoute:
case AppRoutes.attendance:
  return MaterialPageRoute(
    builder: (context) => AttendancePage(
      database: database,
      auth: auth,
    ),
  );
```

## 🧪 Testing Quick Ref

```dart
// test/attendance_repository_test.dart

void main() {
  test('lists attendance for student', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    
    // Setup
    final repo = AttendanceRepository();
    await connection.insert('attendance', {
      'student_id': 1,
      'date': '2026-08-31',
      'status': 'present',
    });
    
    // Test
    final records = await repo.listForStudent(connection, 1);
    
    // Assert
    expect(records, isNotEmpty);
    expect(records.first.status, 'present');
    
    await database.close();
  });
}
```

## 🎯 The Three Layers

```
UI Layer
├─ StatefulWidget (manages page state)
├─ Local variables (filters, loading flags)
└─ setState(() => {}) to update

          ↓

Service/Repository Layer
├─ Repository (data access)
├─ Methods: list(), create(), update(), delete()
└─ Input validation & audit logging

          ↓

Data Layer
└─ SQLite Database
```

## ✅ Checklist (New Feature)

- [ ] Create `lib/core/[feature]/[feature]_repository.dart`
  - [ ] Extend `BaseRepository`
  - [ ] Implement CRUD methods
  - [ ] Add validation
  - [ ] Call `logActivity()`

- [ ] Create `lib/features/[feature]/pages/[feature]_page.dart`
  - [ ] Extend `StatefulWidget`
  - [ ] Require `database` + `auth` constructor params
  - [ ] Create repository in `initState()`
  - [ ] Load data in `initState()`
  - [ ] Use `setState()` for updates
  - [ ] Handle errors with SnackBar
  - [ ] Implement `dispose()`

- [ ] Add route to `lib/app/routes/app_routes.dart`

- [ ] Create test in `test/[feature]_repository_test.dart`

## 🚫 Common Mistakes

| ❌ Don't | ✅ Do |
|---------|------|
| Direct DB access in UI | Use repository methods |
| Global mutable state | Pass via constructor |
| Forget to dispose | `dispose()` in State |
| No error handling | Try/catch + SnackBar |
| No input validation | Validate in repository |
| Skip audit logging | Call `logActivity()` |
| Create repo in build() | Create in `initState()` |

## 📖 Learn More

Start with [README.md](README.md) for full documentation.

See [IMPLEMENTATION_GUIDE.md](IMPLEMENTATION_GUIDE.md) for detailed step-by-step examples.

## 💡 Example Features in Codebase

- **Students**: [lib/core/students/](../core/students/)
- **Teachers**: [lib/core/teachers/](../core/teachers/)
- **Batches**: [lib/core/batches/](../core/batches/)
- **Auth**: [lib/core/services/auth_service.dart](../core/services/auth_service.dart)
