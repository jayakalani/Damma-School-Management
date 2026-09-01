# State Management Implementation Guide

Quick reference guide for implementing new features using the Damma School Management System state management pattern.

## 🎯 Decision Tree

```
┌─ What needs to be managed?
│
├─ App-level (user session, auth)
│  └─ Use: AuthService (in core/services/)
│     └─ Pass via constructor to DammaSchoolApp
│
├─ Data persistence (students, teachers, etc.)
│  └─ Use: Repository (in core/[domain]/)
│     └─ Instantiate in StatefulWidget
│
└─ UI state (filters, loading, dialog visibility)
   └─ Use: StatefulWidget + setState()
      └─ Define variables in State class
      └─ Update with setState(() => {})
```

## 📋 Checklist for New Feature

### Phase 1: Data Layer

- [ ] Create repository file: `lib/core/[feature]/[feature]_repository.dart`
- [ ] Extend `BaseRepository`
- [ ] Implement all CRUD methods (Create, Read, Update, Delete)
- [ ] Add validation in every method
- [ ] Call `logActivity()` for important operations
- [ ] Write repository tests in `test/[feature]_repository_test.dart`

```dart
// Example repository template
class StudentRepository extends BaseRepository {
  /// Query students by name
  /// 
  /// Returns list of matching students
  /// Throws ArgumentError if db is null
  Future<List<Student>> searchByName(
    Database db,
    String name,
  ) async {
    validateRequired(name, 'name');
    
    final results = await db.query(
      'students',
      where: 'full_name LIKE ?',
      whereArgs: ['%$name%'],
    );
    
    return results.map((row) => Student.fromJson(row)).toList();
  }
}
```

### Phase 2: Feature Pages

- [ ] Create page file: `lib/features/[feature]/pages/[feature]_page.dart`
- [ ] Extend `StatefulWidget` with corresponding `State` class
- [ ] Require `Database` and `AuthService` as constructor parameters
- [ ] Create repository instance in `initState()`
- [ ] Implement initial data load in `initState()`
- [ ] Add local state variables for UI (filters, loading, etc.)
- [ ] Implement dispose() to clean up controllers
- [ ] Use `setState()` for state updates
- [ ] Add error handling with SnackBar

```dart
// Example page template
class StudentListPage extends StatefulWidget {
  final Database database;
  final AuthService auth;
  
  const StudentListPage({
    required this.database,
    required this.auth,
  });
  
  @override
  State<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends State<StudentListPage> {
  late final StudentRepository _repository;
  
  // Local state
  String _searchQuery = '';
  bool _isLoading = false;
  List<Student> _students = [];
  String? _error;
  
  @override
  void initState() {
    super.initState();
    _repository = StudentRepository();
    _loadStudents();
  }
  
  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);
    try {
      _students = await _repository.searchByName(
        widget.database,
        _searchQuery,
      );
      setState(() => _error = null);
    } catch (e) {
      setState(() => _error = 'Failed to load students: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  void dispose() {
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));
    
    return ListView(
      children: [for (final student in _students) StudentTile(student)],
    );
  }
}
```

### Phase 3: Routing

- [ ] Add route constant to `lib/app/routes/app_routes.dart`
- [ ] Add route builder to `lib/app/routes/app_routes.dart`
- [ ] Pass `database` and `auth` to page constructor

```dart
// In app_routes.dart
class AppRoutes {
  static const students = '/students';
  // ... other routes
}

// In app.dart onGenerateRoute
case AppRoutes.students:
  return MaterialPageRoute(
    builder: (context) => StudentListPage(
      database: database,
      auth: auth,
    ),
  );
```

### Phase 4: Testing

- [ ] Create repository tests
- [ ] Create widget tests (if complex UI)
- [ ] Verify error cases

```dart
// test/student_repository_test.dart
void main() {
  test('searches students by name', () async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    final connection = await database.openAt(inMemoryDatabasePath);
    
    // Insert test data
    await connection.insert('students', {
      'full_name': 'John Doe',
      'student_id': 'STU001',
      'batch': '2024A',
    });
    
    // Test repository
    final repository = StudentRepository();
    final results = await repository.searchByName(connection, 'John');
    
    expect(results, isNotEmpty);
    expect(results.first.fullName, 'John Doe');
    
    await database.close();
  });
}
```

## 🔄 Common State Management Patterns

### Pattern 1: Simple List Display with Search

```dart
class StudentListPageState extends State<StudentListPage> {
  final _repository = StudentRepository();
  String _searchQuery = '';
  List<Student> _students = [];
  
  Future<void> _search(String query) async {
    setState(() => _searchQuery = query);
    final results = await _repository.searchByName(widget.database, query);
    setState(() => _students = results);
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SearchBar(onChanged: _search),
        Expanded(child: ListView(
          children: _students.map((s) => StudentTile(s)).toList(),
        )),
      ],
    );
  }
}
```

### Pattern 2: Create/Edit Form with Validation

```dart
class CreateStudentDialogState extends State<CreateStudentDialog> {
  final _repository = StudentRepository();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  
  Future<void> _create() async {
    setState(() => _isLoading = true);
    try {
      await _repository.createStudent(
        widget.database,
        fullName: _nameController.text,
        studentId: DateTime.now().millisecondsSinceEpoch.toString(),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Student created')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Student'),
      content: Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Full Name'),
          ),
          if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _create,
          child: _isLoading ? const CircularProgressIndicator() : const Text('Create'),
        ),
      ],
    );
  }
}
```

### Pattern 3: Async Data with FutureBuilder

```dart
@override
Widget build(BuildContext context) {
  return FutureBuilder<List<Student>>(
    future: _repository.searchByName(widget.database, _searchQuery),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      
      if (snapshot.hasError) {
        return Center(child: Text('Error: ${snapshot.error}'));
      }
      
      final students = snapshot.data ?? [];
      if (students.isEmpty) {
        return const Center(child: Text('No students found'));
      }
      
      return ListView(
        children: students.map((s) => StudentTile(s)).toList(),
      );
    },
  );
}
```

## ⚡ Performance Tips

### 1. Lazy Load Data
```dart
// ❌ Don't load everything on page open
@override
void initState() {
  super.initState();
  _loadAllData(); // Don't do this
}

// ✅ Load data on demand
@override
Widget build(BuildContext context) {
  return Scaffold(
    body: FutureBuilder(
      future: _repository.search(...), // Load when needed
      builder: (context, snapshot) { }
    ),
  );
}
```

### 2. Debounce Search
```dart
Timer? _searchTimer;

@override
void dispose() {
  _searchTimer?.cancel();
  super.dispose();
}

void _onSearchChanged(String query) {
  _searchTimer?.cancel();
  _searchTimer = Timer(const Duration(milliseconds: 500), () {
    _search(query);
  });
}
```

### 3. Pagination for Large Lists
```dart
int _page = 0;
const _pageSize = 20;

Future<void> _loadMore() async {
  final newStudents = await _repository.listPaginated(
    widget.database,
    page: _page++,
    pageSize: _pageSize,
  );
  setState(() => _students.addAll(newStudents));
}
```

## 🐛 Debugging Tips

### Check Database State
```dart
// Add debug method to repository
Future<void> debugPrintAll(Database db) async {
  final all = await db.query('students');
  for (final row in all) {
    print('Student: $row');
  }
}

// Call in page
_repository.debugPrintAll(widget.database);
```

### Trace State Changes
```dart
@override
void setState(VoidCallback fn) {
  print('setState called at ${DateTime.now()}');
  super.setState(fn);
}
```

### Log Lifecycle
```dart
@override
void initState() {
  super.initState();
  print('${runtimeType}.initState()');
}

@override
void dispose() {
  print('${runtimeType}.dispose()');
  super.dispose();
}
```

## ✅ Code Review Checklist

When reviewing code using this pattern:

- [ ] Repository methods have clear documentation
- [ ] All inputs are validated before use
- [ ] Error handling is present and informative
- [ ] `Database` is first parameter in all repository methods
- [ ] Pages accept `database` and `auth` via constructor
- [ ] `setState()` is used for state updates
- [ ] Controllers/resources are disposed in `dispose()`
- [ ] Loading/error states are properly handled
- [ ] Audit logging is called for important operations
- [ ] Tests exist for repositories
- [ ] No direct database queries in UI code

## 📚 Related Files

- [State Management Pattern Overview](README.md)
- [AuthService](../core/services/auth_service.dart)
- [BaseRepository](base_repository.dart)
- [RepositoryProvider](repository_provider.dart)
