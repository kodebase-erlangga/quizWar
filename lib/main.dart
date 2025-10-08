/// QuizWar Application
/// A Flutter app for creating and playing quizzes with friends
///
/// Features:
/// - Google Sign-in authentication
/// - Online and offline quiz modes
/// - Friend system
/// - Custom question creation

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'screens/splash_screen.dart';
import 'screens/auth_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'firebase_options.dart';

/// Entry point of the application
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const QuizWarApp());
}

/// Main application widget
///
/// Configures the MaterialApp with themes, navigation, and initial route
class QuizWarApp extends StatelessWidget {
  const QuizWarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Navigation configuration
      home: const SplashScreen(),

      // Error handling for routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const AuthScreen(),
        );
      },
    );
  }
}
