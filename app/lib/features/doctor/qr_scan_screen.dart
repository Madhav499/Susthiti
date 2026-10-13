import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/errors/failures.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/patient.dart';
import '../../data/models/patient_qr.dart';
import '../../data/models/user.dart';
import '../../data/providers.dart';
import '../../l10n/app_localizations.dart';
import '../access/access_screens.dart';

/// Doctor scans a patient's QR code (profile_screen.dart's PatientQrCard). Scanning only
/// decodes the same two fields the existing manual form already requires (name + Patient ID)
/// -- it never looks anything up on the server. The doctor still explicitly reviews the
/// identity and taps "Request Access"; the backend's existing name+code match check on
/// POST /access-requests is the only authority either way, same as a manually typed request.
class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  PatientQrPayload? _found;
  bool _sending = false;
  AccessRequest? _sent;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_found != null) return; // already showing a result; ignore further frames
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      final payload = PatientQrPayload.tryDecode(raw);
      if (payload != null) {
        _controller.stop();
        setState(() => _found = payload);
        return;
      }
    }
  }

  void _scanAgain() {
    setState(() {
      _found = null;
      _sent = null;
      _error = null;
    });
    _controller.start();
  }

  Future<void> _requestAccess() async {
    final found = _found;
    if (found == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final r = await ref.read(doctorRepositoryProvider).requestAccess(patientName: found.fullName, patientCode: found.patientCode);
      ref.invalidate(accessRequestsProvider(UserRole.doctor));
      if (mounted) setState(() => _sent = r);
    } on Failure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.qrScanPageTitle,
      body: _found == null
          ? Stack(fit: StackFit.expand, children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => EmptyState(
                  icon: Icons.camera_alt_outlined,
                  title: l10n.qrCameraUnavailableTitle,
                  message: l10n.qrCameraUnavailableMessage,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: AppSpacing.xl,
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: AppRadius.panelBorder),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Text(l10n.qrPointCameraHint, style: t.bodyMedium?.copyWith(color: Colors.white), textAlign: TextAlign.center),
                    ),
                  ),
                ),
              ),
            ])
          : PageBody(maxWidth: 560, children: [
              if (_sent != null)
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const IconBadge(Icons.mark_email_read_outlined, tone: StatusTone.positive),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.qrRequestSentTitle, style: t.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text(l10n.qrRequestSentMessage(_sent!.patientName, _sent!.patientCode), style: t.bodyMedium),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(spacing: AppSpacing.sm, children: [
                      FilledButton(onPressed: () => context.go('/d/requests'), child: Text(l10n.qrViewRequestsButton)),
                      OutlinedButton(onPressed: _scanAgain, child: Text(l10n.qrScanAnotherButton)),
                    ]),
                  ]),
                )
              else
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l10n.qrPatientIdentityHeader, style: t.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    KeyValueRow(l10n.commonNameLabel, _found!.fullName),
                    KeyValueRow(l10n.doctorPatientIdLabel, _found!.patientCode),
                    const SizedBox(height: AppSpacing.md),
                    Text(l10n.qrConfirmPatientNote, style: t.bodySmall),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(spacing: AppSpacing.sm, children: [
                      BusyButton(label: l10n.doctorRequestAccessButton, onPressed: _sending ? null : _requestAccess),
                      OutlinedButton(onPressed: _sending ? null : _scanAgain, child: Text(l10n.qrScanAgainButton)),
                    ]),
                  ]),
                ),
            ]),
    );
  }
}
