import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/labels.dart';
import '../../data/models/diabetes.dart';

/// Responsible result presentation: the model's classification (Positive / Negative) and its
/// classification probability, worded as a screening pattern, never a diagnosis or future risk.
class AssessmentResultBlock extends StatelessWidget {
  const AssessmentResultBlock({super.key, required this.assessment, this.onMeaning});
  final DiabetesAssessment assessment;
  final VoidCallback? onMeaning;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final a = assessment;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('ML screening result', style: t.labelMedium),
      const SizedBox(height: AppSpacing.lg),
      Center(child: ClassificationRing(positive: a.isPositive, probability: a.classificationProbability, size: 136)),
      const SizedBox(height: AppSpacing.lg),
      Center(child: ClassificationPill(positive: a.isPositive)),
      const SizedBox(height: AppSpacing.sm),
      SizedBox(width: double.infinity, child: Text(a.headline, style: t.headlineSmall, textAlign: TextAlign.center)),
      const SizedBox(height: AppSpacing.lg),
      Wrap(spacing: AppSpacing.xl, runSpacing: AppSpacing.md, children: [
        _Fact('Model classification', a.prediction),
        _Fact(ScreeningWording.probabilityLabel, Fmt.modelProbability(a.classificationProbability)),
        _Fact('Assessed', Fmt.dateTime(a.assessedAt)),
      ]),
      const SizedBox(height: AppSpacing.sm),
      Text(ScreeningWording.probabilityCaption, style: t.bodySmall),
      if (onMeaning != null) ...[
        const SizedBox(height: AppSpacing.lg),
        OutlinedButton.icon(onPressed: onMeaning, icon: const Icon(Icons.help_outline), label: const Text('View What This Means')),
      ],
    ]);
  }
}

/// Circular view of the model's classification probability (for the Positive class), exactly as
/// the model returned it. Never a chance of developing diabetes.
class ClassificationRing extends StatelessWidget {
  const ClassificationRing({super.key, required this.positive, required this.probability, this.size = 120});

  final bool positive;
  final double? probability;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tone = positive ? StatusTone.attention : StatusTone.positive;
    return Semantics(
      label: 'Model classification ${positive ? 'Positive' : 'Negative'}, ${ScreeningWording.probabilityLabel} ${Fmt.modelProbability(probability)}',
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(value: (probability ?? 0).clamp(0, 1).toDouble(), color: tone.indicator),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(Fmt.modelProbability(probability), style: t.headlineSmall?.copyWith(fontSize: size * 0.2, fontFeatures: const [FontFeature.tabularFigures()])),
              Text('probability', style: t.labelSmall),
            ]),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color});
  final double value;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Offset(stroke / 2, stroke / 2) & Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = AppColors.surfaceSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * value, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color;
}

/// Positive / Negative as text plus a muted tone (never color alone, never alarming).
class ClassificationPill extends StatelessWidget {
  const ClassificationPill({super.key, required this.positive});
  final bool positive;

  @override
  Widget build(BuildContext context) => StatusPill(positive ? 'Positive' : 'Negative', tone: positive ? StatusTone.attention : StatusTone.positive);
}

/// "What this means": the model's own interpretation, stated as a pattern.
class ResultMeaningCard extends StatelessWidget {
  const ResultMeaningCard({super.key, required this.assessment});
  final DiabetesAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.cardBorder, border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('What this means', style: t.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(assessment.explanation, style: t.bodyMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          assessment.isPositive
              ? 'Consider sharing this result with a doctor. Tests such as fasting glucose or HbA1c are how diabetes is actually diagnosed.'
              : 'This does not rule out diabetes. If you have symptoms or concerns, talk to a doctor.',
          style: t.bodySmall,
        ),
      ]),
    );
  }
}

/// The disclaimer, visible on the result (not hidden in a tooltip).
class ResultDisclaimerCard extends StatelessWidget {
  const ResultDisclaimerCard({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(color: AppColors.surfaceSecondary, borderRadius: AppRadius.cardBorder),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Important', style: t.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(text, style: t.bodySmall?.copyWith(color: AppColors.textPrimary)),
          ]),
        ),
      ]),
    );
  }
}

/// One yes/no question with two clearly selected buttons. Screen readers hear the question and
/// the current answer.
class YesNoQuestion extends StatelessWidget {
  const YesNoQuestion({super.key, required this.question, required this.value, required this.onChanged});
  final String question;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget option(String label) {
      final selected = value == label;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: '$question: $label',
          excludeSemantics: true,
          child: Material(
            color: selected ? AppColors.primarySoft : AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder, side: BorderSide(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => onChanged(label),
              child: SizedBox(
                height: 48,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  if (selected) ...[const Icon(Icons.check, size: 18, color: AppColors.primaryDeep), const SizedBox(width: 6)],
                  Text(label, style: t.labelLarge?.copyWith(color: selected ? AppColors.primaryDeep : AppColors.textPrimary)),
                ]),
              ),
            ),
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(question, style: t.bodyLarge),
        const SizedBox(height: AppSpacing.sm),
        Row(children: [option('Yes'), const SizedBox(width: AppSpacing.sm), option('No')]),
      ]),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: t.labelMedium),
      const SizedBox(height: 2),
      Text(value, style: t.titleMedium),
    ]);
  }
}

Future<void> showAssessmentMeaning(BuildContext context) {
  final t = Theme.of(context).textTheme;
  Widget section(String title, String body) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.titleSmall),
          const SizedBox(height: 4),
          Text(body, style: t.bodyMedium),
        ]),
      );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.xxl),
        children: [
          Text('What this assessment means', style: t.titleLarge),
          const SizedBox(height: AppSpacing.lg),
          section('What the model does',
              'A trained machine-learning model (an RBF support vector machine) looks at your age, gender and 14 yes/no symptom answers and classifies whether they match a pattern associated with diabetes in the data it was trained on.'),
          section(ScreeningWording.probabilityLabel,
              'The probability the model assigns to the Positive (diabetes-related pattern) class for the answers you gave. A low value goes with a Negative result. It is not the probability that you have or will develop diabetes.'),
          section("What it can't tell you",
              "It is not a diagnosis, and it cannot predict whether or when you might develop diabetes. The training data doesn't include long-term follow-up, so no timeframe can be estimated."),
          section('What to do next',
              'Share the result with your doctor, especially if it shows an elevated risk pattern or your symptoms continue. Tests such as fasting glucose or HbA1c are how diabetes is actually diagnosed.'),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: AppRadius.controlBorder),
            child: Text('If you feel very unwell, seek medical care promptly. SUSTHITI does not replace professional medical diagnosis, treatment, or emergency care.', style: t.bodySmall?.copyWith(color: AppColors.textPrimary)),
          ),
        ],
      ),
    ),
  );
}
