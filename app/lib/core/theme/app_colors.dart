import 'package:flutter/material.dart';

/// The SUSTHITI palette: soft blue on off-white and light blue-gray surfaces.
/// Use these tokens, never ad-hoc colors.
abstract final class AppColors {
  static const primary = Color(0xFF2F80D8);
  static const primaryDeep = Color(0xFF1769AA);
  static const primarySoft = Color(0xFFEAF4FF);
  static const primaryFaint = Color(0xFFF3F8FD);
  static const primaryBorder = Color(0xFFCFE2F6);
  static const secondary = Color(0xFF7FB3E8);

  static const background = Color(0xFFF6F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSecondary = Color(0xFFF1F6FA);

  static const textPrimary = Color(0xFF172B4D);
  static const textSecondary = Color(0xFF64748B);
  static const textMuted = Color(0xFF94A3B8);
  static const border = Color(0xFFDCE6F0);
  static const inactive = textMuted;

  static const success = Color(0xFF4FAF82);
  static const warning = Color(0xFFD9A441);
  static const error = Color(0xFFD96868);
  static const info = Color(0xFF3A8DDB);

  static const successSoft = Color(0xFFEAF8F1);
  static const warningSoft = Color(0xFFFFF7E6);
  static const errorSoft = Color(0xFFFFF0F0);
  static const infoSoft = Color(0xFFEAF4FF);
  static const neutralSoft = Color(0xFFEEF3F8);

  /// Readable text on the soft status backgrounds (the base tones are too light for text).
  static const successText = Color(0xFF2F7D5A);
  static const warningText = Color(0xFF8A6420);
  static const errorText = Color(0xFFA94747);

  /// Dark surface for toasts and error snackbars.
  static const inverseSurface = Color(0xFF1E3350);
  static const errorInverse = Color(0xFF7A3434);

  /// Chart series, in order. Blue first; supporting shades stay calm (no rainbow).
  static const chartSeries = [primary, Color(0xFF7FB3E8), primaryDeep, Color(0xFF4FAF82), Color(0xFFD9A441)];
}

/// Semantic status tones (always shown together with a text label, never color alone).
enum StatusTone { info, positive, attention, critical, inactive }

extension StatusToneColors on StatusTone {
  Color get foreground => switch (this) {
        StatusTone.info => AppColors.primaryDeep,
        StatusTone.positive => AppColors.successText,
        StatusTone.attention => AppColors.warningText,
        StatusTone.critical => AppColors.errorText,
        StatusTone.inactive => AppColors.textSecondary,
      };

  Color get background => switch (this) {
        StatusTone.info => AppColors.infoSoft,
        StatusTone.positive => AppColors.successSoft,
        StatusTone.attention => AppColors.warningSoft,
        StatusTone.critical => AppColors.errorSoft,
        StatusTone.inactive => AppColors.neutralSoft,
      };

  Color get indicator => switch (this) {
        StatusTone.info => AppColors.info,
        StatusTone.positive => AppColors.success,
        StatusTone.attention => AppColors.warning,
        StatusTone.critical => AppColors.error,
        StatusTone.inactive => AppColors.inactive,
      };
}
