import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_assets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/brand.dart';

export '../../core/widgets/brand.dart' show BrandMark;

/// Calm two-panel layout on wide screens, single column on phones.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.subtitle, required this.child, this.showBack = false});

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.desktop;
    final form = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (showBack) Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => Navigator.of(context).maybePop())),
              if (!wide) ...[const BrandMark(), const SizedBox(height: AppSpacing.xxl)],
              Text(title, style: t.headlineMedium),
              const SizedBox(height: AppSpacing.sm),
              Text(subtitle, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.xl),
              child,
              if (kDebugMode) ...[const SizedBox(height: AppSpacing.xxl), const DevServerCheck()],
            ]),
          ),
        ),
      ),
    );
    if (!wide) return Scaffold(body: form);
    return Scaffold(
      body: Row(children: [
        Expanded(
          child: Container(
            color: AppColors.primarySoft,
            padding: const EdgeInsets.all(56),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Spacer(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Image.asset(AppAssets.logoTransparent, fit: BoxFit.contain, filterQuality: FilterQuality.medium, semanticLabel: 'SUSTHITI. ${AppAssets.tagline}'),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text('Understand your health. Track your journey. Stay connected with your doctor.',
                  style: t.titleMedium?.copyWith(color: AppColors.primaryDeep, height: 1.4), textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('Diabetes-focused longitudinal health monitoring for patients and doctors.',
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
              const Spacer(),
              Text('SUSTHITI provides AI-assisted informational insights and does not replace professional medical diagnosis, treatment, or emergency care.', style: t.bodySmall),
            ]),
          ),
        ),
        Expanded(child: form),
      ]),
    );
  }
}

/// Development builds only: shows which server this build talks to, with a one-tap check that
/// the device can actually reach it. Release builds never include it.
class DevServerCheck extends StatefulWidget {
  const DevServerCheck({super.key, this.check});

  /// Returns null when the server answered, otherwise why not. Replaceable in tests.
  final Future<String?> Function()? check;

  /// A phone built for 127.0.0.1 reaches the PC through the USB cable (adb reverse).
  static bool get _viaUsb => !kIsWeb && defaultTargetPlatform == TargetPlatform.android && RegExp(r'//(127\.0\.0\.1|localhost)[:/]').hasMatch(AppConfig.serverOrigin);

  static Future<String?> _checkHealth() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));
    try {
      final r = await dio.get<dynamic>('${AppConfig.serverOrigin}/health');
      return r.statusCode == 200 ? null : 'Server answered with status ${r.statusCode}.';
    } on DioException catch (e) {
      return switch (e.type) {
        DioExceptionType.connectionTimeout => 'No answer. Is this device on the same Wi-Fi as the PC, and is the backend started with -Lan?',
        DioExceptionType.connectionError => _viaUsb
            ? 'Connection failed. Is the phone plugged in, and did you run phone-usb.bat (or start-susthiti.bat) after plugging it in?'
            : "Connection failed. Is the backend running, and is this the PC's current address?",
        _ => 'Not reachable (${e.type.name}).',
      };
    } finally {
      dio.close();
    }
  }

  @override
  State<DevServerCheck> createState() => _DevServerCheckState();
}

class _DevServerCheckState extends State<DevServerCheck> {
  bool _checking = false;
  bool? _ok;
  String? _reason;

  Future<void> _run() async {
    setState(() => _checking = true);
    final reason = await (widget.check ?? DevServerCheck._checkHealth)();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _ok = reason == null;
      _reason = reason;
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.bodySmall;
    final server = AppConfig.serverOrigin.replaceFirst(RegExp(r'^https?://'), '');
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: AppSpacing.xs, children: [
        Text('Development server: $server', style: t),
        TextButton(onPressed: _checking ? null : _run, child: Text(_checking ? 'Checking…' : 'Test connection')),
      ]),
      if (_ok == true) Text('Reachable', style: t?.copyWith(color: AppColors.success, fontWeight: FontWeight.w600)),
      if (_ok == false) Text(_reason!, textAlign: TextAlign.center, style: t?.copyWith(color: AppColors.error)),
    ]);
  }
}
