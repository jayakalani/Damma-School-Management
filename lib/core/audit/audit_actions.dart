class AuditActions {
  const AuditActions._();

  static const staffCreated = 'staff_created';
  static const staffUpdated = 'staff_updated';
  static const staffStatusChanged = 'staff_status_changed';
  static const teacherCreated = 'teacher_created';
  static const teacherUpdated = 'teacher_updated';
  static const teacherStatusChanged = 'teacher_status_changed';
  static const batchCreated = 'batch_created';
  static const batchUpdated = 'batch_updated';
  static const batchPromoted = 'batch_promoted';
  static const studentAdded = 'student_added';
  static const studentUpdated = 'student_updated';
  static const studentPastPupil = 'student_changed_to_past_pupil';
  static const studentsBulkPastPupil = 'students_bulk_changed_to_past_pupils';
  static const batchTeacherChanged = 'batch_teacher_changed';
  static const examinationCreated = 'examination_created';
  static const examinationResultsUpdated = 'examination_results_updated';
  static const pastPupilBatchCreated = 'past_pupil_batch_created';
  static const backupCreated = 'backup_created';
}