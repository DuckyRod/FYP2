import 'package:flutter/material.dart';
import '../../../../core/data/current_user.dart';
import '../../../../core/widgets/app_button.dart';
import '../data/repositories/auth_repository.dart';
import 'register_screen.dart';

import '../../dashboard/presentation/student_dashboard.dart';
import '../../dashboard/presentation/supervisor_dashboard.dart';
import '../../dashboard/presentation/moderator_dashboard.dart';
import '../../dashboard/presentation/admin_dashboard.dart';
import '../../../../core/services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  final String? initialMessage;
  final bool initialMessageIsError;

  const LoginScreen({
    super.key,
    this.initialMessage,
    this.initialMessageIsError = true,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authRepository = AuthRepository();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    final message = widget.initialMessage;

    if (message != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _showMessage(
          message,
          isError: widget.initialMessageIsError,
        );
      });
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userData = await _authRepository.loginUser(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (userData == null) {
        _showError('User profile not found');
        return;
      }

      final status = userData['status'];
      final role = userData['role'];

      if (status == 'blocked') {
        _showError('Your account has been blocked. Please contact admin.');
        return;
      }

      if (status == 'pending') {
        _showError('Your account is still pending admin approval.');
        return;
      }

      if (status == 'rejected') {
        _showError('Your registration has been rejected.');
        return;
      }

      if (status != 'approved') {
        _showError('Your account is not approved.');
        return;
      }

      // Save current user globally
      CurrentUser.setUser(userData);

      // Save FCM token after login
      await NotificationService.init();

      // Navigate based on role
      if (role == 'admin') {
        _goTo(const AdminDashboard());
      } else if (role == 'student') {
        _goTo(const StudentDashboard());
      } else if (role == 'supervisor') {
        _goTo(const SupervisorDashboard());
      } else if (role == 'moderator') {
        _goTo(const ModeratorDashboard());
      } else {
        _showError('Invalid role');
      }
    } catch (e) {
      if (!mounted) return;
      _showError('Login failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _goTo(Widget page) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  void _showError(String message) {
    _showMessage(message);
  }

  void _showMessage(
    String message, {
    bool isError = true,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            Icon(
              isError ? Icons.error : Icons.check_circle,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Icon(
                    Icons.hive_rounded,
                    size: 90,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'FYPBee',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),

                  const Text(
                    'Mobile All-in-One FYP System',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 36),

                  // Email
                  TextFormField(
                    controller: _emailController,
                    validator: _required,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    validator: _required,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : AppButton(
                            text: 'Login',
                            icon: Icons.login,
                            onPressed: _login,
                          ),
                  ),

                  const SizedBox(height: 16),

                  // Register link
                  TextButton(
                    onPressed: () async {
                      final registered = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ),
                      );

                      if (!mounted) return;

                      if (registered == true) {
                        _showMessage(
                          'Registered. Wait for admin approval.',
                          isError: false,
                        );
                      }
                    },
                    child: const Text("Don't have an account? Register"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
