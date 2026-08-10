import 'dart:ui';
import 'package:flutter/material.dart';
import 'screens/main_navigation_screen.dart';

void main() {
  FlutterError.onError = (FlutterErrorDetails details) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(
                'FLUTTER ERROR:\n\n'
                    '${details.exception}\n\n'
                    '${details.stack}',
              ),
            ),
          ),
        ),
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Text(
                'UNCAUGHT ERROR:\n\n'
                    '$error\n\n'
                    '$stack',
              ),
            ),
          ),
        ),
      ),
    );

    return true;
  };

  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patrimonio & Spese',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}