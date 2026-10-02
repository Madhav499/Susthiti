import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class TableColumnSpec<T> {
  const TableColumnSpec(this.label, this.cell, {this.flex = 2, this.tabletVisible = true});

  final String label;
  final Widget Function(T row) cell;
  final int flex;

  /// Tablet shows a condensed table: columns with false are hidden there.
  final bool tabletVisible;
}

/// Same data, different presentation: a full table on desktop, a condensed table on tablet
/// and cards on phones (never ten columns squeezed onto a phone).
class ResponsiveTable<T> extends StatelessWidget {
  const ResponsiveTable({super.key, required this.rows, required this.columns, required this.mobileCard, this.onRowTap, this.trailing, this.trailingWidth = 176});

  final List<T> rows;
  final List<TableColumnSpec<T>> columns;
  final Widget Function(T row) mobileCard;
  final void Function(T row)? onRowTap;

  /// Actions cell at the end of every desktop/tablet row (e.g. a View button and menu).
  final Widget Function(T row)? trailing;
  final double trailingWidth;

  /// Decided by the width actually available (a tablet in portrait with a rail gets cards).
  static const cardsBelow = 700.0;
  static const condensedBelow = 980.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      if (width < cardsBelow) {
        return Column(children: [
          for (final r in rows) Padding(padding: const EdgeInsets.only(bottom: AppSpacing.sm), child: mobileCard(r)),
        ]);
      }
      return _table(context, [for (final c in columns) if (width >= condensedBelow || c.tabletVisible) c]);
    });
  }

  Widget _table(BuildContext context, List<TableColumnSpec<T>> visible) {
    final t = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorder,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: ClipRRect(
        borderRadius: AppRadius.cardBorder,
        child: Column(children: [
          Container(
            color: AppColors.primaryFaint,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lgPlus, vertical: AppSpacing.md),
            child: Row(children: [
              for (final c in visible) Expanded(flex: c.flex, child: Text(c.label.toUpperCase(), style: t.labelSmall?.copyWith(letterSpacing: 0.6, color: AppColors.textSecondary))),
              if (trailing != null) SizedBox(width: trailingWidth),
            ]),
          ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _TableRow(
              onTap: onRowTap == null ? null : () => onRowTap!(rows[i]),
              child: Row(children: [
                for (final c in visible)
                  Expanded(
                    flex: c.flex,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: c.cell(rows[i]),
                    ),
                  ),
                if (trailing != null) SizedBox(width: trailingWidth, child: Align(alignment: Alignment.centerRight, child: FittedBox(fit: BoxFit.scaleDown, child: trailing!(rows[i])))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppColors.primaryFaint,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lgPlus, vertical: AppSpacing.md), child: child),
      ),
    );
  }
}

/// Status chip cell: left-aligned, and scaled down rather than overflowing a narrow column.
class PillCell extends StatelessWidget {
  const PillCell(this.child, {super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: child));
}

/// Two-line cell: primary text over a muted secondary line.
class CellText extends StatelessWidget {
  const CellText(this.primary, {super.key, this.secondary, this.bold = false});
  final String primary;
  final String? secondary;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(primary, style: bold ? t.titleSmall : t.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
      if (secondary != null && secondary!.isNotEmpty) Text(secondary!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
    ]);
  }
}
