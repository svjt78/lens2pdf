import 'package:flutter/material.dart';
import 'screens/library_screen.dart';
import 'screens/capture_screen.dart';
import 'screens/review_screen.dart';
import 'screens/export_screen.dart';
import 'screens/pdf_view_screen.dart';
import 'screens/settings_screen.dart';

// Observe navigation so Library can refresh when returning.
final RouteObserver<PageRoute<dynamic>> routeObserver =
    RouteObserver<PageRoute<dynamic>>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScannerApp());
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image to PDF Scanner',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      initialRoute: LibraryScreen.route,
      navigatorObservers: [routeObserver],
      routes: {
        LibraryScreen.route: (_) => const LibraryScreen(),
        CaptureScreen.route: (_) => const CaptureScreen(),
        ReviewScreen.route: (_) => const ReviewScreen(),
        ExportScreen.route: (_) => const ExportScreen(),
        PdfViewScreen.route: (_) => const PdfViewScreen(),
        SettingsScreen.route: (_) => const SettingsScreen(),
      },
    );
  }
}
