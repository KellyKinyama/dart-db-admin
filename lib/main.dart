import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'state/app_state.dart';

void main() {
  runApp(const DartDbAdminApp());
}

class DartDbAdminApp extends StatelessWidget {
  const DartDbAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..load(),
      child: MaterialApp(
        title: 'dart-db Admin',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2962FF),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF2962FF),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        home: const HomeShell(),
      ),
    );
  }
}
