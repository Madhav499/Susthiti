import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

abstract final class AppTheme {
  static const fontFamily = 'Inter';

  static TextTheme _textTheme() {
    const c = AppColors.textPrimary;
    const muted = AppColors.textSecondary;
    return const TextTheme(
      headlineLarge: TextStyle(fontSize: 30, height: 1.2, fontWeight: FontWeight.w700, color: c, letterSpacing: -0.6),
      headlineMedium: TextStyle(fontSize: 26, height: 1.2, fontWeight: FontWeight.w700, color: c, letterSpacing: -0.4),
      headlineSmall: TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w600, color: c, letterSpacing: -0.2),
      titleLarge: TextStyle(fontSize: 20, height: 1.3, fontWeight: FontWeight.w600, color: c),
      titleMedium: TextStyle(fontSize: 17, height: 1.35, fontWeight: FontWeight.w600, color: c),
      titleSmall: TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w500, color: c),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w400, color: c),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, fontWeight: FontWeight.w400, color: c),
      bodySmall: TextStyle(fontSize: 13, height: 1.45, fontWeight: FontWeight.w400, color: muted),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: muted),
      labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted, letterSpacing: 0.2),
    ).apply(fontFamily: fontFamily); // component themes reuse these styles directly
  }

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primarySoft,
      onPrimaryContainer: AppColors.primary,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.primarySoft,
      tertiary: AppColors.primaryDeep,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.background,
      surfaceContainer: AppColors.background,
      surfaceContainerHigh: AppColors.surface,
      surfaceContainerHighest: AppColors.surfaceSecondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      error: AppColors.error,
      onError: Colors.white,
    );
    final text = _textTheme();
    final buttonShape = RoundedRectangleBorder(borderRadius: AppRadius.buttonBorder);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: text,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleMedium,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.border)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          textStyle: text.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.border),
          backgroundColor: AppColors.surface,
          shape: buttonShape,
          padding: buttonPadding,
          minimumSize: const Size(64, 48),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: buttonShape,
          minimumSize: const Size(48, 44),
          textStyle: text.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 14),
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.textMuted),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textSecondary,
        helperStyle: text.bodySmall,
        helperMaxLines: 3,
        errorMaxLines: 3,
        border: OutlineInputBorder(borderRadius: AppRadius.controlBorder, borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: AppRadius.controlBorder, borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: AppRadius.controlBorder, borderSide: const BorderSide(color: AppColors.primary, width: 1.4)),
        errorBorder: OutlineInputBorder(borderRadius: AppRadius.controlBorder, borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: AppRadius.controlBorder, borderSide: const BorderSide(color: AppColors.error, width: 1.4)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        selectedColor: AppColors.primarySoft,
        side: WidgetStateBorderSide.resolveWith(
          (s) => BorderSide(color: s.contains(WidgetState.selected) ? AppColors.primaryBorder : AppColors.border),
        ),
        labelStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        secondaryLabelStyle: text.bodyMedium?.copyWith(color: AppColors.primaryDeep, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chipBorder),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          side: const WidgetStatePropertyAll(BorderSide(color: AppColors.border)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: AppRadius.controlBorder)),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primarySoft : AppColors.surface),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textPrimary),
          textStyle: WidgetStatePropertyAll(text.labelLarge?.copyWith(fontWeight: FontWeight.w500)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primarySoft,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium?.copyWith(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(color: s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary, size: 24),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primarySoft,
        selectedIconTheme: const IconThemeData(color: AppColors.primary),
        unselectedIconTheme: const IconThemeData(color: AppColors.textSecondary),
        selectedLabelTextStyle: text.labelLarge?.copyWith(color: AppColors.primary),
        unselectedLabelTextStyle: text.labelLarge?.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
        overlayColor: const WidgetStatePropertyAll(AppColors.primaryFaint),
        dividerColor: AppColors.border,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w500),
        tabAlignment: TabAlignment.start,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.panel))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.panelBorder),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.controlBorder),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
        titleTextStyle: text.titleSmall,
        subtitleTextStyle: text.bodySmall,
        iconColor: AppColors.textSecondary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary, linearTrackColor: AppColors.primarySoft, circularTrackColor: AppColors.primarySoft),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
        side: const BorderSide(color: AppColors.textMuted, width: 1.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 3,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.inverseSurface, borderRadius: AppRadius.controlBorder),
        textStyle: text.bodySmall?.copyWith(color: Colors.white),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.cardBorder, side: const BorderSide(color: AppColors.border)),
        textStyle: text.bodyMedium,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : AppColors.inactive),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.surfaceSecondary),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.border),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.primary : AppColors.textSecondary)),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
