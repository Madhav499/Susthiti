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
    return AppPage(
      title: 'Scan Patient QR',
      body: _found == null
          ? Stack(fit: StackFit.expand, children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                errorBuilder: (context, error) => EmptyState(
                  icon: Icons.camera_alt_outlined,
                  title: 'Camera unavailable',
                  message: 'SUSTHITI needs camera access to scan a QR code. You can still use "Add Patient" to enter the details manually.',
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
                      child: Text('Point the camera at the patient\'s QR code', style: t.bodyMedium?.copyWith(color: Colors.white), textAlign: TextAlign.center),
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
                    Text('Request sent', style: t.titleLarge),
                    const SizedBox(height: AppSpacing.sm),
                    Text('${_sent!.patientName} (${_sent!.patientCode}) will be asked to approve your request. You will be notified when they respond.', style: t.bodyMedium),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(spacing: AppSpacing.sm, children: [
                      FilledButton(onPressed: () => context.go('/d/requests'), child: const Text('View requests')),
                      OutlinedButton(onPressed: _scanAgain, child: const Text('Scan another')),
                    ]),
                  ]),
                )
              else
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Patient identity', style: t.titleMedium),
                    const SizedBox(height: AppSpacing.md),
                    KeyValueRow('Name', _found!.fullName),
                    KeyValueRow('Patient ID', _found!.patientCode),
                    const SizedBox(height: AppSpacing.md),
                    Text('Confirm this is the right patient before requesting access. They must still approve it.', style: t.bodySmall),
                    if (_error != null) Padding(padding: const EdgeInsets.only(top: AppSpacing.md), child: Text(_error!, style: const TextStyle(color: AppColors.error))),
                    const SizedBox(height: AppSpacing.lg),
                    Wrap(spacing: AppSpacing.sm, children: [
                      BusyButton(label: 'Request Access', onPressed: _sending ? null : _requestAccess),
                      OutlinedButton(onPressed: _sending ? null : _scanAgain, child: const Text('Scan again')),
                    ]),
                  ]),
                ),
            ]),
    );
  }
}
