import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../health_profile/body_card.dart';
import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/validators/validators.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/patient.dart';
import '../../data/models/patient_qr.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../authentication/auth_controller.dart';
import '../notifications/notifications.dart';

/// Shown next to the Patient ID. Contains only the opaque Patient ID and the patient's own
/// name -- the same two things a doctor already has to enter manually to request access. No
/// medical data is ever encoded; see data/models/patient_qr.dart.
class PatientQrCard extends StatelessWidget {
  const PatientQrCard({super.key, required this.patientCode, required this.fullName});
  final String patientCode;
  final String fullName;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Row(children: [
          Icon(Icons.qr_code_2, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Text(l10n.profileYourQrCode, style: t.titleSmall),
        ]),
        const SizedBox(height: AppSpacing.md),
        QrImageView(
          data: PatientQrPayload(patientCode: patientCode, fullName: fullName).encode(),
          size: 180,
          backgroundColor: Colors.white,
          semanticsLabel: l10n.profileQrSemanticLabel(patientCode),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.profileQrHelp,
          style: t.bodySmall,
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

final myProfileProvider = FutureProvider.autoDispose<PatientProfile>((ref) => ref.watch(patientRepositoryProvider).myProfile());
final patientProfileProvider = FutureProvider.autoDispose.family<PatientProfile, String>((ref, pid) => ref.watch(patientRepositoryProvider).profile(pid));

/// Photo bytes come from the authorized endpoint, never a public URL.
final patientPhotoProvider = FutureProvider.autoDispose.family<Uint8List?, String>((ref, pid) async {
  try {
    return await ref.watch(patientRepositoryProvider).photo(pid);
  } on NotFoundFailure {
    return null;
  }
});

class PatientAvatar extends ConsumerWidget {
  const PatientAvatar({super.key, required this.patientId, required this.name, this.hasPhoto = false, this.radius = 28});
  final String patientId;
  final String name;
  final bool hasPhoto;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = hasPhoto ? ref.watch(patientPhotoProvider(patientId)).value : null;
    final initials = name.trim().split(RegExp(r'\s+')).take(2).map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primarySoft,
      foregroundImage: bytes == null ? null : MemoryImage(bytes),
      child: Text(initials, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: radius * 0.6)),
    );
  }
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final value = ref.watch(myProfileProvider);
    final t = Theme.of(context).textTheme;
    return AppPage(
      title: l10n.profileTitle,
      large: true,
      actions: [
        const NotificationBell(),
        IconButton(tooltip: l10n.settingsTitle, onPressed: () => context.push('/p/settings'), icon: const Icon(Icons.settings_outlined)),
      ],
      body: PageBody(
        maxWidth: 720,
        onRefresh: () async => ref.invalidate(myProfileProvider),
        children: [
          AsyncBody(
            value: value,
            onRetry: () => ref.invalidate(myProfileProvider),
            data: (p) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Stack(children: [
                  PatientAvatar(patientId: p.id, name: p.fullName, hasPhoto: p.hasPhoto, radius: 36),
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: IconButton.filledTonal(tooltip: l10n.profileChangePhotoTooltip, iconSize: 16, onPressed: () => _changePhoto(context, ref, p), icon: const Icon(Icons.photo_camera_outlined)),
                  ),
                ]),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Flexible(child: Text(p.fullName, style: t.titleLarge)), if (p.isDemo) ...[const SizedBox(width: 6), const DemoBadge()]]),
                    Text(p.email, style: t.bodySmall),
                  ]),
                ),
              ]),
              const SizedBox(height: AppSpacing.xl),
              PatientIdTile(p.patientCode),
              const SizedBox(height: AppSpacing.sm),
              Text(l10n.profileShareIdNote, style: t.bodySmall),
              const SizedBox(height: AppSpacing.lg),
              PatientQrCard(patientCode: p.patientCode, fullName: p.fullName),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(l10n.profilePersonalDetailsHeader, action: TextButton.icon(onPressed: () => _edit(context, ref, p), icon: const Icon(Icons.edit_outlined, size: 18), label: Text(l10n.commonEdit))),
              AppCard(
                child: Column(children: [
                  KeyValueRow(l10n.authDateOfBirth, p.dateOfBirth == null ? l10n.commonNotSet : Fmt.date(p.dateOfBirth)),
                  KeyValueRow(l10n.commonAgeLabel, p.age == null ? l10n.commonNotSet : '${p.age}'),
                  KeyValueRow(l10n.authGender, p.gender ?? l10n.commonNotSet),
                  KeyValueRow(l10n.authPhone, p.phone ?? l10n.commonNotSet),
                ]),
              ),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(l10n.doctorBodyMeasurementsHeader),
              BodyMeasurementsCard(body: p.body, patientId: p.id, canEdit: true),
              const SizedBox(height: AppSpacing.section),
              SectionHeader(l10n.doctorEmergencyContactLabel),
              AppCard(
                child: p.emergencyContact.isEmpty
                    ? Text(l10n.profileNoEmergencyContact, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary))
                    : Column(children: [
                        KeyValueRow(l10n.commonNameLabel, p.emergencyContact.name ?? '—'),
                        KeyValueRow(l10n.commonRelationshipLabel, p.emergencyContact.relationship ?? '—'),
                        KeyValueRow(l10n.authPhone, p.emergencyContact.phone ?? '—'),
                      ]),
              ),
              const SizedBox(height: AppSpacing.section),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  ListTile(
                    leading: const Icon(Icons.monitor_heart_outlined, color: AppColors.primary),
                    title: Text(l10n.profileHealthProfileLabel),
                    subtitle: Text(l10n.profileHealthProfileSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/r/${p.id}/health-profile'),
                  ),
                  const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                  ListTile(leading: const Icon(Icons.verified_user_outlined, color: AppColors.primary), title: Text(l10n.settingsDoctorAccess), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/p/access')),
                  const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                  ListTile(leading: const Icon(Icons.watch_outlined, color: AppColors.primary), title: Text(l10n.settingsConnectedDevices), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/p/devices')),
                  const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                  ListTile(leading: const Icon(Icons.settings_outlined, color: AppColors.primary), title: Text(l10n.settingsTitle), trailing: const Icon(Icons.chevron_right), onTap: () => context.push('/p/settings')),
                ]),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _changePhoto(BuildContext context, WidgetRef ref, PatientProfile p) async {
    final l10n = AppLocalizations.of(context);
    try {
      final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png'], dialogTitle: l10n.profileChoosePhotoDialogTitle);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        if (context.mounted) showToast(context, l10n.profilePhotoTooLargeError, error: true);
        return;
      }
      await ref.read(patientRepositoryProvider).uploadPhoto(bytes, file.name);
      ref.invalidate(patientPhotoProvider(p.id));
      ref.invalidate(myProfileProvider);
      if (context.mounted) showToast(context, l10n.profilePhotoUpdatedToast);
    } catch (e) {
      if (context.mounted) showFailure(context, e);
    }
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, PatientProfile p) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, builder: (_) => _EditProfileSheet(profile: p));
    if (saved == true) {
      ref.invalidate(myProfileProvider);
      if (context.mounted) showToast(context, AppLocalizations.of(context).profileUpdatedToast);
    }
  }
}

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({required this.profile});
  final PatientProfile profile;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone);
  late final _ecName = TextEditingController(text: widget.profile.emergencyContact.name);
  late final _ecRelationship = TextEditingController(text: widget.profile.emergencyContact.relationship);
  late final _ecPhone = TextEditingController(text: widget.profile.emergencyContact.phone);
  late DateTime? _dob = widget.profile.dateOfBirth;
  late String? _gender = widget.profile.gender;

  @override
  void dispose() {
    for (final c in [_name, _phone, _ecName, _ecRelationship, _ecPhone]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    try {
      final updated = await ref.read(patientRepositoryProvider).updateProfile({
        'full_name': _name.text.trim(),
        'date_of_birth': _dob == null ? null : Fmt.isoDate(_dob!),
        'gender': _gender,
        'phone': _v(_phone),
        'emergency_name': _v(_ecName),
        'emergency_relationship': _v(_ecRelationship),
        'emergency_phone': _v(_ecPhone),
      });
      ref.read(authControllerProvider.notifier).updateName(updated.fullName);
      if (mounted) Navigator.pop(context, true);
    } on Failure catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SheetForm(
      title: l10n.settingsEditProfile,
      form: _form,
      children: [
        AppTextField(label: l10n.authFullName, controller: _name, validator: (v) => Validators.required(l10n, v, l10n.authFullName), textCapitalization: TextCapitalization.words),
        DateTimeField(label: l10n.authDateOfBirth, value: _dob, onChanged: (d) => setState(() => _dob = d), validator: (d) => Validators.notFuture(l10n, d, l10n.authDateOfBirth)),
        // Options are sent verbatim as the diabetes model's gender input -- not translated, same as any other API value.
        ChoiceField<String>(label: l10n.authGender, options: const ['Male', 'Female'], value: _gender, labelOf: (g) => g == 'Male' ? l10n.genderMale : l10n.genderFemale, onChanged: (g) => setState(() => _gender = g), helper: l10n.profileGenderModelInputHelper, requiredMessage: l10n.choiceRequiredMessage),
        AppTextField(label: l10n.authPhone, controller: _phone, optional: true, keyboardType: TextInputType.phone, validator: (v) => Validators.optionalPhone(l10n, v)),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.doctorEmergencyContactLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.md),
        AppTextField(label: l10n.commonNameLabel, controller: _ecName, optional: true, textCapitalization: TextCapitalization.words),
        AppTextField(label: l10n.commonRelationshipLabel, controller: _ecRelationship, optional: true),
        AppTextField(label: l10n.authPhone, controller: _ecPhone, optional: true, keyboardType: TextInputType.phone, validator: (v) => Validators.optionalPhone(l10n, v)),
        BusyButton(label: l10n.commonSave, onPressed: _save, expand: true),
      ],
    );
  }
}
