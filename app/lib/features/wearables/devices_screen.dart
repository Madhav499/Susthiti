import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_page.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/health.dart';
import '../../data/models/tracking.dart';
import '../../data/providers.dart';
import 'health_connection.dart';

export 'health_connection.dart' show devicesProvider, wearableProvidersProvider;

/// Connected Devices: what health data is connected, what is being synced, when it last synced,
/// which permissions are active, and how to disconnect.
class DevicesScreen extends ConsumerWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devices = ref.watch(devicesProvider);
    final t = Theme.of(context).textTheme;
    void refresh() {
      ref.invalidate(devicesProvider);
      ref.invalidate(wearableProvidersProvider);
    }

    return AppPage(
      title: 'Connected Devices',
      body: PageBody(maxWidth: 760, onRefresh: () async => refresh(), children: [
        AsyncBody(
          value: devices,
          onRetry: refresh,
          loading: const SkeletonList(count: 2),
          data: (items) {
            final health = healthConnections(items);
            final demo = [for (final d in items) if (d.isDemo && d.status != 'disconnected') d];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              HealthConnectionCard(devices: items, onChanged: refresh, showManage: false),
              const SizedBox(height: AppSpacing.section),
              const SectionHeader('Health data sources', subtitle: 'Synced data is stored in your SUSTHITI record, so it is the same on your phone, tablet and the web.'),
              if (health.isEmpty && demo.isEmpty)
                AppCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('No health device connected.', style: t.titleSmall),
                    const SizedBox(height: 4),
                    Text('Connect a supported health platform to automatically sync your lifestyle data.', style: t.bodySmall),
                  ]),
                )
              else
                for (final d in [...health, ...demo]) ...[ConnectedSourceTile(device: d, onChanged: refresh), const SizedBox(height: AppSpacing.sm)],
              const SizedBox(height: AppSpacing.section),
              _DemoSection(connected: demo.isNotEmpty, onChanged: refresh),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Disconnecting stops new data from syncing. Data already synced stays in your history. '
                'To change what SUSTHITI may read, use Health Connect (Android) or Settings, then Health (iPhone).',
                style: t.bodySmall,
              ),
            ]);
          },
        ),
      ]),
    );
  }
}

/// One connected source with its permissions, freshness and controls.
class ConnectedSourceTile extends ConsumerStatefulWidget {
  const ConnectedSourceTile({super.key, required this.device, required this.onChanged});
  final WearableConnection device;
  final VoidCallback onChanged;

  @override
  ConsumerState<ConnectedSourceTile> createState() => _ConnectedSourceTileState();
}

class _ConnectedSourceTileState extends ConsumerState<ConnectedSourceTile> {
  bool _syncing = false;

  Future<void> _sync() async {
    setState(() => _syncing = true);
    try {
      final outcome = await ref.read(wearableServiceProvider).sync(widget.device);
      widget.onChanged();
      if (mounted && !outcome.device.syncFailed) showToast(context, outcome.upToDate ? 'Already up to date' : 'Synced just now');
    } catch (e) {
      if (mounted) showToast(context, "Sync didn't complete. Check your connection and try again.", error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _disconnect() async {
    final ok = await confirmAction(
      context,
      title: 'Disconnect health data?',
      message: 'SUSTHITI will stop syncing new health data from this source.\n\nPreviously synchronized records will remain available according to your data-retention settings.',
      confirmLabel: 'Disconnect',
    );
    if (!ok) return;
    try {
      await ref.read(wearableServiceProvider).disconnect(widget.device);
      widget.onChanged();
      if (mounted) showToast(context, 'Disconnected. Your synced history is kept.');
    } catch (e) {
      if (mounted) showFailure(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = widget.device;
    final canSync = ref.read(wearableServiceProvider).canSync(d);
    final from = switch (d.platform) { 'android' => 'Android phone', 'ios' => 'iPhone', _ => null };
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          IconBadge(d.isDemo ? Icons.science_outlined : Icons.favorite, tone: d.syncFailed ? StatusTone.attention : StatusTone.positive),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(d.deviceName, style: t.titleSmall),
                if (d.isDemo) const DemoBadge(),
                StatusPill(d.syncFailed ? 'Sync unavailable' : 'Connected', tone: d.syncFailed ? StatusTone.attention : StatusTone.positive),
              ]),
              const SizedBox(height: 2),
              Text(
                [
                  lastSyncedText(d.lastSyncedAt),
                  if (from != null) 'from your $from',
                  if (d.connectedAt != null) 'connected ${Fmt.date(d.connectedAt)}',
                ].join(' · '),
                style: t.bodySmall,
              ),
            ]),
          ),
        ]),
        if (d.syncFailed && d.lastError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(d.lastError!, style: t.bodySmall?.copyWith(color: AppColors.warningText)),
        ],
        const SizedBox(height: AppSpacing.md),
        Text('Permissions', style: t.labelMedium),
        const SizedBox(height: AppSpacing.xs),
        Wrap(spacing: AppSpacing.xs, runSpacing: AppSpacing.xs, children: [
          for (final m in d.supportedMetrics)
            _PermissionChip(label: HealthMetric.tryParse(m)?.label ?? m, granted: d.isGranted(m)),
        ]),
        const SizedBox(height: AppSpacing.md),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
          if (canSync)
            _syncing
                ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
                : OutlinedButton.icon(onPressed: _sync, icon: const Icon(Icons.sync, size: 18), label: Text(d.syncFailed ? 'Retry' : 'Sync Now'))
          else if (!d.isDemo)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Syncs from your ${from ?? 'phone'}. Open SUSTHITI there to sync.', style: t.bodySmall),
            ),
          TextButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.link_off, size: 18),
            label: const Text('Disconnect'),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorText),
          ),
        ]),
      ]),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip({required this.label, required this.granted});
  final String label;
  final bool granted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${granted ? 'shared' : 'not shared'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: granted ? AppColors.successSoft : AppColors.surfaceSecondary, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(granted ? Icons.check : Icons.remove, size: 14, color: granted ? AppColors.successText : AppColors.textMuted),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: granted ? AppColors.successText : AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

/// Development only: the backend's DEMO provider (shown only when the server enables it).
class _DemoSection extends ConsumerStatefulWidget {
  const _DemoSection({required this.connected, required this.onChanged});
  final bool connected;
  final VoidCallback onChanged;

  @override
  ConsumerState<_DemoSection> createState() => _DemoSectionState();
}

class _DemoSectionState extends ConsumerState<_DemoSection> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final providers = ref.watch(wearableProvidersProvider).value ?? const [];
    if (widget.connected || !providers.any((p) => p.isDemo)) return const SizedBox.shrink();
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Row(children: [
        const IconBadge(Icons.science_outlined, tone: StatusTone.attention),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('Try with DEMO data', style: t.titleSmall), const SizedBox(width: 6), const DemoBadge()]),
            Text('Development only. Adds clearly labelled demo values; never real health data.', style: t.bodySmall),
          ]),
        ),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    await ref.read(wearableServiceProvider).connectDemo();
                    widget.onChanged();
                  } catch (e) {
                    if (context.mounted) showFailure(context, e);
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
          child: const Text('Add'),
        ),
      ]),
    );
  }
}
