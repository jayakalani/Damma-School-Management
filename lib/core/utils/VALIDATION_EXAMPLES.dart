/// Example: Enhanced Repository with Comprehensive Input Validation and Sanitization
/// 
/// This file demonstrates best practices for validating and sanitizing inputs
/// before storing them in the database.
/// 
/// Copy and adapt this pattern to other repositories.

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:damma_school_management_system/core/utils/validators.dart';

class StudentRepositoryExample {
  /// Create a new student with full validation and sanitization
  /// 
  /// This method demonstrates the complete validation flow:
  /// 1. Validate all inputs against business rules
  /// 2. Sanitize inputs for safe storage
  /// 3. Check for duplicates
  /// 4. Store in database
  /// 5. Log audit trail
  /// 
  /// Throws ValidationError if validation fails
  Future<int> createStudent({
    required DatabaseExecutor db,
    required String userId,
    required String fullName,
    required String studentId,
    required String batch,
    String? dateOfBirth,
    String? phone,
  }) async {
    // ========================================================================
    // STEP 1: VALIDATE ALL INPUTS
    // ========================================================================
    final errors = InputValidator.validateStudent(
      fullName: fullName,
      studentId: studentId,
      batch: batch,
      dateOfBirth: dateOfBirth,
      phone: phone,
    );
    
    if (errors.isNotEmpty) {
      throw ValidationError(
        field: 'student',
        message: errors.join('; '),
      );
    }
    
    // ========================================================================
    // STEP 2: SANITIZE INPUTS FOR SAFE STORAGE
    // ========================================================================
    final sanitizedName = InputSanitizer.sanitizeText(fullName);
    final sanitizedId = InputSanitizer.sanitizeText(studentId);
    final sanitizedPhone = phone != null 
        ? InputSanitizer.sanitizePhone(phone) 
        : null;
    
    // ========================================================================
    // STEP 3: CHECK FOR DUPLICATES (only after validation/sanitization)
    // ========================================================================
    final existing = await db.query(
      'students',
      where: 'student_id = ?',
      whereArgs: [sanitizedId],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      throw StateError('Student ID "$sanitizedId" already exists');
    }
    
    // ========================================================================
    // STEP 4: INSERT INTO DATABASE
    // ========================================================================
    final studentId = await db.insert('students', {
      'full_name': sanitizedName,
      'student_id': sanitizedId,
      'batch': batch,
      'date_of_birth': dateOfBirth,  // Already validated
      'phone': sanitizedPhone,
      'status': 'active',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    
    // ========================================================================
    // STEP 5: LOG TO AUDIT TRAIL
    // ========================================================================
    await db.insert('audit_logs', {
      'user_id': int.parse(userId),
      'action': 'created',
      'module': 'students',
      'entity_type': 'student',
      'entity_id': studentId,
      'description': 'Created student: $sanitizedName (ID: $sanitizedId)',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    
    return studentId;
  }
  
  /// Update student with validation and sanitization
  /// 
  /// Only updates fields that are provided (optional fields)
  Future<void> updateStudent({
    required DatabaseExecutor db,
    required String userId,
    required int studentId,
    String? fullName,
    String? batch,
    String? dateOfBirth,
    String? phone,
  }) async {
    // Validate only provided fields
    if (fullName != null && InputValidator.requiredText(fullName, fieldName: 'Full Name') != null) {
      throw ValidationError(
        field: 'fullName',
        message: 'Full Name is required',
      );
    }
    
    if (dateOfBirth != null && InputValidator.dateOfBirth(dateOfBirth) != null) {
      throw ValidationError(
        field: 'dateOfBirth',
        message: InputValidator.dateOfBirth(dateOfBirth) ?? 'Invalid date',
      );
    }
    
    if (phone != null && InputValidator.phone(phone) != null) {
      throw ValidationError(
        field: 'phone',
        message: InputValidator.phone(phone) ?? 'Invalid phone',
      );
    }
    
    // Build update map with only provided fields
    final updateMap = <String, Object?>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    
    if (fullName != null) {
      updateMap['full_name'] = InputSanitizer.sanitizeText(fullName);
    }
    if (batch != null) {
      updateMap['batch'] = batch;
    }
    if (dateOfBirth != null) {
      updateMap['date_of_birth'] = dateOfBirth;
    }
    if (phone != null) {
      updateMap['phone'] = InputSanitizer.sanitizePhone(phone);
    }
    
    // Update database
    await db.update(
      'students',
      updateMap,
      where: 'id = ?',
      whereArgs: [studentId],
    );
    
    // Log audit trail
    await db.insert('audit_logs', {
      'user_id': int.parse(userId),
      'action': 'updated',
      'module': 'students',
      'entity_type': 'student',
      'entity_id': studentId,
      'description': 'Updated student record',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
  
  /// Search students with sanitized input
  /// 
  /// Properly escapes search terms to prevent SQL injection
  Future<List<Map<String, Object?>>> search({
    required DatabaseExecutor db,
    String? query,
    String? batch,
  }) async {
    final conditions = <String>[];
    final args = <Object?>[];
    
    // Sanitize and escape search query
    if (query != null && query.isNotEmpty) {
      final sanitized = InputSanitizer.sanitizeForSearch(query);
      conditions.add('(full_name LIKE ? OR student_id LIKE ?)');
      final pattern = '%$sanitized%';
      args.addAll([pattern, pattern]);
    }
    
    if (batch != null && batch.isNotEmpty) {
      conditions.add('batch = ?');
      args.add(batch);
    }
    
    final whereClause = conditions.isEmpty 
        ? '' 
        : 'WHERE ${conditions.join(" AND ")}';
    
    return db.rawQuery(
      'SELECT * FROM students $whereClause ORDER BY full_name COLLATE NOCASE',
      args,
    );
  }
}

/// Example: Form with Inline Validation (UI Layer)
/// 
/// This demonstrates how to use validators in a widget

class CreateStudentFormExample {
  /// Example form builder
  /// 
  /// In a real widget, this would be in a StatefulWidget's build() method
  static Widget buildForm({
    required TextEditingController nameController,
    required TextEditingController idController,
    required VoidCallback onSubmit,
  }) {
    return Form(
      child: Column(
        children: [
          // Full Name field with validation
          TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'e.g., John Doe',
              helperText: '2-150 characters',
            ),
            validator: (value) => InputValidator.textLength(
              value,
              minLength: 2,
              maxLength: 150,
              fieldName: 'Full Name',
            ),
            onChanged: (value) {
              // Real-time validation feedback
              final error = InputValidator.textLength(
                value,
                minLength: 2,
                maxLength: 150,
                fieldName: 'Full Name',
              );
              // Update UI with error
            },
          ),
          const SizedBox(height: 16),
          
          // Student ID field with validation
          TextFormField(
            controller: idController,
            decoration: const InputDecoration(
              labelText: 'Student ID',
              hintText: 'e.g., STU-2024-001',
            ),
            validator: (value) => InputValidator.requiredText(
              value,
              fieldName: 'Student ID',
            ),
          ),
          const SizedBox(height: 16),
          
          // Phone field (optional) with validation
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Phone (Optional)',
              hintText: '0771234567 or +94771234567',
              helperText: 'Must be valid Sri Lankan number',
            ),
            validator: (value) => value != null && value.isNotEmpty
                ? InputValidator.phone(value)
                : null,
            // Auto-format as user types
            onChanged: (value) {
              // Optionally auto-sanitize display
            },
          ),
          const SizedBox(height: 24),
          
          // Submit button
          ElevatedButton(
            onPressed: onSubmit,
            child: const Text('Create Student'),
          ),
        ],
      ),
    );
  }
}

/// Example: Service Layer with Validation
/// 
/// This shows validation at the service layer before calling repository

class StudentService {
  final StudentRepositoryExample _repository = StudentRepositoryExample();
  
  /// High-level service method with comprehensive validation
  /// 
  /// This layer:
  /// 1. Validates inputs
  /// 2. Performs business logic (check permissions, etc.)
  /// 3. Calls repository
  /// 4. Handles errors gracefully
  Future<void> registerNewStudent({
    required DatabaseExecutor db,
    required String userId,
    required String fullName,
    required String studentId,
    required String batch,
    String? dateOfBirth,
    String? phone,
  }) async {
    try {
      // Validate inputs
      final errors = InputValidator.validateStudent(
        fullName: fullName,
        studentId: studentId,
        batch: batch,
        dateOfBirth: dateOfBirth,
        phone: phone,
      );
      
      if (errors.isNotEmpty) {
        throw ValidationError(
          field: 'student',
          message: errors.join('\n'),
        );
      }
      
      // Call repository (which will also validate)
      await _repository.createStudent(
        db: db,
        userId: userId,
        fullName: fullName,
        studentId: studentId,
        batch: batch,
        dateOfBirth: dateOfBirth,
        phone: phone,
      );
      
    } on ValidationError catch (e) {
      // Handle validation errors
      rethrow;
    } catch (e) {
      // Handle other errors
      throw Exception('Failed to register student: $e');
    }
  }
}

/// Example: Error Handling in Widget

class CreateStudentPageExample {
  /// Example of error handling in a page
  static Future<void> handleCreateStudent({
    required DatabaseExecutor database,
    required String userId,
    required String fullName,
    required String studentId,
    required String batch,
    required Function(String) showError,
    required Function(String) showSuccess,
  }) async {
    final service = StudentService();
    
    try {
      // Attempt to create student
      await service.registerNewStudent(
        db: database,
        userId: userId,
        fullName: fullName,
        studentId: studentId,
        batch: batch,
      );
      
      // Success
      showSuccess('Student created successfully');
      
    } on ValidationError catch (e) {
      // Validation error - show all errors to user
      showError('Validation failed:\n${e.message}');
      
    } on StateError catch (e) {
      // Business logic error (e.g., duplicate ID)
      showError(e.message);
      
    } catch (e) {
      // Unexpected error
      showError('An error occurred: $e');
    }
  }
}

/// Best Practices Summary
/// 
/// ✅ DO:
/// - Validate ALL user inputs
/// - Sanitize before database storage
/// - Use parameterized queries
/// - Handle validation errors gracefully
/// - Log important operations
/// - Test validation thoroughly
/// - Show clear error messages to users
/// - Sanitize search inputs
/// 
/// ❌ DON'T:
/// - Skip validation for "trusted" sources
/// - Use string interpolation in SQL queries
/// - Store raw user input directly
/// - Ignore validation errors
/// - Mix business logic with validation
/// - Store unencrypted sensitive data
/// - Trust frontend validation alone
