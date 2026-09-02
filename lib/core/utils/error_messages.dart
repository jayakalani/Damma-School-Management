import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../students/student_repository.dart';
import '../teachers/teacher_repository.dart';
import '../users/user_repository.dart';

/// Converts thrown errors into user-friendly messages for SnackBars/dialogs.
String userFacingError(
  Object error, {
  required String fallback,
}) {
  if (error is StateError) {
    return error.message;
  }
  if (error is InvalidProfileDataException) {
    return error.message;
  }
  if (error is InvalidStudentException) {
    return 'Student details are invalid. Check required fields, dates, and phone number.';
  }
  if (error is TeacherHasAssignmentsException) {
    return 'This teacher is assigned to a batch and cannot be deleted.';
  }

  final message = error.toString();
  if (message.contains('UNIQUE constraint failed: teachers.nic')) {
    return 'A teacher with this NIC number already exists.';
  }
  if (message.contains('UNIQUE constraint failed: students.nic')) {
    return 'A student with this NIC number already exists.';
  }
  if (message.contains('UNIQUE constraint failed: users.username')) {
    return 'This username is already in use.';
  }
  if (message.contains('no column named is_active')) {
    return 'The student database needs an update. Fully close and reopen the app, then try again.';
  }
  if (message.contains('FOREIGN KEY constraint failed')) {
    return 'This record is linked to missing data. Refresh the page and try again.';
  }
  if (message.contains('CHECK constraint failed')) {
    return 'One of the values you entered is not allowed. Check the form and try again.';
  }

  final sqliteDetail = _sqliteDetail(message);
  if (sqliteDetail != null) {
    return sqliteDetail;
  }

  if (_isDatabaseError(error, message)) {
    return fallback;
  }

  return fallback;
}

bool _isDatabaseError(Object error, String message) =>
    error is DatabaseException ||
    message.contains('DatabaseException') ||
    message.contains('Sqflite');

String? _sqliteDetail(String message) {
  final match = RegExp(
    r'SqliteException\(\d+\): (?:while (?:preparing|executing) statement, )?(.+?)(?:, SQL logic error \(code \d+\))?(?:, constraint failed \(code \d+\))?',
  ).firstMatch(message);
  if (match == null) return null;

  final detail = match.group(1)!.trim();
  if (detail.startsWith('UNIQUE constraint failed:')) {
    return 'This value already exists in the system. Check for duplicates and try again.';
  }
  if (detail.startsWith('no column named ')) {
    final column = detail.replaceFirst('no column named ', '').trim();
    return 'The database is missing "$column". Fully close and reopen the app, then try again.';
  }
  if (detail == 'database is locked') {
    return 'The database is busy. Wait a moment and try again.';
  }
  return detail;
}
