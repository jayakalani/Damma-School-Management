import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../teachers/teacher_repository.dart';

/// Converts thrown errors into user-friendly messages for SnackBars/dialogs.
String userFacingError(
  Object error, {
  required String fallback,
}) {
  if (error is StateError) {
    return error.message;
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
  if (error is DatabaseException) {
    return 'A database error occurred. Please check your entries and try again.';
  }

  return fallback;
}
