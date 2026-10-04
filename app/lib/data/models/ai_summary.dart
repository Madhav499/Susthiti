import '../../core/utils/formatters.dart';

enum AISummaryKind {
  individualReport('individual_report', 'Individual Report Summary'),
  allReports('all_reports', 'All Reports Summary'),
  patientSummary('patient_summary', 'AI Patient Summary'),
  patientFriendlySummary('patient_friendly_summary', 'Your Health Summary'),
  lifestyle('lifestyle', 'Lifestyle Insight'),
  assessmentInterpretation('assessment_interpretation', 'Assessment Interpretation'),
  heartInterpretation('heart_interpretation', 'Heart Risk Screening Interpretation');

  const AISummaryKind(this.apiValue, this.label);
  final String apiValue;
  final String label;

  static AISummaryKind parse(String v) => values.firstWhere((k) => k.apiValue == v);

  String get pdfFileLabel => switch (this) {
        individualReport => 'Individual_Report_Summary',
        allReports => 'All_Reports_Summary',
        patientSummary => 'Patient_Summary',
        patientFriendlySummary => 'Your_Health_Summary',
        lifestyle => 'Lifestyle_Insight',
        assessmentInterpretation => 'Assessment_Interpretation',
        heartInterpretation => 'Heart_Risk_Screening_Interpretation',
      };
}

/// A stored AI generation. Content is the structured JSON returned by the backend service.
class AISummary {
  const AISummary({
    required this.id,
    required this.kind,
    required this.content,
    required this.generatedAt,
    required this.model,
    required this.provider,
    this.basedOn = const [],
    this.isStale = false,
    this.generatedByRole,
  });

  final String id;
  final AISummaryKind kind;
  final Map<String, dynamic> content;
  final DateTime generatedAt;
  final String model;
  final String provider;
  final List<String> basedOn;
  final bool isStale;
  final String? generatedByRole;

  String text(String key) => (content[key] as String?)?.trim() ?? '';
  List<String> list(String key) => [for (final v in (content[key] as List? ?? const [])) if (v is String) v];
  List<Map<String, dynamic>> maps(String key) => [for (final v in (content[key] as List? ?? const [])) if (v is Map<String, dynamic>) v];
  String get disclaimer => text('disclaimer');

  /// e.g. SUSTHITI_Patient_Summary_2026-09-24.pdf
  String get pdfFilename => 'SUSTHITI_${kind.pdfFileLabel}_${Fmt.isoDate(generatedAt.toUtc())}.pdf';

  factory AISummary.fromJson(Map<String, dynamic> j) => AISummary(
        id: j['id'] as String,
        kind: AISummaryKind.parse(j['kind'] as String),
        content: Map<String, dynamic>.from(j['content'] as Map),
        generatedAt: parseDate(j['generated_at'])!,
        model: j['model'] as String? ?? '',
        provider: j['provider'] as String? ?? '',
        basedOn: [for (final v in (j['based_on'] as List? ?? const [])) v as String],
        isStale: j['is_stale'] as bool? ?? false,
        generatedByRole: j['generated_by_role'] as String?,
      );
}
