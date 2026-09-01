# State Management Pattern - Damma School Management System

This directory contains the **formalized state management pattern** for the Damma School Management System.

## 📋 Architecture Overview

The application uses a **lightweight, reactive state management architecture** based on:
- **Service Pattern** - For app-level state (authentication, session management)
- **Repository Pattern** - For data access and business logic
- **StatefulWidget + setState()** - For local UI state
- **FutureBuilder** - For async data fetching and display

### Data Flow Diagram

```
┌─────────────────────────────────┐
│   UI Layer (Pages/Widgets)      │
│  - StatefulWidget with setState │
│  - FutureBuilder for async ops  │
└──────────────┬──────────────────┘
               │ depends on
               ↓
┌─────────────────────────────────┐
│   Service Layer                 │
│  - AuthService                  │
│  - Dependency injection point    │
└──────────────┬──────────────────┘
               │ uses
               ↓
┌─────────────────────────────────┐
│   Repository Layer              │
│  - StudentRepository            │
│  - TeacherRepository            │
│  - BatchRepository              │
│  - ExaminationRepository        │
│  - UserRepository               │
│  - AuditLogRepository           │
└──────────────┬──────────────────┘
               │ queries
               ↓
┌─────────────────────────────────┐
│   Data Layer                    │
│  - SQLite Database              │
│  - AppDatabase                  │
└─────────────────────────────────┘
```

## 🏗️ Design Patterns

### 1. Service Pattern (App-Level State)

**Purpose**: Manage application-wide state like authentication sessions.

**Example: AuthService**
```dart
class AuthService {
  AuthSession? _currentSession;
  
  Future<void> login(Database db, String username, String password) async {
    // Authenticate and store session
    _currentSession = await _authenticateUser(db, username, password);
  }
  
  AuthSession? get currentSession => _currentSession;
  bool get isAuthenticated => _currentSession != null;
  
  Future<void> logout() async {
    _currentSession = null;
  }
}
```

**Key Characteristics**:
- Singleton-like pattern (passed through app)
- Holds mutable state (`_currentSession`)
- Provides methods to modify state
- Passed to pages via constructor

### 2. Repository Pattern (Data Access)

**Purpose**: Abstract data access logic and provide clean interface for domain entities.

**Example: StudentRepository**
```dart
class StudentRepository {
  Future<List<Student>> searchStudents(
    Database db,
    String? query,
    String? status,
    String? batch,
  ) async {
    // Query database with filters
  }
  
  Future<void> createStudent(
    Database db,
    String fullName,
    String studentId,
    String batch,
  ) async {
    // Validate and insert student
  }
  
  Future<void> updateStudent(Database db, int id, {required String fullName}) async {
    // Update existing student
  }
}
```

**Key Characteristics**:
- Encapsulates data access logic
- Provides high-level methods for domain operations
- Returns domain models, not raw database rows
- Can include business logic (validation, calculations)

### 3. Local UI State Pattern

**Purpose**: Manage page-specific state like filters, loading states, and dialog visibility.

**Example: StudentManagementPage**
```dart
class StudentManagementPage extends StatefulWidget {
  final Database database;
  final AuthService auth;
  
  const StudentManagementPage({
    required this.database,
    required this.auth,
  });
  
  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  // Local state
  String _searchQuery = '';
  String? _selectedStatus;
  bool _isLoading = false;
  
  final _repository = StudentRepository();
  List<Student> _students = [];
  
  @override
  void initState() {
    super.initState();
    _loadStudents(); // Initial load
  }
  
  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      _students = await _repository.searchStudents(
        widget.database,
        _searchQuery.isEmpty ? null : _searchQuery,
        _selectedStatus,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: Column(
        children: [
          SearchBar(onChanged: (value) {
            setState(() => _searchQuery = value);
            _loadStudents();
          }),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else
            Expanded(
              child: ListView.builder(
                itemCount: _students.length,
                itemBuilder: (context, index) => StudentTile(_students[index]),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddStudentDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

**Key Characteristics**:
- Extends `StatefulWidget`
- Local state for UI-specific data (filters, loading flags)
- Calls repository methods in response to user actions
- Uses `setState()` to trigger rebuilds
- Can use `FutureBuilder` for simpler async flows

## 📚 Repository Conventions

All repositories should follow these conventions:

### 1. Method Naming

| Operation | Pattern | Example |
|-----------|---------|---------|
| Query/Read | `listAll`, `search`, `getById`, `findWhere` | `listStudents()`, `searchByName()` |
| Create | `create` | `createStudent()` |
| Update | `update` | `updateStudent()` |
| Delete | `delete` | `deleteStudent()` |
| Special | `verb` + `entity` | `convertToAlumni()`, `generateReport()` |

### 2. Parameter Order

1. `Database db` - Always first parameter
2. Primary entity ID (if needed)
3. Filter/Query parameters
4. Optional parameters with defaults

```dart
// ✅ Good
Future<List<Student>> search(
  Database db,
  String? query,
  String? status,
  String? batch,
) async { }

// ❌ Inconsistent
Future<List<Student>> search(
  String? query,
  Database db,
  String? status,
) async { }
```

### 3. Error Handling

All repositories should include validation:

```dart
Future<void> createStudent(
  Database db,
  String fullName,
  String studentId,
  String batch,
) async {
  // Validate inputs
  if (fullName.isEmpty) throw ArgumentError('Full name required');
  if (studentId.isEmpty) throw ArgumentError('Student ID required');
  
  // Check for duplicates
  final existing = await db.query('students', 
    where: 'student_id = ?', 
    whereArgs: [studentId]
  );
  if (existing.isNotEmpty) {
    throw StateError('Student ID already exists');
  }
  
  // Perform operation
  await db.insert('students', {/* ... */});
}
```

## 🔄 State Management Workflow

### For Simple Data Display (Read-Only)

```dart
// 1. Repository method
Future<List<Teacher>> listTeachers(Database db) async { }

// 2. Page State
class TeacherListPage extends StatefulWidget { }

class _TeacherListPageState extends State<TeacherListPage> {
  List<Teacher> teachers = [];
  
  @override
  void initState() {
    super.initState();
    _loadTeachers();
  }
  
  Future<void> _loadTeachers() async {
    setState(() => teachers = await repository.listTeachers(database));
  }
  
  @override
  Widget build(BuildContext context) {
    return ListView(children: [
      for (final teacher in teachers) TeacherTile(teacher),
    ]);
  }
}
```

### For Complex Async Operations (FutureBuilder)

```dart
@override
Widget build(BuildContext context) {
  return FutureBuilder<List<Batch>>(
    future: _repository.listBatches(widget.database),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }
      return ListView(
        children: [
          for (final batch in snapshot.data ?? []) BatchTile(batch),
        ],
      );
    },
  );
}
```

### For Create/Update Operations (with User Feedback)

```dart
Future<void> _createStudent() async {
  setState(() => _isLoading = true);
  try {
    await _repository.createStudent(
      widget.database,
      fullName: _nameController.text,
      studentId: _idController.text,
      batch: _selectedBatch!,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student created successfully')),
    );
    
    Navigator.pop(context); // Close dialog
    _loadStudents(); // Refresh list
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
```

## 🎯 Best Practices

### 1. Dependency Injection
Always pass `Database` and `AuthService` through constructors:
```dart
// ✅ Good - explicit dependencies
class StudentListPage extends StatefulWidget {
  final Database database;
  final AuthService auth;
  
  const StudentListPage({
    required this.database,
    required this.auth,
  });
}

// ❌ Avoid - implicit global state
final database = serviceLocator.get<Database>();
```

### 2. Separation of Concerns
- **Repository** = Data access & validation
- **Page/Widget** = UI logic & user interaction
- **Service** = App-level state (auth, sessions)

```dart
// ✅ Good - repository handles validation
class StudentRepository {
  Future<void> createStudent(Database db, String name) async {
    if (name.isEmpty) throw ArgumentError('Name required');
    await db.insert('students', {'name': name});
  }
}

// ❌ Avoid - mixing concerns
class StudentPage {
  Future<void> _createStudent() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(...);
      return;
    }
    // Direct database access
    await database.insert('students', {...});
  }
}
```

### 3. Avoid State Leaks
Always clean up when navigating:
```dart
@override
void dispose() {
  _searchController.dispose();
  _nameController.dispose();
  _batchController.dispose();
  super.dispose();
}
```

### 4. Testing
All repositories should be easily testable:
```dart
// ✅ Good - receives database as parameter
Future<List<Student>> search(Database db, String? query) async { }

// Can be tested with in-memory database
final db = AppDatabase(factory: databaseFactoryFfi);
final connection = await db.openAt(inMemoryDatabasePath);
final results = await repository.search(connection, 'John');
```

## 📂 Folder Structure

```
lib/
├── providers/              # This directory
│   ├── README.md          # This file
│   ├── auth_service_provider.dart      # Singleton auth service
│   └── repository_provider.dart        # Factory methods for repositories
│
├── core/
│   ├── services/
│   │   └── auth_service.dart          # Authentication state management
│   ├── students/
│   │   └── student_repository.dart    # Student data access
│   ├── teachers/
│   │   └── teacher_repository.dart    # Teacher data access
│   └── database/
│       └── app_database.dart          # Database initialization
│
├── features/
│   ├── students/
│   │   └── pages/
│   │       └── student_management_page.dart  # Uses StudentRepository
│   ├── teachers/
│   │   └── pages/
│   │       └── teacher_management_page.dart  # Uses TeacherRepository
│   └── auth/
│       └── pages/
│           └── login_page.dart              # Uses AuthService
└── main.dart                                 # App bootstrap
```

## 🔧 Adding a New Feature

When adding a new feature (e.g., Attendance Management), follow this pattern:

### Step 1: Create Repository

```dart
// lib/core/attendance/attendance_repository.dart
class AttendanceRepository {
  Future<List<AttendanceRecord>> listForStudent(
    Database db,
    int studentId,
    {DateTime? startDate, DateTime? endDate}
  ) async {
    // Query and return attendance records
  }
  
  Future<void> markAttendance(
    Database db,
    int studentId,
    DateTime date,
    String status,
  ) async {
    // Validate and insert attendance
  }
}
```

### Step 2: Create Feature Pages

```dart
// lib/features/attendance/pages/attendance_page.dart
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
  final _repository = AttendanceRepository();
  List<AttendanceRecord> _records = [];
  
  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }
  
  Future<void> _loadAttendance() async {
    final records = await _repository.listForStudent(
      widget.database,
      widget.auth.currentSession!.userId,
    );
    setState(() => _records = records);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: ListView(children: [
        for (final record in _records) AttendanceRecordTile(record),
      ]),
    );
  }
}
```

### Step 3: Integrate into App Routes

```dart
// lib/app/routes/app_routes.dart
static const attendance = '/attendance';

// In app.dart
case AppRoutes.attendance:
  return MaterialPageRoute(
    builder: (context) => AttendancePage(
      database: database,
      auth: auth,
    ),
  );
```

## 🧪 Testing State Management

### Testing Repositories

```dart
// test/attendance_repository_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test('marks attendance for student', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    final repository = AttendanceRepository();
    
    // Arrange
    final studentId = 1;
    final date = DateTime.utc(2026, 8, 31);
    
    // Act
    await repository.markAttendance(connection, studentId, date, 'present');
    
    // Assert
    final records = await repository.listForStudent(connection, studentId);
    expect(records, isNotEmpty);
    expect(records.first.status, 'present');
    
    await database.close();
  });
}
```

### Testing Pages (with Mocking)

```dart
// test/attendance_page_test.dart
void main() {
  testWidgets('displays attendance records', (WidgetTester tester) async {
    // Mock dependencies
    final mockAuth = MockAuthService();
    final mockDatabase = MockDatabase();
    
    // Build widget
    await tester.pumpWidget(
      MaterialApp(
        home: AttendancePage(
          database: mockDatabase,
          auth: mockAuth,
        ),
      ),
    );
    
    // Assert
    expect(find.byType(ListView), findsOneWidget);
  });
}
```

## 📝 Summary

| Aspect | Pattern | Location |
|--------|---------|----------|
| **App-level state** | Service (AuthService) | `lib/core/services/` |
| **Data access** | Repository | `lib/core/[domain]/` |
| **UI state** | StatefulWidget + setState | `lib/features/[feature]/pages/` |
| **Async operations** | FutureBuilder | Within page build() |
| **Dependency passing** | Constructor injection | Page constructors |
| **Testing** | In-memory SQLite + mocking | `test/` directory |

This pattern provides a **lightweight, maintainable approach** that's perfect for offline-first, database-heavy applications like a school management system.
