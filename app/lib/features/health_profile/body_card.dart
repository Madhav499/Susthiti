import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../data/models/patient.dart';

/// Height, weight and BMI. BMI is always calculated by SUSTHITI from the latest height and weight
/// in the health profile, so the patient, their doctor and the admin all see the same value.
class BodyMeasurementsCard extends StatelessWidget {
  const BodyMeasurementsCard({super.key, required this.body, required this.patientId, this.canEdit = false});
  final BodyMeasurements body;
  final String patientId;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KeyValueRow('Height', body.heightCm == null ? 'Not recorded' : '${_num(body.heightCm!)} cm'),
        KeyValueRow('Weight', body.weightKg == null ? 'Not recorded' : '${_num(body.weightKg!)} kg${body.weightRecordedAt == null ? '' : ' (${Fmt.date(body.weightRecordedAt)})'}'),
        KeyValueRow('BMI', body.bmi == null ? 'Needs height and weight' : body.bmi!.toStringAsFixed(1)),
        Text('BMI is calculated automatically from height and weight.', style: t.bodySmall),
        if (canEdit) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/r/$patientId/health-profile'),
              icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.primary),
              label: Text(body.bmi == null ? 'Add height and weight' : 'Update height or weight'),
            ),
          ),
        ],
      ]),
    );
  }

  static String _num(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
}
