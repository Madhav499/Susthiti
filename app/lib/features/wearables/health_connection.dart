import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import '../../data/services/wearable_service.dart';
import '../../l10n/app_localizations.dart';

final devicesProvider = FutureProvider.autoDispose<List<WearableConnection>>((ref) => ref.watch(wearableRepositoryProvider).devices());
final wearableProvidersProvider = FutureProvider.autoDispose<List<WearableProvider>>((ref) => ref.watch(wearableRepositoryProvider).providers());

/// Health-platform connections (not the DEMO provider), newest first.
List<WearableConnection> healthConnections(List<WearableConnection> devices) => [for (final d in devices) if (!d.isDemo && d.status != 'disconnected') d];

/// "Last synced 10:32 AM" today, "Last synced 24 Sep, 10:32 AM" otherwise.
String lastSyncedText(AppLocalizations l10n, DateTime? t) {
  if (t == null) return l10n.wearNotSyncedYet;
  final l = t.toLocal();
  final now = DateTime.now();
  final today = l.year == now.year && l.month == now.month && l.day == now.day;
  if (now.difference(l).inMinutes < 1) return l10n.lifestyleSyncedJustNowToast;
  return l10n.wearLastSyncedAt(today ? Fmt.time(l) : Fmt.dateTime(l));
}

/// Syncs in the foreground when a sync is due (on launch and when lifestyle opens). Failures
/// are quiet here; the connection card shows a failed sync with a Retry.
Future<void> syncHealthIfDue(WidgetRef ref, {VoidCallback? onSynced}) async {
  final service = ref.read(wearableServiceProvider);
  if (!service.canReadHealthData) return;
  try {
    final devices = await ref.read(wearableRepositoryProvider).devices();
    final outcome = await service.syncIfDue(devices);
    if (outcome != null) {
      ref.invalidate(devicesProvider);
      onSynced?.call();
    }
  } catch (_) {
    // Offline or platform unavailable: the dashboard keeps showing the last synced values.
  }
}

enum _CardState { notConnected, connected, syncing, error, readOnly }

/// Reusable status card for health data. On a phone or tablet with a health platform it offers
/// Connect / Sync Now / Retry. On web and desktop it is read-only: those devices show what the
/// phone synced and never pretend to pair with a watch.
class HealthConnectionCard extends ConsumerStatefulWidget {
  const HealthConnectionCard({super.key, required this.devices, required this.onChanged, this.showManage = true});
  final List<WearableConnection> devices;
  final VoidCallback onChanged;

  /// Shows a "Manage" link to Connected Devices.
  final bool showManage;

  @override
  ConsumerState<HealthConnectionCard> createState() => _HealthConnectionCardState();
}

class _HealthConnectionCardState extends ConsumerState<HealthConnectionCard> {
  bool _syncing = false;

  WearableConnection? get _connection {
    final list = healthConnections(widget.devices);
    final service = ref.read(wearableServiceProvider);
    return list.where(service.canSync).firstOrNull ?? list.firstOrNull;
  }

  _CardState get _state {
    final service = ref.read(wearableServiceProvider);
    final c = _connection;
    if (!service.canReadHealthData || (c != null && !service.canSync(c))) return _CardState.readOnly;
    if (_syncing) return _CardState.syncing;
    if (c == null) return _CardState.notConnected;
    return c.syncFailed ? _CardState.error : _CardState.connected;
  }

  Future<void> _sync() async {
    final c = _connection;
    if (c == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _syncing = true);
    try {
      final outcome = await ref.read(wearableServiceProvider).sync(c);
      widget.onChanged();
      ref.invalidate(devicesProvider);
      if (!mounted) return;
      if (outcome.device.syncFailed) {
        showToast(context, l10n.wearSyncFailedPermissions, error: true);
      } else {
        showToast(context, outcome.upToDate ? l10n.lifestyleAlreadyUpToDateToast : l10n.lifestyleSyncedJustNowToast);
      }
    } catch (e) {
      if (mounted) showToast(context, l10n.lifestyleSyncFailedToast, error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _connect() async {
    final connected = await context.push<bool>('/p/devices/connect');
    if (connected == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final c = _connection;
    final platformName = ref.read(wearableServiceProvider).platform.name;
    final (IconData icon, StatusTone tone, String title, String subtitle, Widget? action) = switch (_state) {
      _CardState.notConnected => (
          Icons.favorite_border,
          StatusTone.info,
          l10n.wearConnectTitle,
          l10n.wearConnectSubtitle(platformName),
          FilledButton(onPressed: _connect, child: Text(l10n.wearConnectButton)),
        ),
      _CardState.syncing => (
          Icons.sync,
          StatusTone.info,
          l10n.wearSyncingTitle,
          l10n.wearReadingDataSubtitle(platformName),
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      _CardState.connected => (
          Icons.favorite,
          StatusTone.positive,
          l10n.wearConnectedTitle,
          '${c!.deviceName} · ${lastSyncedText(l10n, c.lastSyncedAt)}',
          OutlinedButton.icon(onPressed: _sync, icon: const Icon(Icons.sync, size: 18), label: Text(l10n.wearSyncNowButton)),
        ),
      _CardState.error => (
          Icons.sync_problem,
          StatusTone.attention,
          l10n.wearSyncUnavailablePill,
          c?.lastError ?? l10n.wearLastSyncIncomplete,
          FilledButton(onPressed: _sync, child: Text(l10n.wearRetryButton)),
        ),
      _CardState.readOnly => c == null
          ? (
              Icons.phone_iphone,
              StatusTone.inactive,
              l10n.wearNotConnectedReadOnlyTitle,
              l10n.wearConnectFromMobileNote,
              null,
            )
          : (
              Icons.favorite,
              StatusTone.positive,
              l10n.wearHealthDataLabel,
              '${l10n.wearConnectedThroughNote(c.platform == 'ios' ? l10n.wearApplePlatformLabel : c.platform == 'android' ? l10n.wearAndroidPlatformLabel : l10n.wearGenericMobilePlatformLabel)} · ${lastSyncedText(l10n, c.lastSyncedAt)}',
              OutlinedButton.icon(onPressed: widget.onChanged, icon: const Icon(Icons.refresh, size: 18), label: Text(l10n.wearRefreshButton)),
            ),
    };
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconBadge(icon, tone: tone),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Semantics(
              liveRegion: _state == _CardState.syncing,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: t.titleSmall),
                const SizedBox(height: 2),
                Text(subtitle, style: t.bodySmall),
              ]),
            ),
          ),
          if (action != null) ...[const SizedBox(width: AppSpacing.sm), action],
        ]),
        if (widget.showManage && _state != _CardState.readOnly && _state != _CardState.notConnected)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () async {
                await context.push('/p/devices');
                widget.onChanged();
              },
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 36)),
              child: Text(l10n.wearManageDevicesButton),
            ),
          ),
      ]),
    );
  }
}

/// Small "Last synced 10:32 AM" line with a sync icon; tapping syncs (or refreshes on web).
class SyncIndicator extends ConsumerWidget {
  const SyncIndicator({super.key, required this.devices, required this.onTap, this.offline = false});
  final List<WearableConnection> devices;
  final VoidCallback onTap;
  final bool offline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final connection = healthConnections(devices).firstOrNull;
    if (connection == null && !offline) return const SizedBox.shrink();
    final syncedText = lastSyncedText(l10n, connection?.lastSyncedAt);
    final text = offline ? '${l10n.wearOfflineLabel} · $syncedText' : syncedText;
    return Semantics(
      button: true,
      label: '$text ${l10n.wearTapToSyncHint}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.controlBorder,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(offline ? Icons.cloud_off_outlined : Icons.sync, size: 16, color: offline ? AppColors.warningText : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: offline ? AppColors.warningText : null)),
          ]),
        ),
      ),
    );
  }
}

/// Read-only summary for doctors and admins: which platform supplies the data and how fresh it is.
class HealthSourceSummary extends StatelessWidget {
  const HealthSourceSummary({super.key, required this.devices});
  final List<WearableConnection> devices;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final connections = healthConnections(devices);
    return Row(children: [
      const Icon(Icons.favorite_border, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          connections.isEmpty
              ? l10n.wearNoneConnectedSummary
              : connections.map((c) => '${c.deviceName} · ${lastSyncedText(l10n, c.lastSyncedAt)}').join('   '),
          style: t.bodySmall,
        ),
      ),
    ]);
  }
}

/// Maps a thrown connection error to what the connect screen should show.
enum ConnectFailure { denied, needsInstall, unavailable, failed }

ConnectFailure connectFailureOf(Object error) => switch (error) {
      WearableAuthorizationDenied() => ConnectFailure.denied,
      HealthNeedsInstall() => ConnectFailure.needsInstall,
      HealthUnavailable() => ConnectFailure.unavailable,
      _ => ConnectFailure.failed,
    };
