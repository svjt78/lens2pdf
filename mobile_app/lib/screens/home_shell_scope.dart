import 'package:flutter/material.dart';

class HomeShellScope extends InheritedWidget {
  const HomeShellScope({
    super.key,
    required this.index,
    required this.onSelectTab,
    required super.child,
  });

  final int index;
  final ValueChanged<int> onSelectTab;

  static HomeShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<HomeShellScope>();
  }

  static HomeShellScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'HomeShellScope not found in context');
    return scope!;
  }

  @override
  bool updateShouldNotify(HomeShellScope oldWidget) => index != oldWidget.index;
}
