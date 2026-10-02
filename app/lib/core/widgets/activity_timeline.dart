import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../utils/formatters.dart';

class TimelineEntry {
  const TimelineEntry({required this.title, required this.at, this.subtitle, this.icon, this.tone = StatusTone.info, this.onTap, this.actionLabel});

  final String title;
  final String? subtitle;
  final DateTime at;
  final IconData? icon;
  final StatusTone tone;

  /// Opens the related record, when there is one.
  final VoidCallback? onTap;
  final String? actionLabel;
}

/// Vertical activity timeline: a dot per entry joined by a subtle connector.
class ActivityTimeline extends StatelessWidget {
  const ActivityTimeline({super.key, required this.entries, this.emptyMessage = 'No recent activity.'});

  final List<TimelineEntry> entries;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Text(emptyMessage, style: t.bodyMedium?.copyWith(color: AppColors.textSecondary)),
      );
    }
    return Column(children: [
      for (var i = 0; i < entries.length; i++) _Row(entry: entries[i], first: i == 0, last: i == entries.length - 1),
    ]);
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, required this.first, required this.last});
  final TimelineEntry entry;
  final bool first;
  final bool last;

  static String _when(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final time = Fmt.time(local);
    if (day == today) return 'Today, $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday, $time';
    return '${Fmt.date(local)}, $time';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final content = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_when(entry.at), style: t.labelMedium),
            const SizedBox(height: 2),
            Text(entry.title, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
            if (entry.subtitle != null && entry.subtitle!.isNotEmpty) Text(entry.subtitle!, style: t.bodySmall),
          ]),
        ),
        if (entry.onTap != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Text(entry.actionLabel ?? 'Open', style: t.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
          const Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
        ],
      ]),
    );
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SizedBox(
          width: 28,
          child: Column(children: [
            Container(width: 2, height: 6, color: first ? Colors.transparent : AppColors.border),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: entry.tone.background, shape: BoxShape.circle, border: Border.all(color: entry.tone.indicator, width: 2.5)),
            ),
            Expanded(child: Container(width: 2, color: last ? Colors.transparent : AppColors.border)),
          ]),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: entry.onTap == null
              ? content
              : InkWell(onTap: entry.onTap, borderRadius: AppRadius.controlBorder, child: content),
        ),
      ]),
    );
  }
}
