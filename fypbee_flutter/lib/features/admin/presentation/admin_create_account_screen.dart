import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/app_button.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();

  final _idController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _maxStudentsController = TextEditingController();
  final _nameController = TextEditingController();

  String _selectedRole = 'student';
  bool _isLoading = false;

  @override
  void dispose() {
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _maxStudentsController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  String? _confirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please confirm password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final uid = credential.user!.uid;

      final data = {
        'uid': uid,
        'id': _idController.text.trim(),
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'status': 'approved',
        'createdBy': 'admin',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (_selectedRole == 'supervisor') {
        data['maxStudents'] =
            int.tryParse(_maxStudentsController.text.trim()) ?? 0;
        data['currentStudents'] = 0;
      }

      await FirebaseFirestore.instance.collection('users').doc(uid).set(data);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully'),
          backgroundColor: Colors.green,
        ),
      );

      _idController.clear();
      _emailController.clear();
      _passwordController.clear();
      _confirmPasswordController.clear();
      _maxStudentsController.clear();
      _nameController.clear();

      setState(() => _selectedRole = 'student');
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Create account failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSupervisor = _selectedRole == 'supervisor';

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  prefixIcon: Icon(Icons.badge),
                ),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Student')),
                  DropdownMenuItem(
                    value: 'supervisor',
                    child: Text('Supervisor'),
                  ),
                  DropdownMenuItem(
                      value: 'moderator', child: Text('Moderator')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedRole = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _idController,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'User ID / Staff ID',
                  prefixIcon: Icon(Icons.perm_identity),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                validator: _required,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                validator: _required,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                validator: _confirmPassword,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
              ),
              if (isSupervisor) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _maxStudentsController,
                  validator: _required,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Maximum Students',
                    hintText: 'Example: 7',
                    prefixIcon: Icon(Icons.groups),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : AppButton(
                        text: 'Create Account',
                        icon: Icons.person_add,
                        onPressed: _createAccount,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
