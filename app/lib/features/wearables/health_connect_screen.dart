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
import '../../l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context);
    return AppPage(
      title: l10n.wearConnectPageTitle,
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
                  title: l10n.wearDeniedTitle,
                  body: platform.platform == 'ios' ? l10n.wearDeniedBodyIos : l10n.wearDeniedBodyOther,
                  primaryLabel: platform.platform == 'android' ? l10n.wearOpenHealthConnectButton : null,
                  onPrimary: _continue, // user-initiated: shows Health Connect's permission screen again
                  secondaryLabel: l10n.wearNotNowButton,
                ),
              _Stage.needsInstall => _Message(
                  icon: Icons.download_outlined,
                  title: l10n.wearNeedsInstallTitle,
                  body: l10n.wearNeedsInstallBody,
                  primaryLabel: l10n.wearInstallButton,
                  onPrimary: () async {
                    await ref.read(wearableServiceProvider).platform.install();
                    if (mounted) setState(() => _stage = _Stage.explain);
                  },
                  secondaryLabel: l10n.wearNotNowButton,
                ),
              _Stage.unavailable => _Message(
                  icon: Icons.phone_iphone,
                  title: l10n.wearUnavailableTitle,
                  body: l10n.wearUnavailableBody,
                  secondaryLabel: l10n.commonBack,
                ),
              _Stage.failed => _Message(
                  icon: Icons.cloud_off_outlined,
                  title: l10n.wearFailedTitle,
                  body: l10n.wearFailedBody,
                  primaryLabel: l10n.commonTryAgain,
                  onPrimary: _continue,
                  secondaryLabel: l10n.wearNotNowButton,
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
    final l10n = AppLocalizations.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: AppSpacing.md),
      const Center(child: _Emblem(icon: Icons.favorite_border)),
      const SizedBox(height: AppSpacing.lg),
      Text(l10n.wearConnectTitle, style: t.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.sm),
      Text(
        l10n.wearExplainSubtitle(platformName),
        style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: AppSpacing.xl),
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.wearDataMayIncludeHeader, style: t.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final (metric, note) in [
            (HealthMetric.steps, ''),
            (HealthMetric.heartRate, ''),
            (HealthMetric.sleep, ''),
            (HealthMetric.activity, l10n.wearExerciseMinutesNote),
            (HealthMetric.calories, ''),
            (HealthMetric.bloodPressure, l10n.wearWhereSupportedNote),
            (HealthMetric.spo2, l10n.wearWhereSupportedNote),
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
        l10n.wearPrivacyNote,
        style: t.bodySmall,
      ),
      const SizedBox(height: AppSpacing.xl),
      FilledButton(onPressed: onContinue, child: Text(l10n.wearContinueButton)),
      const SizedBox(height: AppSpacing.sm),
      TextButton(onPressed: () => context.pop(false), child: Text(l10n.wearNotNowButton)),
    ]);
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.huge),
        child: Column(children: [
          const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.wearConnectingTitle, style: t.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(l10n.wearConnectingBody, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
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
    final l10n = AppLocalizations.of(context);
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
      Text(l10n.wearSuccessHeadline, style: t.headlineSmall, textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.sm),
      Text(l10n.wearSuccessSubtitle, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center),
      const SizedBox(height: AppSpacing.lg),
      AppCard(
        child: Column(children: [
          KeyValueRow(l10n.wearSourceLabel, outcome.device.deviceName),
          KeyValueRow(l10n.wearLastSyncLabel, l10n.wearJustNowValue),
          KeyValueRow(l10n.wearMeasurementsAddedLabel, '${outcome.imported}'),
          KeyValueRow(l10n.wearSharingLabel, (outcome.device.grantedMetrics ?? const []).map((m) => HealthMetric.tryParse(m)?.label ?? m).join(', ')),
        ]),
      ),
      if (outcome.imported == 0) ...[
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.wearNoRecentDataNote, style: t.bodySmall),
      ],
      const SizedBox(height: AppSpacing.xl),
      FilledButton(onPressed: () => context.pop(true), child: Text(l10n.wearViewDashboardButton)),
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
