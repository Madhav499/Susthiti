import '../../core/utils/formatters.dart';

/// Report categories, in the order the upload screen asks "What type of report is this?".
enum ReportCategory {
  fullBody('full_body', 'Full Body Checkup'),
  bloodReport('blood_report', 'Blood Report'),
  hba1c('hba1c', 'HbA1c'),
  bloodGlucose('blood_glucose', 'Blood Glucose'),
  lipidProfile('lipid_profile', 'Lipid Profile'),
  kidneyFunction('kidney_function', 'Kidney Function'),
  liverFunction('liver_function', 'Liver Function'),
  urineTest('urine_test', 'Urine Test'),
  xRay('x_ray', 'X-Ray'),
  mri('mri', 'MRI'),
  ct('ct', 'CT'),
  ecg('ecg', 'ECG'),
  other('other', 'Other');

  const ReportCategory(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static ReportCategory parse(String v) => values.firstWhere((c) => c.apiValue == v, orElse: () => other);
}

/// Filter groups on the reports list (All / Blood / HbA1c / Imaging / Other).
enum ReportFilterGroup {
  all('all', 'All'),
  blood('blood', 'Blood'),
  hba1c('hba1c', 'HbA1c'),
  imaging('imaging', 'Imaging'),
  other('other', 'Other');

  const ReportFilterGroup(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class Uploader {
  const Uploader({required this.role, required this.userId, required this.name});
  final String role;
  final String userId;
  final String name;

  String get roleLabel => Fmt.titleCase(role);
  String get display => role == 'doctor' ? 'Dr. $name' : name;
}

class MedicalReport {
  const MedicalReport({
    required this.id,
    required this.reportCode,
    required this.patientId,
    required this.category,
    this.categories = const [],
    required this.reportDate,
    required this.uploadedAt,
    required this.uploadedBy,
    required this.originalFilename,
    required this.fileType,
    required this.fileSize,
    this.description,
  });

  final String id;
  final String reportCode;
  final String patientId;
  /// The primary type (the first one chosen).
  final ReportCategory category;

  /// Every type the report covers (e.g. Full Body Checkup and HbA1c).
  final List<ReportCategory> categories;

  List<ReportCategory> get allCategories => categories.isEmpty ? [category] : categories;

  /// Medical event date (what the report is about).
  final DateTime reportDate;

  /// When it was uploaded to SUSTHITI. Never merged with [reportDate].
  final DateTime uploadedAt;
  final Uploader uploadedBy;
  final String originalFilename;
  final String fileType;
  final int fileSize;
  final String? description;

  bool get isPdf => fileType == 'application/pdf';
  bool get isImage => fileType.startsWith('image/');
  String get title {
    final names = allCategories.map((c) => c == ReportCategory.bloodReport ? 'Blood' : c.label).toList();
    return '${names.join(', ')} Report';
  }

  factory MedicalReport.fromJson(Map<String, dynamic> j) {
    final u = j['uploaded_by'] as Map<String, dynamic>;
    return MedicalReport(
      id: j['id'] as String,
      reportCode: j['report_code'] as String,
      patientId: j['patient_id'] as String,
      category: ReportCategory.parse(j['category'] as String),
      categories: [for (final c in j['categories'] as List? ?? const []) ReportCategory.parse(c as String)],
      reportDate: parseDate(j['report_date'])!,
      uploadedAt: parseDate(j['uploaded_at'])!,
      uploadedBy: Uploader(role: u['role'] as String, userId: u['user_id'] as String, name: u['name'] as String),
      originalFilename: j['original_filename'] as String,
      fileType: j['file_type'] as String,
      fileSize: j['file_size'] as int,
      description: j['description'] as String?,
    );
  }
}

class ReportQuery {
  const ReportQuery({this.search = '', this.group = ReportFilterGroup.all, this.start, this.end, this.newestFirst = true});
  final String search;
  final ReportFilterGroup group;
  final DateTime? start;
  final DateTime? end;
  final bool newestFirst;

  ReportQuery copyWith({String? search, ReportFilterGroup? group, DateTime? start, DateTime? end, bool? newestFirst, bool clearDates = false}) => ReportQuery(
        search: search ?? this.search,
        group: group ?? this.group,
        start: clearDates ? null : (start ?? this.start),
        end: clearDates ? null : (end ?? this.end),
        newestFirst: newestFirst ?? this.newestFirst,
      );

  bool get hasFilters => group != ReportFilterGroup.all || start != null || end != null || !newestFirst;

  @override
  bool operator ==(Object other) =>
      other is ReportQuery && other.search == search && other.group == group && other.start == start && other.end == end && other.newestFirst == newestFirst;

  @override
  int get hashCode => Object.hash(search, group, start, end, newestFirst);
}

class ReportPage {
  const ReportPage({required this.items, required this.total});
  final List<MedicalReport> items;
  final int total;
}
