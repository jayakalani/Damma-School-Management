import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:damma_school_management_system/core/batches/batch_repository.dart';
import 'package:damma_school_management_system/core/database/app_database.dart';
import 'package:damma_school_management_system/core/past_pupils/past_pupil_repository.dart';
import 'package:damma_school_management_system/core/reports/report_catalog.dart';
import 'package:damma_school_management_system/core/reports/report_query_service.dart';
import 'package:damma_school_management_system/core/students/student_repository.dart';
import 'package:damma_school_management_system/core/teachers/teacher_repository.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

Future<int> _createStaff(Database connection, int adminId) {
  return UserRepository().createStaff(
    database: connection,
    adminId: adminId,
    fullName: 'Staff User',
    username: 'staff.reports.${DateTime.now().microsecondsSinceEpoch}',
    password: 'StaffPassword123!',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database connection;
  late int adminId;
  late int staffId;
  late ReportQueryService service;

  setUp(() async {
    sqfliteFfiInit();
    final database = AppDatabase(factory: databaseFactoryFfi);
    connection = await database.openAt(
      'file:report_query_${DateTime.now().microsecondsSinceEpoch}?mode=memory&cache=shared',
    );
    adminId = (await connection.query('users')).single['id']! as int;
    staffId = await _createStaff(connection, adminId);
    service = ReportQueryService();
  });

  tearDown(() async {
    await connection.close();
  });

  test('filters teachers by status and registered date', () async {
    final teachers = TeacherRepository();
    await teachers.createTeacher(
      database: connection,
      adminId: adminId,
      details: {
        'full_name': 'Active Recent',
        'name_with_initials': 'A. Recent',
        'registered_date': '2026-03-01',
        'status': 'active',
        'nic': '900000001V',
      },
      qualifications: const [],
    );
    await teachers.createTeacher(
      database: connection,
      adminId: adminId,
      details: {
        'full_name': 'Active Older',
        'name_with_initials': 'A. Older',
        'registered_date': '2025-01-01',
        'status': 'active',
        'nic': '900000002V',
      },
      qualifications: const [],
    );
    await teachers.createTeacher(
      database: connection,
      adminId: adminId,
      details: {
        'full_name': 'Inactive Teacher',
        'name_with_initials': 'I. Teacher',
        'registered_date': '2026-03-01',
        'status': 'inactive',
        'nic': '900000003V',
      },
      qualifications: const [],
    );

    final byStatus = await service.loadReport(
      database: connection,
      userId: adminId,
      query: const ReportQuery(
        reportId: ReportId.teachers,
        status: 'inactive',
      ),
    );
    expect(byStatus.rows, hasLength(1));
    expect(byStatus.rows.single['full_name'], 'Inactive Teacher');
    expect(byStatus.rows.single['status'], 'Inactive');
    expect(byStatus.filterSummary, 'Status: Inactive');

    final byDate = await service.loadReport(
      database: connection,
      userId: adminId,
      query: ReportQuery(
        reportId: ReportId.teachers,
        status: 'active',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
      ),
    );
    expect(byDate.rows, hasLength(1));
    expect(byDate.rows.single['full_name'], 'Active Recent');
    expect(byDate.filterSummary, contains('From: 2026-01-01'));
  });

  test('filters students by current batch', () async {
    final students = StudentRepository();
    final batches = BatchRepository();
    await batches.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Alpha',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );
    await batches.createBatch(
      database: connection,
      adminId: staffId,
      name: 'Beta',
      startingYear: 2026,
      startingGrade: 'Grade 1',
    );
    final batchRows = await connection.query('batches', orderBy: 'batch_name');
    final alphaId = batchRows.first['id']! as int;
    final betaId = batchRows.last['id']! as int;

    final alphaStudent = await students.createStudent(
      database: connection,
      adminId: staffId,
      details: {
        'full_name': 'Alpha Student',
        'name_with_initials': 'A. Student',
        'joined_date': '2026-01-01',
      },
    );
    final betaStudent = await students.createStudent(
      database: connection,
      adminId: staffId,
      details: {
        'full_name': 'Beta Student',
        'name_with_initials': 'B. Student',
        'joined_date': '2026-01-01',
      },
    );
    await batches.addStudentToBatch(
      database: connection,
      adminId: adminId,
      batchId: alphaId,
      studentId: alphaStudent,
    );
    await batches.addStudentToBatch(
      database: connection,
      adminId: adminId,
      batchId: betaId,
      studentId: betaStudent,
    );

    final result = await service.loadReport(
      database: connection,
      userId: adminId,
      query: ReportQuery(
        reportId: ReportId.students,
        batchId: alphaId,
      ),
    );

    expect(result.rows, hasLength(1));
    expect(result.rows.single['full_name'], 'Alpha Student');
    expect(result.rows.single['batch_name'], 'Alpha');
    expect(result.filterSummary, 'Batch: Alpha');
  });

  test('joins historical past pupils to alumni batches', () async {
    final pastPupils = PastPupilRepository();
    final olderBatch = await pastPupils.createBatch(
      database: connection,
      adminId: adminId,
      name: '2018 Darmacharya',
      year: 2018,
    );
    final recentBatch = await pastPupils.createBatch(
      database: connection,
      adminId: adminId,
      name: '2022 Alumni',
      year: 2022,
    );
    await pastPupils.addPupil(
      database: connection,
      adminId: adminId,
      batchId: olderBatch,
      details: {'full_name': 'Older Alumni'},
    );
    await pastPupils.addPupil(
      database: connection,
      adminId: adminId,
      batchId: recentBatch,
      details: {'full_name': 'Recent Alumni'},
    );

    final byBatch = await service.loadReport(
      database: connection,
      userId: adminId,
      query: ReportQuery(
        reportId: ReportId.pastPupils,
        alumniBatchId: recentBatch,
      ),
    );
    expect(byBatch.rows, hasLength(1));
    expect(byBatch.rows.single['full_name'], 'Recent Alumni');
    expect(byBatch.rows.single['batch_name'], '2022 Alumni');
    expect(byBatch.rows.single['year_completed'], '2022');
    expect(byBatch.filterSummary, 'Alumni batch: 2022 Alumni');

    final byYear = await service.loadReport(
      database: connection,
      userId: adminId,
      query: ReportQuery(
        reportId: ReportId.pastPupils,
        startDate: DateTime(2020, 1, 1),
        endDate: DateTime(2026, 12, 31),
      ),
    );
    expect(byYear.rows, hasLength(1));
    expect(byYear.rows.single['full_name'], 'Recent Alumni');
  });

  test('returns an empty result when no rows match', () async {
    final result = await service.loadReport(
      database: connection,
      userId: adminId,
      query: const ReportQuery(
        reportId: ReportId.teachers,
        status: 'inactive',
      ),
    );

    expect(result.rows, isEmpty);
    expect(result.filterSummary, 'Status: Inactive');
  });
}
