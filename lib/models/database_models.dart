class User {
  const User({this.id, required this.fullName, required this.username, required this.passwordHash, required this.role, required this.status, required this.createdAt, required this.updatedAt});
  final int? id; final String fullName, username, passwordHash, role, status, createdAt, updatedAt;
  factory User.fromMap(Map<String, Object?> map) => User(id: map['id'] as int?, fullName: map['full_name']! as String, username: map['username']! as String, passwordHash: map['password_hash']! as String, role: map['role']! as String, status: map['status']! as String, createdAt: map['created_at']! as String, updatedAt: map['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'full_name': fullName, 'username': username, 'password_hash': passwordHash, 'role': role, 'status': status, 'created_at': createdAt, 'updated_at': updatedAt};
}

class Teacher {
  const Teacher({this.id, required this.fullName, required this.nameWithInitials, this.dateOfBirth, this.nic, this.phoneNumber, this.address, required this.registeredDate, required this.status, this.bankAccountNumber, this.bankName, this.bankBranch, required this.createdAt, required this.updatedAt});
  final int? id; final String fullName, nameWithInitials, registeredDate, status, createdAt, updatedAt; final String? dateOfBirth, nic, phoneNumber, address, bankAccountNumber, bankName, bankBranch;
  factory Teacher.fromMap(Map<String, Object?> m) => Teacher(id: m['id'] as int?, fullName: m['full_name']! as String, nameWithInitials: m['name_with_initials']! as String, dateOfBirth: m['date_of_birth'] as String?, nic: m['nic'] as String?, phoneNumber: m['phone_number'] as String?, address: m['address'] as String?, registeredDate: m['registered_date']! as String, status: m['status']! as String, bankAccountNumber: m['bank_account_number'] as String?, bankName: m['bank_name'] as String?, bankBranch: m['bank_branch'] as String?, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'full_name': fullName, 'name_with_initials': nameWithInitials, 'date_of_birth': dateOfBirth, 'nic': nic, 'phone_number': phoneNumber, 'address': address, 'registered_date': registeredDate, 'status': status, 'bank_account_number': bankAccountNumber, 'bank_name': bankName, 'bank_branch': bankBranch, 'created_at': createdAt, 'updated_at': updatedAt};
}

class TeacherQualification {
  const TeacherQualification({this.id, required this.teacherId, required this.qualification, this.institution, this.completionYear, this.notes, required this.createdAt, required this.updatedAt});
  final int? id; final int teacherId; final String qualification, createdAt, updatedAt; final String? institution, notes; final int? completionYear;
  factory TeacherQualification.fromMap(Map<String, Object?> m) => TeacherQualification(id: m['id'] as int?, teacherId: m['teacher_id']! as int, qualification: m['qualification']! as String, institution: m['institution'] as String?, completionYear: m['completion_year'] as int?, notes: m['notes'] as String?, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'teacher_id': teacherId, 'qualification': qualification, 'institution': institution, 'completion_year': completionYear, 'notes': notes, 'created_at': createdAt, 'updated_at': updatedAt};
}

class Batch {
  const Batch({
    this.id,
    required this.batchName,
    required this.startingYear,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });
  final int? id, startingYear;
  final String batchName, createdAt, updatedAt;
  final bool isActive;
  factory Batch.fromMap(Map<String, Object?> m) => Batch(
    id: m['id'] as int?,
    batchName: m['batch_name']! as String,
    startingYear: m['starting_year']! as int,
    isActive: (m['is_active'] ?? 1) == 1,
    createdAt: m['created_at']! as String,
    updatedAt: m['updated_at']! as String,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'batch_name': batchName,
    'starting_year': startingYear,
    'is_active': isActive ? 1 : 0,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

class BatchHistory {
  const BatchHistory({this.id, required this.batchId, required this.academicYear, required this.grade, required this.startedDate, this.endedDate, required this.isCurrent, required this.createdAt, required this.updatedAt});
  final int? id, batchId, academicYear; final String grade, startedDate, createdAt, updatedAt; final String? endedDate; final bool isCurrent;
  factory BatchHistory.fromMap(Map<String, Object?> m) => BatchHistory(id: m['id'] as int?, batchId: m['batch_id']! as int, academicYear: m['academic_year']! as int, grade: m['grade']! as String, startedDate: m['started_date']! as String, endedDate: m['ended_date'] as String?, isCurrent: m['is_current'] == 1, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'batch_id': batchId, 'academic_year': academicYear, 'grade': grade, 'started_date': startedDate, 'ended_date': endedDate, 'is_current': isCurrent ? 1 : 0, 'created_at': createdAt, 'updated_at': updatedAt};
}

class Student {
  const Student({this.id, required this.fullName, required this.nameWithInitials, this.dateOfBirth, this.nic, this.phoneNumber, this.address, required this.joinedDate, required this.status, required this.createdAt, required this.updatedAt});
  final int? id; final String fullName, nameWithInitials, joinedDate, status, createdAt, updatedAt; final String? dateOfBirth, nic, phoneNumber, address;
  factory Student.fromMap(Map<String, Object?> m) => Student(id: m['id'] as int?, fullName: m['full_name']! as String, nameWithInitials: m['name_with_initials']! as String, dateOfBirth: m['date_of_birth'] as String?, nic: m['nic'] as String?, phoneNumber: m['phone_number'] as String?, address: m['address'] as String?, joinedDate: m['joined_date']! as String, status: m['status']! as String, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'full_name': fullName, 'name_with_initials': nameWithInitials, 'date_of_birth': dateOfBirth, 'nic': nic, 'phone_number': phoneNumber, 'address': address, 'joined_date': joinedDate, 'status': status, 'created_at': createdAt, 'updated_at': updatedAt};
}

class StudentBatchHistory {
  const StudentBatchHistory({this.id, required this.studentId, required this.batchId, required this.batchHistoryId, required this.joinedDate, this.leftDate, required this.isCurrent, required this.createdAt, required this.updatedAt});
  final int? id, studentId, batchId, batchHistoryId; final String joinedDate, createdAt, updatedAt; final String? leftDate; final bool isCurrent;
  factory StudentBatchHistory.fromMap(Map<String, Object?> m) => StudentBatchHistory(id: m['id'] as int?, studentId: m['student_id']! as int, batchId: m['batch_id']! as int, batchHistoryId: m['batch_history_id']! as int, joinedDate: m['joined_date']! as String, leftDate: m['left_date'] as String?, isCurrent: m['is_current'] == 1, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'student_id': studentId, 'batch_id': batchId, 'batch_history_id': batchHistoryId, 'joined_date': joinedDate, 'left_date': leftDate, 'is_current': isCurrent ? 1 : 0, 'created_at': createdAt, 'updated_at': updatedAt};
}

class BatchTeacherHistory {
  const BatchTeacherHistory({this.id, required this.batchHistoryId, required this.teacherId, required this.assignedDate, this.removedDate, required this.isCurrent, required this.createdAt, required this.updatedAt});
  final int? id, batchHistoryId, teacherId; final String assignedDate, createdAt, updatedAt; final String? removedDate; final bool isCurrent;
  factory BatchTeacherHistory.fromMap(Map<String, Object?> m) => BatchTeacherHistory(id: m['id'] as int?, batchHistoryId: m['batch_history_id']! as int, teacherId: m['teacher_id']! as int, assignedDate: m['assigned_date']! as String, removedDate: m['removed_date'] as String?, isCurrent: m['is_current'] == 1, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'batch_history_id': batchHistoryId, 'teacher_id': teacherId, 'assigned_date': assignedDate, 'removed_date': removedDate, 'is_current': isCurrent ? 1 : 0, 'created_at': createdAt, 'updated_at': updatedAt};
}

class Examination {
  const Examination({
    this.id,
    required this.examinationName,
    required this.examinationDate,
    required this.totalMarks,
    required this.createdAt,
    required this.updatedAt,
  });
  final int? id;
  final String examinationName, examinationDate, createdAt, updatedAt;
  final num totalMarks;
  factory Examination.fromMap(Map<String, Object?> m) => Examination(
    id: m['id'] as int?,
    examinationName: m['examination_name']! as String,
    examinationDate: m['examination_date']! as String,
    totalMarks: m['total_marks']! as num,
    createdAt: m['created_at']! as String,
    updatedAt: m['updated_at']! as String,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'examination_name': examinationName,
    'examination_date': examinationDate,
    'total_marks': totalMarks,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };
}

class ExamResult {
  const ExamResult({this.id, required this.examinationId, required this.studentId, required this.attendanceStatus, this.marks, required this.createdAt, required this.updatedAt});
  final int? id, examinationId, studentId; final String attendanceStatus, createdAt, updatedAt; final num? marks;
  factory ExamResult.fromMap(Map<String, Object?> m) => ExamResult(id: m['id'] as int?, examinationId: m['examination_id']! as int, studentId: m['student_id']! as int, attendanceStatus: m['attendance_status']! as String, marks: m['marks'] as num?, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'examination_id': examinationId, 'student_id': studentId, 'attendance_status': attendanceStatus, 'marks': marks, 'created_at': createdAt, 'updated_at': updatedAt};
}

class PastPupilBatch {
  const PastPupilBatch({this.id, required this.batchName, required this.yearCompleted, this.notes, required this.createdAt, required this.updatedAt});
  final int? id, yearCompleted; final String batchName, createdAt, updatedAt; final String? notes;
  factory PastPupilBatch.fromMap(Map<String, Object?> m) => PastPupilBatch(id: m['id'] as int?, batchName: m['batch_name']! as String, yearCompleted: m['year_completed']! as int, notes: m['notes'] as String?, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'batch_name': batchName, 'year_completed': yearCompleted, 'notes': notes, 'created_at': createdAt, 'updated_at': updatedAt};
}

class HistoricalPastPupil {
  const HistoricalPastPupil({this.id, required this.pastPupilBatchId, required this.fullName, this.nameWithInitials, this.dateOfBirth, this.nic, this.phoneNumber, this.address, this.notes, required this.createdAt, required this.updatedAt});
  final int? id, pastPupilBatchId; final String fullName, createdAt, updatedAt; final String? nameWithInitials, dateOfBirth, nic, phoneNumber, address, notes;
  factory HistoricalPastPupil.fromMap(Map<String, Object?> m) => HistoricalPastPupil(id: m['id'] as int?, pastPupilBatchId: m['past_pupil_batch_id']! as int, fullName: m['full_name']! as String, nameWithInitials: m['name_with_initials'] as String?, dateOfBirth: m['date_of_birth'] as String?, nic: m['nic'] as String?, phoneNumber: m['phone_number'] as String?, address: m['address'] as String?, notes: m['notes'] as String?, createdAt: m['created_at']! as String, updatedAt: m['updated_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'past_pupil_batch_id': pastPupilBatchId, 'full_name': fullName, 'name_with_initials': nameWithInitials, 'date_of_birth': dateOfBirth, 'nic': nic, 'phone_number': phoneNumber, 'address': address, 'notes': notes, 'created_at': createdAt, 'updated_at': updatedAt};
}

class AuditLog {
  const AuditLog({this.id, required this.userId, required this.action, required this.module, this.entityType, this.entityId, required this.description, required this.createdAt});
  final int? id, userId, entityId; final String action, module, description, createdAt; final String? entityType;
  factory AuditLog.fromMap(Map<String, Object?> m) => AuditLog(id: m['id'] as int?, userId: m['user_id']! as int, action: m['action']! as String, module: m['module']! as String, entityType: m['entity_type'] as String?, entityId: m['entity_id'] as int?, description: m['description']! as String, createdAt: m['created_at']! as String);
  Map<String, Object?> toMap() => {'id': id, 'user_id': userId, 'action': action, 'module': module, 'entity_type': entityType, 'entity_id': entityId, 'description': description, 'created_at': createdAt};
}
