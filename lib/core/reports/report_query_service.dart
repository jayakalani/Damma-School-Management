import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../auth/access_control.dart';
import '../students/student_repository.dart';
import '../teachers/teacher_repository.dart';
import 'report_catalog.dart';

class ReportQuery {
  const ReportQuery({
    required this.reportId,
    this.status,
    this.batchId,
    this.alumniBatchId,
    this.startDate,
    this.endDate,
  });

  final ReportId reportId;
  final String? status;
  final int? batchId;
  final int? alumniBatchId;
  final DateTime? startDate;
  final DateTime? endDate;
}

class ReportLookupOptions {
  const ReportLookupOptions({
    this.batches = const [],
    this.alumniBatches = const [],
  });

  final List<Map<String, Object?>> batches;
  final List<Map<String, Object?>> alumniBatches;
}

class ReportResult {
  const ReportResult({
    required this.rows,
    required this.filterSummary,
  });

  final List<Map<String, String>> rows;
  final String filterSummary;
}

class ReportQueryService {
  ReportQueryService({
    TeacherRepository? teachers,
    StudentRepository? students,
  })  : _teachers = teachers ?? TeacherRepository(),
        _students = students ?? StudentRepository();

  final TeacherRepository _teachers;
  final StudentRepository _students;

  Future<ReportLookupOptions> loadLookups({
    required Database database,
    required int userId,
  }) async {
    await _requireAccess(database, userId);
    final batches = await database.rawQuery('''
      SELECT id, batch_name
      FROM batches
      ORDER BY batch_name COLLATE NOCASE
    ''');
    final alumniBatches = await database.rawQuery('''
      SELECT id, batch_name, year_completed
      FROM past_pupil_batches
      ORDER BY year_completed DESC, batch_name COLLATE NOCASE
    ''');
    return ReportLookupOptions(
      batches: batches,
      alumniBatches: alumniBatches,
    );
  }

  Future<ReportResult> loadReport({
    required Database database,
    required int userId,
    required ReportQuery query,
  }) async {
    await _requireAccess(database, userId);
    final definition = ReportCatalog.byId(query.reportId);
    final lookups = await loadLookups(database: database, userId: userId);
    final rows = switch (query.reportId) {
      ReportId.teachers => await _loadTeachers(database, userId, query),
      ReportId.students => await _loadStudents(database, userId, query),
      ReportId.batches => await _loadBatches(database, query),
      ReportId.pastPupils => await _loadPastPupils(database, query),
      ReportId.examinations => await _loadExaminations(database, query),
      ReportId.competitions => await _loadCompetitions(database, query),
    };
    return ReportResult(
      rows: rows,
      filterSummary: _filterSummary(definition, query, lookups),
    );
  }

  Future<void> _requireAccess(Database database, int userId) {
    return AccessControl.requireActiveAdminOrStaff(
      database,
      userId,
      action: 'generate reports',
    );
  }

  Future<List<Map<String, String>>> _loadTeachers(
    Database database,
    int userId,
    ReportQuery query,
  ) async {
    final teachers = await _teachers.searchTeachers(
      database: database,
      adminId: userId,
      status: query.status,
      startDate: query.startDate,
      endDate: query.endDate,
    );
    return teachers
        .map(
          (teacher) => {
            'full_name': _text(teacher['full_name']),
            'name_with_initials': _text(teacher['name_with_initials']),
            'nic': _text(teacher['nic']),
            'phone_number': _text(teacher['phone_number']),
            'address': _text(teacher['address']),
            'date_of_birth': _text(teacher['date_of_birth']),
            'registered_date': _text(teacher['registered_date']),
            'status': _activeInactive(teacher['status']),
            'bank_name': _text(teacher['bank_name']),
            'bank_branch': _text(teacher['bank_branch']),
            'bank_account_number': _text(teacher['bank_account_number']),
          },
        )
        .toList();
  }

  Future<List<Map<String, String>>> _loadStudents(
    Database database,
    int userId,
    ReportQuery query,
  ) async {
    final students = await _students.searchStudents(
      database: database,
      adminId: userId,
      status: query.status,
      batchId: query.batchId,
      startDate: query.startDate,
      endDate: query.endDate,
    );
    return students
        .map(
          (student) => {
            'full_name': _text(student['full_name']),
            'name_with_initials': _text(student['name_with_initials']),
            'nic': _text(student['nic']),
            'phone_number': _text(student['phone_number']),
            'address': _text(student['address']),
            'date_of_birth': _text(student['date_of_birth']),
            'joined_date': _text(student['joined_date']),
            'status': _studentStatus(student),
            'is_active': _studentActive(student),
            'batch_name': _text(student['batch_name']),
            'grade': _text(student['grade']),
            'academic_year': _text(student['academic_year']),
          },
        )
        .toList();
  }

  Future<List<Map<String, String>>> _loadBatches(
    Database database,
    ReportQuery query,
  ) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (query.status == 'active') {
      conditions.add('batches.is_active = 1');
    } else if (query.status == 'inactive') {
      conditions.add('batches.is_active = 0');
    }
    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await database.rawQuery(
      '''
      SELECT batches.*, history.academic_year, history.grade, history.started_date
      FROM batches
      LEFT JOIN batch_history history
        ON history.batch_id = batches.id AND history.is_current = 1
      $where
      ORDER BY batches.batch_name COLLATE NOCASE
      ''',
      arguments.isEmpty ? null : arguments,
    );
    return rows
        .map(
          (batch) => {
            'batch_name': _text(batch['batch_name']),
            'starting_year': _text(batch['starting_year']),
            'status': (batch['is_active'] ?? 1) == 1 ? 'Active' : 'Inactive',
            'grade': _text(batch['grade']),
            'academic_year': _text(batch['academic_year']),
            'started_date': _text(batch['started_date']),
          },
        )
        .toList();
  }

  Future<List<Map<String, String>>> _loadPastPupils(
    Database database,
    ReportQuery query,
  ) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (query.alumniBatchId != null) {
      conditions.add('historical_past_pupils.past_pupil_batch_id = ?');
      arguments.add(query.alumniBatchId);
    }
    if (query.startDate != null) {
      conditions.add('past_pupil_batches.year_completed >= ?');
      arguments.add(query.startDate!.year);
    }
    if (query.endDate != null) {
      conditions.add('past_pupil_batches.year_completed <= ?');
      arguments.add(query.endDate!.year);
    }
    final where =
        conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await database.rawQuery(
      '''
      SELECT historical_past_pupils.*,
        past_pupil_batches.batch_name,
        past_pupil_batches.year_completed
      FROM historical_past_pupils
      INNER JOIN past_pupil_batches
        ON past_pupil_batches.id = historical_past_pupils.past_pupil_batch_id
      $where
      ORDER BY historical_past_pupils.full_name COLLATE NOCASE
      ''',
      arguments.isEmpty ? null : arguments,
    );
    return rows
        .map(
          (pupil) => {
            'full_name': _text(pupil['full_name']),
            'name_with_initials': _text(pupil['name_with_initials']),
            'nic': _text(pupil['nic']),
            'phone_number': _text(pupil['phone_number']),
            'address': _text(pupil['address']),
            'date_of_birth': _text(pupil['date_of_birth']),
            'batch_name': _text(pupil['batch_name']),
            'year_completed': _text(pupil['year_completed']),
            'notes': _text(pupil['notes']),
          },
        )
        .toList();
  }

  Future<List<Map<String, String>>> _loadExaminations(
    Database database,
    ReportQuery query,
  ) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (query.startDate != null) {
      conditions.add('examination_date >= ?');
      arguments.add(_storageDate(query.startDate!));
    }
    if (query.endDate != null) {
      conditions.add('examination_date <= ?');
      arguments.add(_storageDate(query.endDate!));
    }
    final rows = await database.query(
      'examinations',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'examination_date DESC, id DESC',
    );
    return rows
        .map(
          (exam) => {
            'examination_name': _text(exam['examination_name']),
            'examination_date': _text(exam['examination_date']),
            'total_marks': _number(exam['total_marks']),
          },
        )
        .toList();
  }

  Future<List<Map<String, String>>> _loadCompetitions(
    Database database,
    ReportQuery query,
  ) async {
    final conditions = <String>[];
    final arguments = <Object?>[];
    if (query.startDate != null) {
      conditions.add('competition_date >= ?');
      arguments.add(_storageDate(query.startDate!));
    }
    if (query.endDate != null) {
      conditions.add('competition_date <= ?');
      arguments.add(_storageDate(query.endDate!));
    }
    final rows = await database.query(
      'competitions',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: arguments.isEmpty ? null : arguments,
      orderBy: 'competition_date DESC, id DESC',
    );
    return rows
        .map(
          (competition) => {
            'competition_name': _text(competition['competition_name']),
            'competition_date': _text(competition['competition_date']),
            'venue': _text(competition['venue']),
            'description': _text(competition['description']),
          },
        )
        .toList();
  }

  String _filterSummary(
    ReportDefinition definition,
    ReportQuery query,
    ReportLookupOptions lookups,
  ) {
    final parts = <String>[];
    if (query.status != null) {
      parts.add('Status: ${_statusLabel(query.status!)}');
    }
    if (query.batchId != null) {
      final batch = lookups.batches.where((row) => row['id'] == query.batchId);
      parts.add(
        'Batch: ${batch.isEmpty ? query.batchId : _text(batch.first['batch_name'])}',
      );
    }
    if (query.alumniBatchId != null) {
      final batch = lookups.alumniBatches
          .where((row) => row['id'] == query.alumniBatchId);
      parts.add(
        'Alumni batch: ${batch.isEmpty ? query.alumniBatchId : _text(batch.first['batch_name'])}',
      );
    }
    if (query.startDate != null) {
      parts.add('From: ${_storageDate(query.startDate!)}');
    }
    if (query.endDate != null) {
      parts.add('To: ${_storageDate(query.endDate!)}');
    }
    return parts.isEmpty ? definition.emptyFilterSummary : parts.join(' · ');
  }

  String _statusLabel(String value) => switch (value) {
        'active' => 'Active',
        'inactive' => 'Inactive',
        'past_pupil' => 'Past pupil',
        'student' => 'Students',
        _ => value,
      };

  String _studentStatus(Map<String, Object?> student) {
    if (student['status'] == 'past_pupil') return 'Past pupil';
    return (student['is_active'] ?? 1) == 1 ? 'Active' : 'Inactive';
  }

  String _studentActive(Map<String, Object?> student) {
    if (student['status'] == 'past_pupil') return '-';
    return (student['is_active'] ?? 1) == 1 ? 'Yes' : 'No';
  }

  String _activeInactive(Object? value) =>
      value == 'active' ? 'Active' : 'Inactive';

  String _text(Object? value) => value?.toString() ?? '';

  String _number(Object? value) {
    if (value is num && value == value.roundToDouble()) {
      return '${value.round()}';
    }
    return value?.toString() ?? '';
  }

  String _storageDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
