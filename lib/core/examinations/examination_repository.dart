import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../audit/audit_actions.dart';
import '../audit/audit_log_repository.dart';
import '../auth/access_control.dart';
import '../utils/app_validators.dart';

class ExaminationRepository {
  ExaminationRepository({AuditLogRepository? auditLogs})
    : _auditLogs = auditLogs ?? const AuditLogRepository();

  final AuditLogRepository _auditLogs;

  Future<List<Map<String, Object?>>> listBatchYears({
    required Database database,
    required int adminId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage examinations',
    );
    return database.rawQuery(
      'SELECT history.*, batches.batch_name FROM batch_history history INNER JOIN batches ON batches.id = history.batch_id ORDER BY history.academic_year DESC, batches.batch_name COLLATE NOCASE',
    );
  }

  Future<List<Map<String, Object?>>> listExaminations({
    required Database database,
    required int adminId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage examinations',
    );
    return database.rawQuery(
      'SELECT examinations.*, history.batch_id, history.academic_year, history.grade, batches.batch_name FROM examinations INNER JOIN batch_history history ON history.id = examinations.batch_history_id INNER JOIN batches ON batches.id = history.batch_id ORDER BY examinations.examination_date DESC, examinations.id DESC',
    );
  }

  Future<ExaminationDetails> getDetails({
    required Database database,
    required int adminId,
    required int examinationId,
  }) async {
    await AccessControl.requireActiveAdminOrStaff(
      database,
      adminId,
      action: 'manage examinations',
    );
    final exams = await database.rawQuery(
      'SELECT examinations.*, history.batch_id, history.academic_year, history.grade, batches.batch_name FROM examinations INNER JOIN batch_history history ON history.id = examinations.batch_history_id INNER JOIN batches ON batches.id = history.batch_id WHERE examinations.id = ?',
      [examinationId],
    );
    if (exams.isEmpty) throw StateError('Examination not found.');
    final exam = exams.single;
    final students = await database.rawQuery(
      '''
      SELECT students.id, students.full_name, students.name_with_initials,
        results.id AS result_id, results.attendance_status, results.marks
      FROM student_batch_history membership
      INNER JOIN students ON students.id = membership.student_id
      LEFT JOIN exam_results results ON results.student_id = students.id AND results.examination_id = ?
      WHERE membership.batch_history_id = ? AND membership.is_current = 1 AND students.status = 'student'
      ORDER BY students.full_name COLLATE NOCASE
    ''',
      [examinationId, exam['batch_history_id']],
    );
    return ExaminationDetails(
      examination: exam,
      students: students,
      analytics: _analytics(students),
    );
  }

  Future<int> createExamination({
    required Database database,
    required int adminId,
    required int batchHistoryId,
    required String name,
    required String date,
    required num totalMarks,
  }) async {
    if (name.trim().isEmpty ||
        AppValidators.date(date, 'Examination date') != null ||
        totalMarks < 0) {
      throw const InvalidExaminationException();
    }
    return database.transaction((transaction) async {
      await AccessControl.requireActiveStaff(
        transaction,
        adminId,
        action: 'create examinations',
      );
      final histories = await transaction.query(
        'batch_history',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [batchHistoryId],
        limit: 1,
      );
      if (histories.isEmpty) throw StateError('Batch academic year not found.');
      final id = await transaction.insert('examinations', {
        'batch_history_id': batchHistoryId,
        'examination_name': name.trim(),
        'examination_date': date.trim(),
        'total_marks': totalMarks,
        'created_at': _now(),
        'updated_at': _now(),
      });
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.examinationCreated,
        module: 'examination_management',
        entityType: 'examination',
        entityId: id,
        description: 'Admin created examination ${name.trim()}.',
      );
      return id;
    });
  }

  Future<void> saveResults({
    required Database database,
    required int adminId,
    required int examinationId,
    required List<ExamMarkInput> results,
  }) async {
    await database.transaction((transaction) async {
      await AccessControl.requireActiveAdminOrStaff(
        transaction,
        adminId,
        action: 'manage examinations',
      );
      final exams = await transaction.query(
        'examinations',
        columns: ['id', 'batch_history_id', 'total_marks'],
        where: 'id = ?',
        whereArgs: [examinationId],
        limit: 1,
      );
      if (exams.isEmpty) throw StateError('Examination not found.');
      final exam = exams.single;
      final roster = await transaction.query(
        'student_batch_history',
        columns: ['student_id'],
        where: 'batch_history_id = ? AND is_current = 1',
        whereArgs: [exam['batch_history_id']],
      );
      final rosterIds = roster.map((row) => row['student_id']! as int).toSet();
      final now = _now();
      for (final result in results) {
        if (!rosterIds.contains(result.studentId)) {
          throw StateError('Student is not in this batch academic year.');
        }
        if (result.attendanceStatus != 'present' &&
            result.attendanceStatus != 'absent') {
          throw const InvalidExamResultException();
        }
        if (result.attendanceStatus == 'absent' && result.marks != null) {
          throw const InvalidExamResultException();
        }
        if (result.attendanceStatus == 'present' &&
            (result.marks == null ||
                result.marks! < 0 ||
                result.marks! > (exam['total_marks']! as num))) {
          throw const InvalidExamResultException();
        }
        final values = {
          'examination_id': examinationId,
          'student_id': result.studentId,
          'attendance_status': result.attendanceStatus,
          'marks': result.attendanceStatus == 'absent' ? null : result.marks,
          'created_at': now,
          'updated_at': now,
        };
        final existing = await transaction.query(
          'exam_results',
          columns: ['id'],
          where: 'examination_id = ? AND student_id = ?',
          whereArgs: [examinationId, result.studentId],
          limit: 1,
        );
        if (existing.isEmpty) {
          await transaction.insert('exam_results', values);
        } else {
          await transaction.update(
            'exam_results',
            {
              'attendance_status': values['attendance_status'],
              'marks': values['marks'],
              'updated_at': now,
            },
            where: 'id = ?',
            whereArgs: [existing.single['id']],
          );
        }
      }
      await _auditLogs.record(
        database: transaction,
        userId: adminId,
        action: AuditActions.examinationResultsUpdated,
        module: 'examination_management',
        entityType: 'examination',
        entityId: examinationId,
        description: 'Admin updated examination marks and attendance.',
      );
    });
  }

  ExaminationAnalytics _analytics(List<Map<String, Object?>> students) {
    final present =
        students
            .where(
              (row) =>
                  row['attendance_status'] == 'present' && row['marks'] != null,
            )
            .toList()
          ..sort((a, b) => (b['marks']! as num).compareTo(a['marks']! as num));
    final absent = students
        .where((row) => row['attendance_status'] == 'absent')
        .length;
    final marks = present.map((row) => row['marks']! as num).toList();
    final ranking = <ExamRanking>[];
    for (var index = 0; index < present.length; index++) {
      final mark = present[index]['marks']! as num;
      final rank = index == 0 || mark != (present[index - 1]['marks']! as num)
          ? index + 1
          : ranking.last.rank;
      ranking.add(
        ExamRanking(
          studentId: present[index]['id']! as int,
          studentName: present[index]['full_name']! as String,
          marks: mark,
          rank: rank,
        ),
      );
    }
    return ExaminationAnalytics(
      presentCount: present.length,
      absentCount: absent,
      highest: marks.isEmpty ? null : marks.first,
      lowest: marks.isEmpty ? null : marks.last,
      average: marks.isEmpty
          ? null
          : marks.reduce((a, b) => a + b) / marks.length,
      rankings: ranking.where((item) => item.rank <= 3).toList(),
    );
  }

  String _now() => DateTime.now().toUtc().toIso8601String();
}

class ExaminationDetails {
  const ExaminationDetails({
    required this.examination,
    required this.students,
    required this.analytics,
  });
  final Map<String, Object?> examination;
  final List<Map<String, Object?>> students;
  final ExaminationAnalytics analytics;
}

class ExamMarkInput {
  const ExamMarkInput({
    required this.studentId,
    required this.attendanceStatus,
    this.marks,
  });
  final int studentId;
  final String attendanceStatus;
  final num? marks;
}

class ExaminationAnalytics {
  const ExaminationAnalytics({
    required this.presentCount,
    required this.absentCount,
    required this.highest,
    required this.lowest,
    required this.average,
    required this.rankings,
  });
  final int presentCount, absentCount;
  final num? highest, lowest, average;
  final List<ExamRanking> rankings;
}

class ExamRanking {
  const ExamRanking({
    required this.studentId,
    required this.studentName,
    required this.marks,
    required this.rank,
  });
  final int studentId, rank;
  final String studentName;
  final num marks;
}

class InvalidExaminationException implements Exception {
  const InvalidExaminationException();
}

class InvalidExamResultException implements Exception {
  const InvalidExamResultException();
}
