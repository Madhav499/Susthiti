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

final devicesProvider = FutureProvider.autoDispose<List<WearableConnection>>((ref) => ref.watch(wearableRepositoryProvider).devices());
final wearableProvidersProvider = FutureProvider.autoDispose<List<WearableProvider>>((ref) => ref.watch(wearableRepositoryProvider).providers());

/// Health-platform connections (not the DEMO provider), newest first.
List<WearableConnection> healthConnections(List<WearableConnection> devices) => [for (final d in devices) if (!d.isDemo && d.status != 'disconnected') d];

/// "Last synced 10:32 AM" today, "Last synced 24 Sep, 10:32 AM" otherwise.
String lastSyncedText(DateTime? t) {
  if (t == null) return 'Not synced yet';
  final l = t.toLocal();
  final now = DateTime.now();
  final today = l.year == now.year && l.month == now.month && l.day == now.day;
  if (now.difference(l).inMinutes < 1) return 'Synced just now';
  return 'Last synced ${today ? Fmt.time(l) : Fmt.dateTime(l)}';
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
    setState(() => _syncing = true);
    try {
      final outcome = await ref.read(wearableServiceProvider).sync(c);
      widget.onChanged();
      ref.invalidate(devicesProvider);
      if (!mounted) return;
      if (outcome.device.syncFailed) {
        showToast(context, "Sync didn't complete. Check your health permissions and try again.", error: true);
      } else {
        showToast(context, outcome.upToDate ? 'Already up to date' : 'Synced just now');
      }
    } catch (e) {
      if (mounted) showToast(context, "Sync didn't complete. Check your connection and try again.", error: true);
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
    final c = _connection;
    final platformName = ref.read(wearableServiceProvider).platform.name;
    final (IconData icon, StatusTone tone, String title, String subtitle, Widget? action) = switch (_state) {
      _CardState.notConnected => (
          Icons.favorite_border,
          StatusTone.info,
          'Connect your health data',
          'Sync steps, heart rate, sleep and more from $platformName.',
          FilledButton(onPressed: _connect, child: const Text('Connect')),
        ),
      _CardState.syncing => (
          Icons.sync,
          StatusTone.info,
          'Syncing health data...',
          'Reading new data from $platformName.',
          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4)),
        ),
      _CardState.connected => (
          Icons.favorite,
          StatusTone.positive,
          'Health data connected',
          '${c!.deviceName} · ${lastSyncedText(c.lastSyncedAt)}',
          OutlinedButton.icon(onPressed: _sync, icon: const Icon(Icons.sync, size: 18), label: const Text('Sync Now')),
        ),
      _CardState.error => (
          Icons.sync_problem,
          StatusTone.attention,
          'Sync unavailable',
          c?.lastError ?? 'The last sync did not complete.',
          FilledButton(onPressed: _sync, child: const Text('Retry')),
        ),
      _CardState.readOnly => c == null
          ? (
              Icons.phone_iphone,
              StatusTone.inactive,
              'Health data not connected',
              'Connect health data from the SUSTHITI mobile app (Lifestyle, then Connect). It will appear here automatically.',
              null,
            )
          : (
              Icons.favorite,
              StatusTone.positive,
              'Health data',
              'Connected through ${c.platform == 'ios' ? 'Apple Health on iPhone' : c.platform == 'android' ? 'Health Connect on Android' : 'the mobile health platform'} · ${lastSyncedText(c.lastSyncedAt)}',
              OutlinedButton.icon(onPressed: widget.onChanged, icon: const Icon(Icons.refresh, size: 18), label: const Text('Refresh')),
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
              child: const Text('Manage connected devices'),
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
    final connection = healthConnections(devices).firstOrNull;
    if (connection == null && !offline) return const SizedBox.shrink();
    final text = offline ? 'Offline · ${lastSyncedText(connection?.lastSyncedAt)}' : lastSyncedText(connection?.lastSyncedAt);
    return Semantics(
      button: true,
      label: '$text. Tap to sync.',
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
    final connections = healthConnections(devices);
    return Row(children: [
      const Icon(Icons.favorite_border, size: 18, color: AppColors.textSecondary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(
        child: Text(
          connections.isEmpty
              ? 'No health platform connected. Values shown were entered manually.'
              : connections.map((c) => '${c.deviceName} · ${lastSyncedText(c.lastSyncedAt)}').join('   '),
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
