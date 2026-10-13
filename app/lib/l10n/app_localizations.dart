import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_gu.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('gu'),
    Locale('hi'),
  ];

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try Again'**
  String get commonTryAgain;

  /// No description provided for @commonLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get commonLoading;

  /// No description provided for @commonViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get commonViewAll;

  /// No description provided for @commonNoData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get commonNoData;

  /// No description provided for @errorUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load this right now.'**
  String get errorUnableToLoad;

  /// No description provided for @errorAccessNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Access not available.'**
  String get errorAccessNotAvailable;

  /// No description provided for @errorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found.'**
  String get errorNotFound;

  /// No description provided for @errorSomethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong.'**
  String get errorSomethingWrong;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authSignInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue to your health overview.'**
  String get authSignInSubtitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authNewToSusthiti.
  ///
  /// In en, this message translates to:
  /// **'New to SUSTHITI?'**
  String get authNewToSusthiti;

  /// No description provided for @authCreatePatientAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a patient account'**
  String get authCreatePatientAccount;

  /// No description provided for @authDoctorAccountsNote.
  ///
  /// In en, this message translates to:
  /// **'Doctor accounts are created by your SUSTHITI administrator.'**
  String get authDoctorAccountsNote;

  /// No description provided for @authCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authCreateAccountTitle;

  /// No description provided for @authCreateAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start building your health history. You can add more details later.'**
  String get authCreateAccountSubtitle;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// No description provided for @authDateOfBirth.
  ///
  /// In en, this message translates to:
  /// **'Date of birth'**
  String get authDateOfBirth;

  /// No description provided for @authGender.
  ///
  /// In en, this message translates to:
  /// **'Gender'**
  String get authGender;

  /// No description provided for @genderMale.
  ///
  /// In en, this message translates to:
  /// **'Male'**
  String get genderMale;

  /// No description provided for @genderFemale.
  ///
  /// In en, this message translates to:
  /// **'Female'**
  String get genderFemale;

  /// No description provided for @authPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get authPhone;

  /// No description provided for @authGenderRequired.
  ///
  /// In en, this message translates to:
  /// **'Please choose a gender.'**
  String get authGenderRequired;

  /// No description provided for @authConsentText.
  ///
  /// In en, this message translates to:
  /// **'I understand SUSTHITI provides informational insights and does not replace professional medical diagnosis, treatment, or emergency care.'**
  String get authConsentText;

  /// No description provided for @authConsentError.
  ///
  /// In en, this message translates to:
  /// **'Please confirm you understand SUSTHITI does not replace medical care.'**
  String get authConsentError;

  /// No description provided for @authCreateAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountButton;

  /// No description provided for @authPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters with a letter and a number.'**
  String get authPasswordHelper;

  /// No description provided for @authLanguageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get authLanguageLabel;

  /// No description provided for @authLanguageHelper.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get authLanguageHelper;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authResetPasswordTitle;

  /// No description provided for @authResetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the email you use for SUSTHITI and we will send reset instructions.'**
  String get authResetPasswordSubtitle;

  /// No description provided for @authResetSentMessage.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for this email, password reset instructions have been sent.'**
  String get authResetSentMessage;

  /// No description provided for @authDevModeTitle.
  ///
  /// In en, this message translates to:
  /// **'DEVELOPMENT MODE'**
  String get authDevModeTitle;

  /// No description provided for @authDevModeBody.
  ///
  /// In en, this message translates to:
  /// **'No email provider is configured on this server, so the 8-digit reset code is shown below. This never happens in production.'**
  String get authDevModeBody;

  /// No description provided for @authCopyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy code'**
  String get authCopyCode;

  /// No description provided for @authCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Reset code copied to clipboard'**
  String get authCodeCopied;

  /// No description provided for @authEnterResetCode.
  ///
  /// In en, this message translates to:
  /// **'Enter reset code'**
  String get authEnterResetCode;

  /// No description provided for @authSendResetInstructions.
  ///
  /// In en, this message translates to:
  /// **'Send reset instructions'**
  String get authSendResetInstructions;

  /// No description provided for @authChooseNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Choose a new password'**
  String get authChooseNewPassword;

  /// No description provided for @authChooseNewPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-digit reset code you received and a new password.'**
  String get authChooseNewPasswordSubtitle;

  /// No description provided for @auth8DigitCode.
  ///
  /// In en, this message translates to:
  /// **'8-digit reset code'**
  String get auth8DigitCode;

  /// No description provided for @authPasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get authPasteFromClipboard;

  /// No description provided for @authInvalid8DigitCode.
  ///
  /// In en, this message translates to:
  /// **'Enter the 8-digit code from your email.'**
  String get authInvalid8DigitCode;

  /// No description provided for @authNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get authNewPassword;

  /// No description provided for @authConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get authConfirmNewPassword;

  /// No description provided for @authPasswordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordsDontMatch;

  /// No description provided for @authUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get authUpdatePassword;

  /// No description provided for @authPastedCode.
  ///
  /// In en, this message translates to:
  /// **'Pasted 8-digit code from clipboard'**
  String get authPastedCode;

  /// No description provided for @authPastedCodeGeneric.
  ///
  /// In en, this message translates to:
  /// **'Pasted code from clipboard'**
  String get authPastedCodeGeneric;

  /// No description provided for @authClipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get authClipboardEmpty;

  /// No description provided for @authPasswordUpdatedSignIn.
  ///
  /// In en, this message translates to:
  /// **'Your password has been updated. Please sign in.'**
  String get authPasswordUpdatedSignIn;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @settingsDoctorIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor ID {code}'**
  String settingsDoctorIdLabel(String code);

  /// No description provided for @settingsEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get settingsEditProfile;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsDoctorAccess.
  ///
  /// In en, this message translates to:
  /// **'Doctor access'**
  String get settingsDoctorAccess;

  /// No description provided for @settingsDoctorAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approve, reject or revoke doctors who can see your records'**
  String get settingsDoctorAccessSubtitle;

  /// No description provided for @settingsConnectedDevices.
  ///
  /// In en, this message translates to:
  /// **'Connected devices'**
  String get settingsConnectedDevices;

  /// No description provided for @settingsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Your records are only visible to you and to doctors you approve. Administrators manage accounts but cannot read your medical records.'**
  String get settingsPrivacyNote;

  /// No description provided for @settingsSecurity.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecurity;

  /// No description provided for @settingsChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get settingsChangePassword;

  /// No description provided for @settingsLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogOut;

  /// No description provided for @settingsLogOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out?'**
  String get settingsLogOutConfirmTitle;

  /// No description provided for @settingsLogOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to see your records.'**
  String get settingsLogOutConfirmMessage;

  /// No description provided for @settingsPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get settingsPasswordChanged;

  /// No description provided for @settingsCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get settingsCurrentPassword;

  /// No description provided for @settingsNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get settingsNewPassword;

  /// No description provided for @settingsConfirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get settingsConfirmNewPassword;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose the language SUSTHITI is shown in'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsLanguageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language updated'**
  String get settingsLanguageUpdated;

  /// No description provided for @settingsLanguageUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update your language. Please check your connection and try again.'**
  String get settingsLanguageUpdateFailed;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// No description provided for @languageGujarati.
  ///
  /// In en, this message translates to:
  /// **'ગુજરાતી'**
  String get languageGujarati;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navReports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get navReports;

  /// No description provided for @navLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle'**
  String get navLifestyle;

  /// No description provided for @navDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Diabetes'**
  String get navDiabetes;

  /// No description provided for @navHeart.
  ///
  /// In en, this message translates to:
  /// **'Heart'**
  String get navHeart;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @navGlucose.
  ///
  /// In en, this message translates to:
  /// **'Glucose'**
  String get navGlucose;

  /// No description provided for @navFoodLog.
  ///
  /// In en, this message translates to:
  /// **'Food log'**
  String get navFoodLog;

  /// No description provided for @navPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions'**
  String get navPrescriptions;

  /// No description provided for @navAppointments.
  ///
  /// In en, this message translates to:
  /// **'Appointments'**
  String get navAppointments;

  /// No description provided for @navFollowUps.
  ///
  /// In en, this message translates to:
  /// **'Follow-ups'**
  String get navFollowUps;

  /// No description provided for @navSurgeries.
  ///
  /// In en, this message translates to:
  /// **'Surgeries'**
  String get navSurgeries;

  /// No description provided for @navSideEffects.
  ///
  /// In en, this message translates to:
  /// **'Side effects'**
  String get navSideEffects;

  /// No description provided for @navHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get navHistory;

  /// No description provided for @navNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get navNotifications;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @navDashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get navDashboard;

  /// No description provided for @navPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get navPatients;

  /// No description provided for @navRequests.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get navRequests;

  /// No description provided for @navAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get navAccount;

  /// No description provided for @navAddPatient.
  ///
  /// In en, this message translates to:
  /// **'Add patient'**
  String get navAddPatient;

  /// No description provided for @navDoctors.
  ///
  /// In en, this message translates to:
  /// **'Doctors'**
  String get navDoctors;

  /// No description provided for @navAccess.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get navAccess;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @navAuditLogs.
  ///
  /// In en, this message translates to:
  /// **'Audit logs'**
  String get navAuditLogs;

  /// No description provided for @navNotificationDelivery.
  ///
  /// In en, this message translates to:
  /// **'Notification delivery'**
  String get navNotificationDelivery;

  /// No description provided for @navSystemSettings.
  ///
  /// In en, this message translates to:
  /// **'System settings'**
  String get navSystemSettings;

  /// No description provided for @navAddDoctor.
  ///
  /// In en, this message translates to:
  /// **'Add doctor'**
  String get navAddDoctor;

  /// No description provided for @dashTodaysOverview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Overview'**
  String get dashTodaysOverview;

  /// No description provided for @dashNoReadingsYet.
  ///
  /// In en, this message translates to:
  /// **'No readings yet'**
  String get dashNoReadingsYet;

  /// No description provided for @dashQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get dashQuickActions;

  /// No description provided for @dashUploadReport.
  ///
  /// In en, this message translates to:
  /// **'Upload Report'**
  String get dashUploadReport;

  /// No description provided for @dashRecordGlucose.
  ///
  /// In en, this message translates to:
  /// **'Record Glucose'**
  String get dashRecordGlucose;

  /// No description provided for @dashLogFood.
  ///
  /// In en, this message translates to:
  /// **'Log Food'**
  String get dashLogFood;

  /// No description provided for @dashDiabetesRisk.
  ///
  /// In en, this message translates to:
  /// **'Diabetes Risk'**
  String get dashDiabetesRisk;

  /// No description provided for @dashReportSideEffect.
  ///
  /// In en, this message translates to:
  /// **'Report Side Effect'**
  String get dashReportSideEffect;

  /// No description provided for @dashAiLifestyleInsight.
  ///
  /// In en, this message translates to:
  /// **'AI Lifestyle Insight'**
  String get dashAiLifestyleInsight;

  /// No description provided for @dashInsightPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Generate suggestions based on your activity, sleep, food and glucose.'**
  String get dashInsightPlaceholder;

  /// No description provided for @dashGenerated.
  ///
  /// In en, this message translates to:
  /// **'Generated {time}'**
  String dashGenerated(String time);

  /// No description provided for @dashRecentReports.
  ///
  /// In en, this message translates to:
  /// **'Recent Reports'**
  String get dashRecentReports;

  /// No description provided for @dashNoReportsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No reports available.'**
  String get dashNoReportsAvailable;

  /// No description provided for @dashMyRecords.
  ///
  /// In en, this message translates to:
  /// **'My Records'**
  String get dashMyRecords;

  /// No description provided for @dashDoctorVisits.
  ///
  /// In en, this message translates to:
  /// **'Doctor visits'**
  String get dashDoctorVisits;

  /// No description provided for @dashAppointmentRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Appointment recommendations'**
  String get dashAppointmentRecommendations;

  /// No description provided for @dashHealthTimeline.
  ///
  /// In en, this message translates to:
  /// **'Health timeline'**
  String get dashHealthTimeline;

  /// No description provided for @dashHealthSummary.
  ///
  /// In en, this message translates to:
  /// **'Your Health Summary'**
  String get dashHealthSummary;

  /// No description provided for @dashHappyBirthday.
  ///
  /// In en, this message translates to:
  /// **'Happy birthday'**
  String get dashHappyBirthday;

  /// No description provided for @dashHappyBirthdayMessage.
  ///
  /// In en, this message translates to:
  /// **'Happy birthday, {name}! Wishing you a happy and healthy year ahead.'**
  String dashHappyBirthdayMessage(String name);

  /// No description provided for @dashUpcomingAppointment.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Appointment'**
  String get dashUpcomingAppointment;

  /// No description provided for @dashContactClinic.
  ///
  /// In en, this message translates to:
  /// **'Contact the clinic to schedule a time'**
  String get dashContactClinic;

  /// No description provided for @dashUpcomingFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Follow-up'**
  String get dashUpcomingFollowUp;

  /// No description provided for @dashOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dashOverdue;

  /// No description provided for @dashScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get dashScheduled;

  /// No description provided for @dashUpcomingSurgery.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Surgery'**
  String get dashUpcomingSurgery;

  /// No description provided for @dashDateTbc.
  ///
  /// In en, this message translates to:
  /// **'Date to be confirmed'**
  String get dashDateTbc;

  /// No description provided for @dashYourHealth.
  ///
  /// In en, this message translates to:
  /// **'Your Health'**
  String get dashYourHealth;

  /// No description provided for @dashNoEstimateYet.
  ///
  /// In en, this message translates to:
  /// **'No estimate yet'**
  String get dashNoEstimateYet;

  /// No description provided for @dashEstimateFutureRisk.
  ///
  /// In en, this message translates to:
  /// **'Estimate your future diabetes risk. A few questions, already filled in with what SUSTHITI knows.'**
  String get dashEstimateFutureRisk;

  /// No description provided for @dashStartAssessment.
  ///
  /// In en, this message translates to:
  /// **'Start assessment'**
  String get dashStartAssessment;

  /// No description provided for @dashIncludesReportValues.
  ///
  /// In en, this message translates to:
  /// **'Includes medical report values'**
  String get dashIncludesReportValues;

  /// No description provided for @dashBasedOnSymptomsOnly.
  ///
  /// In en, this message translates to:
  /// **'Based on symptoms and risk factors only'**
  String get dashBasedOnSymptomsOnly;

  /// No description provided for @dashUpdatedRiskInfo.
  ///
  /// In en, this message translates to:
  /// **'Updated health information is available. Refresh your assessment to include it.'**
  String get dashUpdatedRiskInfo;

  /// No description provided for @dashReviewAndRefresh.
  ///
  /// In en, this message translates to:
  /// **'Review and refresh'**
  String get dashReviewAndRefresh;

  /// No description provided for @dashViewDetails.
  ///
  /// In en, this message translates to:
  /// **'View details'**
  String get dashViewDetails;

  /// No description provided for @dashNoScreeningYet.
  ///
  /// In en, this message translates to:
  /// **'No screening yet'**
  String get dashNoScreeningYet;

  /// No description provided for @dashScreenHeartRisk.
  ///
  /// In en, this message translates to:
  /// **'Screen your heart disease risk. A short form, already filled in with what SUSTHITI knows.'**
  String get dashScreenHeartRisk;

  /// No description provided for @dashStartScreening.
  ///
  /// In en, this message translates to:
  /// **'Start screening'**
  String get dashStartScreening;

  /// No description provided for @dashUpdatedScreeningInfo.
  ///
  /// In en, this message translates to:
  /// **'Updated health information is available. Refresh your screening to include it.'**
  String get dashUpdatedScreeningInfo;

  /// No description provided for @docPatientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get docPatientsLabel;

  /// No description provided for @docPatientsCaption.
  ///
  /// In en, this message translates to:
  /// **'with approved access'**
  String get docPatientsCaption;

  /// No description provided for @docPendingRequests.
  ///
  /// In en, this message translates to:
  /// **'Pending requests'**
  String get docPendingRequests;

  /// No description provided for @docPendingRequestsCaption.
  ///
  /// In en, this message translates to:
  /// **'awaiting patient approval'**
  String get docPendingRequestsCaption;

  /// No description provided for @docOpenSideEffects.
  ///
  /// In en, this message translates to:
  /// **'Open side effects'**
  String get docOpenSideEffects;

  /// No description provided for @docOpenSideEffectsCaption.
  ///
  /// In en, this message translates to:
  /// **'not yet resolved'**
  String get docOpenSideEffectsCaption;

  /// No description provided for @docFollowUpsCaption.
  ///
  /// In en, this message translates to:
  /// **'in the next 7 days'**
  String get docFollowUpsCaption;

  /// No description provided for @docAppointmentsCaption.
  ///
  /// In en, this message translates to:
  /// **'in the next 7 days'**
  String get docAppointmentsCaption;

  /// No description provided for @docNewReports.
  ///
  /// In en, this message translates to:
  /// **'New reports'**
  String get docNewReports;

  /// No description provided for @docNewReportsCaption.
  ///
  /// In en, this message translates to:
  /// **'in the last 7 days'**
  String get docNewReportsCaption;

  /// No description provided for @docNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get docNeedsAttention;

  /// No description provided for @docNeedsAttentionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Based on patient-reported severity, unresolved items and due follow-ups. Not a clinical triage.'**
  String get docNeedsAttentionSubtitle;

  /// No description provided for @docNothingNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Nothing needs attention right now.'**
  String get docNothingNeedsAttention;

  /// No description provided for @docQuickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get docQuickActions;

  /// No description provided for @docAddPatient.
  ///
  /// In en, this message translates to:
  /// **'Add Patient'**
  String get docAddPatient;

  /// No description provided for @docMyPatients.
  ///
  /// In en, this message translates to:
  /// **'My Patients'**
  String get docMyPatients;

  /// No description provided for @docAccessRequests.
  ///
  /// In en, this message translates to:
  /// **'Access Requests'**
  String get docAccessRequests;

  /// No description provided for @docRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get docRecentActivity;

  /// No description provided for @docNoRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity.'**
  String get docNoRecentActivity;

  /// No description provided for @docToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get docToday;

  /// No description provided for @docAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get docAll;

  /// No description provided for @docScheduleClear.
  ///
  /// In en, this message translates to:
  /// **'Your schedule is clear today.'**
  String get docScheduleClear;

  /// No description provided for @docAppointmentType.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get docAppointmentType;

  /// No description provided for @docFollowUpType.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get docFollowUpType;

  /// No description provided for @docSurgeryType.
  ///
  /// In en, this message translates to:
  /// **'Surgery'**
  String get docSurgeryType;

  /// No description provided for @docTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get docTodayAt;

  /// No description provided for @validatorRequiredField.
  ///
  /// In en, this message translates to:
  /// **'{label} is required.'**
  String validatorRequiredField(String label);

  /// No description provided for @validatorThisField.
  ///
  /// In en, this message translates to:
  /// **'This field'**
  String get validatorThisField;

  /// No description provided for @validatorEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get validatorEmailRequired;

  /// No description provided for @validatorEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get validatorEmailInvalid;

  /// No description provided for @validatorPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get validatorPasswordRequired;

  /// No description provided for @validatorPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Use at least 8 characters.'**
  String get validatorPasswordTooShort;

  /// No description provided for @validatorPasswordNeedsLetterNumber.
  ///
  /// In en, this message translates to:
  /// **'Include at least one letter and one number.'**
  String get validatorPasswordNeedsLetterNumber;

  /// No description provided for @validatorPhoneInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number.'**
  String get validatorPhoneInvalid;

  /// No description provided for @validatorPatientIdRequired.
  ///
  /// In en, this message translates to:
  /// **'Patient ID is required.'**
  String get validatorPatientIdRequired;

  /// No description provided for @validatorPatientIdInvalid.
  ///
  /// In en, this message translates to:
  /// **'Patient ID should look like SUS-P-8A42F1.'**
  String get validatorPatientIdInvalid;

  /// No description provided for @validatorAgeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter your age in whole years.'**
  String get validatorAgeInvalid;

  /// No description provided for @validatorAgeRange.
  ///
  /// In en, this message translates to:
  /// **'Age must be between 1 and 120.'**
  String get validatorAgeRange;

  /// No description provided for @validatorNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a number.'**
  String get validatorNumberRequired;

  /// No description provided for @validatorGlucoseRange.
  ///
  /// In en, this message translates to:
  /// **'Enter a value between {low} and {high} {unit}.'**
  String validatorGlucoseRange(String low, String high, String unit);

  /// No description provided for @validatorNumberRange.
  ///
  /// In en, this message translates to:
  /// **'{label} must be between {low} and {high}.'**
  String validatorNumberRange(String label, String low, String high);

  /// No description provided for @validatorValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get validatorValueLabel;

  /// No description provided for @validatorDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get validatorDateLabel;

  /// No description provided for @validatorDateNotFuture.
  ///
  /// In en, this message translates to:
  /// **'{label} can\'t be in the future.'**
  String validatorDateNotFuture(String label);

  /// No description provided for @fmtJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get fmtJustNow;

  /// No description provided for @fmtMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String fmtMinutesAgo(num count);

  /// No description provided for @fmtHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String fmtHoursAgo(num count);

  /// No description provided for @fmtDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day ago} other{{count} days ago}}'**
  String fmtDaysAgo(num count);

  /// No description provided for @fmtGoodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get fmtGoodMorning;

  /// No description provided for @fmtGoodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get fmtGoodAfternoon;

  /// No description provided for @fmtGoodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get fmtGoodEvening;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonDrName.
  ///
  /// In en, this message translates to:
  /// **'Dr. {name}'**
  String commonDrName(String name);

  /// No description provided for @dashLastRecorded.
  ///
  /// In en, this message translates to:
  /// **'Last recorded {date}'**
  String dashLastRecorded(String date);

  /// No description provided for @dashRiskUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated {time}'**
  String dashRiskUpdated(String time);

  /// No description provided for @dashAppointmentDoctorLine.
  ///
  /// In en, this message translates to:
  /// **'Dr. {doctor} · {subtitle}'**
  String dashAppointmentDoctorLine(String doctor, String subtitle);

  /// No description provided for @dashFollowUpDoctorLine.
  ///
  /// In en, this message translates to:
  /// **'Dr. {doctor} · Due {date}'**
  String dashFollowUpDoctorLine(String doctor, String date);

  /// No description provided for @dashSurgeryDoctorLine.
  ///
  /// In en, this message translates to:
  /// **'Dr. {doctor} · {when}'**
  String dashSurgeryDoctorLine(String doctor, String when);

  /// No description provided for @commonAnd.
  ///
  /// In en, this message translates to:
  /// **'and'**
  String get commonAnd;

  /// No description provided for @docTodaySummary.
  ///
  /// In en, this message translates to:
  /// **'Today you have {list}.'**
  String docTodaySummary(String list);

  /// No description provided for @docSummaryAppointments.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 appointment} other{{count} appointments}}'**
  String docSummaryAppointments(num count);

  /// No description provided for @docSummaryFollowUps.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 follow-up} other{{count} follow-ups}}'**
  String docSummaryFollowUps(num count);

  /// No description provided for @docSummarySurgeries.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 surgery} other{{count} surgeries}}'**
  String docSummarySurgeries(num count);

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonReschedule.
  ///
  /// In en, this message translates to:
  /// **'Reschedule'**
  String get commonReschedule;

  /// No description provided for @commonMarkCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark Completed'**
  String get commonMarkCompleted;

  /// No description provided for @commonSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get commonSaveChanges;

  /// No description provided for @commonSaveNewDate.
  ///
  /// In en, this message translates to:
  /// **'Save New Date'**
  String get commonSaveNewDate;

  /// No description provided for @commonPurposeLabel.
  ///
  /// In en, this message translates to:
  /// **'Purpose'**
  String get commonPurposeLabel;

  /// No description provided for @commonDoctorLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get commonDoctorLabel;

  /// No description provided for @commonReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get commonReasonLabel;

  /// No description provided for @commonInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get commonInstructionsLabel;

  /// No description provided for @visitsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Visits'**
  String get visitsPageTitle;

  /// No description provided for @visitsRecordVisit.
  ///
  /// In en, this message translates to:
  /// **'Record Visit'**
  String get visitsRecordVisit;

  /// No description provided for @visitsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No visits recorded yet.'**
  String get visitsEmptyTitle;

  /// No description provided for @visitsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Visits recorded by your doctor will appear here.'**
  String get visitsEmptyMessage;

  /// No description provided for @visitsDoctorDateCode.
  ///
  /// In en, this message translates to:
  /// **'Dr. {doctor} · {date} · {code}'**
  String visitsDoctorDateCode(String doctor, String date, String code);

  /// No description provided for @visitsFollowUpOn.
  ///
  /// In en, this message translates to:
  /// **'Follow-up {date}'**
  String visitsFollowUpOn(String date);

  /// No description provided for @visitDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Visit'**
  String get visitDetailTitle;

  /// No description provided for @visitIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit ID'**
  String get visitIdLabel;

  /// No description provided for @visitDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit date'**
  String get visitDateLabel;

  /// No description provided for @visitFollowUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Follow-up'**
  String get visitFollowUpLabel;

  /// No description provided for @visitClinicalNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Clinical notes'**
  String get visitClinicalNotesLabel;

  /// No description provided for @visitAssessmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Assessment'**
  String get visitAssessmentLabel;

  /// No description provided for @visitDoctorReasoningLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor\'s reasoning'**
  String get visitDoctorReasoningLabel;

  /// No description provided for @visitTreatmentDecisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Treatment decision'**
  String get visitTreatmentDecisionLabel;

  /// No description provided for @visitInstructionsForPatientLabel.
  ///
  /// In en, this message translates to:
  /// **'Instructions for the patient'**
  String get visitInstructionsForPatientLabel;

  /// No description provided for @visitRecordedToast.
  ///
  /// In en, this message translates to:
  /// **'Visit {code} recorded'**
  String visitRecordedToast(String code);

  /// No description provided for @visitReasonForVisitLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for visit'**
  String get visitReasonForVisitLabel;

  /// No description provided for @visitFollowUpDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Follow-up date'**
  String get visitFollowUpDateLabel;

  /// No description provided for @visitSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save visit'**
  String get visitSaveButton;

  /// No description provided for @followUpsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No follow-ups scheduled.'**
  String get followUpsEmptyTitle;

  /// No description provided for @followUpsScheduleButton.
  ///
  /// In en, this message translates to:
  /// **'Schedule Follow-up'**
  String get followUpsScheduleButton;

  /// No description provided for @followUpMarkCompletedTitle.
  ///
  /// In en, this message translates to:
  /// **'Mark as completed?'**
  String get followUpMarkCompletedTitle;

  /// No description provided for @followUpMarkCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'This follow-up will be marked as done.'**
  String get followUpMarkCompletedMessage;

  /// No description provided for @followUpCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this follow-up?'**
  String get followUpCancelTitle;

  /// No description provided for @followUpCancelMessage.
  ///
  /// In en, this message translates to:
  /// **'The patient will be notified that it was cancelled.'**
  String get followUpCancelMessage;

  /// No description provided for @followUpCancelConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Follow-up'**
  String get followUpCancelConfirmLabel;

  /// No description provided for @followUpMarkedCompletedToast.
  ///
  /// In en, this message translates to:
  /// **'Follow-up marked completed'**
  String get followUpMarkedCompletedToast;

  /// No description provided for @followUpCancelledToast.
  ///
  /// In en, this message translates to:
  /// **'Follow-up cancelled'**
  String get followUpCancelledToast;

  /// No description provided for @followUpsDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get followUpsDueDateLabel;

  /// No description provided for @followUpsRescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Reschedule Follow-up'**
  String get followUpsRescheduleTitle;

  /// No description provided for @followUpsNewDueDateLabel.
  ///
  /// In en, this message translates to:
  /// **'New due date'**
  String get followUpsNewDueDateLabel;

  /// No description provided for @surgeriesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No surgeries scheduled.'**
  String get surgeriesEmptyTitle;

  /// No description provided for @surgeriesScheduleButton.
  ///
  /// In en, this message translates to:
  /// **'Schedule Surgery'**
  String get surgeriesScheduleButton;

  /// No description provided for @surgeryMarkCompletedMessage.
  ///
  /// In en, this message translates to:
  /// **'This surgery will be marked as done.'**
  String get surgeryMarkCompletedMessage;

  /// No description provided for @surgeryCancelTitle.
  ///
  /// In en, this message translates to:
  /// **'Cancel this surgery?'**
  String get surgeryCancelTitle;

  /// No description provided for @surgeryCancelConfirmLabel.
  ///
  /// In en, this message translates to:
  /// **'Cancel Surgery'**
  String get surgeryCancelConfirmLabel;

  /// No description provided for @surgeryMarkedCompletedToast.
  ///
  /// In en, this message translates to:
  /// **'Surgery marked completed'**
  String get surgeryMarkedCompletedToast;

  /// No description provided for @surgeryCancelledToast.
  ///
  /// In en, this message translates to:
  /// **'Surgery cancelled'**
  String get surgeryCancelledToast;

  /// No description provided for @surgeryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Surgery name'**
  String get surgeryNameLabel;

  /// No description provided for @surgeryEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Surgery'**
  String get surgeryEditTitle;

  /// No description provided for @surgeryScheduledDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Scheduled date and time'**
  String get surgeryScheduledDateTimeLabel;

  /// No description provided for @surgeryHospitalLabel.
  ///
  /// In en, this message translates to:
  /// **'Hospital / location'**
  String get surgeryHospitalLabel;

  /// No description provided for @surgeryPatientInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient-visible instructions'**
  String get surgeryPatientInstructionsLabel;

  /// No description provided for @surgeryPatientInstructionsHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown to the patient (e.g. fasting instructions).'**
  String get surgeryPatientInstructionsHelper;

  /// No description provided for @surgeryInternalNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Internal notes'**
  String get surgeryInternalNotesLabel;

  /// No description provided for @surgeryInternalNotesHelper.
  ///
  /// In en, this message translates to:
  /// **'Never shown to the patient.'**
  String get surgeryInternalNotesHelper;

  /// No description provided for @surgeryInternalNotesSectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Internal notes (not shown to the patient)'**
  String get surgeryInternalNotesSectionLabel;

  /// No description provided for @surgeryRescheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Reschedule Surgery'**
  String get surgeryRescheduleTitle;

  /// No description provided for @surgeryNewDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'New date and time'**
  String get surgeryNewDateTimeLabel;

  /// No description provided for @commonNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotesLabel;

  /// No description provided for @sideEffectsTitle.
  ///
  /// In en, this message translates to:
  /// **'Side Effects'**
  String get sideEffectsTitle;

  /// No description provided for @sideEffectsReportButton.
  ///
  /// In en, this message translates to:
  /// **'Report Side Effect'**
  String get sideEffectsReportButton;

  /// No description provided for @sideEffectsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No side effects reported.'**
  String get sideEffectsEmptyTitle;

  /// No description provided for @sideEffectsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'If a medicine makes you feel unwell, report it here so your doctor can review it.'**
  String get sideEffectsEmptyMessage;

  /// No description provided for @sideEffectPriorityLabel.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get sideEffectPriorityLabel;

  /// No description provided for @sideEffectDescribeLabel.
  ///
  /// In en, this message translates to:
  /// **'What are you experiencing?'**
  String get sideEffectDescribeLabel;

  /// No description provided for @sideEffectDescribeValidation.
  ///
  /// In en, this message translates to:
  /// **'Please describe what you are experiencing.'**
  String get sideEffectDescribeValidation;

  /// No description provided for @sideEffectSeverityLabel.
  ///
  /// In en, this message translates to:
  /// **'How severe is it?'**
  String get sideEffectSeverityLabel;

  /// No description provided for @sideEffectUrgentWarning.
  ///
  /// In en, this message translates to:
  /// **'If you feel your symptoms need urgent care, contact your local emergency services or go to the nearest hospital now. SUSTHITI is not monitored in real time.'**
  String get sideEffectUrgentWarning;

  /// No description provided for @sideEffectRelatedMedicineLabel.
  ///
  /// In en, this message translates to:
  /// **'Related medicine'**
  String get sideEffectRelatedMedicineLabel;

  /// No description provided for @sideEffectRelatedMedicineHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Metformin'**
  String get sideEffectRelatedMedicineHint;

  /// No description provided for @sideEffectWhenStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'When did it start?'**
  String get sideEffectWhenStartedLabel;

  /// No description provided for @sideEffectSubmitButton.
  ///
  /// In en, this message translates to:
  /// **'Submit report'**
  String get sideEffectSubmitButton;

  /// No description provided for @sideEffectReportedToast.
  ///
  /// In en, this message translates to:
  /// **'Side effect reported. Your doctor has been notified.'**
  String get sideEffectReportedToast;

  /// No description provided for @sideEffectDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Side Effect'**
  String get sideEffectDetailTitle;

  /// No description provided for @sideEffectReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference'**
  String get sideEffectReferenceLabel;

  /// No description provided for @sideEffectStartedLabel.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get sideEffectStartedLabel;

  /// No description provided for @sideEffectNotSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get sideEffectNotSpecified;

  /// No description provided for @sideEffectReportedLabel.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get sideEffectReportedLabel;

  /// No description provided for @sideEffectPriorityExplanation.
  ///
  /// In en, this message translates to:
  /// **'Marked as priority because the patient selected {severity} severity. This is not a clinical judgement.'**
  String sideEffectPriorityExplanation(String severity);

  /// No description provided for @sideEffectDoctorActionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor actions'**
  String get sideEffectDoctorActionsLabel;

  /// No description provided for @sideEffectRespondButton.
  ///
  /// In en, this message translates to:
  /// **'Respond'**
  String get sideEffectRespondButton;

  /// No description provided for @sideEffectMarkUnderReviewButton.
  ///
  /// In en, this message translates to:
  /// **'Mark under review'**
  String get sideEffectMarkUnderReviewButton;

  /// No description provided for @sideEffectMarkResolvedButton.
  ///
  /// In en, this message translates to:
  /// **'Mark resolved'**
  String get sideEffectMarkResolvedButton;

  /// No description provided for @sideEffectResponseSentToast.
  ///
  /// In en, this message translates to:
  /// **'Response sent to the patient'**
  String get sideEffectResponseSentToast;

  /// No description provided for @sideEffectMarkedResolvedToast.
  ///
  /// In en, this message translates to:
  /// **'Marked as resolved'**
  String get sideEffectMarkedResolvedToast;

  /// No description provided for @sideEffectMarkedUnderReviewToast.
  ///
  /// In en, this message translates to:
  /// **'Marked as under review'**
  String get sideEffectMarkedUnderReviewToast;

  /// No description provided for @sideEffectRespondToTitle.
  ///
  /// In en, this message translates to:
  /// **'Respond to {code}'**
  String sideEffectRespondToTitle(String code);

  /// No description provided for @sideEffectResponseFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Response'**
  String get sideEffectResponseFieldLabel;

  /// No description provided for @sideEffectMessageToPatientLabel.
  ///
  /// In en, this message translates to:
  /// **'Message to patient'**
  String get sideEffectMessageToPatientLabel;

  /// No description provided for @sideEffectTellPatientValidation.
  ///
  /// In en, this message translates to:
  /// **'Tell the patient what to do next.'**
  String get sideEffectTellPatientValidation;

  /// No description provided for @sideEffectAppointmentReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Appointment reason'**
  String get sideEffectAppointmentReasonLabel;

  /// No description provided for @sideEffectSuggestedDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggested date'**
  String get sideEffectSuggestedDateLabel;

  /// No description provided for @sideEffectSendResponseButton.
  ///
  /// In en, this message translates to:
  /// **'Send response'**
  String get sideEffectSendResponseButton;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonEditedTag.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get commonEditedTag;

  /// No description provided for @foodLogTitle.
  ///
  /// In en, this message translates to:
  /// **'Food Log'**
  String get foodLogTitle;

  /// No description provided for @foodLogButton.
  ///
  /// In en, this message translates to:
  /// **'Log Food'**
  String get foodLogButton;

  /// No description provided for @foodMealLoggedToast.
  ///
  /// In en, this message translates to:
  /// **'Meal logged'**
  String get foodMealLoggedToast;

  /// No description provided for @foodEntryUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Entry updated. The earlier version is kept in history.'**
  String get foodEntryUpdatedToast;

  /// No description provided for @foodPeriodYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get foodPeriodYesterday;

  /// No description provided for @foodPeriodThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get foodPeriodThisWeek;

  /// No description provided for @foodPeriodCustomDate.
  ///
  /// In en, this message translates to:
  /// **'Custom date'**
  String get foodPeriodCustomDate;

  /// No description provided for @foodEmptyToday.
  ///
  /// In en, this message translates to:
  /// **'No meals recorded today.'**
  String get foodEmptyToday;

  /// No description provided for @foodEmptyPeriod.
  ///
  /// In en, this message translates to:
  /// **'No meals recorded for this period.'**
  String get foodEmptyPeriod;

  /// No description provided for @foodEntrySubtitle.
  ///
  /// In en, this message translates to:
  /// **'{quantity} · {meal} · {time}'**
  String foodEntrySubtitle(String quantity, String meal, String time);

  /// No description provided for @foodEditEntryTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Entry'**
  String get foodEditEntryTitle;

  /// No description provided for @foodNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Food name'**
  String get foodNameLabel;

  /// No description provided for @foodNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Rice'**
  String get foodNameHint;

  /// No description provided for @foodQuantityLabel.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get foodQuantityLabel;

  /// No description provided for @foodQuantityHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 2 bowls'**
  String get foodQuantityHint;

  /// No description provided for @foodMealLabel.
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get foodMealLabel;

  /// No description provided for @foodTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get foodTimeLabel;

  /// No description provided for @glucoseRecordReadingButton.
  ///
  /// In en, this message translates to:
  /// **'Record Reading'**
  String get glucoseRecordReadingButton;

  /// No description provided for @glucoseEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No glucose readings yet.'**
  String get glucoseEmptyTitle;

  /// No description provided for @glucoseEmptyMessageCanRecord.
  ///
  /// In en, this message translates to:
  /// **'Record readings to see your averages and trends here.'**
  String get glucoseEmptyMessageCanRecord;

  /// No description provided for @glucoseEmptyMessageViewOnly.
  ///
  /// In en, this message translates to:
  /// **'The patient has not recorded any glucose readings.'**
  String get glucoseEmptyMessageViewOnly;

  /// No description provided for @glucoseRecordFirstButton.
  ///
  /// In en, this message translates to:
  /// **'Record First Reading'**
  String get glucoseRecordFirstButton;

  /// No description provided for @glucoseTodaysReadingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Today\'s readings'**
  String get glucoseTodaysReadingsLabel;

  /// No description provided for @glucoseNoneRecordedToday.
  ///
  /// In en, this message translates to:
  /// **'None recorded today'**
  String get glucoseNoneRecordedToday;

  /// No description provided for @glucoseLatestReading.
  ///
  /// In en, this message translates to:
  /// **'Latest {value} mg/dL'**
  String glucoseLatestReading(String value);

  /// No description provided for @glucoseRecentAverageLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent average'**
  String get glucoseRecentAverageLabel;

  /// No description provided for @glucoseLast7DaysCaption.
  ///
  /// In en, this message translates to:
  /// **'Last 7 days · {count} readings'**
  String glucoseLast7DaysCaption(String count);

  /// No description provided for @glucoseTrendLabel.
  ///
  /// In en, this message translates to:
  /// **'Trend'**
  String get glucoseTrendLabel;

  /// No description provided for @glucoseTrendHigher.
  ///
  /// In en, this message translates to:
  /// **'Higher'**
  String get glucoseTrendHigher;

  /// No description provided for @glucoseTrendLower.
  ///
  /// In en, this message translates to:
  /// **'Lower'**
  String get glucoseTrendLower;

  /// No description provided for @glucoseTrendStable.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get glucoseTrendStable;

  /// No description provided for @glucoseTrendNotEnoughData.
  ///
  /// In en, this message translates to:
  /// **'Not enough data'**
  String get glucoseTrendNotEnoughData;

  /// No description provided for @glucoseTrendCaption.
  ///
  /// In en, this message translates to:
  /// **'This week vs previous weeks'**
  String get glucoseTrendCaption;

  /// No description provided for @glucoseReadingRecordedToast.
  ///
  /// In en, this message translates to:
  /// **'Reading recorded'**
  String get glucoseReadingRecordedToast;

  /// No description provided for @glucoseRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Record Glucose'**
  String get glucoseRecordTitle;

  /// No description provided for @glucoseValueLabel.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get glucoseValueLabel;

  /// No description provided for @glucoseReadingTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading type'**
  String get glucoseReadingTypeLabel;

  /// No description provided for @glucoseDateTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Date and time'**
  String get glucoseDateTimeLabel;

  /// No description provided for @glucoseContextLabel.
  ///
  /// In en, this message translates to:
  /// **'Context'**
  String get glucoseContextLabel;

  /// No description provided for @glucoseContextHelper.
  ///
  /// In en, this message translates to:
  /// **'For example \"after a walk\" or \"felt dizzy\".'**
  String get glucoseContextHelper;

  /// No description provided for @glucoseSaveReadingButton.
  ///
  /// In en, this message translates to:
  /// **'Save reading'**
  String get glucoseSaveReadingButton;

  /// No description provided for @riskTitle.
  ///
  /// In en, this message translates to:
  /// **'Future Diabetes Risk'**
  String get riskTitle;

  /// No description provided for @riskEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Model-estimated risk'**
  String get riskEstimateLabel;

  /// No description provided for @riskSafetyText.
  ///
  /// In en, this message translates to:
  /// **'This is a research and screening estimate from a machine-learning model trained on synthetic data. It is not clinically validated and is not a medical diagnosis. Talk to your doctor about your results.'**
  String get riskSafetyText;

  /// No description provided for @riskNoReportBasis.
  ///
  /// In en, this message translates to:
  /// **'Based on available symptoms and risk factors. No medical report values were used.'**
  String get riskNoReportBasis;

  /// No description provided for @riskReportBasisGeneric.
  ///
  /// In en, this message translates to:
  /// **'Includes values from your medical reports.'**
  String get riskReportBasisGeneric;

  /// No description provided for @riskReportBasisWithFields.
  ///
  /// In en, this message translates to:
  /// **'Includes {fields} from your medical reports.'**
  String riskReportBasisWithFields(String fields);

  /// No description provided for @riskCategoryLowLabel.
  ///
  /// In en, this message translates to:
  /// **'Low risk'**
  String get riskCategoryLowLabel;

  /// No description provided for @riskCategoryModerateLabel.
  ///
  /// In en, this message translates to:
  /// **'Moderate risk'**
  String get riskCategoryModerateLabel;

  /// No description provided for @riskCategoryHighLabel.
  ///
  /// In en, this message translates to:
  /// **'High risk'**
  String get riskCategoryHighLabel;

  /// No description provided for @riskPatternPrefix.
  ///
  /// In en, this message translates to:
  /// **'Risk pattern: {label}'**
  String riskPatternPrefix(String label);

  /// No description provided for @riskLastUpdated.
  ///
  /// In en, this message translates to:
  /// **'Last updated {relative} · {absolute}'**
  String riskLastUpdated(String relative, String absolute);

  /// No description provided for @riskUpdatedInfoAvailable.
  ///
  /// In en, this message translates to:
  /// **'Updated health information is available.'**
  String get riskUpdatedInfoAvailable;

  /// No description provided for @riskNewInfoOffline.
  ///
  /// In en, this message translates to:
  /// **'New health information is available. Connect to the internet to update your assessment.'**
  String get riskNewInfoOffline;

  /// No description provided for @riskRefreshToInclude.
  ///
  /// In en, this message translates to:
  /// **'The estimate above doesn\'t include it yet. Refresh your diabetes risk assessment to use your latest information.'**
  String get riskRefreshToInclude;

  /// No description provided for @riskUpdateWithLatestData.
  ///
  /// In en, this message translates to:
  /// **'Update with my latest data'**
  String get riskUpdateWithLatestData;

  /// No description provided for @riskOfflineSavedInfo.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing the information saved on this device.'**
  String get riskOfflineSavedInfo;

  /// No description provided for @riskOfflineLastAssessment.
  ///
  /// In en, this message translates to:
  /// **'You\'re offline. Showing your last assessment, updated {relative}. Newer health information isn\'t included until you\'re back online.'**
  String riskOfflineLastAssessment(String relative);

  /// No description provided for @riskNoDataAvailable.
  ///
  /// In en, this message translates to:
  /// **'No health information was available yet beyond what the model requires.'**
  String get riskNoDataAvailable;

  /// No description provided for @riskUpdateProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Update profile'**
  String get riskUpdateProfileAction;

  /// No description provided for @riskOpenHealthProfileAction.
  ///
  /// In en, this message translates to:
  /// **'Open health profile'**
  String get riskOpenHealthProfileAction;

  /// No description provided for @riskAddReportValuesAction.
  ///
  /// In en, this message translates to:
  /// **'Add values from a report'**
  String get riskAddReportValuesAction;

  /// No description provided for @riskConnectHealthDataAction.
  ///
  /// In en, this message translates to:
  /// **'Connect health data'**
  String get riskConnectHealthDataAction;

  /// No description provided for @riskAnswerOnHeartFormAction.
  ///
  /// In en, this message translates to:
  /// **'Answer on the heart assessment form'**
  String get riskAnswerOnHeartFormAction;

  /// No description provided for @heartTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart Disease Risk Screening'**
  String get heartTitle;

  /// No description provided for @heartEstimateLabel.
  ///
  /// In en, this message translates to:
  /// **'Model screening result'**
  String get heartEstimateLabel;

  /// No description provided for @heartSignalHigh.
  ///
  /// In en, this message translates to:
  /// **'Elevated risk signal'**
  String get heartSignalHigh;

  /// No description provided for @heartSignalModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate risk signal'**
  String get heartSignalModerate;

  /// No description provided for @heartSignalLow.
  ///
  /// In en, this message translates to:
  /// **'Low risk signal'**
  String get heartSignalLow;

  /// No description provided for @heartRefreshToInclude.
  ///
  /// In en, this message translates to:
  /// **'The screening above doesn\'t include it yet. Refresh your heart risk screening to use your latest information.'**
  String get heartRefreshToInclude;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @lifestyleAlreadyUpToDateToast.
  ///
  /// In en, this message translates to:
  /// **'Already up to date'**
  String get lifestyleAlreadyUpToDateToast;

  /// No description provided for @lifestyleSyncedJustNowToast.
  ///
  /// In en, this message translates to:
  /// **'Synced just now'**
  String get lifestyleSyncedJustNowToast;

  /// No description provided for @lifestyleSyncFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Sync didn\'t complete. Check your connection and try again.'**
  String get lifestyleSyncFailedToast;

  /// No description provided for @lifestyleTodaySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recorded values only. Comparisons appear once there is enough history.'**
  String get lifestyleTodaySubtitle;

  /// No description provided for @lifestyleFoodLabel.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get lifestyleFoodLabel;

  /// No description provided for @lifestyleMealsLoggedTodayCaption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{meal logged today} other{meals logged today}}'**
  String lifestyleMealsLoggedTodayCaption(num count);

  /// No description provided for @lifestyleTrendsHeader.
  ///
  /// In en, this message translates to:
  /// **'Trends'**
  String get lifestyleTrendsHeader;

  /// No description provided for @lifestyleInsightTitle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle Insight'**
  String get lifestyleInsightTitle;

  /// No description provided for @lifestyleInsightSubtitle.
  ///
  /// In en, this message translates to:
  /// **'AI suggestions based on your activity, sleep, food and glucose'**
  String get lifestyleInsightSubtitle;

  /// No description provided for @lifestyleNotAvailableFromDevice.
  ///
  /// In en, this message translates to:
  /// **'Not available from connected device'**
  String get lifestyleNotAvailableFromDevice;

  /// No description provided for @lifestyleNotRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'Not recorded yet'**
  String get lifestyleNotRecordedYet;

  /// No description provided for @lifestyleChangeVsAverage.
  ///
  /// In en, this message translates to:
  /// **'{value}% vs your recent average'**
  String lifestyleChangeVsAverage(String value);

  /// No description provided for @lifestyleMeasurementAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Measurement added'**
  String get lifestyleMeasurementAddedToast;

  /// No description provided for @lifestyleAddMeasurementTitle.
  ///
  /// In en, this message translates to:
  /// **'Add measurement'**
  String get lifestyleAddMeasurementTitle;

  /// No description provided for @lifestyleMeasurementFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Measurement'**
  String get lifestyleMeasurementFieldLabel;

  /// No description provided for @lifestyleStepsLabel.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get lifestyleStepsLabel;

  /// No description provided for @lifestyleHeartRateFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Heart rate (bpm)'**
  String get lifestyleHeartRateFieldLabel;

  /// No description provided for @lifestyleSleepFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Sleep (minutes)'**
  String get lifestyleSleepFieldLabel;

  /// No description provided for @lifestyleActiveMinutesLabel.
  ///
  /// In en, this message translates to:
  /// **'Active minutes'**
  String get lifestyleActiveMinutesLabel;

  /// No description provided for @lifestyleSystolicLabel.
  ///
  /// In en, this message translates to:
  /// **'Systolic (mmHg)'**
  String get lifestyleSystolicLabel;

  /// No description provided for @lifestyleSpo2FieldLabel.
  ///
  /// In en, this message translates to:
  /// **'SpO₂ (%)'**
  String get lifestyleSpo2FieldLabel;

  /// No description provided for @lifestyleDiastolicLabel.
  ///
  /// In en, this message translates to:
  /// **'Diastolic (mmHg)'**
  String get lifestyleDiastolicLabel;

  /// No description provided for @lifestyleDiastolicLowerThanSystolic.
  ///
  /// In en, this message translates to:
  /// **'Diastolic must be lower than systolic.'**
  String get lifestyleDiastolicLowerThanSystolic;

  /// No description provided for @lifestyleManualEntryNote.
  ///
  /// In en, this message translates to:
  /// **'Recorded as a manual entry.'**
  String get lifestyleManualEntryNote;

  /// No description provided for @lifestyleOfflineNotice.
  ///
  /// In en, this message translates to:
  /// **'Offline. Showing the last values received'**
  String get lifestyleOfflineNotice;

  /// No description provided for @notifTooltipUnread.
  ///
  /// In en, this message translates to:
  /// **'Notifications, {count} unread'**
  String notifTooltipUnread(num count);

  /// No description provided for @notifMarkAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notifMarkAllRead;

  /// No description provided for @notifLoadError.
  ///
  /// In en, this message translates to:
  /// **'Notifications could not be loaded.'**
  String get notifLoadError;

  /// No description provided for @notifCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'You\'re all caught up.'**
  String get notifCaughtUp;

  /// No description provided for @notifViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all notifications'**
  String get notifViewAll;

  /// No description provided for @notifNoNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No notifications'**
  String get notifNoNotificationsTitle;

  /// No description provided for @notifFilterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notifFilterAll;

  /// No description provided for @notifFilterUnread.
  ///
  /// In en, this message translates to:
  /// **'Unread'**
  String get notifFilterUnread;

  /// No description provided for @notifFilterRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get notifFilterRead;

  /// No description provided for @notifUnreadPrefix.
  ///
  /// In en, this message translates to:
  /// **'Unread. '**
  String get notifUnreadPrefix;

  /// No description provided for @notifFoodRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Food logging reminders'**
  String get notifFoodRemindersTitle;

  /// No description provided for @notifFoodRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'An evening nudge if no meals are logged'**
  String get notifFoodRemindersSubtitle;

  /// No description provided for @notifLifestyleRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle reminders'**
  String get notifLifestyleRemindersTitle;

  /// No description provided for @notifLifestyleRemindersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A daily nudge for any lifestyle metric or glucose reading with nothing recorded yet'**
  String get notifLifestyleRemindersSubtitle;

  /// No description provided for @notifFollowUpRemindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Follow-up reminders'**
  String get notifFollowUpRemindersTitle;

  /// No description provided for @notifPatientUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Patient updates'**
  String get notifPatientUpdatesTitle;

  /// No description provided for @notifPatientUpdatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'New reports and patient updates'**
  String get notifPatientUpdatesSubtitle;

  /// No description provided for @tabOverview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get tabOverview;

  /// No description provided for @tabAiSummary.
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get tabAiSummary;

  /// No description provided for @tabVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get tabVisits;

  /// No description provided for @patientFallbackName.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get patientFallbackName;

  /// No description provided for @doctorBodyMeasurementsHeader.
  ///
  /// In en, this message translates to:
  /// **'Body measurements'**
  String get doctorBodyMeasurementsHeader;

  /// No description provided for @commonActionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get commonActionsHeader;

  /// No description provided for @doctorNewPrescriptionButton.
  ///
  /// In en, this message translates to:
  /// **'New Prescription'**
  String get doctorNewPrescriptionButton;

  /// No description provided for @doctorRecommendAppointmentButton.
  ///
  /// In en, this message translates to:
  /// **'Recommend Appointment'**
  String get doctorRecommendAppointmentButton;

  /// No description provided for @commonContactHeader.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get commonContactHeader;

  /// No description provided for @commonNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided'**
  String get commonNotProvided;

  /// No description provided for @doctorEmergencyContactLabel.
  ///
  /// In en, this message translates to:
  /// **'Emergency contact'**
  String get doctorEmergencyContactLabel;

  /// No description provided for @doctorAllReportsSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'All Reports Summary'**
  String get doctorAllReportsSummaryLabel;

  /// No description provided for @doctorAppointmentRecommendationSentToast.
  ///
  /// In en, this message translates to:
  /// **'Appointment recommendation sent to the patient'**
  String get doctorAppointmentRecommendationSentToast;

  /// No description provided for @doctorSendRecommendationButton.
  ///
  /// In en, this message translates to:
  /// **'Send recommendation'**
  String get doctorSendRecommendationButton;

  /// No description provided for @doctorScanPatientQrTooltip.
  ///
  /// In en, this message translates to:
  /// **'Scan Patient QR'**
  String get doctorScanPatientQrTooltip;

  /// No description provided for @doctorFilterRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get doctorFilterRecentActivity;

  /// No description provided for @doctorFilterFollowUpDue.
  ///
  /// In en, this message translates to:
  /// **'Follow-up due'**
  String get doctorFilterFollowUpDue;

  /// No description provided for @doctorSelectPatientTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a patient'**
  String get doctorSelectPatientTitle;

  /// No description provided for @doctorSelectPatientMessage.
  ///
  /// In en, this message translates to:
  /// **'Their overview, records and lifestyle data appear here.'**
  String get doctorSelectPatientMessage;

  /// No description provided for @doctorSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name or Patient ID'**
  String get doctorSearchHint;

  /// No description provided for @doctorNoPatientsYet.
  ///
  /// In en, this message translates to:
  /// **'No patients yet.'**
  String get doctorNoPatientsYet;

  /// No description provided for @doctorNoPatientsMatch.
  ///
  /// In en, this message translates to:
  /// **'No patients match.'**
  String get doctorNoPatientsMatch;

  /// No description provided for @doctorNoPatientsMessage.
  ///
  /// In en, this message translates to:
  /// **'Request access with the patient\'s name and Patient ID. They approve it in their app.'**
  String get doctorNoPatientsMessage;

  /// No description provided for @doctorLastActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Last activity {relative}'**
  String doctorLastActivityLabel(String relative);

  /// No description provided for @doctorSideEffectsCountPill.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 side effect} other{{count} side effects}}'**
  String doctorSideEffectsCountPill(num count);

  /// No description provided for @doctorFollowUpShortDate.
  ///
  /// In en, this message translates to:
  /// **'Follow-up {date}'**
  String doctorFollowUpShortDate(String date);

  /// No description provided for @doctorRequestSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get doctorRequestSentTitle;

  /// No description provided for @doctorRequestSentMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} ({code}) will be asked to approve your request. You will be notified when they respond.'**
  String doctorRequestSentMessage(String name, String code);

  /// No description provided for @doctorViewRequestsButton.
  ///
  /// In en, this message translates to:
  /// **'View requests'**
  String get doctorViewRequestsButton;

  /// No description provided for @doctorAddAnotherButton.
  ///
  /// In en, this message translates to:
  /// **'Add another'**
  String get doctorAddAnotherButton;

  /// No description provided for @doctorAddPatientInstructions.
  ///
  /// In en, this message translates to:
  /// **'Enter the patient\'s full name and Patient ID exactly as shown in their SUSTHITI profile. The patient must approve before you can see any records.'**
  String get doctorAddPatientInstructions;

  /// No description provided for @doctorPatientFullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient full name'**
  String get doctorPatientFullNameLabel;

  /// No description provided for @doctorPatientNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient name'**
  String get doctorPatientNameLabel;

  /// No description provided for @doctorPatientIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient ID'**
  String get doctorPatientIdLabel;

  /// No description provided for @doctorMessageToPatientLabel.
  ///
  /// In en, this message translates to:
  /// **'Message to patient'**
  String get doctorMessageToPatientLabel;

  /// No description provided for @doctorRequestAccessButton.
  ///
  /// In en, this message translates to:
  /// **'Request Access'**
  String get doctorRequestAccessButton;

  /// No description provided for @doctorScanInsteadButton.
  ///
  /// In en, this message translates to:
  /// **'Or scan the patient\'s QR code instead'**
  String get doctorScanInsteadButton;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profileTitle;

  /// No description provided for @profileYourQrCode.
  ///
  /// In en, this message translates to:
  /// **'Your QR code'**
  String get profileYourQrCode;

  /// No description provided for @profileQrSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'QR code for Patient ID {code}'**
  String profileQrSemanticLabel(String code);

  /// No description provided for @profileQrHelp.
  ///
  /// In en, this message translates to:
  /// **'Show this to a doctor in person so they can request access. It contains no medical information.'**
  String get profileQrHelp;

  /// No description provided for @profileChangePhotoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Change photo'**
  String get profileChangePhotoTooltip;

  /// No description provided for @profileShareIdNote.
  ///
  /// In en, this message translates to:
  /// **'Share your Patient ID only with doctors you trust. They also need your name, and you approve every request.'**
  String get profileShareIdNote;

  /// No description provided for @profilePersonalDetailsHeader.
  ///
  /// In en, this message translates to:
  /// **'Personal details'**
  String get profilePersonalDetailsHeader;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @commonAgeLabel.
  ///
  /// In en, this message translates to:
  /// **'Age'**
  String get commonAgeLabel;

  /// No description provided for @profileNoEmergencyContact.
  ///
  /// In en, this message translates to:
  /// **'No emergency contact added.'**
  String get profileNoEmergencyContact;

  /// No description provided for @commonNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonNameLabel;

  /// No description provided for @commonRelationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get commonRelationshipLabel;

  /// No description provided for @profileHealthProfileLabel.
  ///
  /// In en, this message translates to:
  /// **'Health profile'**
  String get profileHealthProfileLabel;

  /// No description provided for @profileHealthProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Height, weight, medical history, habits and symptoms'**
  String get profileHealthProfileSubtitle;

  /// No description provided for @profileChoosePhotoDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get profileChoosePhotoDialogTitle;

  /// No description provided for @profilePhotoTooLargeError.
  ///
  /// In en, this message translates to:
  /// **'Photo must be 5 MB or smaller.'**
  String get profilePhotoTooLargeError;

  /// No description provided for @profilePhotoUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Photo updated'**
  String get profilePhotoUpdatedToast;

  /// No description provided for @profileUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Profile updated'**
  String get profileUpdatedToast;

  /// No description provided for @profileGenderModelInputHelper.
  ///
  /// In en, this message translates to:
  /// **'Used as a diabetes model input.'**
  String get profileGenderModelInputHelper;

  /// No description provided for @rxSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by medicine, doctor or ID'**
  String get rxSearchHint;

  /// No description provided for @rxClearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get rxClearSearchTooltip;

  /// No description provided for @rxEmptyNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions yet.'**
  String get rxEmptyNoneYet;

  /// No description provided for @rxEmptyNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions match \"{query}\".'**
  String rxEmptyNoMatch(String query);

  /// No description provided for @rxEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions from your doctor will appear here.'**
  String get rxEmptyMessage;

  /// No description provided for @rxDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get rxDetailTitle;

  /// No description provided for @rxIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Prescription ID'**
  String get rxIdLabel;

  /// No description provided for @rxDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get rxDateLabel;

  /// No description provided for @rxMedicinesHeader.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get rxMedicinesHeader;

  /// No description provided for @rxDosageLabel.
  ///
  /// In en, this message translates to:
  /// **'Dosage'**
  String get rxDosageLabel;

  /// No description provided for @rxFrequencyLabel.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get rxFrequencyLabel;

  /// No description provided for @rxDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get rxDurationLabel;

  /// No description provided for @rxNeverEditedNote.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions are never edited. A change is issued as a new prescription.'**
  String get rxNeverEditedNote;

  /// No description provided for @rxPrescriptionDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Prescription date'**
  String get rxPrescriptionDateLabel;

  /// No description provided for @rxMedicineNLabel.
  ///
  /// In en, this message translates to:
  /// **'Medicine {n}'**
  String rxMedicineNLabel(int n);

  /// No description provided for @rxRemoveMedicineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Remove medicine'**
  String get rxRemoveMedicineTooltip;

  /// No description provided for @rxMedicineLabel.
  ///
  /// In en, this message translates to:
  /// **'Medicine'**
  String get rxMedicineLabel;

  /// No description provided for @rxDosageHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 500 mg'**
  String get rxDosageHint;

  /// No description provided for @rxFrequencyHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Twice daily'**
  String get rxFrequencyHint;

  /// No description provided for @rxDurationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 30 days'**
  String get rxDurationHint;

  /// No description provided for @rxMedicineInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. After meals'**
  String get rxMedicineInstructionsHint;

  /// No description provided for @rxAddMedicineButton.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get rxAddMedicineButton;

  /// No description provided for @rxGeneralInstructionsLabel.
  ///
  /// In en, this message translates to:
  /// **'General instructions'**
  String get rxGeneralInstructionsLabel;

  /// No description provided for @rxCreateButton.
  ///
  /// In en, this message translates to:
  /// **'Create prescription'**
  String get rxCreateButton;

  /// No description provided for @rxCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Prescription {code} created'**
  String rxCreatedToast(String code);

  /// No description provided for @rxPatientNotifiedNote.
  ///
  /// In en, this message translates to:
  /// **'The patient is notified. Earlier prescriptions stay unchanged.'**
  String get rxPatientNotifiedNote;

  /// No description provided for @uploadChooseReportDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a report'**
  String get uploadChooseReportDialogTitle;

  /// No description provided for @uploadFileTypeError.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF or an image (JPEG, PNG, WebP, HEIC).'**
  String get uploadFileTypeError;

  /// No description provided for @uploadFileTooLargeError.
  ///
  /// In en, this message translates to:
  /// **'File must be {mb} MB or smaller.'**
  String uploadFileTooLargeError(String mb);

  /// No description provided for @uploadFileEmptyError.
  ///
  /// In en, this message translates to:
  /// **'The selected file is empty.'**
  String get uploadFileEmptyError;

  /// No description provided for @uploadPickerFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the file picker. Please try again.'**
  String get uploadPickerFailedToast;

  /// No description provided for @uploadChooseFileError.
  ///
  /// In en, this message translates to:
  /// **'Choose the report file to upload.'**
  String get uploadChooseFileError;

  /// No description provided for @uploadChooseCategoryError.
  ///
  /// In en, this message translates to:
  /// **'Choose at least one report type.'**
  String get uploadChooseCategoryError;

  /// No description provided for @uploadAdminAddedToast.
  ///
  /// In en, this message translates to:
  /// **'Report {code} added to the patient\'s record'**
  String uploadAdminAddedToast(String code);

  /// No description provided for @uploadReportUploadedToast.
  ///
  /// In en, this message translates to:
  /// **'Report uploaded'**
  String get uploadReportUploadedToast;

  /// No description provided for @uploadReportTypeLabel.
  ///
  /// In en, this message translates to:
  /// **'What type of report is this?'**
  String get uploadReportTypeLabel;

  /// No description provided for @uploadReportTypeHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose every type it covers. A full body checkup, for example, can also include HbA1c.'**
  String get uploadReportTypeHelp;

  /// No description provided for @uploadReportDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Report date'**
  String get uploadReportDateLabel;

  /// No description provided for @uploadReportDateHelper.
  ///
  /// In en, this message translates to:
  /// **'The date on the report itself (when the test was done), not today. Older reports are welcome.'**
  String get uploadReportDateHelper;

  /// No description provided for @uploadReportFileLabel.
  ///
  /// In en, this message translates to:
  /// **'Report file'**
  String get uploadReportFileLabel;

  /// No description provided for @uploadChooseFilePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Choose file'**
  String get uploadChooseFilePlaceholder;

  /// No description provided for @uploadFileTypesHint.
  ///
  /// In en, this message translates to:
  /// **'PDF, JPEG, PNG, WebP or HEIC, up to 20 MB'**
  String get uploadFileTypesHint;

  /// No description provided for @commonChange.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get commonChange;

  /// No description provided for @uploadFileStoredNote.
  ///
  /// In en, this message translates to:
  /// **'Your original file is stored securely and always stays available, even if AI features are unavailable.'**
  String get uploadFileStoredNote;

  /// No description provided for @commonDescriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescriptionLabel;

  /// No description provided for @uploadDescriptionHelper.
  ///
  /// In en, this message translates to:
  /// **'For example the lab name or why the test was done.'**
  String get uploadDescriptionHelper;

  /// No description provided for @uploadDescriptionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Keep the description under 1000 characters.'**
  String get uploadDescriptionTooLong;

  /// No description provided for @auditLogin.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get auditLogin;

  /// No description provided for @auditLogout.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get auditLogout;

  /// No description provided for @auditPatientRegistered.
  ///
  /// In en, this message translates to:
  /// **'Registered as a patient'**
  String get auditPatientRegistered;

  /// No description provided for @auditProfileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated their profile'**
  String get auditProfileUpdated;

  /// No description provided for @auditProfilePhotoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated their profile photo'**
  String get auditProfilePhotoUpdated;

  /// No description provided for @auditPatientUpdatedByAdmin.
  ///
  /// In en, this message translates to:
  /// **'Patient details updated by admin'**
  String get auditPatientUpdatedByAdmin;

  /// No description provided for @auditPatientRecordViewed.
  ///
  /// In en, this message translates to:
  /// **'Patient record viewed by admin'**
  String get auditPatientRecordViewed;

  /// No description provided for @auditPatientActivated.
  ///
  /// In en, this message translates to:
  /// **'Patient account reactivated'**
  String get auditPatientActivated;

  /// No description provided for @auditPatientDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Patient account deactivated'**
  String get auditPatientDeactivated;

  /// No description provided for @auditDoctorCreated.
  ///
  /// In en, this message translates to:
  /// **'Doctor account created'**
  String get auditDoctorCreated;

  /// No description provided for @auditDoctorUpdated.
  ///
  /// In en, this message translates to:
  /// **'Doctor details updated'**
  String get auditDoctorUpdated;

  /// No description provided for @auditDoctorActivated.
  ///
  /// In en, this message translates to:
  /// **'Doctor account reactivated'**
  String get auditDoctorActivated;

  /// No description provided for @auditDoctorDeactivated.
  ///
  /// In en, this message translates to:
  /// **'Doctor account deactivated'**
  String get auditDoctorDeactivated;

  /// No description provided for @auditAccessRequested.
  ///
  /// In en, this message translates to:
  /// **'Requested patient access'**
  String get auditAccessRequested;

  /// No description provided for @auditAccessApproved.
  ///
  /// In en, this message translates to:
  /// **'Patient access approved'**
  String get auditAccessApproved;

  /// No description provided for @auditAccessRejected.
  ///
  /// In en, this message translates to:
  /// **'Patient access rejected'**
  String get auditAccessRejected;

  /// No description provided for @auditAccessRevoked.
  ///
  /// In en, this message translates to:
  /// **'Patient access revoked'**
  String get auditAccessRevoked;

  /// No description provided for @auditReportUploaded.
  ///
  /// In en, this message translates to:
  /// **'Report uploaded'**
  String get auditReportUploaded;

  /// No description provided for @auditReportFileAccessed.
  ///
  /// In en, this message translates to:
  /// **'Original report opened'**
  String get auditReportFileAccessed;

  /// No description provided for @auditDiabetesAssessmentCreated.
  ///
  /// In en, this message translates to:
  /// **'Diabetes assessment completed'**
  String get auditDiabetesAssessmentCreated;

  /// No description provided for @auditPrescriptionCreated.
  ///
  /// In en, this message translates to:
  /// **'Prescription created'**
  String get auditPrescriptionCreated;

  /// No description provided for @auditVisitRecorded.
  ///
  /// In en, this message translates to:
  /// **'Doctor visit recorded'**
  String get auditVisitRecorded;

  /// No description provided for @auditAppointmentRecommended.
  ///
  /// In en, this message translates to:
  /// **'Appointment recommended'**
  String get auditAppointmentRecommended;

  /// No description provided for @auditSideEffectReported.
  ///
  /// In en, this message translates to:
  /// **'Side effect reported'**
  String get auditSideEffectReported;

  /// No description provided for @auditSideEffectResponded.
  ///
  /// In en, this message translates to:
  /// **'Responded to a side-effect report'**
  String get auditSideEffectResponded;

  /// No description provided for @auditSideEffectUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Side-effect report marked under review'**
  String get auditSideEffectUnderReview;

  /// No description provided for @auditSideEffectResolved.
  ///
  /// In en, this message translates to:
  /// **'Side-effect report resolved'**
  String get auditSideEffectResolved;

  /// No description provided for @auditAiSummaryPdfDownloaded.
  ///
  /// In en, this message translates to:
  /// **'AI summary PDF downloaded'**
  String get auditAiSummaryPdfDownloaded;

  /// No description provided for @auditAiIndividualReportGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI report summary generated'**
  String get auditAiIndividualReportGenerated;

  /// No description provided for @auditAiAllReportsGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI all-reports summary generated'**
  String get auditAiAllReportsGenerated;

  /// No description provided for @auditAiPatientSummaryGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI patient summary generated'**
  String get auditAiPatientSummaryGenerated;

  /// No description provided for @auditAiLifestyleGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI lifestyle insight generated'**
  String get auditAiLifestyleGenerated;

  /// No description provided for @auditAiAssessmentInterpretationGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI assessment interpretation generated'**
  String get auditAiAssessmentInterpretationGenerated;

  /// No description provided for @auditWearableConnected.
  ///
  /// In en, this message translates to:
  /// **'Wearable device connected'**
  String get auditWearableConnected;

  /// No description provided for @auditWearableDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Wearable device disconnected'**
  String get auditWearableDisconnected;

  /// No description provided for @auditPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get auditPasswordChanged;

  /// No description provided for @auditPasswordResetRequested.
  ///
  /// In en, this message translates to:
  /// **'Password reset requested'**
  String get auditPasswordResetRequested;

  /// No description provided for @auditPasswordResetCompleted.
  ///
  /// In en, this message translates to:
  /// **'Password reset completed'**
  String get auditPasswordResetCompleted;

  /// No description provided for @auditSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'System settings updated'**
  String get auditSettingsUpdated;

  /// No description provided for @auditSystemActor.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get auditSystemActor;

  /// No description provided for @auditAdminSuffix.
  ///
  /// In en, this message translates to:
  /// **'{name} (Admin)'**
  String auditAdminSuffix(String name);

  /// No description provided for @auditPatientPrefix.
  ///
  /// In en, this message translates to:
  /// **'Patient: {name}'**
  String auditPatientPrefix(String name);

  /// No description provided for @trendHigher.
  ///
  /// In en, this message translates to:
  /// **'Higher than previous weeks'**
  String get trendHigher;

  /// No description provided for @trendLower.
  ///
  /// In en, this message translates to:
  /// **'Lower than previous weeks'**
  String get trendLower;

  /// No description provided for @trendStable.
  ///
  /// In en, this message translates to:
  /// **'Similar to previous weeks'**
  String get trendStable;

  /// No description provided for @trendInsufficientData.
  ///
  /// In en, this message translates to:
  /// **'Not enough readings to compare'**
  String get trendInsufficientData;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// No description provided for @diabetesNotAssessed.
  ///
  /// In en, this message translates to:
  /// **'Not assessed'**
  String get diabetesNotAssessed;

  /// No description provided for @adminProgressNoOpenItems.
  ///
  /// In en, this message translates to:
  /// **'No open items'**
  String get adminProgressNoOpenItems;

  /// No description provided for @adminNoRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity'**
  String get adminNoRecentActivity;

  /// No description provided for @adminDashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminDashboardTitle;

  /// No description provided for @adminActiveCountCaption.
  ///
  /// In en, this message translates to:
  /// **'{count} active'**
  String adminActiveCountCaption(String count);

  /// No description provided for @adminRegisteredCaption.
  ///
  /// In en, this message translates to:
  /// **'registered'**
  String get adminRegisteredCaption;

  /// No description provided for @adminActivePatientsLabel.
  ///
  /// In en, this message translates to:
  /// **'Active patients'**
  String get adminActivePatientsLabel;

  /// No description provided for @adminLast30DaysCaption.
  ///
  /// In en, this message translates to:
  /// **'in the last 30 days'**
  String get adminLast30DaysCaption;

  /// No description provided for @adminDoctorAccessCaption.
  ///
  /// In en, this message translates to:
  /// **'doctor access'**
  String get adminDoctorAccessCaption;

  /// No description provided for @adminOperationalOverviewHeader.
  ///
  /// In en, this message translates to:
  /// **'Operational overview'**
  String get adminOperationalOverviewHeader;

  /// No description provided for @adminOperationalOverviewSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Aggregate counts only — never clinical content.'**
  String get adminOperationalOverviewSubtitle;

  /// No description provided for @commonScheduledCaption.
  ///
  /// In en, this message translates to:
  /// **'scheduled'**
  String get commonScheduledCaption;

  /// No description provided for @adminUploadedLast7Days.
  ///
  /// In en, this message translates to:
  /// **'uploaded in the last 7 days'**
  String get adminUploadedLast7Days;

  /// No description provided for @adminFailedPushesLabel.
  ///
  /// In en, this message translates to:
  /// **'Failed pushes'**
  String get adminFailedPushesLabel;

  /// No description provided for @adminAddDoctorButton.
  ///
  /// In en, this message translates to:
  /// **'Add Doctor'**
  String get adminAddDoctorButton;

  /// No description provided for @adminAuditLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get adminAuditLogsTitle;

  /// No description provided for @adminSystemSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get adminSystemSettingsTitle;

  /// No description provided for @adminNoActivityYetDot.
  ///
  /// In en, this message translates to:
  /// **'No activity yet.'**
  String get adminNoActivityYetDot;

  /// No description provided for @adminDeactivateDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate Dr. {name}?'**
  String adminDeactivateDoctorTitle(String name);

  /// No description provided for @adminDeactivateDoctorMessage.
  ///
  /// In en, this message translates to:
  /// **'They will be signed out and cannot sign in. Their past records remain in patient histories.'**
  String get adminDeactivateDoctorMessage;

  /// No description provided for @commonDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get commonDeactivate;

  /// No description provided for @commonReactivate.
  ///
  /// In en, this message translates to:
  /// **'Reactivate'**
  String get commonReactivate;

  /// No description provided for @adminDoctorDeactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'Doctor deactivated'**
  String get adminDoctorDeactivatedToast;

  /// No description provided for @adminDoctorReactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'Doctor reactivated'**
  String get adminDoctorReactivatedToast;

  /// No description provided for @adminActionsForDoctorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Actions for Dr. {name}'**
  String adminActionsForDoctorTooltip(String name);

  /// No description provided for @commonViewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get commonViewProfile;

  /// No description provided for @adminEditDoctorMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Edit doctor'**
  String get adminEditDoctorMenuItem;

  /// No description provided for @adminViewPatientsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'View patients'**
  String get adminViewPatientsMenuItem;

  /// No description provided for @commonViewActivity.
  ///
  /// In en, this message translates to:
  /// **'View activity'**
  String get commonViewActivity;

  /// No description provided for @adminNoActivityShort.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get adminNoActivityShort;

  /// No description provided for @adminLastActiveLabel.
  ///
  /// In en, this message translates to:
  /// **'Last active {relative}'**
  String adminLastActiveLabel(String relative);

  /// No description provided for @adminDoctorSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, email or Doctor ID'**
  String get adminDoctorSearchHint;

  /// No description provided for @adminNoDoctorsFound.
  ///
  /// In en, this message translates to:
  /// **'No doctors found.'**
  String get adminNoDoctorsFound;

  /// No description provided for @adminDoctorsCountHeader.
  ///
  /// In en, this message translates to:
  /// **'Doctors ({count})'**
  String adminDoctorsCountHeader(int count);

  /// No description provided for @adminColDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get adminColDoctor;

  /// No description provided for @adminColDoctorId.
  ///
  /// In en, this message translates to:
  /// **'Doctor ID'**
  String get adminColDoctorId;

  /// No description provided for @commonSpecializationLabel.
  ///
  /// In en, this message translates to:
  /// **'Specialization'**
  String get commonSpecializationLabel;

  /// No description provided for @adminColPatients.
  ///
  /// In en, this message translates to:
  /// **'Patients'**
  String get adminColPatients;

  /// No description provided for @adminColLastActivity.
  ///
  /// In en, this message translates to:
  /// **'Last activity'**
  String get adminColLastActivity;

  /// No description provided for @adminColStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get adminColStatus;

  /// No description provided for @commonViewProfileButton.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get commonViewProfileButton;

  /// No description provided for @adminDoctorRowCaption.
  ///
  /// In en, this message translates to:
  /// **'{count} active patients · {lastActive}'**
  String adminDoctorRowCaption(int count, String lastActive);

  /// No description provided for @adminEditDoctorTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Doctor'**
  String get adminEditDoctorTitle;

  /// No description provided for @commonCreatedOn.
  ///
  /// In en, this message translates to:
  /// **'Created {date}'**
  String commonCreatedOn(String date);

  /// No description provided for @adminDeactivateDoctorConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate doctor?'**
  String get adminDeactivateDoctorConfirmTitle;

  /// No description provided for @adminDoctorUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Doctor updated'**
  String get adminDoctorUpdatedToast;

  /// No description provided for @adminDoctorCreatedToast.
  ///
  /// In en, this message translates to:
  /// **'Doctor account created. Share the temporary password securely.'**
  String get adminDoctorCreatedToast;

  /// No description provided for @adminTemporaryPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Temporary password'**
  String get adminTemporaryPasswordLabel;

  /// No description provided for @adminTempPasswordHelper.
  ///
  /// In en, this message translates to:
  /// **'The doctor should change it after first sign-in.'**
  String get adminTempPasswordHelper;

  /// No description provided for @adminSpecializationHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Endocrinology'**
  String get adminSpecializationHint;

  /// No description provided for @adminLicenseNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'License / registration number'**
  String get adminLicenseNumberLabel;

  /// No description provided for @adminLicenseValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter the doctor\'s license or registration number.'**
  String get adminLicenseValidation;

  /// No description provided for @adminCreateDoctorAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Create doctor account'**
  String get adminCreateDoctorAccountButton;

  /// No description provided for @adminDeactivateDoctorButton.
  ///
  /// In en, this message translates to:
  /// **'Deactivate doctor'**
  String get adminDeactivateDoctorButton;

  /// No description provided for @adminReactivateDoctorButton.
  ///
  /// In en, this message translates to:
  /// **'Reactivate doctor'**
  String get adminReactivateDoctorButton;

  /// No description provided for @adminDeactivatePatientTitle.
  ///
  /// In en, this message translates to:
  /// **'Deactivate {name}?'**
  String adminDeactivatePatientTitle(String name);

  /// No description provided for @adminDeactivatePatientMessage.
  ///
  /// In en, this message translates to:
  /// **'They will be signed out and cannot sign in. Their records are kept.'**
  String get adminDeactivatePatientMessage;

  /// No description provided for @adminPatientDeactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'Patient deactivated'**
  String get adminPatientDeactivatedToast;

  /// No description provided for @adminPatientReactivatedToast.
  ///
  /// In en, this message translates to:
  /// **'Patient reactivated'**
  String get adminPatientReactivatedToast;

  /// No description provided for @adminActionsForPatientTooltip.
  ///
  /// In en, this message translates to:
  /// **'Actions for {name}'**
  String adminActionsForPatientTooltip(String name);

  /// No description provided for @adminEditPatientMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Edit patient'**
  String get adminEditPatientMenuItem;

  /// No description provided for @adminViewReportsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'View reports'**
  String get adminViewReportsMenuItem;

  /// No description provided for @adminViewDoctorsMenuItem.
  ///
  /// In en, this message translates to:
  /// **'View doctors'**
  String get adminViewDoctorsMenuItem;

  /// No description provided for @adminUploadReportForPatientMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Upload report for patient'**
  String get adminUploadReportForPatientMenuItem;

  /// No description provided for @adminDeactivateAccountMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Deactivate account'**
  String get adminDeactivateAccountMenuItem;

  /// No description provided for @adminReactivateAccountMenuItem.
  ///
  /// In en, this message translates to:
  /// **'Reactivate account'**
  String get adminReactivateAccountMenuItem;

  /// No description provided for @adminPatientSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name, email or Patient ID'**
  String get adminPatientSearchHint;

  /// No description provided for @adminNoPatientsFound.
  ///
  /// In en, this message translates to:
  /// **'No patients found.'**
  String get adminNoPatientsFound;

  /// No description provided for @adminPatientsCountShowing.
  ///
  /// In en, this message translates to:
  /// **'Patients ({total}) · showing the {shown} most recent. Search to find others.'**
  String adminPatientsCountShowing(int total, int shown);

  /// No description provided for @adminPatientsCountHeader.
  ///
  /// In en, this message translates to:
  /// **'Patients ({total})'**
  String adminPatientsCountHeader(int total);

  /// No description provided for @adminColPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get adminColPatient;

  /// No description provided for @adminColAgeGender.
  ///
  /// In en, this message translates to:
  /// **'Age / gender'**
  String get adminColAgeGender;

  /// No description provided for @adminColDiabetesStatus.
  ///
  /// In en, this message translates to:
  /// **'Diabetes status'**
  String get adminColDiabetesStatus;

  /// No description provided for @adminPatientRowCaption.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 doctor} other{{count} doctors}} · {lastActive}'**
  String adminPatientRowCaption(num count, String lastActive);

  /// No description provided for @adminAuditSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by action, person or reference'**
  String get adminAuditSearchHint;

  /// No description provided for @adminNoAuditEntries.
  ///
  /// In en, this message translates to:
  /// **'No audit entries.'**
  String get adminNoAuditEntries;

  /// No description provided for @adminSystemRoleFallback.
  ///
  /// In en, this message translates to:
  /// **'system'**
  String get adminSystemRoleFallback;

  /// No description provided for @adminPushSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get adminPushSent;

  /// No description provided for @adminPushFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get adminPushFailed;

  /// No description provided for @adminPushNotAttempted.
  ///
  /// In en, this message translates to:
  /// **'Not attempted'**
  String get adminPushNotAttempted;

  /// No description provided for @adminPushStatusOnlyNote.
  ///
  /// In en, this message translates to:
  /// **'Push delivery status only. A notification\'s content is never shown here.'**
  String get adminPushStatusOnlyNote;

  /// No description provided for @adminNoNotificationsMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No notifications match this filter.'**
  String get adminNoNotificationsMatchFilter;

  /// No description provided for @adminUnknownRecipient.
  ///
  /// In en, this message translates to:
  /// **'Unknown recipient'**
  String get adminUnknownRecipient;

  /// No description provided for @adminSupportEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Support email'**
  String get adminSupportEmailLabel;

  /// No description provided for @adminSupportEmailHelper.
  ///
  /// In en, this message translates to:
  /// **'Shown to users who need help.'**
  String get adminSupportEmailHelper;

  /// No description provided for @adminUploadLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Upload limit shown to users (MB)'**
  String get adminUploadLimitLabel;

  /// No description provided for @adminUploadLimitHelper.
  ///
  /// In en, this message translates to:
  /// **'Display only. The enforced limit is set on the server.'**
  String get adminUploadLimitHelper;

  /// No description provided for @adminMaintenanceNoticeLabel.
  ///
  /// In en, this message translates to:
  /// **'Maintenance notice'**
  String get adminMaintenanceNoticeLabel;

  /// No description provided for @adminMaintenanceNoticeHelper.
  ///
  /// In en, this message translates to:
  /// **'Optional banner text.'**
  String get adminMaintenanceNoticeHelper;

  /// No description provided for @adminSettingsSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get adminSettingsSavedToast;

  /// No description provided for @adminServiceStatusHeader.
  ///
  /// In en, this message translates to:
  /// **'Service status'**
  String get adminServiceStatusHeader;

  /// No description provided for @adminServiceStatusSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Secrets are configured on the server and are never shown here.'**
  String get adminServiceStatusSubtitle;

  /// No description provided for @adminEnvironmentLabel.
  ///
  /// In en, this message translates to:
  /// **'Environment'**
  String get adminEnvironmentLabel;

  /// No description provided for @adminAiServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'AI (Google AI Studio)'**
  String get adminAiServiceLabel;

  /// No description provided for @adminConfiguredWithModel.
  ///
  /// In en, this message translates to:
  /// **'Configured · {model}'**
  String adminConfiguredWithModel(String model);

  /// No description provided for @commonNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get commonNotConfigured;

  /// No description provided for @commonOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get commonOn;

  /// No description provided for @commonOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get commonOff;

  /// No description provided for @adminDiabetesModelServiceLabel.
  ///
  /// In en, this message translates to:
  /// **'Diabetes model service'**
  String get adminDiabetesModelServiceLabel;

  /// No description provided for @adminUrlConfigured.
  ///
  /// In en, this message translates to:
  /// **'URL configured'**
  String get adminUrlConfigured;

  /// No description provided for @adminDemoWearableLabel.
  ///
  /// In en, this message translates to:
  /// **'Demo wearable'**
  String get adminDemoWearableLabel;

  /// No description provided for @adminDemoWearableEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled (data labelled DEMO)'**
  String get adminDemoWearableEnabled;

  /// No description provided for @commonDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get commonDisabled;

  /// No description provided for @adminEditableSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'Editable settings'**
  String get adminEditableSettingsHeader;

  /// No description provided for @adminSaveSettingsButton.
  ///
  /// In en, this message translates to:
  /// **'Save settings'**
  String get adminSaveSettingsButton;

  /// No description provided for @adminChangesRecordedNote.
  ///
  /// In en, this message translates to:
  /// **'Changes are recorded in the audit log.'**
  String get adminChangesRecordedNote;

  /// No description provided for @adminEmailAdministratorLine.
  ///
  /// In en, this message translates to:
  /// **'{email} · Administrator'**
  String adminEmailAdministratorLine(String email);

  /// No description provided for @adminAccountAndPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Account and password'**
  String get adminAccountAndPasswordLabel;

  /// No description provided for @diabetesRunNewAssessment.
  ///
  /// In en, this message translates to:
  /// **'Run new assessment'**
  String get diabetesRunNewAssessment;

  /// No description provided for @diabetesGetRiskEstimate.
  ///
  /// In en, this message translates to:
  /// **'Get risk estimate'**
  String get diabetesGetRiskEstimate;

  /// No description provided for @diabetesRefreshAssessment.
  ///
  /// In en, this message translates to:
  /// **'Refresh assessment'**
  String get diabetesRefreshAssessment;

  /// No description provided for @diabetesEstimateUpdatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Your future diabetes risk estimate has been updated.'**
  String get diabetesEstimateUpdatedSnack;

  /// No description provided for @diabetesNothingChangedSnack.
  ///
  /// In en, this message translates to:
  /// **'Nothing relevant has changed since your last estimate, so it is still current.'**
  String get diabetesNothingChangedSnack;

  /// No description provided for @diabetesHba1cTrendHeader.
  ///
  /// In en, this message translates to:
  /// **'HbA1c Trend'**
  String get diabetesHba1cTrendHeader;

  /// No description provided for @diabetesHba1cTrendSubtitle.
  ///
  /// In en, this message translates to:
  /// **'From confirmed values on your uploaded reports.'**
  String get diabetesHba1cTrendSubtitle;

  /// No description provided for @diabetesDataUsedHeader.
  ///
  /// In en, this message translates to:
  /// **'Data used for this assessment'**
  String get diabetesDataUsedHeader;

  /// No description provided for @diabetesDataUsedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only information SUSTHITI already had. Nothing was guessed or filled in.'**
  String get diabetesDataUsedSubtitle;

  /// No description provided for @diabetesHealthInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What an estimate would use, from your SUSTHITI records.'**
  String get diabetesHealthInfoSubtitle;

  /// No description provided for @riskHealthInfoAvailableHeader.
  ///
  /// In en, this message translates to:
  /// **'Health information available now'**
  String get riskHealthInfoAvailableHeader;

  /// No description provided for @riskNotRecordedHeader.
  ///
  /// In en, this message translates to:
  /// **'Not recorded yet'**
  String get riskNotRecordedHeader;

  /// No description provided for @riskNotRecordedSubtitleDiabetes.
  ///
  /// In en, this message translates to:
  /// **'The estimate uses these when they are in your records. Until then they are left out, not assumed. {available} of {total} available.'**
  String riskNotRecordedSubtitleDiabetes(String available, String total);

  /// No description provided for @riskNotRecordedSubtitleHeart.
  ///
  /// In en, this message translates to:
  /// **'The screening uses these when they are in your records or answered on the form. {available} of {total} available.'**
  String riskNotRecordedSubtitleHeart(String available, String total);

  /// No description provided for @diabetesAssessmentHistoryHeader.
  ///
  /// In en, this message translates to:
  /// **'Assessment history'**
  String get diabetesAssessmentHistoryHeader;

  /// No description provided for @diabetesAssessmentHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every estimate is kept exactly as it was made.'**
  String get diabetesAssessmentHistorySubtitle;

  /// No description provided for @diabetesEarlierSymptomQuestionnaire.
  ///
  /// In en, this message translates to:
  /// **'Earlier symptom questionnaire'**
  String get diabetesEarlierSymptomQuestionnaire;

  /// No description provided for @diabetesEarlierModelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Results from a previous model, kept for your history'**
  String get diabetesEarlierModelSubtitle;

  /// No description provided for @diabetesClassificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Classification: {value}'**
  String diabetesClassificationLabel(String value);

  /// No description provided for @diabetesIntroText.
  ///
  /// In en, this message translates to:
  /// **'Estimate your future diabetes risk. You\'ll confirm a few questions, already filled in with what SUSTHITI knows; values from your medical reports, your lifestyle and connected devices are added automatically.'**
  String get diabetesIntroText;

  /// No description provided for @riskHealthDetailsAvailableCaption.
  ///
  /// In en, this message translates to:
  /// **'{available} of {total} health details are available now.'**
  String riskHealthDetailsAvailableCaption(String available, String total);

  /// No description provided for @heartRunNewScreening.
  ///
  /// In en, this message translates to:
  /// **'Run new screening'**
  String get heartRunNewScreening;

  /// No description provided for @heartGetRiskScreening.
  ///
  /// In en, this message translates to:
  /// **'Get risk screening'**
  String get heartGetRiskScreening;

  /// No description provided for @heartRefreshScreening.
  ///
  /// In en, this message translates to:
  /// **'Refresh screening'**
  String get heartRefreshScreening;

  /// No description provided for @heartScreeningUpdatedSnack.
  ///
  /// In en, this message translates to:
  /// **'Your heart risk screening has been updated.'**
  String get heartScreeningUpdatedSnack;

  /// No description provided for @heartNothingChangedSnack.
  ///
  /// In en, this message translates to:
  /// **'Nothing relevant has changed since your last screening, so it is still current.'**
  String get heartNothingChangedSnack;

  /// No description provided for @heartDataUsedHeader.
  ///
  /// In en, this message translates to:
  /// **'Data used for this screening'**
  String get heartDataUsedHeader;

  /// No description provided for @heartDataUsedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Only information SUSTHITI already had, or that was answered on the assessment form.'**
  String get heartDataUsedSubtitle;

  /// No description provided for @heartHealthInfoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'What a screening would use, from your SUSTHITI records.'**
  String get heartHealthInfoSubtitle;

  /// No description provided for @heartScreeningHistoryHeader.
  ///
  /// In en, this message translates to:
  /// **'Screening history'**
  String get heartScreeningHistoryHeader;

  /// No description provided for @heartScreeningHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every screening is kept exactly as it was made.'**
  String get heartScreeningHistorySubtitle;

  /// No description provided for @heartIntroText.
  ///
  /// In en, this message translates to:
  /// **'Screen your heart disease risk. You\'ll answer a short form covering symptoms, vitals and cardiac tests; values already in your SUSTHITI records (profile, labs, lifestyle) are filled in for you to review.'**
  String get heartIntroText;

  /// No description provided for @commonActivityTab.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get commonActivityTab;

  /// No description provided for @commonAuditTab.
  ///
  /// In en, this message translates to:
  /// **'Audit'**
  String get commonAuditTab;

  /// No description provided for @commonPatientFallback.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get commonPatientFallback;

  /// No description provided for @commonNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get commonNotRecorded;

  /// No description provided for @commonNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get commonNever;

  /// No description provided for @commonNoneRecorded.
  ///
  /// In en, this message translates to:
  /// **'None recorded'**
  String get commonNoneRecorded;

  /// No description provided for @commonNoneYet.
  ///
  /// In en, this message translates to:
  /// **'None yet'**
  String get commonNoneYet;

  /// No description provided for @commonResolvedLabel.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get commonResolvedLabel;

  /// No description provided for @adminEditDoctorButton.
  ///
  /// In en, this message translates to:
  /// **'Edit Doctor'**
  String get adminEditDoctorButton;

  /// No description provided for @adocUnableToLoadProfile.
  ///
  /// In en, this message translates to:
  /// **'Unable to load profile.'**
  String get adocUnableToLoadProfile;

  /// No description provided for @adocBackToDoctors.
  ///
  /// In en, this message translates to:
  /// **'Back to Doctors'**
  String get adocBackToDoctors;

  /// No description provided for @adocDoctorIdColon.
  ///
  /// In en, this message translates to:
  /// **'Doctor ID: {code}'**
  String adocDoctorIdColon(String code);

  /// No description provided for @adocSpecializationNotRecorded.
  ///
  /// In en, this message translates to:
  /// **'Specialization not recorded'**
  String get adocSpecializationNotRecorded;

  /// No description provided for @adocMoreActionsTooltip.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get adocMoreActionsTooltip;

  /// No description provided for @adocViewAuditLogMenuItem.
  ///
  /// In en, this message translates to:
  /// **'View audit log'**
  String get adocViewAuditLogMenuItem;

  /// No description provided for @adocTotalPendingCaption.
  ///
  /// In en, this message translates to:
  /// **'{total} total · {pending} pending'**
  String adocTotalPendingCaption(String total, String pending);

  /// No description provided for @adocThisMonthTotalCaption.
  ///
  /// In en, this message translates to:
  /// **'{month} this month · {total} total'**
  String adocThisMonthTotalCaption(String month, String total);

  /// No description provided for @adocUpcomingLabel.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get adocUpcomingLabel;

  /// No description provided for @adocFollowUpsApptsCaption.
  ///
  /// In en, this message translates to:
  /// **'{followUps} follow-ups · {appts} appts'**
  String adocFollowUpsApptsCaption(String followUps, String appts);

  /// No description provided for @adocPendingResolvedCaption.
  ///
  /// In en, this message translates to:
  /// **'{pending} pending · {resolved} resolved'**
  String adocPendingResolvedCaption(String pending, String resolved);

  /// No description provided for @adocActivePatientsHeader.
  ///
  /// In en, this message translates to:
  /// **'Active Patients'**
  String get adocActivePatientsHeader;

  /// No description provided for @adocNoActivePatients.
  ///
  /// In en, this message translates to:
  /// **'No active patients.'**
  String get adocNoActivePatients;

  /// No description provided for @adocNoRecordedActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No recorded activity yet.'**
  String get adocNoRecordedActivityYet;

  /// No description provided for @adocPatientAccessHeader.
  ///
  /// In en, this message translates to:
  /// **'Patient Access'**
  String get adocPatientAccessHeader;

  /// No description provided for @adocPatientAccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Relationships approved or pending through patient authorization'**
  String get adocPatientAccessSubtitle;

  /// No description provided for @adocNoAccessRequestsYet.
  ///
  /// In en, this message translates to:
  /// **'No access requests yet.'**
  String get adocNoAccessRequestsYet;

  /// No description provided for @adocRequestedOnCaption.
  ///
  /// In en, this message translates to:
  /// **'{code} · requested {date}'**
  String adocRequestedOnCaption(String code, String date);

  /// No description provided for @adocFiguresDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'Figures are counted from recorded data. SUSTHITI does not calculate a health score.'**
  String get adocFiguresDisclaimer;

  /// No description provided for @adocNoActivity.
  ///
  /// In en, this message translates to:
  /// **'No activity'**
  String get adocNoActivity;

  /// No description provided for @adocPatientProgressHeader.
  ///
  /// In en, this message translates to:
  /// **'Patient Progress'**
  String get adocPatientProgressHeader;

  /// No description provided for @adocAcrossActivePatients.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Across 1 active patient} other{Across {count} active patients}}'**
  String adocAcrossActivePatients(num count);

  /// No description provided for @adocLatestClassificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest diabetes model classification'**
  String get adocLatestClassificationLabel;

  /// No description provided for @adocPatternDetected.
  ///
  /// In en, this message translates to:
  /// **'Pattern detected'**
  String get adocPatternDetected;

  /// No description provided for @adocNoPatternDetected.
  ///
  /// In en, this message translates to:
  /// **'No pattern detected'**
  String get adocNoPatternDetected;

  /// No description provided for @adocGlucoseLast7DaysLabel.
  ///
  /// In en, this message translates to:
  /// **'Glucose, last 7 days vs previous weeks'**
  String get adocGlucoseLast7DaysLabel;

  /// No description provided for @adocSimilarLabel.
  ///
  /// In en, this message translates to:
  /// **'Similar'**
  String get adocSimilarLabel;

  /// No description provided for @adocTooFewReadings.
  ///
  /// In en, this message translates to:
  /// **'Too few readings'**
  String get adocTooFewReadings;

  /// No description provided for @adocNeedAttentionPill.
  ///
  /// In en, this message translates to:
  /// **'{count} need attention'**
  String adocNeedAttentionPill(String count);

  /// No description provided for @adocOpenSideEffectsPill.
  ///
  /// In en, this message translates to:
  /// **'{count} with open side effects'**
  String adocOpenSideEffectsPill(String count);

  /// No description provided for @adocAssessedIn30DaysPill.
  ///
  /// In en, this message translates to:
  /// **'{count} assessed in 30 days'**
  String adocAssessedIn30DaysPill(String count);

  /// No description provided for @adocInactiveFor30DaysPill.
  ///
  /// In en, this message translates to:
  /// **'{count} inactive for 30 days'**
  String adocInactiveFor30DaysPill(String count);

  /// No description provided for @adocNoPatientsInGroup.
  ///
  /// In en, this message translates to:
  /// **'No patients in this group.'**
  String get adocNoPatientsInGroup;

  /// No description provided for @adocPatientsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 patient} other{{count} patients}}'**
  String adocPatientsCountLabel(num count);

  /// No description provided for @adocLatestGlucoseCol.
  ///
  /// In en, this message translates to:
  /// **'Latest glucose'**
  String get adocLatestGlucoseCol;

  /// No description provided for @adocProgressCol.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get adocProgressCol;

  /// No description provided for @adocAccessCol.
  ///
  /// In en, this message translates to:
  /// **'Access'**
  String get adocAccessCol;

  /// No description provided for @adocGlucoseMgDl.
  ///
  /// In en, this message translates to:
  /// **'Glucose {value} mg/dL'**
  String adocGlucoseMgDl(String value);

  /// No description provided for @adocLastActivityLine.
  ///
  /// In en, this message translates to:
  /// **'Last activity {value}'**
  String adocLastActivityLine(String value);

  /// No description provided for @adocReportDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Report date {date}'**
  String adocReportDateLabel(String date);

  /// No description provided for @adocOpenedLabel.
  ///
  /// In en, this message translates to:
  /// **'Opened {relative}'**
  String adocOpenedLabel(String relative);

  /// No description provided for @adocUploadedLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {date}'**
  String adocUploadedLabel(String date);

  /// No description provided for @adocReportsUploadedHeader.
  ///
  /// In en, this message translates to:
  /// **'Reports Uploaded'**
  String get adocReportsUploadedHeader;

  /// No description provided for @adocNoReportsUploadedByDoctor.
  ///
  /// In en, this message translates to:
  /// **'No reports uploaded by this doctor.'**
  String get adocNoReportsUploadedByDoctor;

  /// No description provided for @adocReportsOpenedHeader.
  ///
  /// In en, this message translates to:
  /// **'Reports Opened'**
  String get adocReportsOpenedHeader;

  /// No description provided for @adocReportsOpenedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Original files the doctor viewed or downloaded'**
  String get adocReportsOpenedSubtitle;

  /// No description provided for @adocNoRecentReportActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent report activity.'**
  String get adocNoRecentReportActivity;

  /// No description provided for @adocAiSummariesHeader.
  ///
  /// In en, this message translates to:
  /// **'AI Report Summaries Generated'**
  String get adocAiSummariesHeader;

  /// No description provided for @adocNoSummariesGenerated.
  ///
  /// In en, this message translates to:
  /// **'No report summaries generated.'**
  String get adocNoSummariesGenerated;

  /// No description provided for @adocAllReportsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'All-reports summary'**
  String get adocAllReportsSummaryTitle;

  /// No description provided for @adocReportSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Report summary'**
  String get adocReportSummaryTitle;

  /// No description provided for @adocPrescriptionsHistoricalNote.
  ///
  /// In en, this message translates to:
  /// **'Prescriptions are historical records. Viewing them never changes them.'**
  String get adocPrescriptionsHistoricalNote;

  /// No description provided for @adocNoPrescriptionsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No prescriptions recorded.'**
  String get adocNoPrescriptionsRecorded;

  /// No description provided for @adocPrescriptionsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 prescription} other{{count} prescriptions}}'**
  String adocPrescriptionsCountLabel(num count);

  /// No description provided for @adocPrescriptionCol.
  ///
  /// In en, this message translates to:
  /// **'Prescription'**
  String get adocPrescriptionCol;

  /// No description provided for @adocMedicinesCol.
  ///
  /// In en, this message translates to:
  /// **'Medicines'**
  String get adocMedicinesCol;

  /// No description provided for @adocMedicinesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 medicine} other{{count} medicines}}'**
  String adocMedicinesCountLabel(num count);

  /// No description provided for @adocUpcomingFollowUpsHeader.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Follow-ups'**
  String get adocUpcomingFollowUpsHeader;

  /// No description provided for @adocUpcomingFollowUpsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Follow-up dates from this doctor\'s visits and prescriptions'**
  String get adocUpcomingFollowUpsSubtitle;

  /// No description provided for @adocNoUpcomingFollowUps.
  ///
  /// In en, this message translates to:
  /// **'No upcoming follow-ups.'**
  String get adocNoUpcomingFollowUps;

  /// No description provided for @adocVisitFollowUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Visit follow-up'**
  String get adocVisitFollowUpLabel;

  /// No description provided for @adocPrescriptionFollowUpLabel.
  ///
  /// In en, this message translates to:
  /// **'Prescription follow-up'**
  String get adocPrescriptionFollowUpLabel;

  /// No description provided for @adocFollowUpStatusLabel.
  ///
  /// In en, this message translates to:
  /// **'Follow-up{status}'**
  String adocFollowUpStatusLabel(String status);

  /// No description provided for @adocAppointmentRecommendationsHeader.
  ///
  /// In en, this message translates to:
  /// **'Appointment Recommendations'**
  String get adocAppointmentRecommendationsHeader;

  /// No description provided for @adocNoAppointmentRecommendations.
  ///
  /// In en, this message translates to:
  /// **'No appointment recommendations.'**
  String get adocNoAppointmentRecommendations;

  /// No description provided for @adocRecommendedOn.
  ///
  /// In en, this message translates to:
  /// **'Recommended {date}'**
  String adocRecommendedOn(String date);

  /// No description provided for @adocSuggestedFor.
  ///
  /// In en, this message translates to:
  /// **'Suggested for {date}'**
  String adocSuggestedFor(String date);

  /// No description provided for @adocRecentVisitsHeader.
  ///
  /// In en, this message translates to:
  /// **'Recent Visits'**
  String get adocRecentVisitsHeader;

  /// No description provided for @adocNoVisitsRecorded.
  ///
  /// In en, this message translates to:
  /// **'No visits recorded.'**
  String get adocNoVisitsRecorded;

  /// No description provided for @adocScheduledSurgeriesHeader.
  ///
  /// In en, this message translates to:
  /// **'Scheduled Surgeries'**
  String get adocScheduledSurgeriesHeader;

  /// No description provided for @adocPendingReviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Pending review'**
  String get adocPendingReviewLabel;

  /// No description provided for @adocRespondedByDoctorLabel.
  ///
  /// In en, this message translates to:
  /// **'Responded by this doctor'**
  String get adocRespondedByDoctorLabel;

  /// No description provided for @adocNoSideEffectReports.
  ///
  /// In en, this message translates to:
  /// **'No side-effect reports.'**
  String get adocNoSideEffectReports;

  /// No description provided for @adocSideEffectCol.
  ///
  /// In en, this message translates to:
  /// **'Side effect'**
  String get adocSideEffectCol;

  /// No description provided for @adocSeverityCol.
  ///
  /// In en, this message translates to:
  /// **'Severity'**
  String get adocSeverityCol;

  /// No description provided for @adocReportedCol.
  ///
  /// In en, this message translates to:
  /// **'Reported'**
  String get adocReportedCol;

  /// No description provided for @adocDoctorResponseCol.
  ///
  /// In en, this message translates to:
  /// **'Doctor response'**
  String get adocDoctorResponseCol;

  /// No description provided for @adocNoResponseYet.
  ///
  /// In en, this message translates to:
  /// **'No response yet'**
  String get adocNoResponseYet;

  /// No description provided for @adocDoctorActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What this doctor has done in SUSTHITI. Open an entry to see the record.'**
  String get adocDoctorActivitySubtitle;

  /// No description provided for @adocLatestOfTotalEntries.
  ///
  /// In en, this message translates to:
  /// **'Latest {shown} of {total} entries'**
  String adocLatestOfTotalEntries(int shown, int total);

  /// No description provided for @adocEntriesCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 entry} other{{count} entries}}'**
  String adocEntriesCountLabel(num count);

  /// No description provided for @commonDateColumnLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get commonDateColumnLabel;

  /// No description provided for @adocActionCol.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get adocActionCol;

  /// No description provided for @adocRelatedRecordCol.
  ///
  /// In en, this message translates to:
  /// **'Related record'**
  String get adocRelatedRecordCol;

  /// No description provided for @adocPerformedByCol.
  ///
  /// In en, this message translates to:
  /// **'Performed by'**
  String get adocPerformedByCol;

  /// No description provided for @adocDoctorInformationHeader.
  ///
  /// In en, this message translates to:
  /// **'Doctor Information'**
  String get adocDoctorInformationHeader;

  /// No description provided for @adocLicenseRegistrationLabel.
  ///
  /// In en, this message translates to:
  /// **'License / registration'**
  String get adocLicenseRegistrationLabel;

  /// No description provided for @adocAccountCreatedLabel.
  ///
  /// In en, this message translates to:
  /// **'Account created'**
  String get adocAccountCreatedLabel;

  /// No description provided for @adocLastSignInLabel.
  ///
  /// In en, this message translates to:
  /// **'Last sign-in'**
  String get adocLastSignInLabel;

  /// No description provided for @apatUnableToLoadDetails.
  ///
  /// In en, this message translates to:
  /// **'Unable to load patient details.'**
  String get apatUnableToLoadDetails;

  /// No description provided for @apatBackToPatients.
  ///
  /// In en, this message translates to:
  /// **'Back to Patients'**
  String get apatBackToPatients;

  /// No description provided for @apatPatientIdColon.
  ///
  /// In en, this message translates to:
  /// **'Patient ID: {code}'**
  String apatPatientIdColon(String code);

  /// No description provided for @commonAgeYears.
  ///
  /// In en, this message translates to:
  /// **'{age} years'**
  String commonAgeYears(String age);

  /// No description provided for @apatEditPatientButton.
  ///
  /// In en, this message translates to:
  /// **'Edit Patient'**
  String get apatEditPatientButton;

  /// No description provided for @apatFoodTab.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get apatFoodTab;

  /// No description provided for @apatAiSummariesTab.
  ///
  /// In en, this message translates to:
  /// **'AI Summaries'**
  String get apatAiSummariesTab;

  /// No description provided for @apatUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load'**
  String get apatUnableToLoad;

  /// No description provided for @apatLatestGlucoseLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest glucose'**
  String get apatLatestGlucoseLabel;

  /// No description provided for @apatGlucoseRelativeTrend.
  ///
  /// In en, this message translates to:
  /// **'{relative} · {trend}'**
  String apatGlucoseRelativeTrend(String relative, String trend);

  /// No description provided for @apatCurrentDoctorsHeader.
  ///
  /// In en, this message translates to:
  /// **'Current Doctors'**
  String get apatCurrentDoctorsHeader;

  /// No description provided for @apatAllRelationshipsButton.
  ///
  /// In en, this message translates to:
  /// **'All relationships'**
  String get apatAllRelationshipsButton;

  /// No description provided for @apatNoDoctorAccess.
  ///
  /// In en, this message translates to:
  /// **'No doctor currently has access.'**
  String get apatNoDoctorAccess;

  /// No description provided for @apatRecentReportsHeader.
  ///
  /// In en, this message translates to:
  /// **'Recent Reports'**
  String get apatRecentReportsHeader;

  /// No description provided for @apatNoRecordedHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No recorded history yet.'**
  String get apatNoRecordedHistoryYet;

  /// No description provided for @apatNoUpcomingFollowUp.
  ///
  /// In en, this message translates to:
  /// **'No upcoming follow-up'**
  String get apatNoUpcomingFollowUp;

  /// No description provided for @apatNextFollowUpOn.
  ///
  /// In en, this message translates to:
  /// **'Next follow-up {date}'**
  String apatNextFollowUpOn(String date);

  /// No description provided for @apatFromVisitsAndPrescriptions.
  ///
  /// In en, this message translates to:
  /// **'From visits and prescriptions'**
  String get apatFromVisitsAndPrescriptions;

  /// No description provided for @apatForDate.
  ///
  /// In en, this message translates to:
  /// **'for {date}'**
  String apatForDate(String date);

  /// No description provided for @apatLongitudinalTrendsHeader.
  ///
  /// In en, this message translates to:
  /// **'Longitudinal Trends'**
  String get apatLongitudinalTrendsHeader;

  /// No description provided for @apatLongitudinalTrendsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recorded values only. Nothing is estimated or filled in.'**
  String get apatLongitudinalTrendsSubtitle;

  /// No description provided for @apatGlucoseDetailsButton.
  ///
  /// In en, this message translates to:
  /// **'Glucose details'**
  String get apatGlucoseDetailsButton;

  /// No description provided for @apatGlucoseMgDlTitle.
  ///
  /// In en, this message translates to:
  /// **'Glucose (mg/dL)'**
  String get apatGlucoseMgDlTitle;

  /// No description provided for @apatNoDevicesConnected.
  ///
  /// In en, this message translates to:
  /// **'No devices connected.'**
  String get apatNoDevicesConnected;

  /// No description provided for @apatDisconnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get apatDisconnectedLabel;

  /// No description provided for @apatNeverLower.
  ///
  /// In en, this message translates to:
  /// **'never'**
  String get apatNeverLower;

  /// No description provided for @apatLastSyncedPrefix.
  ///
  /// In en, this message translates to:
  /// **'Last synced {value}'**
  String apatLastSyncedPrefix(String value);

  /// No description provided for @apatSyncFailedLabel.
  ///
  /// In en, this message translates to:
  /// **'sync failed'**
  String get apatSyncFailedLabel;

  /// No description provided for @apatCountsSummary.
  ///
  /// In en, this message translates to:
  /// **'Counts: {reports} reports · {assessments} assessments · {glucose} glucose readings · {prescriptions} prescriptions · {visits} visits · {sideEffects} side effects'**
  String apatCountsSummary(
    String reports,
    String assessments,
    String glucose,
    String prescriptions,
    String visits,
    String sideEffects,
  );

  /// No description provided for @apatHistoryCountButton.
  ///
  /// In en, this message translates to:
  /// **'History ({count})'**
  String apatHistoryCountButton(int count);

  /// No description provided for @apatNoRiskEstimateYet.
  ///
  /// In en, this message translates to:
  /// **'No risk estimate recorded yet.'**
  String get apatNoRiskEstimateYet;

  /// No description provided for @apatAssessedOn.
  ///
  /// In en, this message translates to:
  /// **'Assessed {date}{model}'**
  String apatAssessedOn(String date, String model);

  /// No description provided for @apatOpenEstimateButton.
  ///
  /// In en, this message translates to:
  /// **'Open estimate'**
  String get apatOpenEstimateButton;

  /// No description provided for @apatAccessSinceLabel.
  ///
  /// In en, this message translates to:
  /// **'Access since {date}'**
  String apatAccessSinceLabel(String date);

  /// No description provided for @apatPersonalInfoHeader.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get apatPersonalInfoHeader;

  /// No description provided for @apatHeightWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height / weight'**
  String get apatHeightWeightLabel;

  /// No description provided for @apatBmiCalculatedLabel.
  ///
  /// In en, this message translates to:
  /// **'BMI (calculated)'**
  String get apatBmiCalculatedLabel;

  /// No description provided for @apatNoEmergencyContactRecorded.
  ///
  /// In en, this message translates to:
  /// **'No emergency contact recorded.'**
  String get apatNoEmergencyContactRecorded;

  /// No description provided for @apatFoodLoggedNote.
  ///
  /// In en, this message translates to:
  /// **'Food logged in the last 30 days. Edited entries keep their earlier versions.'**
  String get apatFoodLoggedNote;

  /// No description provided for @apatNoFoodLogged30Days.
  ///
  /// In en, this message translates to:
  /// **'No food logged in the last 30 days.'**
  String get apatNoFoodLogged30Days;

  /// No description provided for @apatNoUpcomingFollowUpRecorded.
  ///
  /// In en, this message translates to:
  /// **'No upcoming follow-up recorded.'**
  String get apatNoUpcomingFollowUpRecorded;

  /// No description provided for @apatNextFollowUpColon.
  ///
  /// In en, this message translates to:
  /// **'Next follow-up: {date}'**
  String apatNextFollowUpColon(String date);

  /// No description provided for @commonRelatedToSideEffect.
  ///
  /// In en, this message translates to:
  /// **'Related to a side-effect report'**
  String get commonRelatedToSideEffect;

  /// No description provided for @apatAiDisclaimerText.
  ///
  /// In en, this message translates to:
  /// **'AI summaries are generated from available records. They are not a doctor\'s clinical conclusion and do not replace medical advice. Every generation is kept; nothing here is regenerated when you view it.'**
  String get apatAiDisclaimerText;

  /// No description provided for @apatNoAiSummariesYet.
  ///
  /// In en, this message translates to:
  /// **'No AI summaries generated yet.'**
  String get apatNoAiSummariesYet;

  /// No description provided for @apatGeneratedOn.
  ///
  /// In en, this message translates to:
  /// **'Generated {datetime}'**
  String apatGeneratedOn(String datetime);

  /// No description provided for @apatByRoleSuffix.
  ///
  /// In en, this message translates to:
  /// **' by {role}'**
  String apatByRoleSuffix(String role);

  /// No description provided for @apatNewerRecordsExist.
  ///
  /// In en, this message translates to:
  /// **'newer records exist'**
  String get apatNewerRecordsExist;

  /// No description provided for @apatBasedOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Based on: {list}'**
  String apatBasedOnLabel(String list);

  /// No description provided for @apatAiModelLabel.
  ///
  /// In en, this message translates to:
  /// **'AI model: {model}'**
  String apatAiModelLabel(String model);

  /// No description provided for @apatViewPdfButton.
  ///
  /// In en, this message translates to:
  /// **'View PDF'**
  String get apatViewPdfButton;

  /// No description provided for @apatDownloadPdfButton.
  ///
  /// In en, this message translates to:
  /// **'Download PDF'**
  String get apatDownloadPdfButton;

  /// No description provided for @apatDoctorRelationshipsNote.
  ///
  /// In en, this message translates to:
  /// **'Every doctor relationship, including past ones. Doctors see records only while access is approved by the patient.'**
  String get apatDoctorRelationshipsNote;

  /// No description provided for @apatNoDoctorRequestedAccess.
  ///
  /// In en, this message translates to:
  /// **'No doctor has requested access yet.'**
  String get apatNoDoctorRequestedAccess;

  /// No description provided for @apatRequestedCol.
  ///
  /// In en, this message translates to:
  /// **'Requested'**
  String get apatRequestedCol;

  /// No description provided for @apatGrantedEndedCol.
  ///
  /// In en, this message translates to:
  /// **'Granted / ended'**
  String get apatGrantedEndedCol;

  /// No description provided for @apatEndedOn.
  ///
  /// In en, this message translates to:
  /// **'Ended {date}'**
  String apatEndedOn(String date);

  /// No description provided for @apatSpecRequestedCaption.
  ///
  /// In en, this message translates to:
  /// **'{spec} · requested {date}'**
  String apatSpecRequestedCaption(String spec, String date);

  /// No description provided for @apatLongitudinalHistoryHeader.
  ///
  /// In en, this message translates to:
  /// **'Longitudinal History'**
  String get apatLongitudinalHistoryHeader;

  /// No description provided for @apatLongitudinalHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each record keeps its own medical date. Open an entry to see the record.'**
  String get apatLongitudinalHistorySubtitle;

  /// No description provided for @apatNothingInCategory.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded in this category.'**
  String get apatNothingInCategory;

  /// No description provided for @apatNotificationsSentHeader.
  ///
  /// In en, this message translates to:
  /// **'Notifications Sent to the Patient'**
  String get apatNotificationsSentHeader;

  /// No description provided for @apatNoNotificationsSent.
  ///
  /// In en, this message translates to:
  /// **'No notifications sent.'**
  String get apatNoNotificationsSent;

  /// No description provided for @commonRead.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get commonRead;

  /// No description provided for @apatEditPatientTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Patient'**
  String get apatEditPatientTitle;

  /// No description provided for @apatPatientDetailsUpdatedToast.
  ///
  /// In en, this message translates to:
  /// **'Patient details updated'**
  String get apatPatientDetailsUpdatedToast;

  /// No description provided for @apatDobGenderNotEditableNote.
  ///
  /// In en, this message translates to:
  /// **'Date of birth and gender are provided by the patient and used by the diabetes model, so they are not editable here. Medical records cannot be changed from this screen. Changes are recorded in the audit log.'**
  String get apatDobGenderNotEditableNote;

  /// No description provided for @timelineFilterAssessments.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get timelineFilterAssessments;

  /// No description provided for @timelineFilterAiSummaries.
  ///
  /// In en, this message translates to:
  /// **'AI summaries'**
  String get timelineFilterAiSummaries;

  /// No description provided for @timelineNoRecordsYet.
  ///
  /// In en, this message translates to:
  /// **'No records yet.'**
  String get timelineNoRecordsYet;

  /// No description provided for @timelineEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Reports, assessments, prescriptions and visits will appear here in date order.'**
  String get timelineEmptyMessage;

  /// No description provided for @apptRecommendationsNote.
  ///
  /// In en, this message translates to:
  /// **'Recommendations from your doctor. Please contact the clinic to book a time.'**
  String get apptRecommendationsNote;

  /// No description provided for @adocRecentActivityHeader.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get adocRecentActivityHeader;

  /// No description provided for @reportsSelectReportTitle.
  ///
  /// In en, this message translates to:
  /// **'Select a report'**
  String get reportsSelectReportTitle;

  /// No description provided for @reportsSelectReportMessage.
  ///
  /// In en, this message translates to:
  /// **'Its details, original file and AI summary appear here.'**
  String get reportsSelectReportMessage;

  /// No description provided for @reportsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search reports...'**
  String get reportsSearchHint;

  /// No description provided for @reportsFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter reports'**
  String get reportsFilterTooltip;

  /// No description provided for @reportsUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load your reports.'**
  String get reportsUnableToLoad;

  /// No description provided for @reportsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching reports'**
  String get reportsNoMatchTitle;

  /// No description provided for @reportsNoMatchMessage.
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get reportsNoMatchMessage;

  /// No description provided for @reportsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No reports yet.'**
  String get reportsEmptyTitle;

  /// No description provided for @reportsEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Upload your first medical report to begin building your health history.'**
  String get reportsEmptyMessage;

  /// No description provided for @reportsCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 report} other{{count} reports}}'**
  String reportsCountLabel(num count);

  /// No description provided for @commonLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get commonLoadMore;

  /// No description provided for @allReportsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'All Reports Summary'**
  String get allReportsSummaryTitle;

  /// No description provided for @allReportsSummarySubtitle.
  ///
  /// In en, this message translates to:
  /// **'What your collection of reports shows over time'**
  String get allReportsSummarySubtitle;

  /// No description provided for @reportTileSemantic.
  ///
  /// In en, this message translates to:
  /// **'{title}, report date {reportDate}, uploaded {uploadedDate} by {role}'**
  String reportTileSemantic(
    String title,
    String reportDate,
    String uploadedDate,
    String role,
  );

  /// No description provided for @reportUploadedByLine.
  ///
  /// In en, this message translates to:
  /// **'Uploaded {date} · by {role}'**
  String reportUploadedByLine(String date, String role);

  /// No description provided for @reportsFilterSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Reports'**
  String get reportsFilterSheetTitle;

  /// No description provided for @commonCategoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get commonCategoryLabel;

  /// No description provided for @commonAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get commonAny;

  /// No description provided for @reportsClearDatesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear dates'**
  String get reportsClearDatesTooltip;

  /// No description provided for @commonSortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get commonSortLabel;

  /// No description provided for @commonNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get commonNewest;

  /// No description provided for @commonOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get commonOldest;

  /// No description provided for @commonReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get commonReset;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @allReportsSummaryDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This summary reviews your authorized report history together, in order of report date, and only describes trends that the reports actually support. For what a single report says, open that report and use its AI Summary.'**
  String get allReportsSummaryDisclaimer;

  /// No description provided for @combinedReportSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Combined report summary'**
  String get combinedReportSummaryTitle;

  /// No description provided for @combinedSummaryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No combined summary generated yet. {count, plural, =1{1 report} other{{count} reports}} available.'**
  String combinedSummaryEmptyMessage(num count);

  /// No description provided for @needTwoReportsReason.
  ///
  /// In en, this message translates to:
  /// **'At least two reports are needed to look at changes over time.'**
  String get needTwoReportsReason;

  /// No description provided for @generateAllReportsSummaryButton.
  ///
  /// In en, this message translates to:
  /// **'Generate All Reports Summary'**
  String get generateAllReportsSummaryButton;

  /// No description provided for @reviewingHistoricalReportsMessage.
  ///
  /// In en, this message translates to:
  /// **'Reviewing historical reports...'**
  String get reviewingHistoricalReportsMessage;

  /// No description provided for @originalReportsSafeMessage.
  ///
  /// In en, this message translates to:
  /// **'Your original reports are still safely available.'**
  String get originalReportsSafeMessage;

  /// No description provided for @reportFallbackTitle.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportFallbackTitle;

  /// No description provided for @aiSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Summary'**
  String get aiSummaryTitle;

  /// No description provided for @noSummaryGeneratedYet.
  ///
  /// In en, this message translates to:
  /// **'No summary generated yet.'**
  String get noSummaryGeneratedYet;

  /// No description provided for @analyzingReportMessage.
  ///
  /// In en, this message translates to:
  /// **'Analyzing report...'**
  String get analyzingReportMessage;

  /// No description provided for @originalReportSafeMessage.
  ///
  /// In en, this message translates to:
  /// **'Your original report is still safely available.'**
  String get originalReportSafeMessage;

  /// No description provided for @commonUploadedLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get commonUploadedLabel;

  /// No description provided for @commonUploadedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Uploaded by'**
  String get commonUploadedByLabel;

  /// No description provided for @reportIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Report ID'**
  String get reportIdLabel;

  /// No description provided for @originalReportHeader.
  ///
  /// In en, this message translates to:
  /// **'Original Report'**
  String get originalReportHeader;

  /// No description provided for @commonView.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// No description provided for @commonDownload.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get commonDownload;

  /// No description provided for @imageCannotPreview.
  ///
  /// In en, this message translates to:
  /// **'This image can\'t be previewed here.'**
  String get imageCannotPreview;

  /// No description provided for @useDownloadToOpen.
  ///
  /// In en, this message translates to:
  /// **'Use Download to open it in another app.'**
  String get useDownloadToOpen;

  /// No description provided for @reportValuesSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Report values saved.'**
  String get reportValuesSavedToast;

  /// No description provided for @noValuesReadFromReport.
  ///
  /// In en, this message translates to:
  /// **'No values could be read from this report.'**
  String get noValuesReadFromReport;

  /// No description provided for @valuesReadPleaseCheck.
  ///
  /// In en, this message translates to:
  /// **'Values read from the report. Please check them.'**
  String get valuesReadPleaseCheck;

  /// No description provided for @valuesFromReportHeader.
  ///
  /// In en, this message translates to:
  /// **'Values from this report'**
  String get valuesFromReportHeader;

  /// No description provided for @reportValuesAutoReadDescription.
  ///
  /// In en, this message translates to:
  /// **'SUSTHITI reads HbA1c and glucose results from the report automatically and uses them in your health features, including your future diabetes risk estimate.'**
  String get reportValuesAutoReadDescription;

  /// No description provided for @noValuesRecordedYet.
  ///
  /// In en, this message translates to:
  /// **'No values recorded from this report yet.'**
  String get noValuesRecordedYet;

  /// No description provided for @looksRightButton.
  ///
  /// In en, this message translates to:
  /// **'Looks right'**
  String get looksRightButton;

  /// No description provided for @readAutomaticallyLabel.
  ///
  /// In en, this message translates to:
  /// **'Read automatically'**
  String get readAutomaticallyLabel;

  /// No description provided for @checkedByDoctorLabel.
  ///
  /// In en, this message translates to:
  /// **'Checked by doctor'**
  String get checkedByDoctorLabel;

  /// No description provided for @checkedByYouLabel.
  ///
  /// In en, this message translates to:
  /// **'Checked by you'**
  String get checkedByYouLabel;

  /// No description provided for @commonYou.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get commonYou;

  /// No description provided for @readAutoCheckNote.
  ///
  /// In en, this message translates to:
  /// **'Read automatically: please check these against the report. Correct them with \"Add or correct values\" if needed.'**
  String get readAutoCheckNote;

  /// No description provided for @foundInAiSummaryNote.
  ///
  /// In en, this message translates to:
  /// **'Found in the AI summary. Please check them against the report before confirming:'**
  String get foundInAiSummaryNote;

  /// No description provided for @theseMatchReportButton.
  ///
  /// In en, this message translates to:
  /// **'These match the report'**
  String get theseMatchReportButton;

  /// No description provided for @readValuesFromReportButton.
  ///
  /// In en, this message translates to:
  /// **'Read values from this report'**
  String get readValuesFromReportButton;

  /// No description provided for @addValuesYourselfButton.
  ///
  /// In en, this message translates to:
  /// **'Add values yourself'**
  String get addValuesYourselfButton;

  /// No description provided for @addOrCorrectValuesButton.
  ///
  /// In en, this message translates to:
  /// **'Add or correct values'**
  String get addOrCorrectValuesButton;

  /// No description provided for @reportValuesFormSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Report date {date}. Leave a value empty if the report doesn\'t show it.'**
  String reportValuesFormSubtitle(String date);

  /// No description provided for @enterAsNumberError.
  ///
  /// In en, this message translates to:
  /// **'Enter {label} as a number, exactly as in the report.'**
  String enterAsNumberError(String label);

  /// No description provided for @classificationOnlyIfStatedNote.
  ///
  /// In en, this message translates to:
  /// **'Only if the report itself states it. SUSTHITI never works this out from the numbers.'**
  String get classificationOnlyIfStatedNote;

  /// No description provided for @notStatedChip.
  ///
  /// In en, this message translates to:
  /// **'Not stated'**
  String get notStatedChip;

  /// No description provided for @saveValuesButton.
  ///
  /// In en, this message translates to:
  /// **'Save values'**
  String get saveValuesButton;

  /// No description provided for @riskEstimateTitle.
  ///
  /// In en, this message translates to:
  /// **'Risk estimate'**
  String get riskEstimateTitle;

  /// No description provided for @riskDetailDataUsedHeader.
  ///
  /// In en, this message translates to:
  /// **'Data used'**
  String get riskDetailDataUsedHeader;

  /// No description provided for @riskDetailDataUsedSubtitleEstimate.
  ///
  /// In en, this message translates to:
  /// **'As recorded when this estimate was made.'**
  String get riskDetailDataUsedSubtitleEstimate;

  /// No description provided for @riskDetailNotAvailableHeader.
  ///
  /// In en, this message translates to:
  /// **'Not available at the time'**
  String get riskDetailNotAvailableHeader;

  /// No description provided for @riskDetailNotAssumedSubtitleEstimate.
  ///
  /// In en, this message translates to:
  /// **'Left out of this estimate, not assumed.'**
  String get riskDetailNotAssumedSubtitleEstimate;

  /// No description provided for @commonRecordLabel.
  ///
  /// In en, this message translates to:
  /// **'Record'**
  String get commonRecordLabel;

  /// No description provided for @assessmentIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Assessment ID'**
  String get assessmentIdLabel;

  /// No description provided for @commonMadeLabel.
  ///
  /// In en, this message translates to:
  /// **'Made'**
  String get commonMadeLabel;

  /// No description provided for @commonRequestedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Requested by'**
  String get commonRequestedByLabel;

  /// No description provided for @commonModelVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'Model version'**
  String get commonModelVersionLabel;

  /// No description provided for @riskBandsLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk bands'**
  String get riskBandsLabel;

  /// No description provided for @riskPatternThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Risk pattern threshold'**
  String get riskPatternThresholdLabel;

  /// No description provided for @bmiCalculatedByModelLabel.
  ///
  /// In en, this message translates to:
  /// **'BMI (calculated by the model service)'**
  String get bmiCalculatedByModelLabel;

  /// No description provided for @valuesSentToModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Values sent to the model'**
  String get valuesSentToModelLabel;

  /// No description provided for @modelInputFieldsNote.
  ///
  /// In en, this message translates to:
  /// **'Only the model\'s own input fields; unknown values were left out.'**
  String get modelInputFieldsNote;

  /// No description provided for @commonTimeLabel.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get commonTimeLabel;

  /// No description provided for @commonModelLabel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get commonModelLabel;

  /// No description provided for @commonEnteredByLabel.
  ///
  /// In en, this message translates to:
  /// **'Entered by'**
  String get commonEnteredByLabel;

  /// No description provided for @modelInputsHeader.
  ///
  /// In en, this message translates to:
  /// **'Model inputs'**
  String get modelInputsHeader;

  /// No description provided for @sixteenAnswersNote.
  ///
  /// In en, this message translates to:
  /// **'All 16 answers exactly as sent to the earlier model.'**
  String get sixteenAnswersNote;

  /// No description provided for @aiInterpretationTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Interpretation'**
  String get aiInterpretationTitle;

  /// No description provided for @aiInterpretationEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Combine this assessment with your recent lifestyle and glucose data for a calm, forward-looking explanation. This is an AI interpretation, not a new prediction.'**
  String get aiInterpretationEmptyMessage;

  /// No description provided for @generateInterpretationButton.
  ///
  /// In en, this message translates to:
  /// **'Generate interpretation'**
  String get generateInterpretationButton;

  /// No description provided for @analyzingLifestylePatternsMessage.
  ///
  /// In en, this message translates to:
  /// **'Analyzing lifestyle patterns...'**
  String get analyzingLifestylePatternsMessage;

  /// No description provided for @assessmentResultSafeMessage.
  ///
  /// In en, this message translates to:
  /// **'Your assessment result is still saved and unchanged.'**
  String get assessmentResultSafeMessage;

  /// No description provided for @glucoseAverageReadings.
  ///
  /// In en, this message translates to:
  /// **'{avg} mg/dL average ({count} readings)'**
  String glucoseAverageReadings(String avg, String count);

  /// No description provided for @foodEntriesOverDays.
  ///
  /// In en, this message translates to:
  /// **'{count} entries over {days} days'**
  String foodEntriesOverDays(String count, String days);

  /// No description provided for @metricAverageDays.
  ///
  /// In en, this message translates to:
  /// **'{value} average ({days} days)'**
  String metricAverageDays(String value, String days);

  /// No description provided for @lifestyleSnapshotHeader.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle snapshot'**
  String get lifestyleSnapshotHeader;

  /// No description provided for @last7DaysBeforeAssessmentNote.
  ///
  /// In en, this message translates to:
  /// **'Recorded data from the 7 days before this assessment.'**
  String get last7DaysBeforeAssessmentNote;

  /// No description provided for @noLifestyleDataAtTime.
  ///
  /// In en, this message translates to:
  /// **'No lifestyle data was recorded at the time.'**
  String get noLifestyleDataAtTime;

  /// No description provided for @heartRiskScreeningTitle.
  ///
  /// In en, this message translates to:
  /// **'Heart risk screening'**
  String get heartRiskScreeningTitle;

  /// No description provided for @riskDetailDataUsedSubtitleScreening.
  ///
  /// In en, this message translates to:
  /// **'As recorded when this screening was made.'**
  String get riskDetailDataUsedSubtitleScreening;

  /// No description provided for @riskDetailNotAssumedSubtitleScreening.
  ///
  /// In en, this message translates to:
  /// **'Left out of this screening, not assumed.'**
  String get riskDetailNotAssumedSubtitleScreening;

  /// No description provided for @screeningIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Screening ID'**
  String get screeningIdLabel;

  /// No description provided for @decisionThresholdLabel.
  ///
  /// In en, this message translates to:
  /// **'Decision threshold'**
  String get decisionThresholdLabel;

  /// No description provided for @bmiCalculatedHeightWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'BMI (calculated from height and weight)'**
  String get bmiCalculatedHeightWeightLabel;

  /// No description provided for @mlScreeningResultLabel.
  ///
  /// In en, this message translates to:
  /// **'ML screening result'**
  String get mlScreeningResultLabel;

  /// No description provided for @modelClassificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Model classification'**
  String get modelClassificationLabel;

  /// No description provided for @assessedLabel.
  ///
  /// In en, this message translates to:
  /// **'Assessed'**
  String get assessedLabel;

  /// No description provided for @viewWhatThisMeansButton.
  ///
  /// In en, this message translates to:
  /// **'View What This Means'**
  String get viewWhatThisMeansButton;

  /// No description provided for @whatThisMeansHeader.
  ///
  /// In en, this message translates to:
  /// **'What this means'**
  String get whatThisMeansHeader;

  /// No description provided for @shareWithDoctorPositiveNote.
  ///
  /// In en, this message translates to:
  /// **'Consider sharing this result with a doctor. Tests such as fasting glucose or HbA1c are how diabetes is actually diagnosed.'**
  String get shareWithDoctorPositiveNote;

  /// No description provided for @doesNotRuleOutNote.
  ///
  /// In en, this message translates to:
  /// **'This does not rule out diabetes. If you have symptoms or concerns, talk to a doctor.'**
  String get doesNotRuleOutNote;

  /// No description provided for @commonImportantLabel.
  ///
  /// In en, this message translates to:
  /// **'Important'**
  String get commonImportantLabel;

  /// No description provided for @whatAssessmentMeansHeader.
  ///
  /// In en, this message translates to:
  /// **'What this assessment means'**
  String get whatAssessmentMeansHeader;

  /// No description provided for @whatModelDoesHeader.
  ///
  /// In en, this message translates to:
  /// **'What the model does'**
  String get whatModelDoesHeader;

  /// No description provided for @whatModelDoesText.
  ///
  /// In en, this message translates to:
  /// **'A trained machine-learning model (an RBF support vector machine) looks at your age, gender and 14 yes/no symptom answers and classifies whether they match a pattern associated with diabetes in the data it was trained on.'**
  String get whatModelDoesText;

  /// No description provided for @probabilityExplanationText.
  ///
  /// In en, this message translates to:
  /// **'The probability the model assigns to the Positive (diabetes-related pattern) class for the answers you gave. A low value goes with a Negative result. It is not the probability that you have or will develop diabetes.'**
  String get probabilityExplanationText;

  /// No description provided for @whatItCantTellHeader.
  ///
  /// In en, this message translates to:
  /// **'What it can\'t tell you'**
  String get whatItCantTellHeader;

  /// No description provided for @whatItCantTellText.
  ///
  /// In en, this message translates to:
  /// **'It is not a diagnosis, and it cannot predict whether or when you might develop diabetes. The training data doesn\'t include long-term follow-up, so no timeframe can be estimated.'**
  String get whatItCantTellText;

  /// No description provided for @whatToDoNextHeader.
  ///
  /// In en, this message translates to:
  /// **'What to do next'**
  String get whatToDoNextHeader;

  /// No description provided for @whatToDoNextText.
  ///
  /// In en, this message translates to:
  /// **'Share the result with your doctor, especially if it shows an elevated risk pattern or your symptoms continue. Tests such as fasting glucose or HbA1c are how diabetes is actually diagnosed.'**
  String get whatToDoNextText;

  /// No description provided for @seekCareIfUnwellNote.
  ///
  /// In en, this message translates to:
  /// **'If you feel very unwell, seek medical care promptly. SUSTHITI does not replace professional medical diagnosis, treatment, or emergency care.'**
  String get seekCareIfUnwellNote;

  /// No description provided for @diabetesRiskAssessmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Diabetes risk assessment'**
  String get diabetesRiskAssessmentTitle;

  /// No description provided for @commonReviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get commonReviewLabel;

  /// No description provided for @stepOfTotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}: {label}'**
  String stepOfTotalLabel(int step, int total, String label);

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// No description provided for @seeMyResultButton.
  ///
  /// In en, this message translates to:
  /// **'See my result'**
  String get seeMyResultButton;

  /// No description provided for @answersSavedToProfileNote.
  ///
  /// In en, this message translates to:
  /// **'Your answers are saved to your health profile, so you won\'t be asked again elsewhere.'**
  String get answersSavedToProfileNote;

  /// No description provided for @alsoUsedAutoHeader.
  ///
  /// In en, this message translates to:
  /// **'Also used, collected automatically'**
  String get alsoUsedAutoHeader;

  /// No description provided for @autoValuesExplanation.
  ///
  /// In en, this message translates to:
  /// **'Values read from your reports and data from your phone. To change a report value, open the report.'**
  String get autoValuesExplanation;

  /// No description provided for @noAutoDataYetMessage.
  ///
  /// In en, this message translates to:
  /// **'No report values or phone data yet. Upload a report with HbA1c or glucose results to include them.'**
  String get noAutoDataYetMessage;

  /// No description provided for @heartQuestionnaireIntro.
  ///
  /// In en, this message translates to:
  /// **'A few questions, already filled in with what SUSTHITI knows where possible; symptoms and test results are always answered fresh.'**
  String get heartQuestionnaireIntro;

  /// No description provided for @heartSectionBasicInfo.
  ///
  /// In en, this message translates to:
  /// **'A. Basic information'**
  String get heartSectionBasicInfo;

  /// No description provided for @heartSectionMedicalHistory.
  ///
  /// In en, this message translates to:
  /// **'B. Medical history'**
  String get heartSectionMedicalHistory;

  /// No description provided for @heartSectionSymptoms.
  ///
  /// In en, this message translates to:
  /// **'C. Symptoms'**
  String get heartSectionSymptoms;

  /// No description provided for @heartSectionVitals.
  ///
  /// In en, this message translates to:
  /// **'D. Vitals'**
  String get heartSectionVitals;

  /// No description provided for @heartSectionLabValues.
  ///
  /// In en, this message translates to:
  /// **'E. Laboratory values'**
  String get heartSectionLabValues;

  /// No description provided for @heartSectionCardiacTests.
  ///
  /// In en, this message translates to:
  /// **'F. Cardiac tests'**
  String get heartSectionCardiacTests;

  /// No description provided for @heartSectionLifestyle.
  ///
  /// In en, this message translates to:
  /// **'G. Lifestyle'**
  String get heartSectionLifestyle;

  /// No description provided for @numberBetweenError.
  ///
  /// In en, this message translates to:
  /// **'{label} must be a number between {min} and {max} {unit}.'**
  String numberBetweenError(String label, String min, String max, String unit);

  /// No description provided for @heartAnswersSavedNote.
  ///
  /// In en, this message translates to:
  /// **'Answers to medical history and lifestyle questions are saved to your health profile. Symptoms and test results are kept only with this screening.'**
  String get heartAnswersSavedNote;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @notAnsweredHint.
  ///
  /// In en, this message translates to:
  /// **'Not answered'**
  String get notAnsweredHint;

  /// No description provided for @fromYourRecordsLabel.
  ///
  /// In en, this message translates to:
  /// **'From your records: {value}{detail}'**
  String fromYourRecordsLabel(String value, String detail);

  /// No description provided for @notCurrentlyKnownLabel.
  ///
  /// In en, this message translates to:
  /// **'Not currently known'**
  String get notCurrentlyKnownLabel;

  /// No description provided for @leaveBlankToKeepHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to keep this'**
  String get leaveBlankToKeepHint;

  /// No description provided for @heartFieldChestPain.
  ///
  /// In en, this message translates to:
  /// **'Chest pain'**
  String get heartFieldChestPain;

  /// No description provided for @heartFieldChestPainType.
  ///
  /// In en, this message translates to:
  /// **'Chest pain type'**
  String get heartFieldChestPainType;

  /// No description provided for @heartOptionTypicalAngina.
  ///
  /// In en, this message translates to:
  /// **'Typical angina'**
  String get heartOptionTypicalAngina;

  /// No description provided for @heartOptionAtypicalAngina.
  ///
  /// In en, this message translates to:
  /// **'Atypical angina'**
  String get heartOptionAtypicalAngina;

  /// No description provided for @heartOptionNonAnginal.
  ///
  /// In en, this message translates to:
  /// **'Non-anginal'**
  String get heartOptionNonAnginal;

  /// No description provided for @heartFieldChestPainDuration.
  ///
  /// In en, this message translates to:
  /// **'Chest pain duration'**
  String get heartFieldChestPainDuration;

  /// No description provided for @heartFieldShortnessOfBreath.
  ///
  /// In en, this message translates to:
  /// **'Shortness of breath'**
  String get heartFieldShortnessOfBreath;

  /// No description provided for @heartFieldFatigue.
  ///
  /// In en, this message translates to:
  /// **'Fatigue'**
  String get heartFieldFatigue;

  /// No description provided for @heartFieldDizziness.
  ///
  /// In en, this message translates to:
  /// **'Dizziness'**
  String get heartFieldDizziness;

  /// No description provided for @heartFieldFainting.
  ///
  /// In en, this message translates to:
  /// **'Fainting'**
  String get heartFieldFainting;

  /// No description provided for @heartFieldSweating.
  ///
  /// In en, this message translates to:
  /// **'Sweating'**
  String get heartFieldSweating;

  /// No description provided for @heartFieldNausea.
  ///
  /// In en, this message translates to:
  /// **'Nausea'**
  String get heartFieldNausea;

  /// No description provided for @heartFieldPalpitations.
  ///
  /// In en, this message translates to:
  /// **'Palpitations'**
  String get heartFieldPalpitations;

  /// No description provided for @heartFieldLeftArmPain.
  ///
  /// In en, this message translates to:
  /// **'Left-arm pain'**
  String get heartFieldLeftArmPain;

  /// No description provided for @heartFieldJawNeckPain.
  ///
  /// In en, this message translates to:
  /// **'Jaw or neck pain'**
  String get heartFieldJawNeckPain;

  /// No description provided for @heartFieldBackPain.
  ///
  /// In en, this message translates to:
  /// **'Back pain'**
  String get heartFieldBackPain;

  /// No description provided for @heartFieldRestingEcg.
  ///
  /// In en, this message translates to:
  /// **'Resting ECG'**
  String get heartFieldRestingEcg;

  /// No description provided for @heartOptionNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get heartOptionNormal;

  /// No description provided for @heartOptionNormalVariant.
  ///
  /// In en, this message translates to:
  /// **'Normal variant'**
  String get heartOptionNormalVariant;

  /// No description provided for @heartOptionStTAbnormality.
  ///
  /// In en, this message translates to:
  /// **'ST-T abnormality'**
  String get heartOptionStTAbnormality;

  /// No description provided for @heartOptionOldInfarctPattern.
  ///
  /// In en, this message translates to:
  /// **'Old infarct pattern'**
  String get heartOptionOldInfarctPattern;

  /// No description provided for @heartOptionLvh.
  ///
  /// In en, this message translates to:
  /// **'Left ventricular hypertrophy (LVH)'**
  String get heartOptionLvh;

  /// No description provided for @heartFieldEcgAbnormality.
  ///
  /// In en, this message translates to:
  /// **'ECG abnormality'**
  String get heartFieldEcgAbnormality;

  /// No description provided for @heartFieldStDepression.
  ///
  /// In en, this message translates to:
  /// **'ST depression'**
  String get heartFieldStDepression;

  /// No description provided for @heartFieldExerciseAngina.
  ///
  /// In en, this message translates to:
  /// **'Exercise-induced angina'**
  String get heartFieldExerciseAngina;

  /// No description provided for @heartFieldMaxHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Maximum heart rate (exercise)'**
  String get heartFieldMaxHeartRate;

  /// No description provided for @heartFieldExerciseDuration.
  ///
  /// In en, this message translates to:
  /// **'Exercise duration'**
  String get heartFieldExerciseDuration;

  /// No description provided for @heartFieldStressTestResult.
  ///
  /// In en, this message translates to:
  /// **'Stress test result'**
  String get heartFieldStressTestResult;

  /// No description provided for @heartOptionNegative.
  ///
  /// In en, this message translates to:
  /// **'Negative'**
  String get heartOptionNegative;

  /// No description provided for @heartOptionBorderline.
  ///
  /// In en, this message translates to:
  /// **'Borderline'**
  String get heartOptionBorderline;

  /// No description provided for @heartOptionPositive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get heartOptionPositive;

  /// No description provided for @heartFieldEchoResult.
  ///
  /// In en, this message translates to:
  /// **'Echocardiogram result'**
  String get heartFieldEchoResult;

  /// No description provided for @heartOptionMildAbnormality.
  ///
  /// In en, this message translates to:
  /// **'Mild abnormality'**
  String get heartOptionMildAbnormality;

  /// No description provided for @heartOptionSignificantAbnormality.
  ///
  /// In en, this message translates to:
  /// **'Significant abnormality'**
  String get heartOptionSignificantAbnormality;

  /// No description provided for @heartFieldEjectionFraction.
  ///
  /// In en, this message translates to:
  /// **'Ejection fraction'**
  String get heartFieldEjectionFraction;

  /// No description provided for @heartFieldWallMotionAbnormality.
  ///
  /// In en, this message translates to:
  /// **'Heart wall motion abnormality'**
  String get heartFieldWallMotionAbnormality;

  /// No description provided for @heartFieldPreviousAbnormalTest.
  ///
  /// In en, this message translates to:
  /// **'Previous abnormal cardiac test'**
  String get heartFieldPreviousAbnormalTest;

  /// No description provided for @heartHelpDiabetes.
  ///
  /// In en, this message translates to:
  /// **'A doctor has diagnosed you with diabetes.'**
  String get heartHelpDiabetes;

  /// No description provided for @heartFieldRespiratoryRate.
  ///
  /// In en, this message translates to:
  /// **'Respiratory rate'**
  String get heartFieldRespiratoryRate;

  /// No description provided for @heartFieldStressLevel.
  ///
  /// In en, this message translates to:
  /// **'Stress level (0 = none, 10 = severe)'**
  String get heartFieldStressLevel;

  /// No description provided for @heartFieldRestingHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Resting heart rate'**
  String get heartFieldRestingHeartRate;

  /// No description provided for @heartFieldSystolicBp.
  ///
  /// In en, this message translates to:
  /// **'Systolic blood pressure'**
  String get heartFieldSystolicBp;

  /// No description provided for @heartFieldDiastolicBp.
  ///
  /// In en, this message translates to:
  /// **'Diastolic blood pressure'**
  String get heartFieldDiastolicBp;

  /// No description provided for @heartFieldOxygenSaturation.
  ///
  /// In en, this message translates to:
  /// **'Oxygen saturation'**
  String get heartFieldOxygenSaturation;

  /// No description provided for @heartFieldFastingGlucose.
  ///
  /// In en, this message translates to:
  /// **'Fasting glucose'**
  String get heartFieldFastingGlucose;

  /// No description provided for @heartFieldRandomGlucose.
  ///
  /// In en, this message translates to:
  /// **'Random glucose'**
  String get heartFieldRandomGlucose;

  /// No description provided for @heartFieldTotalCholesterol.
  ///
  /// In en, this message translates to:
  /// **'Total cholesterol'**
  String get heartFieldTotalCholesterol;

  /// No description provided for @heartFieldLdl.
  ///
  /// In en, this message translates to:
  /// **'LDL cholesterol'**
  String get heartFieldLdl;

  /// No description provided for @heartFieldHdl.
  ///
  /// In en, this message translates to:
  /// **'HDL cholesterol'**
  String get heartFieldHdl;

  /// No description provided for @heartFieldTriglycerides.
  ///
  /// In en, this message translates to:
  /// **'Triglycerides'**
  String get heartFieldTriglycerides;

  /// No description provided for @heartFieldTroponin.
  ///
  /// In en, this message translates to:
  /// **'Troponin'**
  String get heartFieldTroponin;

  /// No description provided for @heartFieldHemoglobin.
  ///
  /// In en, this message translates to:
  /// **'Hemoglobin'**
  String get heartFieldHemoglobin;

  /// No description provided for @heartFieldCreatinine.
  ///
  /// In en, this message translates to:
  /// **'Creatinine'**
  String get heartFieldCreatinine;

  /// No description provided for @heartFieldSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get heartFieldSleep;

  /// No description provided for @heartUnitHoursANight.
  ///
  /// In en, this message translates to:
  /// **'h a night'**
  String get heartUnitHoursANight;

  /// No description provided for @healthProfileIntroText.
  ///
  /// In en, this message translates to:
  /// **'SUSTHITI keeps these answers once and uses them wherever they are needed, including your future diabetes risk estimate. Answer what you know; \"Not sure\" is always fine and is never treated as \"No\".'**
  String get healthProfileIntroText;

  /// No description provided for @healthProfileSavedToast.
  ///
  /// In en, this message translates to:
  /// **'Health profile saved.'**
  String get healthProfileSavedToast;

  /// No description provided for @saveHealthProfileButton.
  ///
  /// In en, this message translates to:
  /// **'Save health profile'**
  String get saveHealthProfileButton;

  /// No description provided for @heightLabel.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get heightLabel;

  /// No description provided for @weightLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weightLabel;

  /// No description provided for @bmiLabel.
  ///
  /// In en, this message translates to:
  /// **'BMI'**
  String get bmiLabel;

  /// No description provided for @needsHeightWeightLabel.
  ///
  /// In en, this message translates to:
  /// **'Needs height and weight'**
  String get needsHeightWeightLabel;

  /// No description provided for @bmiAutoCalculatedNote.
  ///
  /// In en, this message translates to:
  /// **'BMI is calculated automatically from height and weight.'**
  String get bmiAutoCalculatedNote;

  /// No description provided for @addHeightWeightButton.
  ///
  /// In en, this message translates to:
  /// **'Add height and weight'**
  String get addHeightWeightButton;

  /// No description provided for @updateHeightWeightButton.
  ///
  /// In en, this message translates to:
  /// **'Update height or weight'**
  String get updateHeightWeightButton;

  /// No description provided for @profileIntroBody.
  ///
  /// In en, this message translates to:
  /// **'Used to calculate BMI and for health risk estimates.'**
  String get profileIntroBody;

  /// No description provided for @profileIntroMedicalHistory.
  ///
  /// In en, this message translates to:
  /// **'Conditions a doctor has diagnosed. Choose \"Not sure\" if you don\'t know.'**
  String get profileIntroMedicalHistory;

  /// No description provided for @profileIntroFamilyHistory.
  ///
  /// In en, this message translates to:
  /// **'Your parents, brothers and sisters.'**
  String get profileIntroFamilyHistory;

  /// No description provided for @profileIntroHabits.
  ///
  /// In en, this message translates to:
  /// **'Your usual habits. Physical activity is taken from your phone\'s step count when enough is recorded.'**
  String get profileIntroHabits;

  /// No description provided for @profileIntroSymptoms.
  ///
  /// In en, this message translates to:
  /// **'In the last few weeks, have you noticed any of these? Answers are used for 90 days.'**
  String get profileIntroSymptoms;

  /// No description provided for @listItemTooLongError.
  ///
  /// In en, this message translates to:
  /// **'{label}: each item must be 200 characters or fewer.'**
  String listItemTooLongError(String label);

  /// No description provided for @listTooManyItemsError.
  ///
  /// In en, this message translates to:
  /// **'{label}: list up to 20 items.'**
  String listTooManyItemsError(String label);

  /// No description provided for @notSureOption.
  ///
  /// In en, this message translates to:
  /// **'Not sure'**
  String get notSureOption;

  /// No description provided for @answeredByLabel.
  ///
  /// In en, this message translates to:
  /// **'Answered {date} by {who}'**
  String answeredByLabel(String date, String who);

  /// No description provided for @yourDoctorLabel.
  ///
  /// In en, this message translates to:
  /// **'your doctor'**
  String get yourDoctorLabel;

  /// No description provided for @notAnsweredYetLabel.
  ///
  /// In en, this message translates to:
  /// **'Not answered yet'**
  String get notAnsweredYetLabel;

  /// No description provided for @confirmStillCorrectCaption.
  ///
  /// In en, this message translates to:
  /// **'{caption}. Please confirm it is still correct.'**
  String confirmStillCorrectCaption(String caption);

  /// No description provided for @stillCorrectButton.
  ///
  /// In en, this message translates to:
  /// **'Still correct'**
  String get stillCorrectButton;

  /// No description provided for @notRecordedListHint.
  ///
  /// In en, this message translates to:
  /// **'Not recorded — separate multiple entries with a comma or a new line'**
  String get notRecordedListHint;

  /// No description provided for @qrScanPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan Patient QR'**
  String get qrScanPageTitle;

  /// No description provided for @qrCameraUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get qrCameraUnavailableTitle;

  /// No description provided for @qrCameraUnavailableMessage.
  ///
  /// In en, this message translates to:
  /// **'SUSTHITI needs camera access to scan a QR code. You can still use \"Add Patient\" to enter the details manually.'**
  String get qrCameraUnavailableMessage;

  /// No description provided for @qrPointCameraHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the patient\'s QR code'**
  String get qrPointCameraHint;

  /// No description provided for @qrRequestSentTitle.
  ///
  /// In en, this message translates to:
  /// **'Request sent'**
  String get qrRequestSentTitle;

  /// No description provided for @qrRequestSentMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} ({code}) will be asked to approve your request. You will be notified when they respond.'**
  String qrRequestSentMessage(String name, String code);

  /// No description provided for @qrViewRequestsButton.
  ///
  /// In en, this message translates to:
  /// **'View requests'**
  String get qrViewRequestsButton;

  /// No description provided for @qrScanAnotherButton.
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get qrScanAnotherButton;

  /// No description provided for @qrScanAgainButton.
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get qrScanAgainButton;

  /// No description provided for @qrPatientIdentityHeader.
  ///
  /// In en, this message translates to:
  /// **'Patient identity'**
  String get qrPatientIdentityHeader;

  /// No description provided for @qrConfirmPatientNote.
  ///
  /// In en, this message translates to:
  /// **'Confirm this is the right patient before requesting access. They must still approve it.'**
  String get qrConfirmPatientNote;

  /// No description provided for @wearDevicesPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected Devices'**
  String get wearDevicesPageTitle;

  /// No description provided for @wearHealthSourcesHeader.
  ///
  /// In en, this message translates to:
  /// **'Health data sources'**
  String get wearHealthSourcesHeader;

  /// No description provided for @wearHealthSourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Synced data is stored in your SUSTHITI record, so it is the same on your phone, tablet and the web.'**
  String get wearHealthSourcesSubtitle;

  /// No description provided for @wearNoDeviceTitle.
  ///
  /// In en, this message translates to:
  /// **'No health device connected.'**
  String get wearNoDeviceTitle;

  /// No description provided for @wearNoDeviceBody.
  ///
  /// In en, this message translates to:
  /// **'Connect a supported health platform to automatically sync your lifestyle data.'**
  String get wearNoDeviceBody;

  /// No description provided for @wearDisconnectNote.
  ///
  /// In en, this message translates to:
  /// **'Disconnecting stops new data from syncing. Data already synced stays in your history. To change what SUSTHITI may read, use Health Connect (Android) or Settings, then Health (iPhone).'**
  String get wearDisconnectNote;

  /// No description provided for @wearSyncFailedPermissions.
  ///
  /// In en, this message translates to:
  /// **'Sync didn\'t complete. Check your health permissions and try again.'**
  String get wearSyncFailedPermissions;

  /// No description provided for @wearDisconnectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect health data?'**
  String get wearDisconnectConfirmTitle;

  /// No description provided for @wearDisconnectConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'SUSTHITI will stop syncing new health data from this source.\n\nPreviously synchronized records will remain available according to your data-retention settings.'**
  String get wearDisconnectConfirmMessage;

  /// No description provided for @wearDisconnectButton.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get wearDisconnectButton;

  /// No description provided for @wearDisconnectedToast.
  ///
  /// In en, this message translates to:
  /// **'Disconnected. Your synced history is kept.'**
  String get wearDisconnectedToast;

  /// No description provided for @wearAndroidPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Android phone'**
  String get wearAndroidPhoneLabel;

  /// No description provided for @wearIphoneLabel.
  ///
  /// In en, this message translates to:
  /// **'iPhone'**
  String get wearIphoneLabel;

  /// No description provided for @wearFromPlatformFragment.
  ///
  /// In en, this message translates to:
  /// **'from your {platform}'**
  String wearFromPlatformFragment(String platform);

  /// No description provided for @wearConnectedDateNote.
  ///
  /// In en, this message translates to:
  /// **'connected {date}'**
  String wearConnectedDateNote(String date);

  /// No description provided for @wearSyncUnavailablePill.
  ///
  /// In en, this message translates to:
  /// **'Sync unavailable'**
  String get wearSyncUnavailablePill;

  /// No description provided for @wearConnectedPill.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get wearConnectedPill;

  /// No description provided for @wearPermissionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Permissions'**
  String get wearPermissionsLabel;

  /// No description provided for @wearRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get wearRetryButton;

  /// No description provided for @wearSyncNowButton.
  ///
  /// In en, this message translates to:
  /// **'Sync Now'**
  String get wearSyncNowButton;

  /// No description provided for @wearSyncsFromPhoneNote.
  ///
  /// In en, this message translates to:
  /// **'Syncs from your {platform}. Open SUSTHITI there to sync.'**
  String wearSyncsFromPhoneNote(String platform);

  /// No description provided for @wearGenericPhoneLabel.
  ///
  /// In en, this message translates to:
  /// **'phone'**
  String get wearGenericPhoneLabel;

  /// No description provided for @wearPermissionShared.
  ///
  /// In en, this message translates to:
  /// **'shared'**
  String get wearPermissionShared;

  /// No description provided for @wearPermissionNotShared.
  ///
  /// In en, this message translates to:
  /// **'not shared'**
  String get wearPermissionNotShared;

  /// No description provided for @wearDemoTryTitle.
  ///
  /// In en, this message translates to:
  /// **'Try with DEMO data'**
  String get wearDemoTryTitle;

  /// No description provided for @wearDemoNote.
  ///
  /// In en, this message translates to:
  /// **'Development only. Adds clearly labelled demo values; never real health data.'**
  String get wearDemoNote;

  /// No description provided for @wearNotSyncedYet.
  ///
  /// In en, this message translates to:
  /// **'Not synced yet'**
  String get wearNotSyncedYet;

  /// No description provided for @wearLastSyncedAt.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String wearLastSyncedAt(String time);

  /// No description provided for @wearConnectTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect your health data'**
  String get wearConnectTitle;

  /// No description provided for @wearConnectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sync steps, heart rate, sleep and more from {platform}.'**
  String wearConnectSubtitle(String platform);

  /// No description provided for @wearConnectButton.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get wearConnectButton;

  /// No description provided for @wearSyncingTitle.
  ///
  /// In en, this message translates to:
  /// **'Syncing health data...'**
  String get wearSyncingTitle;

  /// No description provided for @wearReadingDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Reading new data from {platform}.'**
  String wearReadingDataSubtitle(String platform);

  /// No description provided for @wearConnectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Health data connected'**
  String get wearConnectedTitle;

  /// No description provided for @wearLastSyncIncomplete.
  ///
  /// In en, this message translates to:
  /// **'The last sync did not complete.'**
  String get wearLastSyncIncomplete;

  /// No description provided for @wearNotConnectedReadOnlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Health data not connected'**
  String get wearNotConnectedReadOnlyTitle;

  /// No description provided for @wearConnectFromMobileNote.
  ///
  /// In en, this message translates to:
  /// **'Connect health data from the SUSTHITI mobile app (Lifestyle, then Connect). It will appear here automatically.'**
  String get wearConnectFromMobileNote;

  /// No description provided for @wearHealthDataLabel.
  ///
  /// In en, this message translates to:
  /// **'Health data'**
  String get wearHealthDataLabel;

  /// No description provided for @wearApplePlatformLabel.
  ///
  /// In en, this message translates to:
  /// **'Apple Health on iPhone'**
  String get wearApplePlatformLabel;

  /// No description provided for @wearAndroidPlatformLabel.
  ///
  /// In en, this message translates to:
  /// **'Health Connect on Android'**
  String get wearAndroidPlatformLabel;

  /// No description provided for @wearGenericMobilePlatformLabel.
  ///
  /// In en, this message translates to:
  /// **'the mobile health platform'**
  String get wearGenericMobilePlatformLabel;

  /// No description provided for @wearConnectedThroughNote.
  ///
  /// In en, this message translates to:
  /// **'Connected through {platform}'**
  String wearConnectedThroughNote(String platform);

  /// No description provided for @wearRefreshButton.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get wearRefreshButton;

  /// No description provided for @wearManageDevicesButton.
  ///
  /// In en, this message translates to:
  /// **'Manage connected devices'**
  String get wearManageDevicesButton;

  /// No description provided for @wearOfflineLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get wearOfflineLabel;

  /// No description provided for @wearTapToSyncHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to sync.'**
  String get wearTapToSyncHint;

  /// No description provided for @wearNoneConnectedSummary.
  ///
  /// In en, this message translates to:
  /// **'No health platform connected. Values shown were entered manually.'**
  String get wearNoneConnectedSummary;

  /// No description provided for @wearConnectPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect Health Data'**
  String get wearConnectPageTitle;

  /// No description provided for @wearDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Health data access wasn\'t enabled.'**
  String get wearDeniedTitle;

  /// No description provided for @wearDeniedBodyIos.
  ///
  /// In en, this message translates to:
  /// **'You can enable it later from Connected Devices. On iPhone: open Settings, then Health, Data Access & Devices, SUSTHITI, and turn on the data you want to share.'**
  String get wearDeniedBodyIos;

  /// No description provided for @wearDeniedBodyOther.
  ///
  /// In en, this message translates to:
  /// **'You can enable it later from Connected Devices.'**
  String get wearDeniedBodyOther;

  /// No description provided for @wearOpenHealthConnectButton.
  ///
  /// In en, this message translates to:
  /// **'Open Health Connect'**
  String get wearOpenHealthConnectButton;

  /// No description provided for @wearNotNowButton.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get wearNotNowButton;

  /// No description provided for @wearNeedsInstallTitle.
  ///
  /// In en, this message translates to:
  /// **'Health Connect is needed'**
  String get wearNeedsInstallTitle;

  /// No description provided for @wearNeedsInstallBody.
  ///
  /// In en, this message translates to:
  /// **'Android keeps health data from your watch and fitness apps in Health Connect. Install or update it, then come back and continue.'**
  String get wearNeedsInstallBody;

  /// No description provided for @wearInstallButton.
  ///
  /// In en, this message translates to:
  /// **'Install Health Connect'**
  String get wearInstallButton;

  /// No description provided for @wearUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Connect from your phone'**
  String get wearUnavailableTitle;

  /// No description provided for @wearUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Browsers and computers cannot read health data directly. Open SUSTHITI on your Android phone or iPhone and go to Lifestyle, then Connect. Your synced data then appears here automatically.'**
  String get wearUnavailableBody;

  /// No description provided for @wearFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t connect your health data.'**
  String get wearFailedTitle;

  /// No description provided for @wearFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Please check:\n• Health permissions\n• Device connection\n• Internet connection'**
  String get wearFailedBody;

  /// No description provided for @wearExplainSubtitle.
  ///
  /// In en, this message translates to:
  /// **'SUSTHITI can use health information from {platform} to show your lifestyle trends.'**
  String wearExplainSubtitle(String platform);

  /// No description provided for @wearDataMayIncludeHeader.
  ///
  /// In en, this message translates to:
  /// **'Data may include'**
  String get wearDataMayIncludeHeader;

  /// No description provided for @wearExerciseMinutesNote.
  ///
  /// In en, this message translates to:
  /// **' (exercise minutes)'**
  String get wearExerciseMinutesNote;

  /// No description provided for @wearWhereSupportedNote.
  ///
  /// In en, this message translates to:
  /// **' where supported'**
  String get wearWhereSupportedNote;

  /// No description provided for @wearPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'SUSTHITI only reads this data; it never writes to your health platform. You choose what to share on the next screen and can change it any time. Your doctor sees it only while you have approved their access. Not every watch records blood pressure or SpO₂; SUSTHITI only shows what your device provides.'**
  String get wearPrivacyNote;

  /// No description provided for @wearContinueButton.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get wearContinueButton;

  /// No description provided for @wearConnectingTitle.
  ///
  /// In en, this message translates to:
  /// **'Connecting...'**
  String get wearConnectingTitle;

  /// No description provided for @wearConnectingBody.
  ///
  /// In en, this message translates to:
  /// **'Reading your recent health data for the first sync.'**
  String get wearConnectingBody;

  /// No description provided for @wearSuccessHeadline.
  ///
  /// In en, this message translates to:
  /// **'Health Data Connected'**
  String get wearSuccessHeadline;

  /// No description provided for @wearSuccessSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your health data is now connected to SUSTHITI.'**
  String get wearSuccessSubtitle;

  /// No description provided for @wearSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get wearSourceLabel;

  /// No description provided for @wearLastSyncLabel.
  ///
  /// In en, this message translates to:
  /// **'Last synchronization'**
  String get wearLastSyncLabel;

  /// No description provided for @wearJustNowValue.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get wearJustNowValue;

  /// No description provided for @wearMeasurementsAddedLabel.
  ///
  /// In en, this message translates to:
  /// **'Measurements added'**
  String get wearMeasurementsAddedLabel;

  /// No description provided for @wearSharingLabel.
  ///
  /// In en, this message translates to:
  /// **'Sharing'**
  String get wearSharingLabel;

  /// No description provided for @wearNoRecentDataNote.
  ///
  /// In en, this message translates to:
  /// **'No recent data was found yet. New readings from your watch will sync automatically when you open SUSTHITI.'**
  String get wearNoRecentDataNote;

  /// No description provided for @wearViewDashboardButton.
  ///
  /// In en, this message translates to:
  /// **'View Lifestyle Dashboard'**
  String get wearViewDashboardButton;

  /// No description provided for @accessPatientPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Doctor Access'**
  String get accessPatientPageTitle;

  /// No description provided for @accessAdminPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Access Review'**
  String get accessAdminPageTitle;

  /// No description provided for @accessPatientIntro.
  ///
  /// In en, this message translates to:
  /// **'Doctors can only see your records after you approve them. You can revoke access at any time.'**
  String get accessPatientIntro;

  /// No description provided for @accessAllFilterLabel.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get accessAllFilterLabel;

  /// No description provided for @accessNoRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'No access requests.'**
  String get accessNoRequestsTitle;

  /// No description provided for @accessNoStatusRequestsTitle.
  ///
  /// In en, this message translates to:
  /// **'No {status} requests.'**
  String accessNoStatusRequestsTitle(String status);

  /// No description provided for @accessPatientEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'When a doctor requests access using your name and Patient ID, it will appear here.'**
  String get accessPatientEmptyHint;

  /// No description provided for @accessRejectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject request?'**
  String get accessRejectConfirmTitle;

  /// No description provided for @accessRevokeConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke access?'**
  String get accessRevokeConfirmTitle;

  /// No description provided for @accessRejectConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Dr. {doctor} will not be able to see your records.'**
  String accessRejectConfirmMessage(String doctor);

  /// No description provided for @accessRevokeConfirmMessageAdmin.
  ///
  /// In en, this message translates to:
  /// **'Dr. {doctor} will immediately lose access to {patient}\'s records. The patient and doctor are notified.'**
  String accessRevokeConfirmMessageAdmin(String doctor, String patient);

  /// No description provided for @accessRevokeConfirmMessagePatient.
  ///
  /// In en, this message translates to:
  /// **'Dr. {doctor} will immediately lose access to your records. Records they created stay in your history.'**
  String accessRevokeConfirmMessagePatient(String doctor);

  /// No description provided for @accessRejectButton.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get accessRejectButton;

  /// No description provided for @accessRevokeButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get accessRevokeButton;

  /// No description provided for @accessApprovedToast.
  ///
  /// In en, this message translates to:
  /// **'Access approved'**
  String get accessApprovedToast;

  /// No description provided for @accessRejectedToast.
  ///
  /// In en, this message translates to:
  /// **'Request rejected'**
  String get accessRejectedToast;

  /// No description provided for @accessRevokedToast.
  ///
  /// In en, this message translates to:
  /// **'Access revoked'**
  String get accessRevokedToast;

  /// No description provided for @accessDoctorNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor: {name}'**
  String accessDoctorNameLabel(String name);

  /// No description provided for @accessPatientNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient: {name}'**
  String accessPatientNameLabel(String name);

  /// No description provided for @accessPatientIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Patient ID: {id}'**
  String accessPatientIdLabel(String id);

  /// No description provided for @accessDoctorIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor ID: {id}'**
  String accessDoctorIdLabel(String id);

  /// No description provided for @accessSpecializationLabel.
  ///
  /// In en, this message translates to:
  /// **'Specialization: {specialization}'**
  String accessSpecializationLabel(String specialization);

  /// No description provided for @accessPatientNameCode.
  ///
  /// In en, this message translates to:
  /// **'Patient: {name} · {code}'**
  String accessPatientNameCode(String name, String code);

  /// No description provided for @accessRequestedOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Requested {date}'**
  String accessRequestedOnLabel(String date);

  /// No description provided for @accessApproveButton.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get accessApproveButton;

  /// No description provided for @accessRevokeAccessButton.
  ///
  /// In en, this message translates to:
  /// **'Revoke access'**
  String get accessRevokeAccessButton;

  /// No description provided for @aiPatientSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'AI Patient Summary'**
  String get aiPatientSummaryTitle;

  /// No description provided for @aiPatientSummaryLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Reviewing assessments, reports, glucose, lifestyle and care history...'**
  String get aiPatientSummaryLoadingMessage;

  /// No description provided for @aiPatientSummaryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'No patient summary yet. Generate one to see an overview of the recorded history.'**
  String get aiPatientSummaryEmptyMessage;

  /// No description provided for @aiGeneratePatientSummaryButton.
  ///
  /// In en, this message translates to:
  /// **'Generate Patient Summary'**
  String get aiGeneratePatientSummaryButton;

  /// No description provided for @aiOriginalRecordsUnchangedNote.
  ///
  /// In en, this message translates to:
  /// **'All original records are unchanged and still available.'**
  String get aiOriginalRecordsUnchangedNote;

  /// No description provided for @aiYourHealthSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Your Health Summary'**
  String get aiYourHealthSummaryTitle;

  /// No description provided for @aiHealthSummaryLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Looking at your recorded health information...'**
  String get aiHealthSummaryLoadingMessage;

  /// No description provided for @aiHealthSummaryEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Get a short summary of your recorded health information, in plain language.'**
  String get aiHealthSummaryEmptyMessage;

  /// No description provided for @aiGenerateSummaryButton.
  ///
  /// In en, this message translates to:
  /// **'Generate Summary'**
  String get aiGenerateSummaryButton;

  /// No description provided for @aiYourRecordsUnchangedNote.
  ///
  /// In en, this message translates to:
  /// **'Your original records are unchanged and still available.'**
  String get aiYourRecordsUnchangedNote;

  /// No description provided for @aiLifestyleInsightTitle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle Insight'**
  String get aiLifestyleInsightTitle;

  /// No description provided for @aiLifestyleLoadingMessage.
  ///
  /// In en, this message translates to:
  /// **'Looking at your recent activity, sleep, food and glucose...'**
  String get aiLifestyleLoadingMessage;

  /// No description provided for @aiLifestyleEmptyMessage.
  ///
  /// In en, this message translates to:
  /// **'Get gentle, practical suggestions based on what you have recorded.'**
  String get aiLifestyleEmptyMessage;

  /// No description provided for @aiGenerateInsightButton.
  ///
  /// In en, this message translates to:
  /// **'Generate Insight'**
  String get aiGenerateInsightButton;

  /// No description provided for @aiLifestyleUnchangedNote.
  ///
  /// In en, this message translates to:
  /// **'Your recorded lifestyle data is unchanged.'**
  String get aiLifestyleUnchangedNote;

  /// No description provided for @aiDefaultFailureReassurance.
  ///
  /// In en, this message translates to:
  /// **'Your original medical information is still available.'**
  String get aiDefaultFailureReassurance;

  /// No description provided for @aiAdminCannotGenerateNote.
  ///
  /// In en, this message translates to:
  /// **'No AI summary has been generated for this record. Administrators can view AI summaries but cannot generate them.'**
  String get aiAdminCannotGenerateNote;

  /// No description provided for @aiNotConfiguredMessage.
  ///
  /// In en, this message translates to:
  /// **'AI features are not set up on this server yet.'**
  String get aiNotConfiguredMessage;

  /// No description provided for @aiGenerateFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t generate the summary right now.'**
  String get aiGenerateFailedMessage;

  /// No description provided for @aiStaleSummaryNote.
  ///
  /// In en, this message translates to:
  /// **'New information has been added since this summary was generated. It may no longer reflect the current records.'**
  String get aiStaleSummaryNote;

  /// No description provided for @aiGeneratedOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Generated {date}'**
  String aiGeneratedOnLabel(String date);

  /// No description provided for @aiGeneratedByRole.
  ///
  /// In en, this message translates to:
  /// **'by {role}'**
  String aiGeneratedByRole(String role);

  /// No description provided for @aiBasedOnLabel.
  ///
  /// In en, this message translates to:
  /// **'Based on: {items}'**
  String aiBasedOnLabel(String items);

  /// No description provided for @aiModelLabel.
  ///
  /// In en, this message translates to:
  /// **'AI model: {model}'**
  String aiModelLabel(String model);

  /// No description provided for @aiRegenerateButton.
  ///
  /// In en, this message translates to:
  /// **'Regenerate'**
  String get aiRegenerateButton;

  /// No description provided for @aiHideDetailsButton.
  ///
  /// In en, this message translates to:
  /// **'Hide details'**
  String get aiHideDetailsButton;

  /// No description provided for @aiKeyFindingsLabel.
  ///
  /// In en, this message translates to:
  /// **'Key findings'**
  String get aiKeyFindingsLabel;

  /// No description provided for @aiRelevantValuesLabel.
  ///
  /// In en, this message translates to:
  /// **'Relevant values'**
  String get aiRelevantValuesLabel;

  /// No description provided for @aiReportInformationLabel.
  ///
  /// In en, this message translates to:
  /// **'Report information'**
  String get aiReportInformationLabel;

  /// No description provided for @aiObservedWithinReportLabel.
  ///
  /// In en, this message translates to:
  /// **'Observed within this report'**
  String get aiObservedWithinReportLabel;

  /// No description provided for @aiQuestionsToDiscussLabel.
  ///
  /// In en, this message translates to:
  /// **'Questions to discuss'**
  String get aiQuestionsToDiscussLabel;

  /// No description provided for @aiLimitationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Limitations'**
  String get aiLimitationsLabel;

  /// No description provided for @aiNotEnoughInfoLabel.
  ///
  /// In en, this message translates to:
  /// **'Not enough information to compare'**
  String get aiNotEnoughInfoLabel;

  /// No description provided for @aiAttentionLabel.
  ///
  /// In en, this message translates to:
  /// **'Attention'**
  String get aiAttentionLabel;

  /// No description provided for @aiRecentChangesLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent changes'**
  String get aiRecentChangesLabel;

  /// No description provided for @aiDiabetesHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Diabetes History'**
  String get aiDiabetesHistoryLabel;

  /// No description provided for @aiRecentAssessmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent Assessments'**
  String get aiRecentAssessmentsLabel;

  /// No description provided for @aiMedicalReportsLabel.
  ///
  /// In en, this message translates to:
  /// **'Medical Reports'**
  String get aiMedicalReportsLabel;

  /// No description provided for @aiGlucoseHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Glucose History'**
  String get aiGlucoseHistoryLabel;

  /// No description provided for @aiLifestyleTrendsLabel.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle Trends'**
  String get aiLifestyleTrendsLabel;

  /// No description provided for @aiMedicationHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Medication / Prescription History'**
  String get aiMedicationHistoryLabel;

  /// No description provided for @aiSideEffectsLabel.
  ///
  /// In en, this message translates to:
  /// **'Side Effects'**
  String get aiSideEffectsLabel;

  /// No description provided for @aiDoctorVisitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Doctor Visits'**
  String get aiDoctorVisitsLabel;

  /// No description provided for @aiRecentDevelopmentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent Developments'**
  String get aiRecentDevelopmentsLabel;

  /// No description provided for @aiHeartHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Heart History'**
  String get aiHeartHistoryLabel;

  /// No description provided for @aiWhatStandsOutLabel.
  ///
  /// In en, this message translates to:
  /// **'What stands out'**
  String get aiWhatStandsOutLabel;

  /// No description provided for @aiWhatHasChangedLabel.
  ///
  /// In en, this message translates to:
  /// **'What has changed'**
  String get aiWhatHasChangedLabel;

  /// No description provided for @aiKeepInMindLabel.
  ///
  /// In en, this message translates to:
  /// **'What to keep in mind'**
  String get aiKeepInMindLabel;

  /// No description provided for @aiDiscussWithDoctorLabel.
  ///
  /// In en, this message translates to:
  /// **'What to discuss with your doctor'**
  String get aiDiscussWithDoctorLabel;

  /// No description provided for @aiObservationsLabel.
  ///
  /// In en, this message translates to:
  /// **'Observations'**
  String get aiObservationsLabel;

  /// No description provided for @aiSuggestionsWithAiPrefixLabel.
  ///
  /// In en, this message translates to:
  /// **'AI Suggestions'**
  String get aiSuggestionsWithAiPrefixLabel;

  /// No description provided for @aiSuggestionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get aiSuggestionsLabel;

  /// No description provided for @aiPatternsConsideredLabel.
  ///
  /// In en, this message translates to:
  /// **'Patterns considered'**
  String get aiPatternsConsideredLabel;

  /// No description provided for @aiInterpretationHeading.
  ///
  /// In en, this message translates to:
  /// **'AI interpretation'**
  String get aiInterpretationHeading;

  /// No description provided for @aiReferenceRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Reference {range}'**
  String aiReferenceRangeLabel(String range);

  /// No description provided for @aiEarlierLabel.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get aiEarlierLabel;

  /// No description provided for @aiLatestLabel.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get aiLatestLabel;

  /// No description provided for @aiObservedChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Observed change'**
  String get aiObservedChangeLabel;

  /// No description provided for @aiTrendRecentChangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Recent change'**
  String get aiTrendRecentChangeLabel;

  /// No description provided for @aiTrendStableLabel.
  ///
  /// In en, this message translates to:
  /// **'Stable'**
  String get aiTrendStableLabel;

  /// No description provided for @aiTrendImprovingLabel.
  ///
  /// In en, this message translates to:
  /// **'Improving'**
  String get aiTrendImprovingLabel;

  /// No description provided for @aiTrendWorseningLabel.
  ///
  /// In en, this message translates to:
  /// **'Worsening'**
  String get aiTrendWorseningLabel;

  /// No description provided for @aiTrendUnknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get aiTrendUnknownLabel;

  /// No description provided for @aiLifestyleOverviewLabel.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle Overview'**
  String get aiLifestyleOverviewLabel;

  /// No description provided for @appDisclaimerText.
  ///
  /// In en, this message translates to:
  /// **'SUSTHITI provides AI-assisted informational insights and does not replace professional medical diagnosis, treatment, or emergency care.'**
  String get appDisclaimerText;

  /// No description provided for @chartSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Chart with {count} recorded values from {start} to {end}'**
  String chartSemanticLabel(int count, String start, String end);

  /// No description provided for @metricDemoDataSuffix.
  ///
  /// In en, this message translates to:
  /// **', demo data'**
  String get metricDemoDataSuffix;

  /// No description provided for @aiGeneratedBadgeLabel.
  ///
  /// In en, this message translates to:
  /// **'AI-generated'**
  String get aiGeneratedBadgeLabel;

  /// No description provided for @demoBadgeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Demonstration data, not real health data'**
  String get demoBadgeTooltip;

  /// No description provided for @statusPrefixSemantic.
  ///
  /// In en, this message translates to:
  /// **'Status: {label}'**
  String statusPrefixSemantic(String label);

  /// No description provided for @copyPatientIdTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy {label}'**
  String copyPatientIdTooltip(String label);

  /// No description provided for @patientIdCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'{label} copied'**
  String patientIdCopiedToast(String label);

  /// No description provided for @fieldOptionalSuffix.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get fieldOptionalSuffix;

  /// No description provided for @choiceRequiredMessage.
  ///
  /// In en, this message translates to:
  /// **'Please choose one option.'**
  String get choiceRequiredMessage;

  /// No description provided for @dateFieldSelectPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get dateFieldSelectPlaceholder;

  /// No description provided for @passwordShowTooltip.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get passwordShowTooltip;

  /// No description provided for @passwordHideTooltip.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get passwordHideTooltip;

  /// No description provided for @unableToLoadSection.
  ///
  /// In en, this message translates to:
  /// **'Unable to load {title}.'**
  String unableToLoadSection(String title);

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// No description provided for @timelineTodayAt.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String timelineTodayAt(String time);

  /// No description provided for @timelineYesterdayAt.
  ///
  /// In en, this message translates to:
  /// **'Yesterday, {time}'**
  String timelineYesterdayAt(String time);

  /// No description provided for @timelineOpenLabel.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get timelineOpenLabel;

  /// No description provided for @pageNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found.'**
  String get pageNotFoundTitle;

  /// No description provided for @goHomeButton.
  ///
  /// In en, this message translates to:
  /// **'Go home'**
  String get goHomeButton;

  /// No description provided for @authTaglineHeadline.
  ///
  /// In en, this message translates to:
  /// **'Understand your health. Track your journey. Stay connected with your doctor.'**
  String get authTaglineHeadline;

  /// No description provided for @authTaglineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Diabetes-focused longitudinal health monitoring for patients and doctors.'**
  String get authTaglineSubtitle;

  /// No description provided for @probabilityShortLabel.
  ///
  /// In en, this message translates to:
  /// **'probability'**
  String get probabilityShortLabel;

  /// No description provided for @rolePatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get rolePatient;

  /// No description provided for @roleDoctor.
  ///
  /// In en, this message translates to:
  /// **'Doctor'**
  String get roleDoctor;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @glucoseTypeFasting.
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get glucoseTypeFasting;

  /// No description provided for @glucoseTypePostMeal.
  ///
  /// In en, this message translates to:
  /// **'Post-meal'**
  String get glucoseTypePostMeal;

  /// No description provided for @glucoseTypeRandom.
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get glucoseTypeRandom;

  /// No description provided for @mealTypeBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealTypeBreakfast;

  /// No description provided for @mealTypeLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealTypeLunch;

  /// No description provided for @mealTypeDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealTypeDinner;

  /// No description provided for @mealTypeSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get mealTypeSnack;

  /// No description provided for @mealTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get mealTypeOther;

  /// No description provided for @lifestyleMetricSteps.
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get lifestyleMetricSteps;

  /// No description provided for @lifestyleMetricHeartRate.
  ///
  /// In en, this message translates to:
  /// **'Heart Rate'**
  String get lifestyleMetricHeartRate;

  /// No description provided for @lifestyleMetricSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get lifestyleMetricSleep;

  /// No description provided for @lifestyleMetricActivity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get lifestyleMetricActivity;

  /// No description provided for @lifestyleMetricBloodPressure.
  ///
  /// In en, this message translates to:
  /// **'Blood Pressure'**
  String get lifestyleMetricBloodPressure;

  /// No description provided for @lifestyleMetricSpo2.
  ///
  /// In en, this message translates to:
  /// **'SpO₂'**
  String get lifestyleMetricSpo2;

  /// No description provided for @lifestyleMetricCalories.
  ///
  /// In en, this message translates to:
  /// **'Calories'**
  String get lifestyleMetricCalories;

  /// No description provided for @dataSourceHealthPlatform.
  ///
  /// In en, this message translates to:
  /// **'Health Platform'**
  String get dataSourceHealthPlatform;

  /// No description provided for @dataSourceDevice.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get dataSourceDevice;

  /// No description provided for @dataSourceManual.
  ///
  /// In en, this message translates to:
  /// **'Manual'**
  String get dataSourceManual;

  /// No description provided for @dataSourceImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get dataSourceImported;

  /// No description provided for @rangeDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get rangeDaily;

  /// No description provided for @rangeWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get rangeWeekly;

  /// No description provided for @rangeMonthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get rangeMonthly;

  /// No description provided for @rangeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get rangeCustom;

  /// No description provided for @range7Days.
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get range7Days;

  /// No description provided for @range30Days.
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get range30Days;

  /// No description provided for @range1Month.
  ///
  /// In en, this message translates to:
  /// **'1 Month'**
  String get range1Month;

  /// No description provided for @range3Months.
  ///
  /// In en, this message translates to:
  /// **'3 Months'**
  String get range3Months;

  /// No description provided for @range6Months.
  ///
  /// In en, this message translates to:
  /// **'6 Months'**
  String get range6Months;

  /// No description provided for @range1Year.
  ///
  /// In en, this message translates to:
  /// **'1 Year'**
  String get range1Year;

  /// No description provided for @trendNoDataRecorded.
  ///
  /// In en, this message translates to:
  /// **'No {metric} recorded in this period.'**
  String trendNoDataRecorded(String metric);

  /// No description provided for @trendSingleRecordedResult.
  ///
  /// In en, this message translates to:
  /// **'Single recorded result'**
  String get trendSingleRecordedResult;

  /// No description provided for @trendSingleValueOnDate.
  ///
  /// In en, this message translates to:
  /// **'{value} on {date}'**
  String trendSingleValueOnDate(String value, String date);

  /// No description provided for @trendMoreResultsNeeded.
  ///
  /// In en, this message translates to:
  /// **'More results are needed to show a trend.'**
  String get trendMoreResultsNeeded;

  /// No description provided for @trendAverageAcross.
  ///
  /// In en, this message translates to:
  /// **'Average {avg} across {count} recorded {unit}'**
  String trendAverageAcross(String avg, int count, String unit);

  /// No description provided for @trendUnitReadings.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{reading} other{readings}}'**
  String trendUnitReadings(num count);

  /// No description provided for @trendUnitDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{day} other{days}}'**
  String trendUnitDays(num count);

  /// No description provided for @severityMild.
  ///
  /// In en, this message translates to:
  /// **'Mild'**
  String get severityMild;

  /// No description provided for @severityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get severityModerate;

  /// No description provided for @severitySevere.
  ///
  /// In en, this message translates to:
  /// **'Severe'**
  String get severitySevere;

  /// No description provided for @severityEmergency.
  ///
  /// In en, this message translates to:
  /// **'Emergency'**
  String get severityEmergency;

  /// No description provided for @sideEffectStatusNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get sideEffectStatusNew;

  /// No description provided for @sideEffectStatusUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Under Review'**
  String get sideEffectStatusUnderReview;

  /// No description provided for @sideEffectStatusResponded.
  ///
  /// In en, this message translates to:
  /// **'Responded'**
  String get sideEffectStatusResponded;

  /// No description provided for @sideEffectStatusAppointmentRecommended.
  ///
  /// In en, this message translates to:
  /// **'Appointment Recommended'**
  String get sideEffectStatusAppointmentRecommended;

  /// No description provided for @sideEffectStatusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get sideEffectStatusResolved;

  /// No description provided for @doctorResponseNoImmediateAction.
  ///
  /// In en, this message translates to:
  /// **'No immediate action'**
  String get doctorResponseNoImmediateAction;

  /// No description provided for @doctorResponseMonitor.
  ///
  /// In en, this message translates to:
  /// **'Monitor'**
  String get doctorResponseMonitor;

  /// No description provided for @doctorResponseContactDoctor.
  ///
  /// In en, this message translates to:
  /// **'Contact doctor'**
  String get doctorResponseContactDoctor;

  /// No description provided for @doctorResponseAppointmentRecommended.
  ///
  /// In en, this message translates to:
  /// **'Appointment recommended'**
  String get doctorResponseAppointmentRecommended;

  /// No description provided for @doctorResponseUrgentMedicalAttention.
  ///
  /// In en, this message translates to:
  /// **'Urgent medical attention'**
  String get doctorResponseUrgentMedicalAttention;

  /// No description provided for @followUpStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get followUpStatusScheduled;

  /// No description provided for @followUpStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get followUpStatusCompleted;

  /// No description provided for @followUpStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get followUpStatusCancelled;

  /// No description provided for @surgeryStatusScheduled.
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get surgeryStatusScheduled;

  /// No description provided for @surgeryStatusCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get surgeryStatusCompleted;

  /// No description provided for @surgeryStatusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get surgeryStatusCancelled;

  /// No description provided for @accessStatusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get accessStatusPending;

  /// No description provided for @accessStatusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get accessStatusApproved;

  /// No description provided for @accessStatusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get accessStatusRejected;

  /// No description provided for @accessStatusRevoked.
  ///
  /// In en, this message translates to:
  /// **'Revoked'**
  String get accessStatusRevoked;

  /// No description provided for @reportCategoryFullBody.
  ///
  /// In en, this message translates to:
  /// **'Full Body Checkup'**
  String get reportCategoryFullBody;

  /// No description provided for @reportCategoryBloodReport.
  ///
  /// In en, this message translates to:
  /// **'Blood Report'**
  String get reportCategoryBloodReport;

  /// No description provided for @reportCategoryHba1c.
  ///
  /// In en, this message translates to:
  /// **'HbA1c'**
  String get reportCategoryHba1c;

  /// No description provided for @reportCategoryBloodGlucose.
  ///
  /// In en, this message translates to:
  /// **'Blood Glucose'**
  String get reportCategoryBloodGlucose;

  /// No description provided for @reportCategoryLipidProfile.
  ///
  /// In en, this message translates to:
  /// **'Lipid Profile'**
  String get reportCategoryLipidProfile;

  /// No description provided for @reportCategoryKidneyFunction.
  ///
  /// In en, this message translates to:
  /// **'Kidney Function'**
  String get reportCategoryKidneyFunction;

  /// No description provided for @reportCategoryLiverFunction.
  ///
  /// In en, this message translates to:
  /// **'Liver Function'**
  String get reportCategoryLiverFunction;

  /// No description provided for @reportCategoryUrineTest.
  ///
  /// In en, this message translates to:
  /// **'Urine Test'**
  String get reportCategoryUrineTest;

  /// No description provided for @reportCategoryXRay.
  ///
  /// In en, this message translates to:
  /// **'X-Ray'**
  String get reportCategoryXRay;

  /// No description provided for @reportCategoryMri.
  ///
  /// In en, this message translates to:
  /// **'MRI'**
  String get reportCategoryMri;

  /// No description provided for @reportCategoryCt.
  ///
  /// In en, this message translates to:
  /// **'CT'**
  String get reportCategoryCt;

  /// No description provided for @reportCategoryEcg.
  ///
  /// In en, this message translates to:
  /// **'ECG'**
  String get reportCategoryEcg;

  /// No description provided for @reportCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportCategoryOther;

  /// No description provided for @reportFilterGroupAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get reportFilterGroupAll;

  /// No description provided for @reportFilterGroupBlood.
  ///
  /// In en, this message translates to:
  /// **'Blood'**
  String get reportFilterGroupBlood;

  /// No description provided for @reportFilterGroupHba1c.
  ///
  /// In en, this message translates to:
  /// **'HbA1c'**
  String get reportFilterGroupHba1c;

  /// No description provided for @reportFilterGroupImaging.
  ///
  /// In en, this message translates to:
  /// **'Imaging'**
  String get reportFilterGroupImaging;

  /// No description provided for @reportFilterGroupOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get reportFilterGroupOther;

  /// No description provided for @aiSummaryKindReport.
  ///
  /// In en, this message translates to:
  /// **'Report Summary'**
  String get aiSummaryKindReport;

  /// No description provided for @aiSummaryKindAllReports.
  ///
  /// In en, this message translates to:
  /// **'All Reports Summary'**
  String get aiSummaryKindAllReports;

  /// No description provided for @aiSummaryKindPatient.
  ///
  /// In en, this message translates to:
  /// **'AI Patient Summary'**
  String get aiSummaryKindPatient;

  /// No description provided for @aiSummaryKindPatientFriendly.
  ///
  /// In en, this message translates to:
  /// **'Your Health Summary'**
  String get aiSummaryKindPatientFriendly;

  /// No description provided for @aiSummaryKindLifestyle.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle Insight'**
  String get aiSummaryKindLifestyle;

  /// No description provided for @aiSummaryKindInterpretation.
  ///
  /// In en, this message translates to:
  /// **'Assessment Interpretation'**
  String get aiSummaryKindInterpretation;

  /// No description provided for @aiSummaryKindHeartInterpretation.
  ///
  /// In en, this message translates to:
  /// **'Heart Risk Screening Interpretation'**
  String get aiSummaryKindHeartInterpretation;

  /// No description provided for @followUpStatusUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get followUpStatusUpcoming;

  /// No description provided for @followUpStatusUnscheduled.
  ///
  /// In en, this message translates to:
  /// **'Needs scheduling'**
  String get followUpStatusUnscheduled;

  /// No description provided for @followUpStatusPast.
  ///
  /// In en, this message translates to:
  /// **'Past'**
  String get followUpStatusPast;

  /// No description provided for @aiSummaryFallbackNotice.
  ///
  /// In en, this message translates to:
  /// **'Translation unavailable. Showing English version.'**
  String get aiSummaryFallbackNotice;

  /// No description provided for @aiSummaryRequestTranslation.
  ///
  /// In en, this message translates to:
  /// **'Request translation'**
  String get aiSummaryRequestTranslation;

  /// No description provided for @pdfLanguageLimitationNotice.
  ///
  /// In en, this message translates to:
  /// **'PDF exports are currently available in English only. Full multilingual PDF support coming soon.'**
  String get pdfLanguageLimitationNotice;

  /// No description provided for @profileGroupBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body measurements'**
  String get profileGroupBodyLabel;

  /// No description provided for @profileGroupMedicalHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Medical history'**
  String get profileGroupMedicalHistoryLabel;

  /// No description provided for @profileGroupFamilyHistoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Family history'**
  String get profileGroupFamilyHistoryLabel;

  /// No description provided for @profileGroupHabitsLabel.
  ///
  /// In en, this message translates to:
  /// **'Lifestyle habits'**
  String get profileGroupHabitsLabel;

  /// No description provided for @profileGroupSymptomsLabel.
  ///
  /// In en, this message translates to:
  /// **'Symptoms'**
  String get profileGroupSymptomsLabel;

  /// No description provided for @profileFieldHeight.
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get profileFieldHeight;

  /// No description provided for @profileFieldWeight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get profileFieldWeight;

  /// No description provided for @profileFieldFamilyDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Family history of diabetes'**
  String get profileFieldFamilyDiabetes;

  /// No description provided for @profileFieldPreviousPrediabetes.
  ///
  /// In en, this message translates to:
  /// **'Previous prediabetes'**
  String get profileFieldPreviousPrediabetes;

  /// No description provided for @profileFieldGestationalDiabetes.
  ///
  /// In en, this message translates to:
  /// **'Gestational diabetes'**
  String get profileFieldGestationalDiabetes;

  /// No description provided for @profileFieldHypertension.
  ///
  /// In en, this message translates to:
  /// **'High blood pressure'**
  String get profileFieldHypertension;

  /// No description provided for @profileFieldHighCholesterol.
  ///
  /// In en, this message translates to:
  /// **'High cholesterol'**
  String get profileFieldHighCholesterol;

  /// No description provided for @profileFieldPcos.
  ///
  /// In en, this message translates to:
  /// **'PCOS'**
  String get profileFieldPcos;

  /// No description provided for @profileFieldCardiovascularDisease.
  ///
  /// In en, this message translates to:
  /// **'Cardiovascular disease'**
  String get profileFieldCardiovascularDisease;

  /// No description provided for @profileFieldFattyLiverDisease.
  ///
  /// In en, this message translates to:
  /// **'Fatty liver disease'**
  String get profileFieldFattyLiverDisease;

  /// No description provided for @profileFieldPhysicalActivity.
  ///
  /// In en, this message translates to:
  /// **'Physical activity level'**
  String get profileFieldPhysicalActivity;

  /// No description provided for @profileFieldSedentaryHours.
  ///
  /// In en, this message translates to:
  /// **'Hours sitting per day'**
  String get profileFieldSedentaryHours;

  /// No description provided for @profileFieldDietQuality.
  ///
  /// In en, this message translates to:
  /// **'Diet quality'**
  String get profileFieldDietQuality;

  /// No description provided for @profileFieldSugaryDrinks.
  ///
  /// In en, this message translates to:
  /// **'Sugary drink frequency'**
  String get profileFieldSugaryDrinks;

  /// No description provided for @profileFieldSmokingStatus.
  ///
  /// In en, this message translates to:
  /// **'Smoking status'**
  String get profileFieldSmokingStatus;

  /// No description provided for @profileFieldAlcoholFrequency.
  ///
  /// In en, this message translates to:
  /// **'Alcohol frequency'**
  String get profileFieldAlcoholFrequency;

  /// No description provided for @profileFieldStressLevel.
  ///
  /// In en, this message translates to:
  /// **'Stress level'**
  String get profileFieldStressLevel;

  /// No description provided for @profileFieldPolyuria.
  ///
  /// In en, this message translates to:
  /// **'Frequent urination'**
  String get profileFieldPolyuria;

  /// No description provided for @profileFieldPolydipsia.
  ///
  /// In en, this message translates to:
  /// **'Excessive thirst'**
  String get profileFieldPolydipsia;

  /// No description provided for @profileFieldUnexplainedWeightLoss.
  ///
  /// In en, this message translates to:
  /// **'Unexplained weight loss'**
  String get profileFieldUnexplainedWeightLoss;

  /// No description provided for @profileFieldPolyphagia.
  ///
  /// In en, this message translates to:
  /// **'Increased hunger'**
  String get profileFieldPolyphagia;

  /// No description provided for @profileFieldFamilyHeartDisease.
  ///
  /// In en, this message translates to:
  /// **'Family history of heart disease'**
  String get profileFieldFamilyHeartDisease;

  /// No description provided for @profileFieldPreviousHeartDisease.
  ///
  /// In en, this message translates to:
  /// **'Previous heart disease'**
  String get profileFieldPreviousHeartDisease;

  /// No description provided for @profileFieldPreviousHeartAttack.
  ///
  /// In en, this message translates to:
  /// **'Previous heart attack'**
  String get profileFieldPreviousHeartAttack;

  /// No description provided for @profileFieldKidneyDisease.
  ///
  /// In en, this message translates to:
  /// **'Kidney disease'**
  String get profileFieldKidneyDisease;

  /// No description provided for @profileFieldStrokeHistory.
  ///
  /// In en, this message translates to:
  /// **'History of stroke'**
  String get profileFieldStrokeHistory;

  /// No description provided for @profileHelpPhysicalActivity.
  ///
  /// In en, this message translates to:
  /// **'Choose the option that best describes your usual activity.'**
  String get profileHelpPhysicalActivity;

  /// No description provided for @profileOptionActivityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get profileOptionActivityLow;

  /// No description provided for @profileOptionActivityModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get profileOptionActivityModerate;

  /// No description provided for @profileOptionActivityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get profileOptionActivityHigh;

  /// No description provided for @profileOptionDietGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get profileOptionDietGood;

  /// No description provided for @profileOptionDietAverage.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get profileOptionDietAverage;

  /// No description provided for @profileOptionDietPoor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get profileOptionDietPoor;

  /// No description provided for @profileOptionSugaryDrinksRarely.
  ///
  /// In en, this message translates to:
  /// **'Rarely'**
  String get profileOptionSugaryDrinksRarely;

  /// No description provided for @profileOptionSugaryDrinksOneToThree.
  ///
  /// In en, this message translates to:
  /// **'1–3 times/week'**
  String get profileOptionSugaryDrinksOneToThree;

  /// No description provided for @profileOptionSugaryDrinksFourToSix.
  ///
  /// In en, this message translates to:
  /// **'4–6 times/week'**
  String get profileOptionSugaryDrinksFourToSix;

  /// No description provided for @profileOptionSugaryDrinksDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get profileOptionSugaryDrinksDaily;

  /// No description provided for @profileOptionSmokingNever.
  ///
  /// In en, this message translates to:
  /// **'Never smoked'**
  String get profileOptionSmokingNever;

  /// No description provided for @profileOptionSmokingFormer.
  ///
  /// In en, this message translates to:
  /// **'Former smoker'**
  String get profileOptionSmokingFormer;

  /// No description provided for @profileOptionSmokingCurrent.
  ///
  /// In en, this message translates to:
  /// **'Currently smoke'**
  String get profileOptionSmokingCurrent;

  /// No description provided for @profileOptionAlcoholNever.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get profileOptionAlcoholNever;

  /// No description provided for @profileOptionAlcoholOccasionally.
  ///
  /// In en, this message translates to:
  /// **'Occasionally'**
  String get profileOptionAlcoholOccasionally;

  /// No description provided for @profileOptionAlcoholWeekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get profileOptionAlcoholWeekly;

  /// No description provided for @profileOptionAlcoholFrequent.
  ///
  /// In en, this message translates to:
  /// **'Frequently'**
  String get profileOptionAlcoholFrequent;

  /// No description provided for @profileOptionStressLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get profileOptionStressLow;

  /// No description provided for @profileOptionStressModerate.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get profileOptionStressModerate;

  /// No description provided for @profileOptionStressHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get profileOptionStressHigh;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'gu', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'gu':
      return AppLocalizationsGu();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
