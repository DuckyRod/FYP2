import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';

class ApproveUsersScreen extends StatelessWidget {
  const ApproveUsersScreen({super.key});

  Future<void> _approveUser(BuildContext context, String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'status': 'approved',
      'approvedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User approved successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _rejectUser(BuildContext context, String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'status': 'rejected',
      'rejectedAt': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('User rejected'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersRef = FirebaseFirestore.instance
        .collection('users')
        .where('status', isEqualTo: 'pending');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approve Users'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: usersRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Something Went Wrong',
              message: 'Unable to load pending users.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = snapshot.data?.docs ?? [];

          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.verified_user_outlined,
              title: 'No Pending Users',
              message: 'Student registration requests will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final doc = users[index];
              final data = doc.data() as Map<String, dynamic>;

              final name = data['name'] ?? 'Unknown User';
              final studentId = data['studentId'] ?? data['id'] ?? '-';
              final email = data['email'] ?? '-';
              final trimester = data['enrollTrimester'] ?? '-';
              final role = data['role'] ?? '-';

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Student ID: $studentId'),
                      Text('Email: $email'),
                      Text('Role: $role'),
                      Text('Trimester: $trimester'),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _approveUser(context, doc.id),
                              icon: const Icon(Icons.check),
                              label: const Text('Approve'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _rejectUser(context, doc.id),
                              icon: const Icon(Icons.close),
                              label: const Text('Reject'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
