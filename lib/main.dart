import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wellness Sync',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system, // Auto switch light/dark mode based on device system settings
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6D55),
          brightness: Brightness.light,
          primary: const Color(0xFFFF6D55),
          secondary: const Color(0xFF2EE5A3),
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Rounded', // Beautiful rounded typography matching premium design guidelines
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0D10),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF6D55),
          brightness: Brightness.dark,
          primary: const Color(0xFFFF6D55),
          secondary: const Color(0xFF2EE5A3),
          surface: const Color(0xFF0F1318),
        ),
        useMaterial3: true,
        fontFamily: 'SF Pro Rounded',
      ),
      home: const SplashScreen(),
    );
  }
}
