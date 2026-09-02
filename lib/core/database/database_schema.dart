import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseSchema {
  const DatabaseSchema._();

  static const version = 3;

  static Future<void> onConfigure(Database database) async {
    await database.execute('PRAGMA foreign_keys = ON');
  }

  static Future<void> onCreate(Database database, int version) async {
    await database.transaction((transaction) async {
      for (final sql in _createStatements) {
        await transaction.execute(sql);
      }
    });
  }

  static Future<void> onUpgrade(Database database, int oldVersion, int newVersion) async {
    if (oldVersion < 1) await onCreate(database, newVersion);
    if (oldVersion < 2) await ensureComplete(database);
    if (oldVersion < 3) await _migrateToV3(database);
  }

  static Future<void> _migrateToV3(Database database) async {
    await _ensureStudentColumns(database);
  }

  static Future<void> _ensureStudentColumns(Database database) async {
    final columns = await database.rawQuery('PRAGMA table_info(students)');
    final hasIsActive = columns.any((row) => row['name'] == 'is_active');
    if (!hasIsActive) {
      await database.execute(
        'ALTER TABLE students ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1',
      );
    }
    // Empty NIC values collide on the UNIQUE constraint; store them as NULL instead.
    await database.execute("UPDATE students SET nic = NULL WHERE nic = ''");
    await database.execute("UPDATE teachers SET nic = NULL WHERE nic = ''");
  }

  static Future<void> ensureComplete(Database database) async {
    final tableRows = await database.rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
    final existingTables = tableRows.map((row) => row['name'] as String).toSet();
    for (final sql in _createStatements) {
      if (!sql.startsWith('CREATE TABLE')) continue;
      final tableName = RegExp(r'CREATE TABLE (\w+)').firstMatch(sql)?.group(1);
      if (tableName == null || existingTables.contains(tableName)) continue;
      await database.execute(sql);
      existingTables.add(tableName);
    }

    await _ensureStudentColumns(database);

    final indexRows = await database.rawQuery("SELECT name FROM sqlite_master WHERE type = 'index'");
    final existingIndexes = indexRows.map((row) => row['name'] as String).toSet();
    final triggerRows = await database.rawQuery("SELECT name FROM sqlite_master WHERE type = 'trigger'");
    final existingTriggers = triggerRows.map((row) => row['name'] as String).toSet();
    for (final sql in _createStatements) {
      if (sql.startsWith('CREATE UNIQUE INDEX') || sql.startsWith('CREATE INDEX')) {
        final indexName = RegExp(r'CREATE (?:UNIQUE )?INDEX (\w+)').firstMatch(sql)?.group(1);
        if (indexName == null || existingIndexes.contains(indexName)) continue;
        await database.execute(sql);
      } else if (sql.startsWith('CREATE TRIGGER')) {
        final triggerName = RegExp(r'CREATE TRIGGER (\w+)').firstMatch(sql)?.group(1);
        if (triggerName == null || existingTriggers.contains(triggerName)) continue;
        await database.execute(sql);
      }
    }
  }

  static const _createStatements = <String>[
    '''CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL, username TEXT NOT NULL COLLATE NOCASE UNIQUE, password_hash TEXT NOT NULL, role TEXT NOT NULL CHECK (role IN ('admin', 'staff')), status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')), created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    '''CREATE TABLE audit_logs (id INTEGER PRIMARY KEY AUTOINCREMENT, user_id INTEGER NOT NULL, action TEXT NOT NULL, module TEXT NOT NULL, entity_type TEXT, entity_id INTEGER, description TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE RESTRICT ON UPDATE CASCADE)''',
    '''CREATE TABLE teachers (id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL, name_with_initials TEXT NOT NULL, date_of_birth TEXT, nic TEXT UNIQUE, phone_number TEXT, address TEXT, registered_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')), bank_account_number TEXT, bank_name TEXT, bank_branch TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    '''CREATE TABLE teacher_qualifications (id INTEGER PRIMARY KEY AUTOINCREMENT, teacher_id INTEGER NOT NULL, qualification TEXT NOT NULL, institution TEXT, completion_year INTEGER, notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY (teacher_id) REFERENCES teachers(id) ON DELETE RESTRICT ON UPDATE CASCADE)''',
    '''CREATE TABLE batches (id INTEGER PRIMARY KEY AUTOINCREMENT, batch_name TEXT NOT NULL, starting_year INTEGER NOT NULL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    '''CREATE TABLE batch_history (id INTEGER PRIMARY KEY AUTOINCREMENT, batch_id INTEGER NOT NULL, academic_year INTEGER NOT NULL, grade TEXT NOT NULL, started_date TEXT NOT NULL, ended_date TEXT, is_current INTEGER NOT NULL DEFAULT 1 CHECK (is_current IN (0, 1)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE RESTRICT ON UPDATE CASCADE)''',
    '''CREATE TABLE students (id INTEGER PRIMARY KEY AUTOINCREMENT, full_name TEXT NOT NULL, name_with_initials TEXT NOT NULL, date_of_birth TEXT, nic TEXT UNIQUE, phone_number TEXT, address TEXT, joined_date TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'student' CHECK (status IN ('student', 'past_pupil')), is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    '''CREATE TABLE student_batch_history (id INTEGER PRIMARY KEY AUTOINCREMENT, student_id INTEGER NOT NULL, batch_id INTEGER NOT NULL, batch_history_id INTEGER NOT NULL, joined_date TEXT NOT NULL, left_date TEXT, is_current INTEGER NOT NULL DEFAULT 1 CHECK (is_current IN (0, 1)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (batch_id) REFERENCES batches(id) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (batch_history_id) REFERENCES batch_history(id) ON DELETE RESTRICT ON UPDATE CASCADE)''',
    '''CREATE TABLE batch_teacher_history (id INTEGER PRIMARY KEY AUTOINCREMENT, batch_history_id INTEGER NOT NULL, teacher_id INTEGER NOT NULL, assigned_date TEXT NOT NULL, removed_date TEXT, is_current INTEGER NOT NULL DEFAULT 1 CHECK (is_current IN (0, 1)), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY (batch_history_id) REFERENCES batch_history(id) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (teacher_id) REFERENCES teachers(id) ON DELETE RESTRICT ON UPDATE CASCADE)''',
    '''CREATE TABLE examinations (id INTEGER PRIMARY KEY AUTOINCREMENT, batch_history_id INTEGER NOT NULL, examination_name TEXT NOT NULL, examination_date TEXT NOT NULL, total_marks REAL NOT NULL CHECK (total_marks >= 0), created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY (batch_history_id) REFERENCES batch_history(id) ON DELETE RESTRICT ON UPDATE CASCADE)''',
    '''CREATE TABLE exam_results (id INTEGER PRIMARY KEY AUTOINCREMENT, examination_id INTEGER NOT NULL, student_id INTEGER NOT NULL, attendance_status TEXT NOT NULL CHECK (attendance_status IN ('present', 'absent')), marks REAL, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, UNIQUE (examination_id, student_id), CHECK ((attendance_status = 'absent' AND marks IS NULL) OR (attendance_status = 'present' AND marks IS NOT NULL AND marks >= 0)), FOREIGN KEY (examination_id) REFERENCES examinations(id) ON DELETE RESTRICT ON UPDATE CASCADE, FOREIGN KEY (student_id) REFERENCES students(id) ON DELETE RESTRICT ON UPDATE CASCADE)''',
    '''CREATE TABLE past_pupil_batches (id INTEGER PRIMARY KEY AUTOINCREMENT, batch_name TEXT NOT NULL, year_completed INTEGER NOT NULL, notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)''',
    '''CREATE TABLE historical_past_pupils (id INTEGER PRIMARY KEY AUTOINCREMENT, past_pupil_batch_id INTEGER NOT NULL, full_name TEXT NOT NULL, name_with_initials TEXT, date_of_birth TEXT, nic TEXT, phone_number TEXT, address TEXT, notes TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL, FOREIGN KEY (past_pupil_batch_id) REFERENCES past_pupil_batches(id) ON DELETE RESTRICT ON UPDATE CASCADE)''',
    'CREATE UNIQUE INDEX uq_batch_history_current ON batch_history(batch_id) WHERE is_current = 1',
    'CREATE UNIQUE INDEX uq_student_current_batch ON student_batch_history(student_id) WHERE is_current = 1',
    'CREATE UNIQUE INDEX uq_teacher_current_batch ON batch_teacher_history(batch_history_id) WHERE is_current = 1',
    '''CREATE TRIGGER exam_results_marks_before_insert BEFORE INSERT ON exam_results WHEN NEW.marks IS NOT NULL AND NEW.marks > (SELECT total_marks FROM examinations WHERE id = NEW.examination_id) BEGIN SELECT RAISE(ABORT, 'Marks cannot exceed total marks'); END''',
    '''CREATE TRIGGER exam_results_marks_before_update BEFORE UPDATE OF examination_id, marks ON exam_results WHEN NEW.marks IS NOT NULL AND NEW.marks > (SELECT total_marks FROM examinations WHERE id = NEW.examination_id) BEGIN SELECT RAISE(ABORT, 'Marks cannot exceed total marks'); END''',
    'CREATE INDEX idx_users_role ON users(role)',
    'CREATE INDEX idx_users_status ON users(status)',
    'CREATE INDEX idx_teachers_status ON teachers(status)',
    'CREATE INDEX idx_students_status ON students(status)',
    'CREATE INDEX idx_batch_history_year ON batch_history(academic_year)',
    'CREATE INDEX idx_student_batch_batch ON student_batch_history(batch_id)',
    'CREATE INDEX idx_batch_teacher_teacher ON batch_teacher_history(teacher_id)',
    'CREATE INDEX idx_examinations_batch ON examinations(batch_history_id)',
    'CREATE INDEX idx_exam_results_exam ON exam_results(examination_id)',
    'CREATE INDEX idx_exam_results_student ON exam_results(student_id)',
    'CREATE INDEX idx_audit_logs_user ON audit_logs(user_id)',
    'CREATE INDEX idx_audit_logs_created ON audit_logs(created_at)',
  ];
}