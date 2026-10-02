import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Circular initials avatar. Never a generated or stock photograph.
class SusthitiAvatar extends StatelessWidget {
  const SusthitiAvatar(this.name, {super.key, this.size = 40});

  final String name;
  final double size;

  static String initials(String name) {
    final parts = name.replaceAll(RegExp(r'^(Dr\.?\s+)', caseSensitive: false), '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
        child: Text(
          initials(name),
          style: TextStyle(fontSize: size * 0.36, fontWeight: FontWeight.w600, color: AppColors.primaryDeep, height: 1),
        ),
      ),
    );
  }
}
