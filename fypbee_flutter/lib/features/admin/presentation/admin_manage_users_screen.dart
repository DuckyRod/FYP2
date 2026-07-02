import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import 'admin_edit_user_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _searchController = TextEditingController();

  bool _sortAZ = true;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterAndSort(
    List<QueryDocumentSnapshot> docs,
  ) {
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final name = (data['name'] ?? '').toString().toLowerCase();

      final role = (data['role'] ?? '').toString().toLowerCase();

      final status = (data['status'] ?? '').toString().toLowerCase();

      final search = _searchText.toLowerCase();

      return name.contains(search) ||
          role.contains(search) ||
          status.contains(search);
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aName = (aData['name'] ?? '').toString();

      final bName = (bData['name'] ?? '').toString();

      return _sortAZ ? aName.compareTo(bName) : bName.compareTo(aName);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final usersQuery =
        FirebaseFirestore.instance.collection('users').snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Users'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search user',
                    hintText: 'Search by name, role, or status',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() => _searchText = value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() => _sortAZ = !_sortAZ);
                      },
                      icon: Icon(
                        _sortAZ ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 18,
                      ),
                      label: Text(
                        _sortAZ ? 'Sort A-Z' : 'Sort Z-A',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: usersQuery,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error,
                    title: 'Error',
                    message: 'Failed to load users',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final users = _filterAndSort(
                  snapshot.data?.docs ?? [],
                );

                if (users.isEmpty) {
                  return const EmptyState(
                    icon: Icons.person_outline,
                    title: 'No Users',
                    message: 'No matching users found',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final doc = users[index];

                    final data = doc.data() as Map<String, dynamic>;

                    final name = data['name'] ?? '-';
                    final role = data['role'] ?? '-';
                    final status = data['status'] ?? '-';

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(name),
                        subtitle: Text(
                          'Role: $role\nStatus: $status',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.edit),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditUserScreen(
                                uid: doc.id,
                                data: data,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
