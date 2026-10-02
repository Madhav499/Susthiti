import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../data/models/health.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import 'health_connection.dart';

enum _Stage { explain, connecting, success, denied, needsInstall, unavailable, failed }

/// Connect health data: explain what SUSTHITI will read -> Continue (consent) -> the platform's
/// own permission screen -> connected + first sync. Permissions are never requested silently,
/// and a refusal is not asked again automatically. Pops `true` when connected.
class HealthConnectScreen extends ConsumerStatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  ConsumerState<HealthConnectScreen> createState() => _HealthConnectScreenState();
}

class _HealthConnectScreenState extends ConsumerState<HealthConnectScreen> {
  _Stage _stage = _Stage.explain;
  SyncOutcome? _outcome;

  Future<void> _continue() async {
    setState(() => _stage = _Stage.connecting);
    try {
      final outcome = await ref.read(wearableServiceProvider).connect();
      ref.invalidate(devicesProvider);
      if (mounted) {
        setState(() {
          _outcome = outcome;
          _stage = _Stage.success;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = switch (connectFailureOf(e)) {
            ConnectFailure.denied => _Stage.denied,
            ConnectFailure.needsInstall => _Stage.needsInstall,
            ConnectFailure.unavailable => _Stage.unavailable,
            ConnectFailure.failed => _Stage.failed,
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    final platform = ref.read(wearableServiceProvider).platform;
    return AppPage(
      title: 'Connect Health Data',
      body: PageBody(maxWidth: 560, children: [
        AnimatedSwitcher(
          duration: AppDurations.normal,
          child: KeyedSubtree(
            key: ValueKey(_stage),
            child: switch (_stage) {
              _Stage.explain => _Explain(platformName: platform.name, onContinue: _continue),
              _Stage.connecting => const _Connecting(),
              _Stage.success => _Success(outcome: _outcome!),
              _Stage.denied => _Message(
                  icon: Icons.lock_outline,
                  title: "Health data access wasn't enabled.",
                  body: platform.platform == 'ios'
                      ? 'You can enable it later from Connected Devices. On iPhone: open Settings, then Health, Data Access & Devices, SUSTHITI, and turn on the data you want to share.'
                      : 'You can enable it later from Connected Devices.',
                  primaryLabel: platform.platform == 'android' ? 'Open Health Connect' : null,
                  onPrimary: _continue, // user-initiated: shows Health Connect's permission screen again
                  secondaryLabel: 'Not now',
                ),
              _Stage.needsInstall => _Message(
                  icon: Icons.download_outlined,
                  title: 'Health Connect is needed',
                  body: 'Android keeps health data from your watch and fitness apps in Health Connect. Install or update it, then come back and continue.',
                  primaryLabel: 'Install Health Connect',
                  onPrimary: () async {
                    await ref.read(wearableServiceProvider).platform.install();
                    if (mounted) setState(() => _stage = _Stage.explain);
                  },
                  secondaryLabel: 'Not now',
                ),
              _Stage.unavailable => const _Message(
                  icon: Icons.phone_iphone,
                  title: 'Connect from your phone',
                  body: 'Browsers and computers cannot read health data directly. Open SUSTHITI on your Android phone or iPhone and go to Lifestyle, then Connect. '
                      'Your synced data then appears here automatically.',
                  secondaryLabel: 'Back',
                ),
              _Stage.failed => _Message(
                  icon: Icons.cloud_off_outlined,
                  title: "We couldn't connect your health data.",
                  body: 'Please check:\n• Health permissions\n• Device connection\n• Internet connection',
                  primaryLabel: 'Try Again',
                  onPrimary: _continue,
                  secondaryLabel: 'Not now',
                ),
            },
          ),
        ),
      ]),
    );
  }
}

class _Explain extends StatelessWidget {
  const _Explain({required this.platformName, required this.onContinue});
  final String platformName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: AppSpacing.md),
      const Center(child: _Emblem(icon: Icons.favorite_border)),
      const SizedBox(height: AppSpacing.lg),
      Text('Connect your health data', style: t.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.sm),
      Text(
        'SUSTHITI can use health information from $platformName to show your lifestyle trends.',
        style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xl),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Data may include', style: t.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final (metric, note) in const [
            (HealthMetric.steps, ''),
            (HealthMetric.heartRate, ''),
            (HealthMetric.sleep, ''),
            (HealthMetric.activity, ' (exercise minutes)'),
            (HealthMetric.calories, ''),
            (HealthMetric.bloodPressure, ' where supported'),
            (HealthMetric.spo2, ' where supported'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(children: [
                const Icon(Icons.check_circle_outline, size: 16, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Text('${metric.label}$note', style: t.bodyMedium),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: AppSpacing.md),
      Text(
        'SUSTHITI only reads this data; it never writes to your health platform. You choose what to share on the next screen and can change it any time. '
        'Your doctor sees it only while you have approved their access. Not every watch records blood pressure or SpO₂; SUSTHITI only shows what your device provides.',
        style: t.bodySmall,
      ),
      const SizedBox(height: AppSpacing.xl),
      FilledButton(onPressed: onContinue, child: const Text('Continue')),
      const SizedBox(height: AppSpacing.sm),
      TextButton(onPressed: () => context.pop(false), child: const Text('Not now')),
    ]);
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
        child: Column(children: [
          const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: AppSpacing.lg),
          Text('Connecting...', style: t.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text('Reading your recent health data for the first sync.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

class _Success extends StatelessWidget {
  const _Success({required this.outcome});
  final SyncOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: AppSpacing.md),
      Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.8, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: const _Emblem(icon: Icons.check, success: true),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      Text('Health Data Connected', style: t.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.sm),
      Text('Your health data is now connected to SUSTHITI.', style: t.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.lg),
      AppCard(
        child: Column(children: [
          KeyValueRow('Source', outcome.device.deviceName),
          KeyValueRow('Last synchronization', 'Just now'),
          KeyValueRow('Measurements added', '${outcome.imported}'),
          KeyValueRow('Sharing', (outcome.device.grantedMetrics ?? const []).map((m) => HealthMetric.tryParse(m)?.label ?? m).join(', ')),
        ]),
      ),
      if (outcome.imported == 0) ...[
        const SizedBox(height: AppSpacing.sm),
        Text('No recent data was found yet. New readings from your watch will sync automatically when you open SUSTHITI.', style: t.bodySmall),
      ],
      const SizedBox(height: AppSpacing.xl),
      FilledButton(onPressed: () => context.pop(true), child: const Text('View Lifestyle Dashboard')),
    ]);
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.primaryLabel, this.onPrimary, this.secondaryLabel});
  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: AppSpacing.md),
      Center(child: _Emblem(icon: icon, muted: true)),
      const SizedBox(height: AppSpacing.lg),
      Text(title, style: t.titleLarge, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.sm),
      Text(body, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.xl),
      if (primaryLabel != null && onPrimary != null) FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
      if (secondaryLabel != null) ...[
        const SizedBox(height: AppSpacing.sm),
        TextButton(onPressed: () => context.pop(false), child: Text(secondaryLabel!)),
      ],
    ]);
  }
}

class _Emblem extends StatelessWidget {
  const _Emblem({required this.icon, this.success = false, this.muted = false});
  final IconData icon;
  final bool success;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = success ? AppColors.success : (muted ? AppColors.textSecondary : AppColors.primary);
    final background = success ? AppColors.successSoft : (muted ? AppColors.surfaceSecondary : AppColors.primarySoft);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(color: background, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: 34),
    );
  }
}
