import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/failures.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

void showToast(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.errorInverse : null,
    duration: const Duration(seconds: 3),
  ));
}

void showFailure(BuildContext context, Object error) => showToast(context, asFailure(error).message, error: true);

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction, this.compact = false});

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? AppSpacing.lg : AppSpacing.xxl, horizontal: AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 44 : 56,
            height: compact ? 44 : 56,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.primary, size: compact ? 22 : 26),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(title, style: t.titleSmall, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Text(message!, style: t.bodySmall, textAlign: TextAlign.center)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.lg),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// What happened + what the user can do + retry.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, this.onRetry, this.title, this.reassurance, this.compact = false});

  final Object error;
  final VoidCallback? onRetry;
  final String? title;
  final String? reassurance;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final failure = asFailure(error);
    final t = Theme.of(context).textTheme;
    final heading = title ??
        switch (failure) {
          NetworkFailure() || TimeoutFailure() => 'Unable to load this right now.',
          AuthorizationFailure() => 'Access not available.',
          NotFoundFailure() => 'Not found.',
          _ => 'Something went wrong.',
        };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? AppSpacing.lg : AppSpacing.xxl, horizontal: AppSpacing.lg),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.textSecondary, size: 28),
          const SizedBox(height: AppSpacing.md),
          Text(heading, style: t.titleSmall, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.xs),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 380), child: Text(failure.message, style: t.bodySmall, textAlign: TextAlign.center)),
          if (reassurance != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(reassurance!, style: t.bodySmall?.copyWith(color: AppColors.primary), textAlign: TextAlign.center),
          ],
          if (onRetry != null && failure.isRetryable) ...[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try Again')),
          ],
        ]),
      ),
    );
  }
}

/// Soft pulsing placeholder used instead of spinners.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 8});
  final double height;
  final double? width;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: FadeTransition(
        opacity: Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(color: AppColors.neutralSoft, borderRadius: BorderRadius.circular(widget.radius)),
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.count = 4, this.itemHeight = 72});
  final int count;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: Column(children: [
        for (var i = 0; i < count; i++) ...[
          Skeleton(height: itemHeight, radius: AppRadius.card),
          const SizedBox(height: AppSpacing.md),
        ],
      ]),
    );
  }
}

/// Renders an [AsyncValue] with skeleton loading and a retryable error state.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry, this.loading, this.errorTitle, this.errorReassurance, this.keepDataOnError = false});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;
  final Widget? loading;
  final String? errorTitle;
  final String? errorReassurance;

  /// When a refresh fails but earlier data exists, keep showing it (the caller marks it as not
  /// current) instead of replacing it with an error.
  final bool keepDataOnError;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      skipError: keepDataOnError,
      data: data,
      loading: () => loading ?? const SkeletonList(),
      error: (e, _) => ErrorState(error: e, onRetry: onRetry, title: errorTitle, reassurance: errorReassurance),
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.error) : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Primary button that shows progress while [onPressed] runs and prevents double taps.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false, this.expand = false});

  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool expand;

  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final child = _busy
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
        : Text(widget.label);
    final busyChild = widget.outlined && _busy
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2))
        : child;
    final onPressed = widget.onPressed == null ? null : _run;
    final Widget button = widget.outlined
        ? (widget.icon != null && !_busy
            ? OutlinedButton.icon(onPressed: onPressed, icon: Icon(widget.icon), label: Text(widget.label))
            : OutlinedButton(onPressed: onPressed, child: busyChild))
        : (widget.icon != null && !_busy
            ? FilledButton.icon(onPressed: onPressed, icon: Icon(widget.icon), label: Text(widget.label))
            : FilledButton(onPressed: onPressed, child: busyChild));
    return widget.expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
