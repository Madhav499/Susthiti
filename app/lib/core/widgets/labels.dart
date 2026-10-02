import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'feedback.dart';

/// Pill for status, tags, categories and severity. Always text + a small dot, never color alone.
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = StatusTone.info, this.dot = true});

  final String label;
  final StatusTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              Container(width: 6, height: 6, decoration: BoxDecoration(color: tone.indicator, shape: BoxShape.circle)),
              const SizedBox(width: 6),
            ],
            Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: tone.foreground, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Marks AI-generated content so it never looks like a doctor's note.
class AiLabel extends StatelessWidget {
  const AiLabel({super.key, this.text = 'AI-generated'});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: text,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryFaint,
          border: Border.all(color: AppColors.primaryBorder),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.auto_awesome_outlined, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(text, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

/// Labels development/demo data so it can never be mistaken for real health data.
class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key, this.label = 'DEMO'});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Demonstration data, not real health data',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: AppColors.warningSoft, borderRadius: BorderRadius.circular(6), border: Border.all(color: AppColors.warning)),
        child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.warningText, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
      ),
    );
  }
}

/// Data source transparency: Manual, Device, Doctor, Patient, Admin, AI generated.
class SourceLabel extends StatelessWidget {
  const SourceLabel(this.source, {super.key});
  final String source;

  static IconData _icon(String s) => switch (s.toLowerCase()) {
        'device' => Icons.watch_outlined,
        'doctor' => Icons.medical_services_outlined,
        'admin' => Icons.admin_panel_settings_outlined,
        'imported' => Icons.download_outlined,
        'ai' || 'ai generated' => Icons.auto_awesome_outlined,
        _ => Icons.edit_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final label = source.isEmpty ? source : '${source[0].toUpperCase()}${source.substring(1)}';
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(_icon(source), size: 14, color: AppColors.textSecondary),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.labelMedium),
    ]);
  }
}

/// Clearly displayed Patient ID with a copy button.
class PatientIdTile extends StatelessWidget {
  const PatientIdTile(this.patientCode, {super.key, this.compact = false});
  final String patientCode;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: compact ? AppSpacing.sm : AppSpacing.md),
      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.cardBorder),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Patient ID', style: t.labelMedium),
            const SizedBox(height: 2),
            SelectableText(patientCode, style: t.titleMedium?.copyWith(color: AppColors.primary, letterSpacing: 0.8, fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
        ),
        IconButton(
          tooltip: 'Copy Patient ID',
          icon: const Icon(Icons.copy_outlined, color: AppColors.primary),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: patientCode));
            if (context.mounted) showToast(context, 'Patient ID copied');
          },
        ),
      ]),
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.tone = StatusTone.info, this.size = 40});
  final IconData icon;
  final StatusTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: tone.background, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(icon, size: size * 0.5, color: tone.foreground),
    );
  }
}
