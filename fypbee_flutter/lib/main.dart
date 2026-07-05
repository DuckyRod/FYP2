import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/auth_gate.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Cloud Messaging and notification permissions.
  await NotificationService.init();

  runApp(const FYPBeeApp());
}

class FYPBeeApp extends StatelessWidget {
  const FYPBeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FYPBee',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Checks whether Firebase already has a signed-in user.
      home: const AuthGate(),
    );
  }
}
