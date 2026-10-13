// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonTryAgain => 'Try Again';

  @override
  String get commonLoading => 'Loading';

  @override
  String get commonViewAll => 'View all';

  @override
  String get commonNoData => 'No data';

  @override
  String get errorUnableToLoad => 'Unable to load this right now.';

  @override
  String get errorAccessNotAvailable => 'Access not available.';

  @override
  String get errorNotFound => 'Not found.';

  @override
  String get errorSomethingWrong => 'Something went wrong.';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSignInSubtitle =>
      'Sign in to continue to your health overview.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNewToSusthiti => 'New to SUSTHITI?';

  @override
  String get authCreatePatientAccount => 'Create a patient account';

  @override
  String get authDoctorAccountsNote =>
      'Doctor accounts are created by your SUSTHITI administrator.';

  @override
  String get authCreateAccountTitle => 'Create your account';

  @override
  String get authCreateAccountSubtitle =>
      'Start building your health history. You can add more details later.';

  @override
  String get authFullName => 'Full name';

  @override
  String get authDateOfBirth => 'Date of birth';

  @override
  String get authGender => 'Gender';

  @override
  String get genderMale => 'Male';

  @override
  String get genderFemale => 'Female';

  @override
  String get authPhone => 'Phone';

  @override
  String get authGenderRequired => 'Please choose a gender.';

  @override
  String get authConsentText =>
      'I understand SUSTHITI provides informational insights and does not replace professional medical diagnosis, treatment, or emergency care.';

  @override
  String get authConsentError =>
      'Please confirm you understand SUSTHITI does not replace medical care.';

  @override
  String get authCreateAccountButton => 'Create account';

  @override
  String get authPasswordHelper =>
      'At least 8 characters with a letter and a number.';

  @override
  String get authLanguageLabel => 'Language';

  @override
  String get authLanguageHelper => 'You can change this later in Settings.';

  @override
  String get authResetPasswordTitle => 'Reset your password';

  @override
  String get authResetPasswordSubtitle =>
      'Enter the email you use for SUSTHITI and we will send reset instructions.';

  @override
  String get authResetSentMessage =>
      'If an account exists for this email, password reset instructions have been sent.';

  @override
  String get authDevModeTitle => 'DEVELOPMENT MODE';

  @override
  String get authDevModeBody =>
      'No email provider is configured on this server, so the 8-digit reset code is shown below. This never happens in production.';

  @override
  String get authCopyCode => 'Copy code';

  @override
  String get authCodeCopied => 'Reset code copied to clipboard';

  @override
  String get authEnterResetCode => 'Enter reset code';

  @override
  String get authSendResetInstructions => 'Send reset instructions';

  @override
  String get authChooseNewPassword => 'Choose a new password';

  @override
  String get authChooseNewPasswordSubtitle =>
      'Enter the 8-digit reset code you received and a new password.';

  @override
  String get auth8DigitCode => '8-digit reset code';

  @override
  String get authPasteFromClipboard => 'Paste from clipboard';

  @override
  String get authInvalid8DigitCode => 'Enter the 8-digit code from your email.';

  @override
  String get authNewPassword => 'New password';

  @override
  String get authConfirmNewPassword => 'Confirm new password';

  @override
  String get authPasswordsDontMatch => 'Passwords do not match.';

  @override
  String get authUpdatePassword => 'Update password';

  @override
  String get authPastedCode => 'Pasted 8-digit code from clipboard';

  @override
  String get authPastedCodeGeneric => 'Pasted code from clipboard';

  @override
  String get authClipboardEmpty => 'Clipboard is empty';

  @override
  String get authPasswordUpdatedSignIn =>
      'Your password has been updated. Please sign in.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccount => 'Account';

  @override
  String settingsDoctorIdLabel(String code) {
    return 'Doctor ID $code';
  }

  @override
  String get settingsEditProfile => 'Edit profile';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsDoctorAccess => 'Doctor access';

  @override
  String get settingsDoctorAccessSubtitle =>
      'Approve, reject or revoke doctors who can see your records';

  @override
  String get settingsConnectedDevices => 'Connected devices';

  @override
  String get settingsPrivacyNote =>
      'Your records are only visible to you and to doctors you approve. Administrators manage accounts but cannot read your medical records.';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsChangePassword => 'Change password';

  @override
  String get settingsLogOut => 'Log out';

  @override
  String get settingsLogOutConfirmTitle => 'Log out?';

  @override
  String get settingsLogOutConfirmMessage =>
      'You will need to sign in again to see your records.';

  @override
  String get settingsPasswordChanged => 'Password changed';

  @override
  String get settingsCurrentPassword => 'Current password';

  @override
  String get settingsNewPassword => 'New password';

  @override
  String get settingsConfirmNewPassword => 'Confirm new password';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageSubtitle =>
      'Choose the language SUSTHITI is shown in';

  @override
  String get settingsLanguageUpdated => 'Language updated';

  @override
  String get settingsLanguageUpdateFailed =>
      'Couldn\'t update your language. Please check your connection and try again.';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get languageGujarati => 'ગુજરાતી';

  @override
  String get navHome => 'Home';

  @override
  String get navReports => 'Reports';

  @override
  String get navLifestyle => 'Lifestyle';

  @override
  String get navDiabetes => 'Diabetes';

  @override
  String get navHeart => 'Heart';

  @override
  String get navProfile => 'Profile';

  @override
  String get navGlucose => 'Glucose';

  @override
  String get navFoodLog => 'Food log';

  @override
  String get navPrescriptions => 'Prescriptions';

  @override
  String get navAppointments => 'Appointments';

  @override
  String get navFollowUps => 'Follow-ups';

  @override
  String get navSurgeries => 'Surgeries';

  @override
  String get navSideEffects => 'Side effects';

  @override
  String get navHistory => 'History';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navSettings => 'Settings';

  @override
  String get navDashboard => 'Dashboard';

  @override
  String get navPatients => 'Patients';

  @override
  String get navRequests => 'Requests';

  @override
  String get navAccount => 'Account';

  @override
  String get navAddPatient => 'Add patient';

  @override
  String get navDoctors => 'Doctors';

  @override
  String get navAccess => 'Access';

  @override
  String get navMore => 'More';

  @override
  String get navAuditLogs => 'Audit logs';

  @override
  String get navNotificationDelivery => 'Notification delivery';

  @override
  String get navSystemSettings => 'System settings';

  @override
  String get navAddDoctor => 'Add doctor';

  @override
  String get dashTodaysOverview => 'Today\'s Overview';

  @override
  String get dashNoReadingsYet => 'No readings yet';

  @override
  String get dashQuickActions => 'Quick Actions';

  @override
  String get dashUploadReport => 'Upload Report';

  @override
  String get dashRecordGlucose => 'Record Glucose';

  @override
  String get dashLogFood => 'Log Food';

  @override
  String get dashDiabetesRisk => 'Diabetes Risk';

  @override
  String get dashReportSideEffect => 'Report Side Effect';

  @override
  String get dashAiLifestyleInsight => 'AI Lifestyle Insight';

  @override
  String get dashInsightPlaceholder =>
      'Generate suggestions based on your activity, sleep, food and glucose.';

  @override
  String dashGenerated(String time) {
    return 'Generated $time';
  }

  @override
  String get dashRecentReports => 'Recent Reports';

  @override
  String get dashNoReportsAvailable => 'No reports available.';

  @override
  String get dashMyRecords => 'My Records';

  @override
  String get dashDoctorVisits => 'Doctor visits';

  @override
  String get dashAppointmentRecommendations => 'Appointment recommendations';

  @override
  String get dashHealthTimeline => 'Health timeline';

  @override
  String get dashHealthSummary => 'Your Health Summary';

  @override
  String get dashHappyBirthday => 'Happy birthday';

  @override
  String dashHappyBirthdayMessage(String name) {
    return 'Happy birthday, $name! Wishing you a happy and healthy year ahead.';
  }

  @override
  String get dashUpcomingAppointment => 'Upcoming Appointment';

  @override
  String get dashContactClinic => 'Contact the clinic to schedule a time';

  @override
  String get dashUpcomingFollowUp => 'Upcoming Follow-up';

  @override
  String get dashOverdue => 'Overdue';

  @override
  String get dashScheduled => 'Scheduled';

  @override
  String get dashUpcomingSurgery => 'Upcoming Surgery';

  @override
  String get dashDateTbc => 'Date to be confirmed';

  @override
  String get dashYourHealth => 'Your Health';

  @override
  String get dashNoEstimateYet => 'No estimate yet';

  @override
  String get dashEstimateFutureRisk =>
      'Estimate your future diabetes risk. A few questions, already filled in with what SUSTHITI knows.';

  @override
  String get dashStartAssessment => 'Start assessment';

  @override
  String get dashIncludesReportValues => 'Includes medical report values';

  @override
  String get dashBasedOnSymptomsOnly =>
      'Based on symptoms and risk factors only';

  @override
  String get dashUpdatedRiskInfo =>
      'Updated health information is available. Refresh your assessment to include it.';

  @override
  String get dashReviewAndRefresh => 'Review and refresh';

  @override
  String get dashViewDetails => 'View details';

  @override
  String get dashNoScreeningYet => 'No screening yet';

  @override
  String get dashScreenHeartRisk =>
      'Screen your heart disease risk. A short form, already filled in with what SUSTHITI knows.';

  @override
  String get dashStartScreening => 'Start screening';

  @override
  String get dashUpdatedScreeningInfo =>
      'Updated health information is available. Refresh your screening to include it.';

  @override
  String get docPatientsLabel => 'Patients';

  @override
  String get docPatientsCaption => 'with approved access';

  @override
  String get docPendingRequests => 'Pending requests';

  @override
  String get docPendingRequestsCaption => 'awaiting patient approval';

  @override
  String get docOpenSideEffects => 'Open side effects';

  @override
  String get docOpenSideEffectsCaption => 'not yet resolved';

  @override
  String get docFollowUpsCaption => 'in the next 7 days';

  @override
  String get docAppointmentsCaption => 'in the next 7 days';

  @override
  String get docNewReports => 'New reports';

  @override
  String get docNewReportsCaption => 'in the last 7 days';

  @override
  String get docNeedsAttention => 'Needs attention';

  @override
  String get docNeedsAttentionSubtitle =>
      'Based on patient-reported severity, unresolved items and due follow-ups. Not a clinical triage.';

  @override
  String get docNothingNeedsAttention => 'Nothing needs attention right now.';

  @override
  String get docQuickActions => 'Quick actions';

  @override
  String get docAddPatient => 'Add Patient';

  @override
  String get docMyPatients => 'My Patients';

  @override
  String get docAccessRequests => 'Access Requests';

  @override
  String get docRecentActivity => 'Recent activity';

  @override
  String get docNoRecentActivity => 'No recent activity.';

  @override
  String get docToday => 'Today';

  @override
  String get docAll => 'All';

  @override
  String get docScheduleClear => 'Your schedule is clear today.';

  @override
  String get docAppointmentType => 'Appointment';

  @override
  String get docFollowUpType => 'Follow-up';

  @override
  String get docSurgeryType => 'Surgery';

  @override
  String get docTodayAt => 'Today';

  @override
  String validatorRequiredField(String label) {
    return '$label is required.';
  }

  @override
  String get validatorThisField => 'This field';

  @override
  String get validatorEmailRequired => 'Email is required.';

  @override
  String get validatorEmailInvalid => 'Enter a valid email address.';

  @override
  String get validatorPasswordRequired => 'Password is required.';

  @override
  String get validatorPasswordTooShort => 'Use at least 8 characters.';

  @override
  String get validatorPasswordNeedsLetterNumber =>
      'Include at least one letter and one number.';

  @override
  String get validatorPhoneInvalid => 'Enter a valid phone number.';

  @override
  String get validatorPatientIdRequired => 'Patient ID is required.';

  @override
  String get validatorPatientIdInvalid =>
      'Patient ID should look like SUS-P-8A42F1.';

  @override
  String get validatorAgeInvalid => 'Enter your age in whole years.';

  @override
  String get validatorAgeRange => 'Age must be between 1 and 120.';

  @override
  String get validatorNumberRequired => 'Enter a number.';

  @override
  String validatorGlucoseRange(String low, String high, String unit) {
    return 'Enter a value between $low and $high $unit.';
  }

  @override
  String validatorNumberRange(String label, String low, String high) {
    return '$label must be between $low and $high.';
  }

  @override
  String get validatorValueLabel => 'Value';

  @override
  String get validatorDateLabel => 'Date';

  @override
  String validatorDateNotFuture(String label) {
    return '$label can\'t be in the future.';
  }

  @override
  String get fmtJustNow => 'just now';

  @override
  String fmtMinutesAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String fmtHoursAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String fmtDaysAgo(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get fmtGoodMorning => 'Good morning';

  @override
  String get fmtGoodAfternoon => 'Good afternoon';

  @override
  String get fmtGoodEvening => 'Good evening';

  @override
  String get commonToday => 'Today';

  @override
  String commonDrName(String name) {
    return 'Dr. $name';
  }

  @override
  String dashLastRecorded(String date) {
    return 'Last recorded $date';
  }

  @override
  String dashRiskUpdated(String time) {
    return 'Updated $time';
  }

  @override
  String dashAppointmentDoctorLine(String doctor, String subtitle) {
    return 'Dr. $doctor · $subtitle';
  }

  @override
  String dashFollowUpDoctorLine(String doctor, String date) {
    return 'Dr. $doctor · Due $date';
  }

  @override
  String dashSurgeryDoctorLine(String doctor, String when) {
    return 'Dr. $doctor · $when';
  }

  @override
  String get commonAnd => 'and';

  @override
  String docTodaySummary(String list) {
    return 'Today you have $list.';
  }

  @override
  String docSummaryAppointments(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count appointments',
      one: '1 appointment',
    );
    return '$_temp0';
  }

  @override
  String docSummaryFollowUps(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count follow-ups',
      one: '1 follow-up',
    );
    return '$_temp0';
  }

  @override
  String docSummarySurgeries(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count surgeries',
      one: '1 surgery',
    );
    return '$_temp0';
  }

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonReschedule => 'Reschedule';

  @override
  String get commonMarkCompleted => 'Mark Completed';

  @override
  String get commonSaveChanges => 'Save Changes';

  @override
  String get commonSaveNewDate => 'Save New Date';

  @override
  String get commonPurposeLabel => 'Purpose';

  @override
  String get commonDoctorLabel => 'Doctor';

  @override
  String get commonReasonLabel => 'Reason';

  @override
  String get commonInstructionsLabel => 'Instructions';

  @override
  String get visitsPageTitle => 'Doctor Visits';

  @override
  String get visitsRecordVisit => 'Record Visit';

  @override
  String get visitsEmptyTitle => 'No visits recorded yet.';

  @override
  String get visitsEmptyMessage =>
      'Visits recorded by your doctor will appear here.';

  @override
  String visitsDoctorDateCode(String doctor, String date, String code) {
    return 'Dr. $doctor · $date · $code';
  }

  @override
  String visitsFollowUpOn(String date) {
    return 'Follow-up $date';
  }

  @override
  String get visitDetailTitle => 'Visit';

  @override
  String get visitIdLabel => 'Visit ID';

  @override
  String get visitDateLabel => 'Visit date';

  @override
  String get visitFollowUpLabel => 'Follow-up';

  @override
  String get visitClinicalNotesLabel => 'Clinical notes';

  @override
  String get visitAssessmentLabel => 'Assessment';

  @override
  String get visitDoctorReasoningLabel => 'Doctor\'s reasoning';

  @override
  String get visitTreatmentDecisionLabel => 'Treatment decision';

  @override
  String get visitInstructionsForPatientLabel => 'Instructions for the patient';

  @override
  String visitRecordedToast(String code) {
    return 'Visit $code recorded';
  }

  @override
  String get visitReasonForVisitLabel => 'Reason for visit';

  @override
  String get visitFollowUpDateLabel => 'Follow-up date';

  @override
  String get visitSaveButton => 'Save visit';

  @override
  String get followUpsEmptyTitle => 'No follow-ups scheduled.';

  @override
  String get followUpsScheduleButton => 'Schedule Follow-up';

  @override
  String get followUpMarkCompletedTitle => 'Mark as completed?';

  @override
  String get followUpMarkCompletedMessage =>
      'This follow-up will be marked as done.';

  @override
  String get followUpCancelTitle => 'Cancel this follow-up?';

  @override
  String get followUpCancelMessage =>
      'The patient will be notified that it was cancelled.';

  @override
  String get followUpCancelConfirmLabel => 'Cancel Follow-up';

  @override
  String get followUpMarkedCompletedToast => 'Follow-up marked completed';

  @override
  String get followUpCancelledToast => 'Follow-up cancelled';

  @override
  String get followUpsDueDateLabel => 'Due date';

  @override
  String get followUpsRescheduleTitle => 'Reschedule Follow-up';

  @override
  String get followUpsNewDueDateLabel => 'New due date';

  @override
  String get surgeriesEmptyTitle => 'No surgeries scheduled.';

  @override
  String get surgeriesScheduleButton => 'Schedule Surgery';

  @override
  String get surgeryMarkCompletedMessage =>
      'This surgery will be marked as done.';

  @override
  String get surgeryCancelTitle => 'Cancel this surgery?';

  @override
  String get surgeryCancelConfirmLabel => 'Cancel Surgery';

  @override
  String get surgeryMarkedCompletedToast => 'Surgery marked completed';

  @override
  String get surgeryCancelledToast => 'Surgery cancelled';

  @override
  String get surgeryNameLabel => 'Surgery name';

  @override
  String get surgeryEditTitle => 'Edit Surgery';

  @override
  String get surgeryScheduledDateTimeLabel => 'Scheduled date and time';

  @override
  String get surgeryHospitalLabel => 'Hospital / location';

  @override
  String get surgeryPatientInstructionsLabel => 'Patient-visible instructions';

  @override
  String get surgeryPatientInstructionsHelper =>
      'Shown to the patient (e.g. fasting instructions).';

  @override
  String get surgeryInternalNotesLabel => 'Internal notes';

  @override
  String get surgeryInternalNotesHelper => 'Never shown to the patient.';

  @override
  String get surgeryInternalNotesSectionLabel =>
      'Internal notes (not shown to the patient)';

  @override
  String get surgeryRescheduleTitle => 'Reschedule Surgery';

  @override
  String get surgeryNewDateTimeLabel => 'New date and time';

  @override
  String get commonNotesLabel => 'Notes';

  @override
  String get sideEffectsTitle => 'Side Effects';

  @override
  String get sideEffectsReportButton => 'Report Side Effect';

  @override
  String get sideEffectsEmptyTitle => 'No side effects reported.';

  @override
  String get sideEffectsEmptyMessage =>
      'If a medicine makes you feel unwell, report it here so your doctor can review it.';

  @override
  String get sideEffectPriorityLabel => 'Priority';

  @override
  String get sideEffectDescribeLabel => 'What are you experiencing?';

  @override
  String get sideEffectDescribeValidation =>
      'Please describe what you are experiencing.';

  @override
  String get sideEffectSeverityLabel => 'How severe is it?';

  @override
  String get sideEffectUrgentWarning =>
      'If you feel your symptoms need urgent care, contact your local emergency services or go to the nearest hospital now. SUSTHITI is not monitored in real time.';

  @override
  String get sideEffectRelatedMedicineLabel => 'Related medicine';

  @override
  String get sideEffectRelatedMedicineHint => 'e.g. Metformin';

  @override
  String get sideEffectWhenStartedLabel => 'When did it start?';

  @override
  String get sideEffectSubmitButton => 'Submit report';

  @override
  String get sideEffectReportedToast =>
      'Side effect reported. Your doctor has been notified.';

  @override
  String get sideEffectDetailTitle => 'Side Effect';

  @override
  String get sideEffectReferenceLabel => 'Reference';

  @override
  String get sideEffectStartedLabel => 'Started';

  @override
  String get sideEffectNotSpecified => 'Not specified';

  @override
  String get sideEffectReportedLabel => 'Reported';

  @override
  String sideEffectPriorityExplanation(String severity) {
    return 'Marked as priority because the patient selected $severity severity. This is not a clinical judgement.';
  }

  @override
  String get sideEffectDoctorActionsLabel => 'Doctor actions';

  @override
  String get sideEffectRespondButton => 'Respond';

  @override
  String get sideEffectMarkUnderReviewButton => 'Mark under review';

  @override
  String get sideEffectMarkResolvedButton => 'Mark resolved';

  @override
  String get sideEffectResponseSentToast => 'Response sent to the patient';

  @override
  String get sideEffectMarkedResolvedToast => 'Marked as resolved';

  @override
  String get sideEffectMarkedUnderReviewToast => 'Marked as under review';

  @override
  String sideEffectRespondToTitle(String code) {
    return 'Respond to $code';
  }

  @override
  String get sideEffectResponseFieldLabel => 'Response';

  @override
  String get sideEffectMessageToPatientLabel => 'Message to patient';

  @override
  String get sideEffectTellPatientValidation =>
      'Tell the patient what to do next.';

  @override
  String get sideEffectAppointmentReasonLabel => 'Appointment reason';

  @override
  String get sideEffectSuggestedDateLabel => 'Suggested date';

  @override
  String get sideEffectSendResponseButton => 'Send response';

  @override
  String get commonSave => 'Save';

  @override
  String get commonEditedTag => 'edited';

  @override
  String get foodLogTitle => 'Food Log';

  @override
  String get foodLogButton => 'Log Food';

  @override
  String get foodMealLoggedToast => 'Meal logged';

  @override
  String get foodEntryUpdatedToast =>
      'Entry updated. The earlier version is kept in history.';

  @override
  String get foodPeriodYesterday => 'Yesterday';

  @override
  String get foodPeriodThisWeek => 'This week';

  @override
  String get foodPeriodCustomDate => 'Custom date';

  @override
  String get foodEmptyToday => 'No meals recorded today.';

  @override
  String get foodEmptyPeriod => 'No meals recorded for this period.';

  @override
  String foodEntrySubtitle(String quantity, String meal, String time) {
    return '$quantity · $meal · $time';
  }

  @override
  String get foodEditEntryTitle => 'Edit Entry';

  @override
  String get foodNameLabel => 'Food name';

  @override
  String get foodNameHint => 'e.g. Rice';

  @override
  String get foodQuantityLabel => 'Quantity';

  @override
  String get foodQuantityHint => 'e.g. 2 bowls';

  @override
  String get foodMealLabel => 'Meal';

  @override
  String get foodTimeLabel => 'Time';

  @override
  String get glucoseRecordReadingButton => 'Record Reading';

  @override
  String get glucoseEmptyTitle => 'No glucose readings yet.';

  @override
  String get glucoseEmptyMessageCanRecord =>
      'Record readings to see your averages and trends here.';

  @override
  String get glucoseEmptyMessageViewOnly =>
      'The patient has not recorded any glucose readings.';

  @override
  String get glucoseRecordFirstButton => 'Record First Reading';

  @override
  String get glucoseTodaysReadingsLabel => 'Today\'s readings';

  @override
  String get glucoseNoneRecordedToday => 'None recorded today';

  @override
  String glucoseLatestReading(String value) {
    return 'Latest $value mg/dL';
  }

  @override
  String get glucoseRecentAverageLabel => 'Recent average';

  @override
  String glucoseLast7DaysCaption(String count) {
    return 'Last 7 days · $count readings';
  }

  @override
  String get glucoseTrendLabel => 'Trend';

  @override
  String get glucoseTrendHigher => 'Higher';

  @override
  String get glucoseTrendLower => 'Lower';

  @override
  String get glucoseTrendStable => 'Stable';

  @override
  String get glucoseTrendNotEnoughData => 'Not enough data';

  @override
  String get glucoseTrendCaption => 'This week vs previous weeks';

  @override
  String get glucoseReadingRecordedToast => 'Reading recorded';

  @override
  String get glucoseRecordTitle => 'Record Glucose';

  @override
  String get glucoseValueLabel => 'Value';

  @override
  String get glucoseReadingTypeLabel => 'Reading type';

  @override
  String get glucoseDateTimeLabel => 'Date and time';

  @override
  String get glucoseContextLabel => 'Context';

  @override
  String get glucoseContextHelper =>
      'For example \"after a walk\" or \"felt dizzy\".';

  @override
  String get glucoseSaveReadingButton => 'Save reading';

  @override
  String get riskTitle => 'Future Diabetes Risk';

  @override
  String get riskEstimateLabel => 'Model-estimated risk';

  @override
  String get riskSafetyText =>
      'This is a research and screening estimate from a machine-learning model trained on synthetic data. It is not clinically validated and is not a medical diagnosis. Talk to your doctor about your results.';

  @override
  String get riskNoReportBasis =>
      'Based on available symptoms and risk factors. No medical report values were used.';

  @override
  String get riskReportBasisGeneric =>
      'Includes values from your medical reports.';

  @override
  String riskReportBasisWithFields(String fields) {
    return 'Includes $fields from your medical reports.';
  }

  @override
  String get riskCategoryLowLabel => 'Low risk';

  @override
  String get riskCategoryModerateLabel => 'Moderate risk';

  @override
  String get riskCategoryHighLabel => 'High risk';

  @override
  String riskPatternPrefix(String label) {
    return 'Risk pattern: $label';
  }

  @override
  String riskLastUpdated(String relative, String absolute) {
    return 'Last updated $relative · $absolute';
  }

  @override
  String get riskUpdatedInfoAvailable =>
      'Updated health information is available.';

  @override
  String get riskNewInfoOffline =>
      'New health information is available. Connect to the internet to update your assessment.';

  @override
  String get riskRefreshToInclude =>
      'The estimate above doesn\'t include it yet. Refresh your diabetes risk assessment to use your latest information.';

  @override
  String get riskUpdateWithLatestData => 'Update with my latest data';

  @override
  String get riskOfflineSavedInfo =>
      'You\'re offline. Showing the information saved on this device.';

  @override
  String riskOfflineLastAssessment(String relative) {
    return 'You\'re offline. Showing your last assessment, updated $relative. Newer health information isn\'t included until you\'re back online.';
  }

  @override
  String get riskNoDataAvailable =>
      'No health information was available yet beyond what the model requires.';

  @override
  String get riskUpdateProfileAction => 'Update profile';

  @override
  String get riskOpenHealthProfileAction => 'Open health profile';

  @override
  String get riskAddReportValuesAction => 'Add values from a report';

  @override
  String get riskConnectHealthDataAction => 'Connect health data';

  @override
  String get riskAnswerOnHeartFormAction =>
      'Answer on the heart assessment form';

  @override
  String get heartTitle => 'Heart Disease Risk Screening';

  @override
  String get heartEstimateLabel => 'Model screening result';

  @override
  String get heartSignalHigh => 'Elevated risk signal';

  @override
  String get heartSignalModerate => 'Moderate risk signal';

  @override
  String get heartSignalLow => 'Low risk signal';

  @override
  String get heartRefreshToInclude =>
      'The screening above doesn\'t include it yet. Refresh your heart risk screening to use your latest information.';

  @override
  String get commonAdd => 'Add';

  @override
  String get lifestyleAlreadyUpToDateToast => 'Already up to date';

  @override
  String get lifestyleSyncedJustNowToast => 'Synced just now';

  @override
  String get lifestyleSyncFailedToast =>
      'Sync didn\'t complete. Check your connection and try again.';

  @override
  String get lifestyleTodaySubtitle =>
      'Recorded values only. Comparisons appear once there is enough history.';

  @override
  String get lifestyleFoodLabel => 'Food';

  @override
  String lifestyleMealsLoggedTodayCaption(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'meals logged today',
      one: 'meal logged today',
    );
    return '$_temp0';
  }

  @override
  String get lifestyleTrendsHeader => 'Trends';

  @override
  String get lifestyleInsightTitle => 'Lifestyle Insight';

  @override
  String get lifestyleInsightSubtitle =>
      'AI suggestions based on your activity, sleep, food and glucose';

  @override
  String get lifestyleNotAvailableFromDevice =>
      'Not available from connected device';

  @override
  String get lifestyleNotRecordedYet => 'Not recorded yet';

  @override
  String lifestyleChangeVsAverage(String value) {
    return '$value% vs your recent average';
  }

  @override
  String get lifestyleMeasurementAddedToast => 'Measurement added';

  @override
  String get lifestyleAddMeasurementTitle => 'Add measurement';

  @override
  String get lifestyleMeasurementFieldLabel => 'Measurement';

  @override
  String get lifestyleStepsLabel => 'Steps';

  @override
  String get lifestyleHeartRateFieldLabel => 'Heart rate (bpm)';

  @override
  String get lifestyleSleepFieldLabel => 'Sleep (minutes)';

  @override
  String get lifestyleActiveMinutesLabel => 'Active minutes';

  @override
  String get lifestyleSystolicLabel => 'Systolic (mmHg)';

  @override
  String get lifestyleSpo2FieldLabel => 'SpO₂ (%)';

  @override
  String get lifestyleDiastolicLabel => 'Diastolic (mmHg)';

  @override
  String get lifestyleDiastolicLowerThanSystolic =>
      'Diastolic must be lower than systolic.';

  @override
  String get lifestyleManualEntryNote => 'Recorded as a manual entry.';

  @override
  String get lifestyleOfflineNotice =>
      'Offline. Showing the last values received';

  @override
  String notifTooltipUnread(num count) {
    return 'Notifications, $count unread';
  }

  @override
  String get notifMarkAllRead => 'Mark all read';

  @override
  String get notifLoadError => 'Notifications could not be loaded.';

  @override
  String get notifCaughtUp => 'You\'re all caught up.';

  @override
  String get notifViewAll => 'View all notifications';

  @override
  String get notifNoNotificationsTitle => 'No notifications';

  @override
  String get notifFilterAll => 'All';

  @override
  String get notifFilterUnread => 'Unread';

  @override
  String get notifFilterRead => 'Read';

  @override
  String get notifUnreadPrefix => 'Unread. ';

  @override
  String get notifFoodRemindersTitle => 'Food logging reminders';

  @override
  String get notifFoodRemindersSubtitle =>
      'An evening nudge if no meals are logged';

  @override
  String get notifLifestyleRemindersTitle => 'Lifestyle reminders';

  @override
  String get notifLifestyleRemindersSubtitle =>
      'A daily nudge for any lifestyle metric or glucose reading with nothing recorded yet';

  @override
  String get notifFollowUpRemindersTitle => 'Follow-up reminders';

  @override
  String get notifPatientUpdatesTitle => 'Patient updates';

  @override
  String get notifPatientUpdatesSubtitle => 'New reports and patient updates';

  @override
  String get tabOverview => 'Overview';

  @override
  String get tabAiSummary => 'AI Summary';

  @override
  String get tabVisits => 'Visits';

  @override
  String get patientFallbackName => 'Patient';

  @override
  String get doctorBodyMeasurementsHeader => 'Body measurements';

  @override
  String get commonActionsHeader => 'Actions';

  @override
  String get doctorNewPrescriptionButton => 'New Prescription';

  @override
  String get doctorRecommendAppointmentButton => 'Recommend Appointment';

  @override
  String get commonContactHeader => 'Contact';

  @override
  String get commonNotProvided => 'Not provided';

  @override
  String get doctorEmergencyContactLabel => 'Emergency contact';

  @override
  String get doctorAllReportsSummaryLabel => 'All Reports Summary';

  @override
  String get doctorAppointmentRecommendationSentToast =>
      'Appointment recommendation sent to the patient';

  @override
  String get doctorSendRecommendationButton => 'Send recommendation';

  @override
  String get doctorScanPatientQrTooltip => 'Scan Patient QR';

  @override
  String get doctorFilterRecentActivity => 'Recent activity';

  @override
  String get doctorFilterFollowUpDue => 'Follow-up due';

  @override
  String get doctorSelectPatientTitle => 'Select a patient';

  @override
  String get doctorSelectPatientMessage =>
      'Their overview, records and lifestyle data appear here.';

  @override
  String get doctorSearchHint => 'Search by name or Patient ID';

  @override
  String get doctorNoPatientsYet => 'No patients yet.';

  @override
  String get doctorNoPatientsMatch => 'No patients match.';

  @override
  String get doctorNoPatientsMessage =>
      'Request access with the patient\'s name and Patient ID. They approve it in their app.';

  @override
  String doctorLastActivityLabel(String relative) {
    return 'Last activity $relative';
  }

  @override
  String doctorSideEffectsCountPill(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count side effects',
      one: '1 side effect',
    );
    return '$_temp0';
  }

  @override
  String doctorFollowUpShortDate(String date) {
    return 'Follow-up $date';
  }

  @override
  String get doctorRequestSentTitle => 'Request sent';

  @override
  String doctorRequestSentMessage(String name, String code) {
    return '$name ($code) will be asked to approve your request. You will be notified when they respond.';
  }

  @override
  String get doctorViewRequestsButton => 'View requests';

  @override
  String get doctorAddAnotherButton => 'Add another';

  @override
  String get doctorAddPatientInstructions =>
      'Enter the patient\'s full name and Patient ID exactly as shown in their SUSTHITI profile. The patient must approve before you can see any records.';

  @override
  String get doctorPatientFullNameLabel => 'Patient full name';

  @override
  String get doctorPatientNameLabel => 'Patient name';

  @override
  String get doctorPatientIdLabel => 'Patient ID';

  @override
  String get doctorMessageToPatientLabel => 'Message to patient';

  @override
  String get doctorRequestAccessButton => 'Request Access';

  @override
  String get doctorScanInsteadButton =>
      'Or scan the patient\'s QR code instead';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileYourQrCode => 'Your QR code';

  @override
  String profileQrSemanticLabel(String code) {
    return 'QR code for Patient ID $code';
  }

  @override
  String get profileQrHelp =>
      'Show this to a doctor in person so they can request access. It contains no medical information.';

  @override
  String get profileChangePhotoTooltip => 'Change photo';

  @override
  String get profileShareIdNote =>
      'Share your Patient ID only with doctors you trust. They also need your name, and you approve every request.';

  @override
  String get profilePersonalDetailsHeader => 'Personal details';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get commonAgeLabel => 'Age';

  @override
  String get profileNoEmergencyContact => 'No emergency contact added.';

  @override
  String get commonNameLabel => 'Name';

  @override
  String get commonRelationshipLabel => 'Relationship';

  @override
  String get profileHealthProfileLabel => 'Health profile';

  @override
  String get profileHealthProfileSubtitle =>
      'Height, weight, medical history, habits and symptoms';

  @override
  String get profileChoosePhotoDialogTitle => 'Choose a photo';

  @override
  String get profilePhotoTooLargeError => 'Photo must be 5 MB or smaller.';

  @override
  String get profilePhotoUpdatedToast => 'Photo updated';

  @override
  String get profileUpdatedToast => 'Profile updated';

  @override
  String get profileGenderModelInputHelper => 'Used as a diabetes model input.';

  @override
  String get rxSearchHint => 'Search by medicine, doctor or ID';

  @override
  String get rxClearSearchTooltip => 'Clear search';

  @override
  String get rxEmptyNoneYet => 'No prescriptions yet.';

  @override
  String rxEmptyNoMatch(String query) {
    return 'No prescriptions match \"$query\".';
  }

  @override
  String get rxEmptyMessage =>
      'Prescriptions from your doctor will appear here.';

  @override
  String get rxDetailTitle => 'Prescription';

  @override
  String get rxIdLabel => 'Prescription ID';

  @override
  String get rxDateLabel => 'Date';

  @override
  String get rxMedicinesHeader => 'Medicines';

  @override
  String get rxDosageLabel => 'Dosage';

  @override
  String get rxFrequencyLabel => 'Frequency';

  @override
  String get rxDurationLabel => 'Duration';

  @override
  String get rxNeverEditedNote =>
      'Prescriptions are never edited. A change is issued as a new prescription.';

  @override
  String get rxPrescriptionDateLabel => 'Prescription date';

  @override
  String rxMedicineNLabel(int n) {
    return 'Medicine $n';
  }

  @override
  String get rxRemoveMedicineTooltip => 'Remove medicine';

  @override
  String get rxMedicineLabel => 'Medicine';

  @override
  String get rxDosageHint => 'e.g. 500 mg';

  @override
  String get rxFrequencyHint => 'e.g. Twice daily';

  @override
  String get rxDurationHint => 'e.g. 30 days';

  @override
  String get rxMedicineInstructionsHint => 'e.g. After meals';

  @override
  String get rxAddMedicineButton => 'Add medicine';

  @override
  String get rxGeneralInstructionsLabel => 'General instructions';

  @override
  String get rxCreateButton => 'Create prescription';

  @override
  String rxCreatedToast(String code) {
    return 'Prescription $code created';
  }

  @override
  String get rxPatientNotifiedNote =>
      'The patient is notified. Earlier prescriptions stay unchanged.';

  @override
  String get uploadChooseReportDialogTitle => 'Choose a report';

  @override
  String get uploadFileTypeError =>
      'Choose a PDF or an image (JPEG, PNG, WebP, HEIC).';

  @override
  String uploadFileTooLargeError(String mb) {
    return 'File must be $mb MB or smaller.';
  }

  @override
  String get uploadFileEmptyError => 'The selected file is empty.';

  @override
  String get uploadPickerFailedToast =>
      'Couldn\'t open the file picker. Please try again.';

  @override
  String get uploadChooseFileError => 'Choose the report file to upload.';

  @override
  String get uploadChooseCategoryError => 'Choose at least one report type.';

  @override
  String uploadAdminAddedToast(String code) {
    return 'Report $code added to the patient\'s record';
  }

  @override
  String get uploadReportUploadedToast => 'Report uploaded';

  @override
  String get uploadReportTypeLabel => 'What type of report is this?';

  @override
  String get uploadReportTypeHelp =>
      'Choose every type it covers. A full body checkup, for example, can also include HbA1c.';

  @override
  String get uploadReportDateLabel => 'Report date';

  @override
  String get uploadReportDateHelper =>
      'The date on the report itself (when the test was done), not today. Older reports are welcome.';

  @override
  String get uploadReportFileLabel => 'Report file';

  @override
  String get uploadChooseFilePlaceholder => 'Choose file';

  @override
  String get uploadFileTypesHint => 'PDF, JPEG, PNG, WebP or HEIC, up to 20 MB';

  @override
  String get commonChange => 'Change';

  @override
  String get uploadFileStoredNote =>
      'Your original file is stored securely and always stays available, even if AI features are unavailable.';

  @override
  String get commonDescriptionLabel => 'Description';

  @override
  String get uploadDescriptionHelper =>
      'For example the lab name or why the test was done.';

  @override
  String get uploadDescriptionTooLong =>
      'Keep the description under 1000 characters.';

  @override
  String get auditLogin => 'Signed in';

  @override
  String get auditLogout => 'Signed out';

  @override
  String get auditPatientRegistered => 'Registered as a patient';

  @override
  String get auditProfileUpdated => 'Updated their profile';

  @override
  String get auditProfilePhotoUpdated => 'Updated their profile photo';

  @override
  String get auditPatientUpdatedByAdmin => 'Patient details updated by admin';

  @override
  String get auditPatientRecordViewed => 'Patient record viewed by admin';

  @override
  String get auditPatientActivated => 'Patient account reactivated';

  @override
  String get auditPatientDeactivated => 'Patient account deactivated';

  @override
  String get auditDoctorCreated => 'Doctor account created';

  @override
  String get auditDoctorUpdated => 'Doctor details updated';

  @override
  String get auditDoctorActivated => 'Doctor account reactivated';

  @override
  String get auditDoctorDeactivated => 'Doctor account deactivated';

  @override
  String get auditAccessRequested => 'Requested patient access';

  @override
  String get auditAccessApproved => 'Patient access approved';

  @override
  String get auditAccessRejected => 'Patient access rejected';

  @override
  String get auditAccessRevoked => 'Patient access revoked';

  @override
  String get auditReportUploaded => 'Report uploaded';

  @override
  String get auditReportFileAccessed => 'Original report opened';

  @override
  String get auditDiabetesAssessmentCreated => 'Diabetes assessment completed';

  @override
  String get auditPrescriptionCreated => 'Prescription created';

  @override
  String get auditVisitRecorded => 'Doctor visit recorded';

  @override
  String get auditAppointmentRecommended => 'Appointment recommended';

  @override
  String get auditSideEffectReported => 'Side effect reported';

  @override
  String get auditSideEffectResponded => 'Responded to a side-effect report';

  @override
  String get auditSideEffectUnderReview =>
      'Side-effect report marked under review';

  @override
  String get auditSideEffectResolved => 'Side-effect report resolved';

  @override
  String get auditAiSummaryPdfDownloaded => 'AI summary PDF downloaded';

  @override
  String get auditAiIndividualReportGenerated => 'AI report summary generated';

  @override
  String get auditAiAllReportsGenerated => 'AI all-reports summary generated';

  @override
  String get auditAiPatientSummaryGenerated => 'AI patient summary generated';

  @override
  String get auditAiLifestyleGenerated => 'AI lifestyle insight generated';

  @override
  String get auditAiAssessmentInterpretationGenerated =>
      'AI assessment interpretation generated';

  @override
  String get auditWearableConnected => 'Wearable device connected';

  @override
  String get auditWearableDisconnected => 'Wearable device disconnected';

  @override
  String get auditPasswordChanged => 'Password changed';

  @override
  String get auditPasswordResetRequested => 'Password reset requested';

  @override
  String get auditPasswordResetCompleted => 'Password reset completed';

  @override
  String get auditSettingsUpdated => 'System settings updated';

  @override
  String get auditSystemActor => 'System';

  @override
  String auditAdminSuffix(String name) {
    return '$name (Admin)';
  }

  @override
  String auditPatientPrefix(String name) {
    return 'Patient: $name';
  }

  @override
  String get trendHigher => 'Higher than previous weeks';

  @override
  String get trendLower => 'Lower than previous weeks';

  @override
  String get trendStable => 'Similar to previous weeks';

  @override
  String get trendInsufficientData => 'Not enough readings to compare';

  @override
  String get commonActive => 'Active';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get diabetesNotAssessed => 'Not assessed';

  @override
  String get adminProgressNoOpenItems => 'No open items';

  @override
  String get adminNoRecentActivity => 'No recent activity';

  @override
  String get adminDashboardTitle => 'Admin';

  @override
  String adminActiveCountCaption(String count) {
    return '$count active';
  }

  @override
  String get adminRegisteredCaption => 'registered';

  @override
  String get adminActivePatientsLabel => 'Active patients';

  @override
  String get adminLast30DaysCaption => 'in the last 30 days';

  @override
  String get adminDoctorAccessCaption => 'doctor access';

  @override
  String get adminOperationalOverviewHeader => 'Operational overview';

  @override
  String get adminOperationalOverviewSubtitle =>
      'Aggregate counts only — never clinical content.';

  @override
  String get commonScheduledCaption => 'scheduled';

  @override
  String get adminUploadedLast7Days => 'uploaded in the last 7 days';

  @override
  String get adminFailedPushesLabel => 'Failed pushes';

  @override
  String get adminAddDoctorButton => 'Add Doctor';

  @override
  String get adminAuditLogsTitle => 'Audit Logs';

  @override
  String get adminSystemSettingsTitle => 'System Settings';

  @override
  String get adminNoActivityYetDot => 'No activity yet.';

  @override
  String adminDeactivateDoctorTitle(String name) {
    return 'Deactivate Dr. $name?';
  }

  @override
  String get adminDeactivateDoctorMessage =>
      'They will be signed out and cannot sign in. Their past records remain in patient histories.';

  @override
  String get commonDeactivate => 'Deactivate';

  @override
  String get commonReactivate => 'Reactivate';

  @override
  String get adminDoctorDeactivatedToast => 'Doctor deactivated';

  @override
  String get adminDoctorReactivatedToast => 'Doctor reactivated';

  @override
  String adminActionsForDoctorTooltip(String name) {
    return 'Actions for Dr. $name';
  }

  @override
  String get commonViewProfile => 'View profile';

  @override
  String get adminEditDoctorMenuItem => 'Edit doctor';

  @override
  String get adminViewPatientsMenuItem => 'View patients';

  @override
  String get commonViewActivity => 'View activity';

  @override
  String get adminNoActivityShort => 'No activity yet';

  @override
  String adminLastActiveLabel(String relative) {
    return 'Last active $relative';
  }

  @override
  String get adminDoctorSearchHint => 'Search by name, email or Doctor ID';

  @override
  String get adminNoDoctorsFound => 'No doctors found.';

  @override
  String adminDoctorsCountHeader(int count) {
    return 'Doctors ($count)';
  }

  @override
  String get adminColDoctor => 'Doctor';

  @override
  String get adminColDoctorId => 'Doctor ID';

  @override
  String get commonSpecializationLabel => 'Specialization';

  @override
  String get adminColPatients => 'Patients';

  @override
  String get adminColLastActivity => 'Last activity';

  @override
  String get adminColStatus => 'Status';

  @override
  String get commonViewProfileButton => 'View Profile';

  @override
  String adminDoctorRowCaption(int count, String lastActive) {
    return '$count active patients · $lastActive';
  }

  @override
  String get adminEditDoctorTitle => 'Edit Doctor';

  @override
  String commonCreatedOn(String date) {
    return 'Created $date';
  }

  @override
  String get adminDeactivateDoctorConfirmTitle => 'Deactivate doctor?';

  @override
  String get adminDoctorUpdatedToast => 'Doctor updated';

  @override
  String get adminDoctorCreatedToast =>
      'Doctor account created. Share the temporary password securely.';

  @override
  String get adminTemporaryPasswordLabel => 'Temporary password';

  @override
  String get adminTempPasswordHelper =>
      'The doctor should change it after first sign-in.';

  @override
  String get adminSpecializationHint => 'e.g. Endocrinology';

  @override
  String get adminLicenseNumberLabel => 'License / registration number';

  @override
  String get adminLicenseValidation =>
      'Enter the doctor\'s license or registration number.';

  @override
  String get adminCreateDoctorAccountButton => 'Create doctor account';

  @override
  String get adminDeactivateDoctorButton => 'Deactivate doctor';

  @override
  String get adminReactivateDoctorButton => 'Reactivate doctor';

  @override
  String adminDeactivatePatientTitle(String name) {
    return 'Deactivate $name?';
  }

  @override
  String get adminDeactivatePatientMessage =>
      'They will be signed out and cannot sign in. Their records are kept.';

  @override
  String get adminPatientDeactivatedToast => 'Patient deactivated';

  @override
  String get adminPatientReactivatedToast => 'Patient reactivated';

  @override
  String adminActionsForPatientTooltip(String name) {
    return 'Actions for $name';
  }

  @override
  String get adminEditPatientMenuItem => 'Edit patient';

  @override
  String get adminViewReportsMenuItem => 'View reports';

  @override
  String get adminViewDoctorsMenuItem => 'View doctors';

  @override
  String get adminUploadReportForPatientMenuItem => 'Upload report for patient';

  @override
  String get adminDeactivateAccountMenuItem => 'Deactivate account';

  @override
  String get adminReactivateAccountMenuItem => 'Reactivate account';

  @override
  String get adminPatientSearchHint => 'Search by name, email or Patient ID';

  @override
  String get adminNoPatientsFound => 'No patients found.';

  @override
  String adminPatientsCountShowing(int total, int shown) {
    return 'Patients ($total) · showing the $shown most recent. Search to find others.';
  }

  @override
  String adminPatientsCountHeader(int total) {
    return 'Patients ($total)';
  }

  @override
  String get adminColPatient => 'Patient';

  @override
  String get adminColAgeGender => 'Age / gender';

  @override
  String get adminColDiabetesStatus => 'Diabetes status';

  @override
  String adminPatientRowCaption(num count, String lastActive) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count doctors',
      one: '1 doctor',
    );
    return '$_temp0 · $lastActive';
  }

  @override
  String get adminAuditSearchHint => 'Search by action, person or reference';

  @override
  String get adminNoAuditEntries => 'No audit entries.';

  @override
  String get adminSystemRoleFallback => 'system';

  @override
  String get adminPushSent => 'Sent';

  @override
  String get adminPushFailed => 'Failed';

  @override
  String get adminPushNotAttempted => 'Not attempted';

  @override
  String get adminPushStatusOnlyNote =>
      'Push delivery status only. A notification\'s content is never shown here.';

  @override
  String get adminNoNotificationsMatchFilter =>
      'No notifications match this filter.';

  @override
  String get adminUnknownRecipient => 'Unknown recipient';

  @override
  String get adminSupportEmailLabel => 'Support email';

  @override
  String get adminSupportEmailHelper => 'Shown to users who need help.';

  @override
  String get adminUploadLimitLabel => 'Upload limit shown to users (MB)';

  @override
  String get adminUploadLimitHelper =>
      'Display only. The enforced limit is set on the server.';

  @override
  String get adminMaintenanceNoticeLabel => 'Maintenance notice';

  @override
  String get adminMaintenanceNoticeHelper => 'Optional banner text.';

  @override
  String get adminSettingsSavedToast => 'Settings saved';

  @override
  String get adminServiceStatusHeader => 'Service status';

  @override
  String get adminServiceStatusSubtitle =>
      'Secrets are configured on the server and are never shown here.';

  @override
  String get adminEnvironmentLabel => 'Environment';

  @override
  String get adminAiServiceLabel => 'AI (Google AI Studio)';

  @override
  String adminConfiguredWithModel(String model) {
    return 'Configured · $model';
  }

  @override
  String get commonNotConfigured => 'Not configured';

  @override
  String get commonOn => 'On';

  @override
  String get commonOff => 'Off';

  @override
  String get adminDiabetesModelServiceLabel => 'Diabetes model service';

  @override
  String get adminUrlConfigured => 'URL configured';

  @override
  String get adminDemoWearableLabel => 'Demo wearable';

  @override
  String get adminDemoWearableEnabled => 'Enabled (data labelled DEMO)';

  @override
  String get commonDisabled => 'Disabled';

  @override
  String get adminEditableSettingsHeader => 'Editable settings';

  @override
  String get adminSaveSettingsButton => 'Save settings';

  @override
  String get adminChangesRecordedNote =>
      'Changes are recorded in the audit log.';

  @override
  String adminEmailAdministratorLine(String email) {
    return '$email · Administrator';
  }

  @override
  String get adminAccountAndPasswordLabel => 'Account and password';

  @override
  String get diabetesRunNewAssessment => 'Run new assessment';

  @override
  String get diabetesGetRiskEstimate => 'Get risk estimate';

  @override
  String get diabetesRefreshAssessment => 'Refresh assessment';

  @override
  String get diabetesEstimateUpdatedSnack =>
      'Your future diabetes risk estimate has been updated.';

  @override
  String get diabetesNothingChangedSnack =>
      'Nothing relevant has changed since your last estimate, so it is still current.';

  @override
  String get diabetesHba1cTrendHeader => 'HbA1c Trend';

  @override
  String get diabetesHba1cTrendSubtitle =>
      'From confirmed values on your uploaded reports.';

  @override
  String get diabetesDataUsedHeader => 'Data used for this assessment';

  @override
  String get diabetesDataUsedSubtitle =>
      'Only information SUSTHITI already had. Nothing was guessed or filled in.';

  @override
  String get diabetesHealthInfoSubtitle =>
      'What an estimate would use, from your SUSTHITI records.';

  @override
  String get riskHealthInfoAvailableHeader =>
      'Health information available now';

  @override
  String get riskNotRecordedHeader => 'Not recorded yet';

  @override
  String riskNotRecordedSubtitleDiabetes(String available, String total) {
    return 'The estimate uses these when they are in your records. Until then they are left out, not assumed. $available of $total available.';
  }

  @override
  String riskNotRecordedSubtitleHeart(String available, String total) {
    return 'The screening uses these when they are in your records or answered on the form. $available of $total available.';
  }

  @override
  String get diabetesAssessmentHistoryHeader => 'Assessment history';

  @override
  String get diabetesAssessmentHistorySubtitle =>
      'Every estimate is kept exactly as it was made.';

  @override
  String get diabetesEarlierSymptomQuestionnaire =>
      'Earlier symptom questionnaire';

  @override
  String get diabetesEarlierModelSubtitle =>
      'Results from a previous model, kept for your history';

  @override
  String diabetesClassificationLabel(String value) {
    return 'Classification: $value';
  }

  @override
  String get diabetesIntroText =>
      'Estimate your future diabetes risk. You\'ll confirm a few questions, already filled in with what SUSTHITI knows; values from your medical reports, your lifestyle and connected devices are added automatically.';

  @override
  String riskHealthDetailsAvailableCaption(String available, String total) {
    return '$available of $total health details are available now.';
  }

  @override
  String get heartRunNewScreening => 'Run new screening';

  @override
  String get heartGetRiskScreening => 'Get risk screening';

  @override
  String get heartRefreshScreening => 'Refresh screening';

  @override
  String get heartScreeningUpdatedSnack =>
      'Your heart risk screening has been updated.';

  @override
  String get heartNothingChangedSnack =>
      'Nothing relevant has changed since your last screening, so it is still current.';

  @override
  String get heartDataUsedHeader => 'Data used for this screening';

  @override
  String get heartDataUsedSubtitle =>
      'Only information SUSTHITI already had, or that was answered on the assessment form.';

  @override
  String get heartHealthInfoSubtitle =>
      'What a screening would use, from your SUSTHITI records.';

  @override
  String get heartScreeningHistoryHeader => 'Screening history';

  @override
  String get heartScreeningHistorySubtitle =>
      'Every screening is kept exactly as it was made.';

  @override
  String get heartIntroText =>
      'Screen your heart disease risk. You\'ll answer a short form covering symptoms, vitals and cardiac tests; values already in your SUSTHITI records (profile, labs, lifestyle) are filled in for you to review.';

  @override
  String get commonActivityTab => 'Activity';

  @override
  String get commonAuditTab => 'Audit';

  @override
  String get commonPatientFallback => 'Patient';

  @override
  String get commonNotRecorded => 'Not recorded';

  @override
  String get commonNever => 'Never';

  @override
  String get commonNoneRecorded => 'None recorded';

  @override
  String get commonNoneYet => 'None yet';

  @override
  String get commonResolvedLabel => 'Resolved';

  @override
  String get adminEditDoctorButton => 'Edit Doctor';

  @override
  String get adocUnableToLoadProfile => 'Unable to load profile.';

  @override
  String get adocBackToDoctors => 'Back to Doctors';

  @override
  String adocDoctorIdColon(String code) {
    return 'Doctor ID: $code';
  }

  @override
  String get adocSpecializationNotRecorded => 'Specialization not recorded';

  @override
  String get adocMoreActionsTooltip => 'More actions';

  @override
  String get adocViewAuditLogMenuItem => 'View audit log';

  @override
  String adocTotalPendingCaption(String total, String pending) {
    return '$total total · $pending pending';
  }

  @override
  String adocThisMonthTotalCaption(String month, String total) {
    return '$month this month · $total total';
  }

  @override
  String get adocUpcomingLabel => 'Upcoming';

  @override
  String adocFollowUpsApptsCaption(String followUps, String appts) {
    return '$followUps follow-ups · $appts appts';
  }

  @override
  String adocPendingResolvedCaption(String pending, String resolved) {
    return '$pending pending · $resolved resolved';
  }

  @override
  String get adocActivePatientsHeader => 'Active Patients';

  @override
  String get adocNoActivePatients => 'No active patients.';

  @override
  String get adocNoRecordedActivityYet => 'No recorded activity yet.';

  @override
  String get adocPatientAccessHeader => 'Patient Access';

  @override
  String get adocPatientAccessSubtitle =>
      'Relationships approved or pending through patient authorization';

  @override
  String get adocNoAccessRequestsYet => 'No access requests yet.';

  @override
  String adocRequestedOnCaption(String code, String date) {
    return '$code · requested $date';
  }

  @override
  String get adocFiguresDisclaimer =>
      'Figures are counted from recorded data. SUSTHITI does not calculate a health score.';

  @override
  String get adocNoActivity => 'No activity';

  @override
  String get adocPatientProgressHeader => 'Patient Progress';

  @override
  String adocAcrossActivePatients(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Across $count active patients',
      one: 'Across 1 active patient',
    );
    return '$_temp0';
  }

  @override
  String get adocLatestClassificationLabel =>
      'Latest diabetes model classification';

  @override
  String get adocPatternDetected => 'Pattern detected';

  @override
  String get adocNoPatternDetected => 'No pattern detected';

  @override
  String get adocGlucoseLast7DaysLabel =>
      'Glucose, last 7 days vs previous weeks';

  @override
  String get adocSimilarLabel => 'Similar';

  @override
  String get adocTooFewReadings => 'Too few readings';

  @override
  String adocNeedAttentionPill(String count) {
    return '$count need attention';
  }

  @override
  String adocOpenSideEffectsPill(String count) {
    return '$count with open side effects';
  }

  @override
  String adocAssessedIn30DaysPill(String count) {
    return '$count assessed in 30 days';
  }

  @override
  String adocInactiveFor30DaysPill(String count) {
    return '$count inactive for 30 days';
  }

  @override
  String get adocNoPatientsInGroup => 'No patients in this group.';

  @override
  String adocPatientsCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count patients',
      one: '1 patient',
    );
    return '$_temp0';
  }

  @override
  String get adocLatestGlucoseCol => 'Latest glucose';

  @override
  String get adocProgressCol => 'Progress';

  @override
  String get adocAccessCol => 'Access';

  @override
  String adocGlucoseMgDl(String value) {
    return 'Glucose $value mg/dL';
  }

  @override
  String adocLastActivityLine(String value) {
    return 'Last activity $value';
  }

  @override
  String adocReportDateLabel(String date) {
    return 'Report date $date';
  }

  @override
  String adocOpenedLabel(String relative) {
    return 'Opened $relative';
  }

  @override
  String adocUploadedLabel(String date) {
    return 'Uploaded $date';
  }

  @override
  String get adocReportsUploadedHeader => 'Reports Uploaded';

  @override
  String get adocNoReportsUploadedByDoctor =>
      'No reports uploaded by this doctor.';

  @override
  String get adocReportsOpenedHeader => 'Reports Opened';

  @override
  String get adocReportsOpenedSubtitle =>
      'Original files the doctor viewed or downloaded';

  @override
  String get adocNoRecentReportActivity => 'No recent report activity.';

  @override
  String get adocAiSummariesHeader => 'AI Report Summaries Generated';

  @override
  String get adocNoSummariesGenerated => 'No report summaries generated.';

  @override
  String get adocAllReportsSummaryTitle => 'All-reports summary';

  @override
  String get adocReportSummaryTitle => 'Report summary';

  @override
  String get adocPrescriptionsHistoricalNote =>
      'Prescriptions are historical records. Viewing them never changes them.';

  @override
  String get adocNoPrescriptionsRecorded => 'No prescriptions recorded.';

  @override
  String adocPrescriptionsCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count prescriptions',
      one: '1 prescription',
    );
    return '$_temp0';
  }

  @override
  String get adocPrescriptionCol => 'Prescription';

  @override
  String get adocMedicinesCol => 'Medicines';

  @override
  String adocMedicinesCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medicines',
      one: '1 medicine',
    );
    return '$_temp0';
  }

  @override
  String get adocUpcomingFollowUpsHeader => 'Upcoming Follow-ups';

  @override
  String get adocUpcomingFollowUpsSubtitle =>
      'Follow-up dates from this doctor\'s visits and prescriptions';

  @override
  String get adocNoUpcomingFollowUps => 'No upcoming follow-ups.';

  @override
  String get adocVisitFollowUpLabel => 'Visit follow-up';

  @override
  String get adocPrescriptionFollowUpLabel => 'Prescription follow-up';

  @override
  String adocFollowUpStatusLabel(String status) {
    return 'Follow-up$status';
  }

  @override
  String get adocAppointmentRecommendationsHeader =>
      'Appointment Recommendations';

  @override
  String get adocNoAppointmentRecommendations =>
      'No appointment recommendations.';

  @override
  String adocRecommendedOn(String date) {
    return 'Recommended $date';
  }

  @override
  String adocSuggestedFor(String date) {
    return 'Suggested for $date';
  }

  @override
  String get adocRecentVisitsHeader => 'Recent Visits';

  @override
  String get adocNoVisitsRecorded => 'No visits recorded.';

  @override
  String get adocScheduledSurgeriesHeader => 'Scheduled Surgeries';

  @override
  String get adocPendingReviewLabel => 'Pending review';

  @override
  String get adocRespondedByDoctorLabel => 'Responded by this doctor';

  @override
  String get adocNoSideEffectReports => 'No side-effect reports.';

  @override
  String get adocSideEffectCol => 'Side effect';

  @override
  String get adocSeverityCol => 'Severity';

  @override
  String get adocReportedCol => 'Reported';

  @override
  String get adocDoctorResponseCol => 'Doctor response';

  @override
  String get adocNoResponseYet => 'No response yet';

  @override
  String get adocDoctorActivitySubtitle =>
      'What this doctor has done in SUSTHITI. Open an entry to see the record.';

  @override
  String adocLatestOfTotalEntries(int shown, int total) {
    return 'Latest $shown of $total entries';
  }

  @override
  String adocEntriesCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
    );
    return '$_temp0';
  }

  @override
  String get commonDateColumnLabel => 'Date';

  @override
  String get adocActionCol => 'Action';

  @override
  String get adocRelatedRecordCol => 'Related record';

  @override
  String get adocPerformedByCol => 'Performed by';

  @override
  String get adocDoctorInformationHeader => 'Doctor Information';

  @override
  String get adocLicenseRegistrationLabel => 'License / registration';

  @override
  String get adocAccountCreatedLabel => 'Account created';

  @override
  String get adocLastSignInLabel => 'Last sign-in';

  @override
  String get apatUnableToLoadDetails => 'Unable to load patient details.';

  @override
  String get apatBackToPatients => 'Back to Patients';

  @override
  String apatPatientIdColon(String code) {
    return 'Patient ID: $code';
  }

  @override
  String commonAgeYears(String age) {
    return '$age years';
  }

  @override
  String get apatEditPatientButton => 'Edit Patient';

  @override
  String get apatFoodTab => 'Food';

  @override
  String get apatAiSummariesTab => 'AI Summaries';

  @override
  String get apatUnableToLoad => 'Unable to load';

  @override
  String get apatLatestGlucoseLabel => 'Latest glucose';

  @override
  String apatGlucoseRelativeTrend(String relative, String trend) {
    return '$relative · $trend';
  }

  @override
  String get apatCurrentDoctorsHeader => 'Current Doctors';

  @override
  String get apatAllRelationshipsButton => 'All relationships';

  @override
  String get apatNoDoctorAccess => 'No doctor currently has access.';

  @override
  String get apatRecentReportsHeader => 'Recent Reports';

  @override
  String get apatNoRecordedHistoryYet => 'No recorded history yet.';

  @override
  String get apatNoUpcomingFollowUp => 'No upcoming follow-up';

  @override
  String apatNextFollowUpOn(String date) {
    return 'Next follow-up $date';
  }

  @override
  String get apatFromVisitsAndPrescriptions => 'From visits and prescriptions';

  @override
  String apatForDate(String date) {
    return 'for $date';
  }

  @override
  String get apatLongitudinalTrendsHeader => 'Longitudinal Trends';

  @override
  String get apatLongitudinalTrendsSubtitle =>
      'Recorded values only. Nothing is estimated or filled in.';

  @override
  String get apatGlucoseDetailsButton => 'Glucose details';

  @override
  String get apatGlucoseMgDlTitle => 'Glucose (mg/dL)';

  @override
  String get apatNoDevicesConnected => 'No devices connected.';

  @override
  String get apatDisconnectedLabel => 'Disconnected';

  @override
  String get apatNeverLower => 'never';

  @override
  String apatLastSyncedPrefix(String value) {
    return 'Last synced $value';
  }

  @override
  String get apatSyncFailedLabel => 'sync failed';

  @override
  String apatCountsSummary(
    String reports,
    String assessments,
    String glucose,
    String prescriptions,
    String visits,
    String sideEffects,
  ) {
    return 'Counts: $reports reports · $assessments assessments · $glucose glucose readings · $prescriptions prescriptions · $visits visits · $sideEffects side effects';
  }

  @override
  String apatHistoryCountButton(int count) {
    return 'History ($count)';
  }

  @override
  String get apatNoRiskEstimateYet => 'No risk estimate recorded yet.';

  @override
  String apatAssessedOn(String date, String model) {
    return 'Assessed $date$model';
  }

  @override
  String get apatOpenEstimateButton => 'Open estimate';

  @override
  String apatAccessSinceLabel(String date) {
    return 'Access since $date';
  }

  @override
  String get apatPersonalInfoHeader => 'Personal Information';

  @override
  String get apatHeightWeightLabel => 'Height / weight';

  @override
  String get apatBmiCalculatedLabel => 'BMI (calculated)';

  @override
  String get apatNoEmergencyContactRecorded => 'No emergency contact recorded.';

  @override
  String get apatFoodLoggedNote =>
      'Food logged in the last 30 days. Edited entries keep their earlier versions.';

  @override
  String get apatNoFoodLogged30Days => 'No food logged in the last 30 days.';

  @override
  String get apatNoUpcomingFollowUpRecorded =>
      'No upcoming follow-up recorded.';

  @override
  String apatNextFollowUpColon(String date) {
    return 'Next follow-up: $date';
  }

  @override
  String get commonRelatedToSideEffect => 'Related to a side-effect report';

  @override
  String get apatAiDisclaimerText =>
      'AI summaries are generated from available records. They are not a doctor\'s clinical conclusion and do not replace medical advice. Every generation is kept; nothing here is regenerated when you view it.';

  @override
  String get apatNoAiSummariesYet => 'No AI summaries generated yet.';

  @override
  String apatGeneratedOn(String datetime) {
    return 'Generated $datetime';
  }

  @override
  String apatByRoleSuffix(String role) {
    return ' by $role';
  }

  @override
  String get apatNewerRecordsExist => 'newer records exist';

  @override
  String apatBasedOnLabel(String list) {
    return 'Based on: $list';
  }

  @override
  String apatAiModelLabel(String model) {
    return 'AI model: $model';
  }

  @override
  String get apatViewPdfButton => 'View PDF';

  @override
  String get apatDownloadPdfButton => 'Download PDF';

  @override
  String get apatDoctorRelationshipsNote =>
      'Every doctor relationship, including past ones. Doctors see records only while access is approved by the patient.';

  @override
  String get apatNoDoctorRequestedAccess =>
      'No doctor has requested access yet.';

  @override
  String get apatRequestedCol => 'Requested';

  @override
  String get apatGrantedEndedCol => 'Granted / ended';

  @override
  String apatEndedOn(String date) {
    return 'Ended $date';
  }

  @override
  String apatSpecRequestedCaption(String spec, String date) {
    return '$spec · requested $date';
  }

  @override
  String get apatLongitudinalHistoryHeader => 'Longitudinal History';

  @override
  String get apatLongitudinalHistorySubtitle =>
      'Each record keeps its own medical date. Open an entry to see the record.';

  @override
  String get apatNothingInCategory => 'Nothing recorded in this category.';

  @override
  String get apatNotificationsSentHeader => 'Notifications Sent to the Patient';

  @override
  String get apatNoNotificationsSent => 'No notifications sent.';

  @override
  String get commonRead => 'Read';

  @override
  String get apatEditPatientTitle => 'Edit Patient';

  @override
  String get apatPatientDetailsUpdatedToast => 'Patient details updated';

  @override
  String get apatDobGenderNotEditableNote =>
      'Date of birth and gender are provided by the patient and used by the diabetes model, so they are not editable here. Medical records cannot be changed from this screen. Changes are recorded in the audit log.';

  @override
  String get timelineFilterAssessments => 'Assessments';

  @override
  String get timelineFilterAiSummaries => 'AI summaries';

  @override
  String get timelineNoRecordsYet => 'No records yet.';

  @override
  String get timelineEmptyMessage =>
      'Reports, assessments, prescriptions and visits will appear here in date order.';

  @override
  String get apptRecommendationsNote =>
      'Recommendations from your doctor. Please contact the clinic to book a time.';

  @override
  String get adocRecentActivityHeader => 'Recent Activity';

  @override
  String get reportsSelectReportTitle => 'Select a report';

  @override
  String get reportsSelectReportMessage =>
      'Its details, original file and AI summary appear here.';

  @override
  String get reportsSearchHint => 'Search reports...';

  @override
  String get reportsFilterTooltip => 'Filter reports';

  @override
  String get reportsUnableToLoad => 'Unable to load your reports.';

  @override
  String get reportsNoMatchTitle => 'No matching reports';

  @override
  String get reportsNoMatchMessage => 'Try a different search or filter.';

  @override
  String get reportsEmptyTitle => 'No reports yet.';

  @override
  String get reportsEmptyMessage =>
      'Upload your first medical report to begin building your health history.';

  @override
  String reportsCountLabel(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports',
      one: '1 report',
    );
    return '$_temp0';
  }

  @override
  String get commonLoadMore => 'Load more';

  @override
  String get allReportsSummaryTitle => 'All Reports Summary';

  @override
  String get allReportsSummarySubtitle =>
      'What your collection of reports shows over time';

  @override
  String reportTileSemantic(
    String title,
    String reportDate,
    String uploadedDate,
    String role,
  ) {
    return '$title, report date $reportDate, uploaded $uploadedDate by $role';
  }

  @override
  String reportUploadedByLine(String date, String role) {
    return 'Uploaded $date · by $role';
  }

  @override
  String get reportsFilterSheetTitle => 'Filter Reports';

  @override
  String get commonCategoryLabel => 'Category';

  @override
  String get commonAny => 'Any';

  @override
  String get reportsClearDatesTooltip => 'Clear dates';

  @override
  String get commonSortLabel => 'Sort';

  @override
  String get commonNewest => 'Newest';

  @override
  String get commonOldest => 'Oldest';

  @override
  String get commonReset => 'Reset';

  @override
  String get commonApply => 'Apply';

  @override
  String get allReportsSummaryDisclaimer =>
      'This summary reviews your authorized report history together, in order of report date, and only describes trends that the reports actually support. For what a single report says, open that report and use its AI Summary.';

  @override
  String get combinedReportSummaryTitle => 'Combined report summary';

  @override
  String combinedSummaryEmptyMessage(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reports',
      one: '1 report',
    );
    return 'No combined summary generated yet. $_temp0 available.';
  }

  @override
  String get needTwoReportsReason =>
      'At least two reports are needed to look at changes over time.';

  @override
  String get generateAllReportsSummaryButton => 'Generate All Reports Summary';

  @override
  String get reviewingHistoricalReportsMessage =>
      'Reviewing historical reports...';

  @override
  String get originalReportsSafeMessage =>
      'Your original reports are still safely available.';

  @override
  String get reportFallbackTitle => 'Report';

  @override
  String get aiSummaryTitle => 'AI Summary';

  @override
  String get noSummaryGeneratedYet => 'No summary generated yet.';

  @override
  String get analyzingReportMessage => 'Analyzing report...';

  @override
  String get originalReportSafeMessage =>
      'Your original report is still safely available.';

  @override
  String get commonUploadedLabel => 'Uploaded';

  @override
  String get commonUploadedByLabel => 'Uploaded by';

  @override
  String get reportIdLabel => 'Report ID';

  @override
  String get originalReportHeader => 'Original Report';

  @override
  String get commonView => 'View';

  @override
  String get commonDownload => 'Download';

  @override
  String get imageCannotPreview => 'This image can\'t be previewed here.';

  @override
  String get useDownloadToOpen => 'Use Download to open it in another app.';

  @override
  String get reportValuesSavedToast => 'Report values saved.';

  @override
  String get noValuesReadFromReport =>
      'No values could be read from this report.';

  @override
  String get valuesReadPleaseCheck =>
      'Values read from the report. Please check them.';

  @override
  String get valuesFromReportHeader => 'Values from this report';

  @override
  String get reportValuesAutoReadDescription =>
      'SUSTHITI reads HbA1c and glucose results from the report automatically and uses them in your health features, including your future diabetes risk estimate.';

  @override
  String get noValuesRecordedYet => 'No values recorded from this report yet.';

  @override
  String get looksRightButton => 'Looks right';

  @override
  String get readAutomaticallyLabel => 'Read automatically';

  @override
  String get checkedByDoctorLabel => 'Checked by doctor';

  @override
  String get checkedByYouLabel => 'Checked by you';

  @override
  String get commonYou => 'You';

  @override
  String get readAutoCheckNote =>
      'Read automatically: please check these against the report. Correct them with \"Add or correct values\" if needed.';

  @override
  String get foundInAiSummaryNote =>
      'Found in the AI summary. Please check them against the report before confirming:';

  @override
  String get theseMatchReportButton => 'These match the report';

  @override
  String get readValuesFromReportButton => 'Read values from this report';

  @override
  String get addValuesYourselfButton => 'Add values yourself';

  @override
  String get addOrCorrectValuesButton => 'Add or correct values';

  @override
  String reportValuesFormSubtitle(String date) {
    return 'Report date $date. Leave a value empty if the report doesn\'t show it.';
  }

  @override
  String enterAsNumberError(String label) {
    return 'Enter $label as a number, exactly as in the report.';
  }

  @override
  String get classificationOnlyIfStatedNote =>
      'Only if the report itself states it. SUSTHITI never works this out from the numbers.';

  @override
  String get notStatedChip => 'Not stated';

  @override
  String get saveValuesButton => 'Save values';

  @override
  String get riskEstimateTitle => 'Risk estimate';

  @override
  String get riskDetailDataUsedHeader => 'Data used';

  @override
  String get riskDetailDataUsedSubtitleEstimate =>
      'As recorded when this estimate was made.';

  @override
  String get riskDetailNotAvailableHeader => 'Not available at the time';

  @override
  String get riskDetailNotAssumedSubtitleEstimate =>
      'Left out of this estimate, not assumed.';

  @override
  String get commonRecordLabel => 'Record';

  @override
  String get assessmentIdLabel => 'Assessment ID';

  @override
  String get commonMadeLabel => 'Made';

  @override
  String get commonRequestedByLabel => 'Requested by';

  @override
  String get commonModelVersionLabel => 'Model version';

  @override
  String get riskBandsLabel => 'Risk bands';

  @override
  String get riskPatternThresholdLabel => 'Risk pattern threshold';

  @override
  String get bmiCalculatedByModelLabel =>
      'BMI (calculated by the model service)';

  @override
  String get valuesSentToModelLabel => 'Values sent to the model';

  @override
  String get modelInputFieldsNote =>
      'Only the model\'s own input fields; unknown values were left out.';

  @override
  String get commonTimeLabel => 'Time';

  @override
  String get commonModelLabel => 'Model';

  @override
  String get commonEnteredByLabel => 'Entered by';

  @override
  String get modelInputsHeader => 'Model inputs';

  @override
  String get sixteenAnswersNote =>
      'All 16 answers exactly as sent to the earlier model.';

  @override
  String get aiInterpretationTitle => 'AI Interpretation';

  @override
  String get aiInterpretationEmptyMessage =>
      'Combine this assessment with your recent lifestyle and glucose data for a calm, forward-looking explanation. This is an AI interpretation, not a new prediction.';

  @override
  String get generateInterpretationButton => 'Generate interpretation';

  @override
  String get analyzingLifestylePatternsMessage =>
      'Analyzing lifestyle patterns...';

  @override
  String get assessmentResultSafeMessage =>
      'Your assessment result is still saved and unchanged.';

  @override
  String glucoseAverageReadings(String avg, String count) {
    return '$avg mg/dL average ($count readings)';
  }

  @override
  String foodEntriesOverDays(String count, String days) {
    return '$count entries over $days days';
  }

  @override
  String metricAverageDays(String value, String days) {
    return '$value average ($days days)';
  }

  @override
  String get lifestyleSnapshotHeader => 'Lifestyle snapshot';

  @override
  String get last7DaysBeforeAssessmentNote =>
      'Recorded data from the 7 days before this assessment.';

  @override
  String get noLifestyleDataAtTime =>
      'No lifestyle data was recorded at the time.';

  @override
  String get heartRiskScreeningTitle => 'Heart risk screening';

  @override
  String get riskDetailDataUsedSubtitleScreening =>
      'As recorded when this screening was made.';

  @override
  String get riskDetailNotAssumedSubtitleScreening =>
      'Left out of this screening, not assumed.';

  @override
  String get screeningIdLabel => 'Screening ID';

  @override
  String get decisionThresholdLabel => 'Decision threshold';

  @override
  String get bmiCalculatedHeightWeightLabel =>
      'BMI (calculated from height and weight)';

  @override
  String get mlScreeningResultLabel => 'ML screening result';

  @override
  String get modelClassificationLabel => 'Model classification';

  @override
  String get assessedLabel => 'Assessed';

  @override
  String get viewWhatThisMeansButton => 'View What This Means';

  @override
  String get whatThisMeansHeader => 'What this means';

  @override
  String get shareWithDoctorPositiveNote =>
      'Consider sharing this result with a doctor. Tests such as fasting glucose or HbA1c are how diabetes is actually diagnosed.';

  @override
  String get doesNotRuleOutNote =>
      'This does not rule out diabetes. If you have symptoms or concerns, talk to a doctor.';

  @override
  String get commonImportantLabel => 'Important';

  @override
  String get whatAssessmentMeansHeader => 'What this assessment means';

  @override
  String get whatModelDoesHeader => 'What the model does';

  @override
  String get whatModelDoesText =>
      'A trained machine-learning model (an RBF support vector machine) looks at your age, gender and 14 yes/no symptom answers and classifies whether they match a pattern associated with diabetes in the data it was trained on.';

  @override
  String get probabilityExplanationText =>
      'The probability the model assigns to the Positive (diabetes-related pattern) class for the answers you gave. A low value goes with a Negative result. It is not the probability that you have or will develop diabetes.';

  @override
  String get whatItCantTellHeader => 'What it can\'t tell you';

  @override
  String get whatItCantTellText =>
      'It is not a diagnosis, and it cannot predict whether or when you might develop diabetes. The training data doesn\'t include long-term follow-up, so no timeframe can be estimated.';

  @override
  String get whatToDoNextHeader => 'What to do next';

  @override
  String get whatToDoNextText =>
      'Share the result with your doctor, especially if it shows an elevated risk pattern or your symptoms continue. Tests such as fasting glucose or HbA1c are how diabetes is actually diagnosed.';

  @override
  String get seekCareIfUnwellNote =>
      'If you feel very unwell, seek medical care promptly. SUSTHITI does not replace professional medical diagnosis, treatment, or emergency care.';

  @override
  String get diabetesRiskAssessmentTitle => 'Diabetes risk assessment';

  @override
  String get commonReviewLabel => 'Review';

  @override
  String stepOfTotalLabel(int step, int total, String label) {
    return 'Step $step of $total: $label';
  }

  @override
  String get commonBack => 'Back';

  @override
  String get commonNext => 'Next';

  @override
  String get seeMyResultButton => 'See my result';

  @override
  String get answersSavedToProfileNote =>
      'Your answers are saved to your health profile, so you won\'t be asked again elsewhere.';

  @override
  String get alsoUsedAutoHeader => 'Also used, collected automatically';

  @override
  String get autoValuesExplanation =>
      'Values read from your reports and data from your phone. To change a report value, open the report.';

  @override
  String get noAutoDataYetMessage =>
      'No report values or phone data yet. Upload a report with HbA1c or glucose results to include them.';

  @override
  String get heartQuestionnaireIntro =>
      'A few questions, already filled in with what SUSTHITI knows where possible; symptoms and test results are always answered fresh.';

  @override
  String get heartSectionBasicInfo => 'A. Basic information';

  @override
  String get heartSectionMedicalHistory => 'B. Medical history';

  @override
  String get heartSectionSymptoms => 'C. Symptoms';

  @override
  String get heartSectionVitals => 'D. Vitals';

  @override
  String get heartSectionLabValues => 'E. Laboratory values';

  @override
  String get heartSectionCardiacTests => 'F. Cardiac tests';

  @override
  String get heartSectionLifestyle => 'G. Lifestyle';

  @override
  String numberBetweenError(String label, String min, String max, String unit) {
    return '$label must be a number between $min and $max $unit.';
  }

  @override
  String get heartAnswersSavedNote =>
      'Answers to medical history and lifestyle questions are saved to your health profile. Symptoms and test results are kept only with this screening.';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get notAnsweredHint => 'Not answered';

  @override
  String fromYourRecordsLabel(String value, String detail) {
    return 'From your records: $value$detail';
  }

  @override
  String get notCurrentlyKnownLabel => 'Not currently known';

  @override
  String get leaveBlankToKeepHint => 'Leave blank to keep this';

  @override
  String get heartFieldChestPain => 'Chest pain';

  @override
  String get heartFieldChestPainType => 'Chest pain type';

  @override
  String get heartOptionTypicalAngina => 'Typical angina';

  @override
  String get heartOptionAtypicalAngina => 'Atypical angina';

  @override
  String get heartOptionNonAnginal => 'Non-anginal';

  @override
  String get heartFieldChestPainDuration => 'Chest pain duration';

  @override
  String get heartFieldShortnessOfBreath => 'Shortness of breath';

  @override
  String get heartFieldFatigue => 'Fatigue';

  @override
  String get heartFieldDizziness => 'Dizziness';

  @override
  String get heartFieldFainting => 'Fainting';

  @override
  String get heartFieldSweating => 'Sweating';

  @override
  String get heartFieldNausea => 'Nausea';

  @override
  String get heartFieldPalpitations => 'Palpitations';

  @override
  String get heartFieldLeftArmPain => 'Left-arm pain';

  @override
  String get heartFieldJawNeckPain => 'Jaw or neck pain';

  @override
  String get heartFieldBackPain => 'Back pain';

  @override
  String get heartFieldRestingEcg => 'Resting ECG';

  @override
  String get heartOptionNormal => 'Normal';

  @override
  String get heartOptionNormalVariant => 'Normal variant';

  @override
  String get heartOptionStTAbnormality => 'ST-T abnormality';

  @override
  String get heartOptionOldInfarctPattern => 'Old infarct pattern';

  @override
  String get heartOptionLvh => 'Left ventricular hypertrophy (LVH)';

  @override
  String get heartFieldEcgAbnormality => 'ECG abnormality';

  @override
  String get heartFieldStDepression => 'ST depression';

  @override
  String get heartFieldExerciseAngina => 'Exercise-induced angina';

  @override
  String get heartFieldMaxHeartRate => 'Maximum heart rate (exercise)';

  @override
  String get heartFieldExerciseDuration => 'Exercise duration';

  @override
  String get heartFieldStressTestResult => 'Stress test result';

  @override
  String get heartOptionNegative => 'Negative';

  @override
  String get heartOptionBorderline => 'Borderline';

  @override
  String get heartOptionPositive => 'Positive';

  @override
  String get heartFieldEchoResult => 'Echocardiogram result';

  @override
  String get heartOptionMildAbnormality => 'Mild abnormality';

  @override
  String get heartOptionSignificantAbnormality => 'Significant abnormality';

  @override
  String get heartFieldEjectionFraction => 'Ejection fraction';

  @override
  String get heartFieldWallMotionAbnormality => 'Heart wall motion abnormality';

  @override
  String get heartFieldPreviousAbnormalTest => 'Previous abnormal cardiac test';

  @override
  String get heartHelpDiabetes => 'A doctor has diagnosed you with diabetes.';

  @override
  String get heartFieldRespiratoryRate => 'Respiratory rate';

  @override
  String get heartFieldStressLevel => 'Stress level (0 = none, 10 = severe)';

  @override
  String get heartFieldRestingHeartRate => 'Resting heart rate';

  @override
  String get heartFieldSystolicBp => 'Systolic blood pressure';

  @override
  String get heartFieldDiastolicBp => 'Diastolic blood pressure';

  @override
  String get heartFieldOxygenSaturation => 'Oxygen saturation';

  @override
  String get heartFieldFastingGlucose => 'Fasting glucose';

  @override
  String get heartFieldRandomGlucose => 'Random glucose';

  @override
  String get heartFieldTotalCholesterol => 'Total cholesterol';

  @override
  String get heartFieldLdl => 'LDL cholesterol';

  @override
  String get heartFieldHdl => 'HDL cholesterol';

  @override
  String get heartFieldTriglycerides => 'Triglycerides';

  @override
  String get heartFieldTroponin => 'Troponin';

  @override
  String get heartFieldHemoglobin => 'Hemoglobin';

  @override
  String get heartFieldCreatinine => 'Creatinine';

  @override
  String get heartFieldSleep => 'Sleep';

  @override
  String get heartUnitHoursANight => 'h a night';

  @override
  String get healthProfileIntroText =>
      'SUSTHITI keeps these answers once and uses them wherever they are needed, including your future diabetes risk estimate. Answer what you know; \"Not sure\" is always fine and is never treated as \"No\".';

  @override
  String get healthProfileSavedToast => 'Health profile saved.';

  @override
  String get saveHealthProfileButton => 'Save health profile';

  @override
  String get heightLabel => 'Height';

  @override
  String get weightLabel => 'Weight';

  @override
  String get bmiLabel => 'BMI';

  @override
  String get needsHeightWeightLabel => 'Needs height and weight';

  @override
  String get bmiAutoCalculatedNote =>
      'BMI is calculated automatically from height and weight.';

  @override
  String get addHeightWeightButton => 'Add height and weight';

  @override
  String get updateHeightWeightButton => 'Update height or weight';

  @override
  String get profileIntroBody =>
      'Used to calculate BMI and for health risk estimates.';

  @override
  String get profileIntroMedicalHistory =>
      'Conditions a doctor has diagnosed. Choose \"Not sure\" if you don\'t know.';

  @override
  String get profileIntroFamilyHistory => 'Your parents, brothers and sisters.';

  @override
  String get profileIntroHabits =>
      'Your usual habits. Physical activity is taken from your phone\'s step count when enough is recorded.';

  @override
  String get profileIntroSymptoms =>
      'In the last few weeks, have you noticed any of these? Answers are used for 90 days.';

  @override
  String listItemTooLongError(String label) {
    return '$label: each item must be 200 characters or fewer.';
  }

  @override
  String listTooManyItemsError(String label) {
    return '$label: list up to 20 items.';
  }

  @override
  String get notSureOption => 'Not sure';

  @override
  String answeredByLabel(String date, String who) {
    return 'Answered $date by $who';
  }

  @override
  String get yourDoctorLabel => 'your doctor';

  @override
  String get notAnsweredYetLabel => 'Not answered yet';

  @override
  String confirmStillCorrectCaption(String caption) {
    return '$caption. Please confirm it is still correct.';
  }

  @override
  String get stillCorrectButton => 'Still correct';

  @override
  String get notRecordedListHint =>
      'Not recorded — separate multiple entries with a comma or a new line';

  @override
  String get qrScanPageTitle => 'Scan Patient QR';

  @override
  String get qrCameraUnavailableTitle => 'Camera unavailable';

  @override
  String get qrCameraUnavailableMessage =>
      'SUSTHITI needs camera access to scan a QR code. You can still use \"Add Patient\" to enter the details manually.';

  @override
  String get qrPointCameraHint => 'Point the camera at the patient\'s QR code';

  @override
  String get qrRequestSentTitle => 'Request sent';

  @override
  String qrRequestSentMessage(String name, String code) {
    return '$name ($code) will be asked to approve your request. You will be notified when they respond.';
  }

  @override
  String get qrViewRequestsButton => 'View requests';

  @override
  String get qrScanAnotherButton => 'Scan another';

  @override
  String get qrScanAgainButton => 'Scan again';

  @override
  String get qrPatientIdentityHeader => 'Patient identity';

  @override
  String get qrConfirmPatientNote =>
      'Confirm this is the right patient before requesting access. They must still approve it.';

  @override
  String get wearDevicesPageTitle => 'Connected Devices';

  @override
  String get wearHealthSourcesHeader => 'Health data sources';

  @override
  String get wearHealthSourcesSubtitle =>
      'Synced data is stored in your SUSTHITI record, so it is the same on your phone, tablet and the web.';

  @override
  String get wearNoDeviceTitle => 'No health device connected.';

  @override
  String get wearNoDeviceBody =>
      'Connect a supported health platform to automatically sync your lifestyle data.';

  @override
  String get wearDisconnectNote =>
      'Disconnecting stops new data from syncing. Data already synced stays in your history. To change what SUSTHITI may read, use Health Connect (Android) or Settings, then Health (iPhone).';

  @override
  String get wearSyncFailedPermissions =>
      'Sync didn\'t complete. Check your health permissions and try again.';

  @override
  String get wearDisconnectConfirmTitle => 'Disconnect health data?';

  @override
  String get wearDisconnectConfirmMessage =>
      'SUSTHITI will stop syncing new health data from this source.\n\nPreviously synchronized records will remain available according to your data-retention settings.';

  @override
  String get wearDisconnectButton => 'Disconnect';

  @override
  String get wearDisconnectedToast =>
      'Disconnected. Your synced history is kept.';

  @override
  String get wearAndroidPhoneLabel => 'Android phone';

  @override
  String get wearIphoneLabel => 'iPhone';

  @override
  String wearFromPlatformFragment(String platform) {
    return 'from your $platform';
  }

  @override
  String wearConnectedDateNote(String date) {
    return 'connected $date';
  }

  @override
  String get wearSyncUnavailablePill => 'Sync unavailable';

  @override
  String get wearConnectedPill => 'Connected';

  @override
  String get wearPermissionsLabel => 'Permissions';

  @override
  String get wearRetryButton => 'Retry';

  @override
  String get wearSyncNowButton => 'Sync Now';

  @override
  String wearSyncsFromPhoneNote(String platform) {
    return 'Syncs from your $platform. Open SUSTHITI there to sync.';
  }

  @override
  String get wearGenericPhoneLabel => 'phone';

  @override
  String get wearPermissionShared => 'shared';

  @override
  String get wearPermissionNotShared => 'not shared';

  @override
  String get wearDemoTryTitle => 'Try with DEMO data';

  @override
  String get wearDemoNote =>
      'Development only. Adds clearly labelled demo values; never real health data.';

  @override
  String get wearNotSyncedYet => 'Not synced yet';

  @override
  String wearLastSyncedAt(String time) {
    return 'Last synced $time';
  }

  @override
  String get wearConnectTitle => 'Connect your health data';

  @override
  String wearConnectSubtitle(String platform) {
    return 'Sync steps, heart rate, sleep and more from $platform.';
  }

  @override
  String get wearConnectButton => 'Connect';

  @override
  String get wearSyncingTitle => 'Syncing health data...';

  @override
  String wearReadingDataSubtitle(String platform) {
    return 'Reading new data from $platform.';
  }

  @override
  String get wearConnectedTitle => 'Health data connected';

  @override
  String get wearLastSyncIncomplete => 'The last sync did not complete.';

  @override
  String get wearNotConnectedReadOnlyTitle => 'Health data not connected';

  @override
  String get wearConnectFromMobileNote =>
      'Connect health data from the SUSTHITI mobile app (Lifestyle, then Connect). It will appear here automatically.';

  @override
  String get wearHealthDataLabel => 'Health data';

  @override
  String get wearApplePlatformLabel => 'Apple Health on iPhone';

  @override
  String get wearAndroidPlatformLabel => 'Health Connect on Android';

  @override
  String get wearGenericMobilePlatformLabel => 'the mobile health platform';

  @override
  String wearConnectedThroughNote(String platform) {
    return 'Connected through $platform';
  }

  @override
  String get wearRefreshButton => 'Refresh';

  @override
  String get wearManageDevicesButton => 'Manage connected devices';

  @override
  String get wearOfflineLabel => 'Offline';

  @override
  String get wearTapToSyncHint => 'Tap to sync.';

  @override
  String get wearNoneConnectedSummary =>
      'No health platform connected. Values shown were entered manually.';

  @override
  String get wearConnectPageTitle => 'Connect Health Data';

  @override
  String get wearDeniedTitle => 'Health data access wasn\'t enabled.';

  @override
  String get wearDeniedBodyIos =>
      'You can enable it later from Connected Devices. On iPhone: open Settings, then Health, Data Access & Devices, SUSTHITI, and turn on the data you want to share.';

  @override
  String get wearDeniedBodyOther =>
      'You can enable it later from Connected Devices.';

  @override
  String get wearOpenHealthConnectButton => 'Open Health Connect';

  @override
  String get wearNotNowButton => 'Not now';

  @override
  String get wearNeedsInstallTitle => 'Health Connect is needed';

  @override
  String get wearNeedsInstallBody =>
      'Android keeps health data from your watch and fitness apps in Health Connect. Install or update it, then come back and continue.';

  @override
  String get wearInstallButton => 'Install Health Connect';

  @override
  String get wearUnavailableTitle => 'Connect from your phone';

  @override
  String get wearUnavailableBody =>
      'Browsers and computers cannot read health data directly. Open SUSTHITI on your Android phone or iPhone and go to Lifestyle, then Connect. Your synced data then appears here automatically.';

  @override
  String get wearFailedTitle => 'We couldn\'t connect your health data.';

  @override
  String get wearFailedBody =>
      'Please check:\n• Health permissions\n• Device connection\n• Internet connection';

  @override
  String wearExplainSubtitle(String platform) {
    return 'SUSTHITI can use health information from $platform to show your lifestyle trends.';
  }

  @override
  String get wearDataMayIncludeHeader => 'Data may include';

  @override
  String get wearExerciseMinutesNote => ' (exercise minutes)';

  @override
  String get wearWhereSupportedNote => ' where supported';

  @override
  String get wearPrivacyNote =>
      'SUSTHITI only reads this data; it never writes to your health platform. You choose what to share on the next screen and can change it any time. Your doctor sees it only while you have approved their access. Not every watch records blood pressure or SpO₂; SUSTHITI only shows what your device provides.';

  @override
  String get wearContinueButton => 'Continue';

  @override
  String get wearConnectingTitle => 'Connecting...';

  @override
  String get wearConnectingBody =>
      'Reading your recent health data for the first sync.';

  @override
  String get wearSuccessHeadline => 'Health Data Connected';

  @override
  String get wearSuccessSubtitle =>
      'Your health data is now connected to SUSTHITI.';

  @override
  String get wearSourceLabel => 'Source';

  @override
  String get wearLastSyncLabel => 'Last synchronization';

  @override
  String get wearJustNowValue => 'Just now';

  @override
  String get wearMeasurementsAddedLabel => 'Measurements added';

  @override
  String get wearSharingLabel => 'Sharing';

  @override
  String get wearNoRecentDataNote =>
      'No recent data was found yet. New readings from your watch will sync automatically when you open SUSTHITI.';

  @override
  String get wearViewDashboardButton => 'View Lifestyle Dashboard';

  @override
  String get accessPatientPageTitle => 'Doctor Access';

  @override
  String get accessAdminPageTitle => 'Access Review';

  @override
  String get accessPatientIntro =>
      'Doctors can only see your records after you approve them. You can revoke access at any time.';

  @override
  String get accessAllFilterLabel => 'All';

  @override
  String get accessNoRequestsTitle => 'No access requests.';

  @override
  String accessNoStatusRequestsTitle(String status) {
    return 'No $status requests.';
  }

  @override
  String get accessPatientEmptyHint =>
      'When a doctor requests access using your name and Patient ID, it will appear here.';

  @override
  String get accessRejectConfirmTitle => 'Reject request?';

  @override
  String get accessRevokeConfirmTitle => 'Revoke access?';

  @override
  String accessRejectConfirmMessage(String doctor) {
    return 'Dr. $doctor will not be able to see your records.';
  }

  @override
  String accessRevokeConfirmMessageAdmin(String doctor, String patient) {
    return 'Dr. $doctor will immediately lose access to $patient\'s records. The patient and doctor are notified.';
  }

  @override
  String accessRevokeConfirmMessagePatient(String doctor) {
    return 'Dr. $doctor will immediately lose access to your records. Records they created stay in your history.';
  }

  @override
  String get accessRejectButton => 'Reject';

  @override
  String get accessRevokeButton => 'Revoke';

  @override
  String get accessApprovedToast => 'Access approved';

  @override
  String get accessRejectedToast => 'Request rejected';

  @override
  String get accessRevokedToast => 'Access revoked';

  @override
  String accessDoctorNameLabel(String name) {
    return 'Doctor: $name';
  }

  @override
  String accessPatientNameLabel(String name) {
    return 'Patient: $name';
  }

  @override
  String accessPatientIdLabel(String id) {
    return 'Patient ID: $id';
  }

  @override
  String accessDoctorIdLabel(String id) {
    return 'Doctor ID: $id';
  }

  @override
  String accessSpecializationLabel(String specialization) {
    return 'Specialization: $specialization';
  }

  @override
  String accessPatientNameCode(String name, String code) {
    return 'Patient: $name · $code';
  }

  @override
  String accessRequestedOnLabel(String date) {
    return 'Requested $date';
  }

  @override
  String get accessApproveButton => 'Approve';

  @override
  String get accessRevokeAccessButton => 'Revoke access';

  @override
  String get aiPatientSummaryTitle => 'AI Patient Summary';

  @override
  String get aiPatientSummaryLoadingMessage =>
      'Reviewing assessments, reports, glucose, lifestyle and care history...';

  @override
  String get aiPatientSummaryEmptyMessage =>
      'No patient summary yet. Generate one to see an overview of the recorded history.';

  @override
  String get aiGeneratePatientSummaryButton => 'Generate Patient Summary';

  @override
  String get aiOriginalRecordsUnchangedNote =>
      'All original records are unchanged and still available.';

  @override
  String get aiYourHealthSummaryTitle => 'Your Health Summary';

  @override
  String get aiHealthSummaryLoadingMessage =>
      'Looking at your recorded health information...';

  @override
  String get aiHealthSummaryEmptyMessage =>
      'Get a short summary of your recorded health information, in plain language.';

  @override
  String get aiGenerateSummaryButton => 'Generate Summary';

  @override
  String get aiYourRecordsUnchangedNote =>
      'Your original records are unchanged and still available.';

  @override
  String get aiLifestyleInsightTitle => 'Lifestyle Insight';

  @override
  String get aiLifestyleLoadingMessage =>
      'Looking at your recent activity, sleep, food and glucose...';

  @override
  String get aiLifestyleEmptyMessage =>
      'Get gentle, practical suggestions based on what you have recorded.';

  @override
  String get aiGenerateInsightButton => 'Generate Insight';

  @override
  String get aiLifestyleUnchangedNote =>
      'Your recorded lifestyle data is unchanged.';

  @override
  String get aiDefaultFailureReassurance =>
      'Your original medical information is still available.';

  @override
  String get aiAdminCannotGenerateNote =>
      'No AI summary has been generated for this record. Administrators can view AI summaries but cannot generate them.';

  @override
  String get aiNotConfiguredMessage =>
      'AI features are not set up on this server yet.';

  @override
  String get aiGenerateFailedMessage =>
      'We couldn\'t generate the summary right now.';

  @override
  String get aiStaleSummaryNote =>
      'New information has been added since this summary was generated. It may no longer reflect the current records.';

  @override
  String aiGeneratedOnLabel(String date) {
    return 'Generated $date';
  }

  @override
  String aiGeneratedByRole(String role) {
    return 'by $role';
  }

  @override
  String aiBasedOnLabel(String items) {
    return 'Based on: $items';
  }

  @override
  String aiModelLabel(String model) {
    return 'AI model: $model';
  }

  @override
  String get aiRegenerateButton => 'Regenerate';

  @override
  String get aiHideDetailsButton => 'Hide details';

  @override
  String get aiKeyFindingsLabel => 'Key findings';

  @override
  String get aiRelevantValuesLabel => 'Relevant values';

  @override
  String get aiReportInformationLabel => 'Report information';

  @override
  String get aiObservedWithinReportLabel => 'Observed within this report';

  @override
  String get aiQuestionsToDiscussLabel => 'Questions to discuss';

  @override
  String get aiLimitationsLabel => 'Limitations';

  @override
  String get aiNotEnoughInfoLabel => 'Not enough information to compare';

  @override
  String get aiAttentionLabel => 'Attention';

  @override
  String get aiRecentChangesLabel => 'Recent changes';

  @override
  String get aiDiabetesHistoryLabel => 'Diabetes History';

  @override
  String get aiRecentAssessmentsLabel => 'Recent Assessments';

  @override
  String get aiMedicalReportsLabel => 'Medical Reports';

  @override
  String get aiGlucoseHistoryLabel => 'Glucose History';

  @override
  String get aiLifestyleTrendsLabel => 'Lifestyle Trends';

  @override
  String get aiMedicationHistoryLabel => 'Medication / Prescription History';

  @override
  String get aiSideEffectsLabel => 'Side Effects';

  @override
  String get aiDoctorVisitsLabel => 'Doctor Visits';

  @override
  String get aiRecentDevelopmentsLabel => 'Recent Developments';

  @override
  String get aiHeartHistoryLabel => 'Heart History';

  @override
  String get aiWhatStandsOutLabel => 'What stands out';

  @override
  String get aiWhatHasChangedLabel => 'What has changed';

  @override
  String get aiKeepInMindLabel => 'What to keep in mind';

  @override
  String get aiDiscussWithDoctorLabel => 'What to discuss with your doctor';

  @override
  String get aiObservationsLabel => 'Observations';

  @override
  String get aiSuggestionsWithAiPrefixLabel => 'AI Suggestions';

  @override
  String get aiSuggestionsLabel => 'Suggestions';

  @override
  String get aiPatternsConsideredLabel => 'Patterns considered';

  @override
  String get aiInterpretationHeading => 'AI interpretation';

  @override
  String aiReferenceRangeLabel(String range) {
    return 'Reference $range';
  }

  @override
  String get aiEarlierLabel => 'Earlier';

  @override
  String get aiLatestLabel => 'Latest';

  @override
  String get aiObservedChangeLabel => 'Observed change';

  @override
  String get aiTrendRecentChangeLabel => 'Recent change';

  @override
  String get aiTrendStableLabel => 'Stable';

  @override
  String get aiTrendImprovingLabel => 'Improving';

  @override
  String get aiTrendWorseningLabel => 'Worsening';

  @override
  String get aiTrendUnknownLabel => 'Unknown';

  @override
  String get aiLifestyleOverviewLabel => 'Lifestyle Overview';

  @override
  String get appDisclaimerText =>
      'SUSTHITI provides AI-assisted informational insights and does not replace professional medical diagnosis, treatment, or emergency care.';

  @override
  String chartSemanticLabel(int count, String start, String end) {
    return 'Chart with $count recorded values from $start to $end';
  }

  @override
  String get metricDemoDataSuffix => ', demo data';

  @override
  String get aiGeneratedBadgeLabel => 'AI-generated';

  @override
  String get demoBadgeTooltip => 'Demonstration data, not real health data';

  @override
  String statusPrefixSemantic(String label) {
    return 'Status: $label';
  }

  @override
  String copyPatientIdTooltip(String label) {
    return 'Copy $label';
  }

  @override
  String patientIdCopiedToast(String label) {
    return '$label copied';
  }

  @override
  String get fieldOptionalSuffix => 'Optional';

  @override
  String get choiceRequiredMessage => 'Please choose one option.';

  @override
  String get dateFieldSelectPlaceholder => 'Select';

  @override
  String get passwordShowTooltip => 'Show password';

  @override
  String get passwordHideTooltip => 'Hide password';

  @override
  String unableToLoadSection(String title) {
    return 'Unable to load $title.';
  }

  @override
  String get commonRetry => 'Retry';

  @override
  String timelineTodayAt(String time) {
    return 'Today, $time';
  }

  @override
  String timelineYesterdayAt(String time) {
    return 'Yesterday, $time';
  }

  @override
  String get timelineOpenLabel => 'Open';

  @override
  String get pageNotFoundTitle => 'Page not found.';

  @override
  String get goHomeButton => 'Go home';

  @override
  String get authTaglineHeadline =>
      'Understand your health. Track your journey. Stay connected with your doctor.';

  @override
  String get authTaglineSubtitle =>
      'Diabetes-focused longitudinal health monitoring for patients and doctors.';

  @override
  String get probabilityShortLabel => 'probability';

  @override
  String get rolePatient => 'Patient';

  @override
  String get roleDoctor => 'Doctor';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get glucoseTypeFasting => 'Fasting';

  @override
  String get glucoseTypePostMeal => 'Post-meal';

  @override
  String get glucoseTypeRandom => 'Random';

  @override
  String get mealTypeBreakfast => 'Breakfast';

  @override
  String get mealTypeLunch => 'Lunch';

  @override
  String get mealTypeDinner => 'Dinner';

  @override
  String get mealTypeSnack => 'Snack';

  @override
  String get mealTypeOther => 'Other';

  @override
  String get lifestyleMetricSteps => 'Steps';

  @override
  String get lifestyleMetricHeartRate => 'Heart Rate';

  @override
  String get lifestyleMetricSleep => 'Sleep';

  @override
  String get lifestyleMetricActivity => 'Activity';

  @override
  String get lifestyleMetricBloodPressure => 'Blood Pressure';

  @override
  String get lifestyleMetricSpo2 => 'SpO₂';

  @override
  String get lifestyleMetricCalories => 'Calories';

  @override
  String get dataSourceHealthPlatform => 'Health Platform';

  @override
  String get dataSourceDevice => 'Device';

  @override
  String get dataSourceManual => 'Manual';

  @override
  String get dataSourceImported => 'Imported';

  @override
  String get rangeDaily => 'Daily';

  @override
  String get rangeWeekly => 'Weekly';

  @override
  String get rangeMonthly => 'Monthly';

  @override
  String get rangeCustom => 'Custom';

  @override
  String get range7Days => '7 days';

  @override
  String get range30Days => '30 days';

  @override
  String get range1Month => '1 Month';

  @override
  String get range3Months => '3 Months';

  @override
  String get range6Months => '6 Months';

  @override
  String get range1Year => '1 Year';

  @override
  String trendNoDataRecorded(String metric) {
    return 'No $metric recorded in this period.';
  }

  @override
  String get trendSingleRecordedResult => 'Single recorded result';

  @override
  String trendSingleValueOnDate(String value, String date) {
    return '$value on $date';
  }

  @override
  String get trendMoreResultsNeeded =>
      'More results are needed to show a trend.';

  @override
  String trendAverageAcross(String avg, int count, String unit) {
    return 'Average $avg across $count recorded $unit';
  }

  @override
  String trendUnitReadings(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'readings',
      one: 'reading',
    );
    return '$_temp0';
  }

  @override
  String trendUnitDays(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'days',
      one: 'day',
    );
    return '$_temp0';
  }

  @override
  String get severityMild => 'Mild';

  @override
  String get severityModerate => 'Moderate';

  @override
  String get severitySevere => 'Severe';

  @override
  String get severityEmergency => 'Emergency';

  @override
  String get sideEffectStatusNew => 'New';

  @override
  String get sideEffectStatusUnderReview => 'Under Review';

  @override
  String get sideEffectStatusResponded => 'Responded';

  @override
  String get sideEffectStatusAppointmentRecommended =>
      'Appointment Recommended';

  @override
  String get sideEffectStatusResolved => 'Resolved';

  @override
  String get doctorResponseNoImmediateAction => 'No immediate action';

  @override
  String get doctorResponseMonitor => 'Monitor';

  @override
  String get doctorResponseContactDoctor => 'Contact doctor';

  @override
  String get doctorResponseAppointmentRecommended => 'Appointment recommended';

  @override
  String get doctorResponseUrgentMedicalAttention => 'Urgent medical attention';

  @override
  String get followUpStatusScheduled => 'Scheduled';

  @override
  String get followUpStatusCompleted => 'Completed';

  @override
  String get followUpStatusCancelled => 'Cancelled';

  @override
  String get surgeryStatusScheduled => 'Scheduled';

  @override
  String get surgeryStatusCompleted => 'Completed';

  @override
  String get surgeryStatusCancelled => 'Cancelled';

  @override
  String get accessStatusPending => 'Pending';

  @override
  String get accessStatusApproved => 'Approved';

  @override
  String get accessStatusRejected => 'Rejected';

  @override
  String get accessStatusRevoked => 'Revoked';

  @override
  String get reportCategoryFullBody => 'Full Body Checkup';

  @override
  String get reportCategoryBloodReport => 'Blood Report';

  @override
  String get reportCategoryHba1c => 'HbA1c';

  @override
  String get reportCategoryBloodGlucose => 'Blood Glucose';

  @override
  String get reportCategoryLipidProfile => 'Lipid Profile';

  @override
  String get reportCategoryKidneyFunction => 'Kidney Function';

  @override
  String get reportCategoryLiverFunction => 'Liver Function';

  @override
  String get reportCategoryUrineTest => 'Urine Test';

  @override
  String get reportCategoryXRay => 'X-Ray';

  @override
  String get reportCategoryMri => 'MRI';

  @override
  String get reportCategoryCt => 'CT';

  @override
  String get reportCategoryEcg => 'ECG';

  @override
  String get reportCategoryOther => 'Other';

  @override
  String get reportFilterGroupAll => 'All';

  @override
  String get reportFilterGroupBlood => 'Blood';

  @override
  String get reportFilterGroupHba1c => 'HbA1c';

  @override
  String get reportFilterGroupImaging => 'Imaging';

  @override
  String get reportFilterGroupOther => 'Other';

  @override
  String get aiSummaryKindReport => 'Report Summary';

  @override
  String get aiSummaryKindAllReports => 'All Reports Summary';

  @override
  String get aiSummaryKindPatient => 'AI Patient Summary';

  @override
  String get aiSummaryKindPatientFriendly => 'Your Health Summary';

  @override
  String get aiSummaryKindLifestyle => 'Lifestyle Insight';

  @override
  String get aiSummaryKindInterpretation => 'Assessment Interpretation';

  @override
  String get aiSummaryKindHeartInterpretation =>
      'Heart Risk Screening Interpretation';

  @override
  String get followUpStatusUpcoming => 'Upcoming';

  @override
  String get followUpStatusUnscheduled => 'Needs scheduling';

  @override
  String get followUpStatusPast => 'Past';

  @override
  String get aiSummaryFallbackNotice =>
      'Translation unavailable. Showing English version.';

  @override
  String get aiSummaryRequestTranslation => 'Request translation';

  @override
  String get pdfLanguageLimitationNotice =>
      'PDF exports are currently available in English only. Full multilingual PDF support coming soon.';
}
