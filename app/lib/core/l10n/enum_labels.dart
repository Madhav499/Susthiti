import '../../data/models/care.dart';
import '../../data/models/patient.dart';
import '../../data/models/user.dart';
import '../../l10n/app_localizations.dart';

/// Localized display labels for all enum types used throughout the app.
/// Call these instead of using enum.label or enum.name directly to ensure proper translation.

String accessStatusLabel(AppLocalizations l10n, AccessStatus status) => switch (status) {
      AccessStatus.pending => l10n.accessStatusPending,
      AccessStatus.approved => l10n.accessStatusApproved,
      AccessStatus.rejected => l10n.accessStatusRejected,
      AccessStatus.revoked => l10n.accessStatusRevoked,
    };

String userRoleLabel(AppLocalizations l10n, UserRole role) => switch (role) {
      UserRole.patient => l10n.rolePatient,
      UserRole.doctor => l10n.roleDoctor,
      UserRole.admin => l10n.roleAdmin,
    };

String severityLabel(AppLocalizations l10n, Severity severity) => switch (severity) {
      Severity.mild => l10n.severityMild,
      Severity.moderate => l10n.severityModerate,
      Severity.severe => l10n.severitySevere,
      Severity.emergency => l10n.severityEmergency,
    };

String sideEffectStatusLabel(AppLocalizations l10n, SideEffectStatus status) => switch (status) {
      SideEffectStatus.newReport => l10n.sideEffectStatusNew,
      SideEffectStatus.underReview => l10n.sideEffectStatusUnderReview,
      SideEffectStatus.responded => l10n.sideEffectStatusResponded,
      SideEffectStatus.appointmentRecommended => l10n.sideEffectStatusAppointmentRecommended,
      SideEffectStatus.resolved => l10n.sideEffectStatusResolved,
    };

String followUpStatusLabel(AppLocalizations l10n, FollowUpStatus status) => switch (status) {
      FollowUpStatus.scheduled => l10n.followUpStatusUpcoming,
      FollowUpStatus.completed => l10n.followUpStatusPast,
      FollowUpStatus.cancelled => l10n.followUpStatusPast, // Use same as completed for now
    };

String genderLabel(AppLocalizations l10n, String gender) => switch (gender) {
      'Male' => l10n.genderMale,
      'Female' => l10n.genderFemale,
      _ => gender, // Fallback for unexpected values
    };
