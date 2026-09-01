import 'package:damma_school_management_system/core/audit/audit_log_repository.dart';
import 'package:damma_school_management_system/core/batches/batch_repository.dart';
import 'package:damma_school_management_system/core/examinations/examination_repository.dart';
import 'package:damma_school_management_system/core/students/student_repository.dart';
import 'package:damma_school_management_system/core/teachers/teacher_repository.dart';
import 'package:damma_school_management_system/core/users/user_repository.dart';

/// Centralized repository provider for all data access layers.
/// 
/// This follows the Factory Pattern to create repository instances.
/// Repositories are typically created fresh in each page for isolation.
/// 
/// Usage:
/// ```dart
/// class StudentManagementPage extends StatefulWidget {
///   final Database database;
///   
///   @override
///   State<StudentManagementPage> createState() => _StudentManagementPageState();
/// }
/// 
/// class _StudentManagementPageState extends State<StudentManagementPage> {
///   late final StudentRepository _studentRepo;
///   late final AuditLogRepository _auditRepo;
///   
///   @override
///   void initState() {
///     super.initState();
///     _studentRepo = RepositoryProvider.studentRepository;
///     _auditRepo = RepositoryProvider.auditLogRepository;
///   }
/// }
/// ```
class RepositoryProvider {
  // Private constructor - this is a utility class
  RepositoryProvider._();
  
  /// Creates a new StudentRepository instance
  static StudentRepository get studentRepository => StudentRepository();
  
  /// Creates a new TeacherRepository instance
  static TeacherRepository get teacherRepository => TeacherRepository();
  
  /// Creates a new BatchRepository instance
  static BatchRepository get batchRepository => BatchRepository();
  
  /// Creates a new ExaminationRepository instance
  static ExaminationRepository get examinationRepository => ExaminationRepository();
  
  /// Creates a new UserRepository instance
  static UserRepository get userRepository => UserRepository();
  
  /// Creates a new AuditLogRepository instance
  static AuditLogRepository get auditLogRepository => AuditLogRepository();
  
  /// Get all repositories at once (useful for dependency injection)
  static Map<String, dynamic> getAllRepositories() => {
    'student': studentRepository,
    'teacher': teacherRepository,
    'batch': batchRepository,
    'examination': examinationRepository,
    'user': userRepository,
    'auditLog': auditLogRepository,
  };
}
