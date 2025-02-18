import 'package:flutter/material.dart';
import 'auth_screen.dart';
import 'tracker_screen.dart';
import 'reports_screen.dart';
import 'qgenda_screen_v1.dart';

void main() {
  runApp(const PayTrackerApp());
}

class PayTrackerApp extends StatefulWidget {
  const PayTrackerApp({super.key});

  @override
  _PayTrackerAppState createState() => _PayTrackerAppState();
}

class _PayTrackerAppState extends State<PayTrackerApp> {
  List<Map<String, dynamic>> _entries = [];

  void _updateEntries(List<Map<String, dynamic>> entries) {
    setState(() {
      // This merges or replaces the entire list with new entries
      _entries = entries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => AuthScreen(),
        '/tracker': (context) =>
            ShiftDifferentialTracker(updateEntries: _updateEntries),
        '/qgenda': (context) => QgendaIntegrationNew(),
        // Notice we pass the parent's _entries to the ReportsScreen constructor
        '/reports': (context) => ReportsScreen(entries: _entries),
      },
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        primaryColor: Colors.blue,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.blue),
          titleTextStyle: TextStyle(
            color: Colors.blue,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.blue,
          ),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.blue),
          ),
          labelStyle: TextStyle(color: Colors.blue),
        ),
        dialogTheme: const DialogTheme(
          backgroundColor: Colors.white,
          titleTextStyle: TextStyle(color: Colors.blue, fontSize: 18),
          contentTextStyle: TextStyle(color: Colors.black),
        ),
      ),
    );
  }
}
