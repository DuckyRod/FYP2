import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/current_user.dart';
import '../services/notification_service.dart';
import '../widgets/auth_gate.dart';

class LogoutHelper {
  static void confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                // Remove this device token from the current user before logout.
                await NotificationService.clearTokenForCurrentUser();

                // Sign out from the persistent Firebase session.
                await FirebaseAuth.instance.signOut();

                // Clear locally stored user information.
                CurrentUser.clear();

                if (!context.mounted) return;

                // Remove all existing dashboard screens.
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (_) => const AuthGate(),
                  ),
                  (route) => false,
                );
              } catch (e) {
                if (!context.mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to logout: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
