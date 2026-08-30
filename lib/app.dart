import 'package:flutter/material.dart';

import 'ui/core/theme.dart';
import 'ui/core/tokens.dart';

class ContainerApp extends StatelessWidget {
  const ContainerApp({super.key, this.home});

  /// Overridden by [main]; defaults to a bare surface so widget tests can
  /// pump the app without a database.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Container',
      debugShowCheckedModeBanner: false,
      theme: containerTheme(),
      home: home ?? const Scaffold(backgroundColor: C.bg),
    );
  }
}
