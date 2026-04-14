import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const KiomiApp());
}

class KiomiApp extends StatelessWidget {
  const KiomiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '키오미',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3D8FE0), // 키오미 블루
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.3),
          headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.3),
          bodyLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, height: 1.6),
          bodyMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w400, height: 1.5),
          labelLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 64),
            textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
