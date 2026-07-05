import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditUserScreen extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;

  const EditUserScreen({
    super.key,
    required this.uid,
    required this.data,
  });

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _maxController;

  String _role = 'student';
  String _status = 'approved';

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.data['name'] ?? '',
    );

    _maxController = TextEditingController(
      text: (widget.data['maxStudents'] ?? '').toString(),
    );

    _role = widget.data['role'] ?? 'student';
    _status = widget.data['status'] ?? 'approved';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final Map<String, dynamic> updateData = {
      'name': _nameController.text.trim(),
      'role': _role,
      'status': _status,
    };

    if (_role == 'supervisor') {
      updateData['maxStudents'] = int.tryParse(_maxController.text.trim()) ?? 0;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.uid)
        .update(updateData);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User updated'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isSupervisor = _role == 'supervisor';

    return Scaffold(
      appBar: AppBar(title: const Text('Edit User')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(
                labelText: 'Role',
                prefixIcon: Icon(Icons.badge),
              ),
              items: const [
                DropdownMenuItem(value: 'student', child: Text('Student')),
                DropdownMenuItem(
                    value: 'supervisor', child: Text('Supervisor')),
                DropdownMenuItem(value: 'moderator', child: Text('Moderator')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _role = value);
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.verified_user),
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
                DropdownMenuItem(value: 'archived', child: Text('Archived')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _status = value);
                }
              },
            ),
            if (isSupervisor) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _maxController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Students',
                  prefixIcon: Icon(Icons.groups),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save),
                label: const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
