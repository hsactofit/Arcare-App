import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await GoogleSignIn.instance.initialize();

  final prefs = await SharedPreferences.getInstance();
  final themeStr = prefs.getString('theme_mode') ?? 'system';
  if (themeStr == 'light') {
    themeNotifier.value = ThemeMode.light;
  } else if (themeStr == 'dark') {
    themeNotifier.value = ThemeMode.dark;
  } else {
    themeNotifier.value = ThemeMode.system;
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentThemeMode, _) {
        return MaterialApp(
          title: 'Wellness Sync',
          debugShowCheckedModeBanner: false,
          themeMode: currentThemeMode,
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
      },
    );
  }
}
