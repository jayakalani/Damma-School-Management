class AuditActions {
  const AuditActions._();

  static const staffCreated = 'staff_created';
  static const staffUpdated = 'staff_updated';
  static const staffStatusChanged = 'staff_status_changed';
  static const staffDeleted = 'staff_deleted';
  static const teacherCreated = 'teacher_created';
  static const teacherUpdated = 'teacher_updated';
  static const teacherStatusChanged = 'teacher_status_changed';
  static const batchCreated = 'batch_created';
  static const batchUpdated = 'batch_updated';
  static const batchStatusChanged = 'batch_status_changed';
  static const batchPromoted = 'batch_promoted';
  static const studentAdded = 'student_added';
  static const studentUpdated = 'student_updated';
  static const studentPastPupil = 'student_changed_to_past_pupil';
  static const studentStatusChanged = 'student_status_changed';
  static const studentsBulkPastPupil = 'students_bulk_changed_to_past_pupils';
  static const batchTeacherChanged = 'batch_teacher_changed';
  static const examinationCreated = 'examination_created';
  static const examinationResultsUpdated = 'examination_results_updated';
  static const competitionCreated = 'competition_created';
  static const competitionBatchesAdded = 'competition_batches_added';
  static const competitionSectionCreated = 'competition_section_created';
  static const pastPupilBatchCreated = 'past_pupil_batch_created';
  static const backupCreated = 'backup_created';
  static const profileUpdated = 'profile_updated';
  static const passwordChanged = 'password_changed';
}