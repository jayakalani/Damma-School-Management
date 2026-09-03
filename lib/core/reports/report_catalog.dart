enum ReportId {
  teachers,
  students,
  batches,
  pastPupils,
  examinations,
  competitions,
}

enum ReportFilter {
  teacherStatus,
  studentStatus,
  batchStatus,
  currentBatch,
  alumniBatch,
  dateRange,
}

class ReportField {
  const ReportField({
    required this.key,
    required this.label,
    this.selectedByDefault = false,
  });

  final String key;
  final String label;
  final bool selectedByDefault;
}

class ReportDefinition {
  const ReportDefinition({
    required this.id,
    required this.title,
    required this.fileStem,
    required this.filters,
    required this.fields,
    this.emptyFilterSummary = 'All records',
  });

  final ReportId id;
  final String title;
  final String description = 'Tabular export with field selection';
  final String fileStem;
  final List<ReportFilter> filters;
  final List<ReportField> fields;
  final String emptyFilterSummary;

  Set<String> get defaultFieldKeys => {
        for (final field in fields)
          if (field.selectedByDefault) field.key,
      };
}

class ReportCatalog {
  const ReportCatalog._();

  static const all = [
    teachers,
    students,
    batches,
    pastPupils,
    examinations,
    competitions,
  ];

  static ReportDefinition byId(ReportId id) =>
      all.firstWhere((report) => report.id == id);

  static const teachers = ReportDefinition(
    id: ReportId.teachers,
    title: 'Teachers',
    fileStem: 'teachers',
    emptyFilterSummary: 'All teachers',
    filters: [
      ReportFilter.teacherStatus,
      ReportFilter.dateRange,
    ],
    fields: [
      ReportField(key: 'full_name', label: 'Full name', selectedByDefault: true),
      ReportField(
        key: 'name_with_initials',
        label: 'Initials',
        selectedByDefault: true,
      ),
      ReportField(key: 'nic', label: 'NIC', selectedByDefault: true),
      ReportField(key: 'phone_number', label: 'Phone', selectedByDefault: true),
      ReportField(key: 'address', label: 'Address'),
      ReportField(key: 'date_of_birth', label: 'Date of birth'),
      ReportField(
        key: 'registered_date',
        label: 'Registered date',
        selectedByDefault: true,
      ),
      ReportField(key: 'status', label: 'Status', selectedByDefault: true),
      ReportField(key: 'bank_name', label: 'Bank name'),
      ReportField(key: 'bank_branch', label: 'Bank branch'),
      ReportField(key: 'bank_account_number', label: 'Account number'),
    ],
  );

  static const students = ReportDefinition(
    id: ReportId.students,
    title: 'Students',
    fileStem: 'students',
    emptyFilterSummary: 'All students',
    filters: [
      ReportFilter.studentStatus,
      ReportFilter.currentBatch,
      ReportFilter.dateRange,
    ],
    fields: [
      ReportField(key: 'full_name', label: 'Full name', selectedByDefault: true),
      ReportField(
        key: 'name_with_initials',
        label: 'Initials',
        selectedByDefault: true,
      ),
      ReportField(key: 'nic', label: 'NIC', selectedByDefault: true),
      ReportField(key: 'phone_number', label: 'Phone', selectedByDefault: true),
      ReportField(key: 'address', label: 'Address'),
      ReportField(key: 'date_of_birth', label: 'Date of birth'),
      ReportField(
        key: 'joined_date',
        label: 'Joined date',
        selectedByDefault: true,
      ),
      ReportField(key: 'status', label: 'Status', selectedByDefault: true),
      ReportField(key: 'is_active', label: 'Active', selectedByDefault: true),
      ReportField(key: 'batch_name', label: 'Batch', selectedByDefault: true),
      ReportField(key: 'grade', label: 'Grade'),
      ReportField(key: 'academic_year', label: 'Academic year'),
    ],
  );

  static const batches = ReportDefinition(
    id: ReportId.batches,
    title: 'Batches',
    fileStem: 'batches',
    emptyFilterSummary: 'All batches',
    filters: [ReportFilter.batchStatus],
    fields: [
      ReportField(
        key: 'batch_name',
        label: 'Batch name',
        selectedByDefault: true,
      ),
      ReportField(
        key: 'starting_year',
        label: 'Starting year',
        selectedByDefault: true,
      ),
      ReportField(key: 'status', label: 'Status', selectedByDefault: true),
      ReportField(key: 'grade', label: 'Current grade', selectedByDefault: true),
      ReportField(
        key: 'academic_year',
        label: 'Academic year',
        selectedByDefault: true,
      ),
      ReportField(key: 'started_date', label: 'Started date'),
    ],
  );

  static const pastPupils = ReportDefinition(
    id: ReportId.pastPupils,
    title: 'Past Pupils',
    fileStem: 'past_pupils',
    emptyFilterSummary: 'All past pupils',
    filters: [
      ReportFilter.alumniBatch,
      ReportFilter.dateRange,
    ],
    fields: [
      ReportField(key: 'full_name', label: 'Full name', selectedByDefault: true),
      ReportField(
        key: 'name_with_initials',
        label: 'Initials',
        selectedByDefault: true,
      ),
      ReportField(key: 'nic', label: 'NIC', selectedByDefault: true),
      ReportField(key: 'phone_number', label: 'Phone', selectedByDefault: true),
      ReportField(key: 'address', label: 'Address'),
      ReportField(key: 'date_of_birth', label: 'Date of birth'),
      ReportField(
        key: 'batch_name',
        label: 'Alumni batch',
        selectedByDefault: true,
      ),
      ReportField(
        key: 'year_completed',
        label: 'Year completed',
        selectedByDefault: true,
      ),
      ReportField(key: 'notes', label: 'Notes'),
    ],
  );

  static const examinations = ReportDefinition(
    id: ReportId.examinations,
    title: 'Examinations',
    fileStem: 'examinations',
    emptyFilterSummary: 'All examinations',
    filters: [ReportFilter.dateRange],
    fields: [
      ReportField(
        key: 'examination_name',
        label: 'Name',
        selectedByDefault: true,
      ),
      ReportField(key: 'examination_date', label: 'Date', selectedByDefault: true),
      ReportField(
        key: 'total_marks',
        label: 'Total marks',
        selectedByDefault: true,
      ),
    ],
  );

  static const competitions = ReportDefinition(
    id: ReportId.competitions,
    title: 'Competitions',
    fileStem: 'competitions',
    emptyFilterSummary: 'All competitions',
    filters: [ReportFilter.dateRange],
    fields: [
      ReportField(
        key: 'competition_name',
        label: 'Name',
        selectedByDefault: true,
      ),
      ReportField(
        key: 'competition_date',
        label: 'Date',
        selectedByDefault: true,
      ),
      ReportField(key: 'venue', label: 'Venue', selectedByDefault: true),
      ReportField(key: 'description', label: 'Description'),
    ],
  );
}
