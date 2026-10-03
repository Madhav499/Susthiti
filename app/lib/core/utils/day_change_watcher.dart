import 'dart:async';

import 'package:flutter/widgets.dart';

/// Watches the device's local calendar day and calls [onChanged] once when it advances --
/// whether the app was resumed on a new day, or stayed open and foregrounded across midnight.
/// Screens showing "today" data create one in initState and dispose it in dispose, instead of
/// relying on a timer alone (suspended while the app is backgrounded) or app-resume alone
/// (misses a day that turns over while the screen stays open in the foreground).
class DayChangeWatcher with WidgetsBindingObserver {
  DayChangeWatcher(this.onChanged) {
    _day = _today();
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _check());
  }

  final VoidCallback onChanged;
  late DateTime _day;
  late final Timer _timer;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _check() {
    final day = _today();
    if (day != _day) {
      _day = day;
      onChanged();
    }
  }

  void dispose() {
    _timer.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}
