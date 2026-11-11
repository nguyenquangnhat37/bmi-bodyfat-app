import 'package:flutter/material.dart';

import 'admob_service.dart';
import 'measurement_input_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AdMobService.instance.initialize();
  runApp(const BodyTrackerApp());
}

class BodyTrackerApp extends StatelessWidget {
  const BodyTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Đo BMI & Mỡ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: Brightness.light),
      darkTheme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal, brightness: Brightness.dark),
      home: const MeasurementInputScreen(),
    );
  }
}
