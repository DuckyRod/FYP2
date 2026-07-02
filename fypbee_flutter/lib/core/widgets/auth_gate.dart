import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/current_user.dart';
import '../services/notification_service.dart';

import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/admin_dashboard.dart';
import '../../features/dashboard/presentation/moderator_dashboard.dart';
import '../../features/dashboard/presentation/student_dashboard.dart';
import '../../features/dashboard/presentation/supervisor_dashboard.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final firebaseUser = authSnapshot.data;

        if (firebaseUser == null) {
          CurrentUser.clear();
          return const LoginScreen();
        }

        return _RestoreUserSession(firebaseUser: firebaseUser);
      },
    );
  }
}

class _RestoreUserSession extends StatefulWidget {
  final User firebaseUser;

  const _RestoreUserSession({
    required this.firebaseUser,
  });

  @override
  State<_RestoreUserSession> createState() => _RestoreUserSessionState();
}

class _RestoreUserSessionState extends State<_RestoreUserSession> {
  late final Future<Widget> _destinationFuture;

  @override
  void initState() {
    super.initState();
    _destinationFuture = _restoreSession();
  }

  Future<Widget> _restoreSession() async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.firebaseUser.uid)
        .get();

    if (!userDoc.exists || userDoc.data() == null) {
      await FirebaseAuth.instance.signOut();
      throw Exception('User profile not found.');
    }

    final userData = Map<String, dynamic>.from(userDoc.data()!);

    userData['uid'] = widget.firebaseUser.uid;
    userData['email'] = userData['email'] ?? widget.firebaseUser.email;

    final status = userData['status']?.toString();
    final role = userData['role']?.toString();

    if (status != 'approved') {
      await FirebaseAuth.instance.signOut();
      throw Exception('This account is not approved.');
    }

    // Restore your in-memory CurrentUser after restarting the app.
    CurrentUser.setUser(userData);

    // Regenerate/save the FCM token for the restored account.
    await NotificationService.init();

    switch (role) {
      case 'student':
        return const StudentDashboard();

      case 'supervisor':
        return const SupervisorDashboard();

      case 'moderator':
        return const ModeratorDashboard();

      case 'admin':
        return const AdminDashboard();

      default:
        await FirebaseAuth.instance.signOut();
        throw Exception('Invalid user role.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destinationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error.toString(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                      },
                      child: const Text('Return to Login'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return snapshot.data ?? const LoginScreen();
      },
    );
  }
}
