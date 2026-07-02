import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../domain/entities/selected_supervisor.dart';

class SelectSupervisorScreen extends StatefulWidget {
  const SelectSupervisorScreen({super.key});

  @override
  State<SelectSupervisorScreen> createState() => _SelectSupervisorScreenState();
}

class _SelectSupervisorScreenState extends State<SelectSupervisorScreen> {
  final _searchController = TextEditingController();
  bool _sortAZ = true;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterAndSort(List<QueryDocumentSnapshot> docs) {
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final name = (data['name'] ?? '').toString().toLowerCase();
      final email = (data['email'] ?? '').toString().toLowerCase();
      final id = (data['id'] ?? '').toString().toLowerCase();
      final search = _searchText.toLowerCase();

      return name.contains(search) ||
          email.contains(search) ||
          id.contains(search);
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aName = (aData['name'] ?? aData['id'] ?? '').toString();
      final bName = (bData['name'] ?? bData['id'] ?? '').toString();

      return _sortAZ ? aName.compareTo(bName) : bName.compareTo(aName);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final supervisorsQuery = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'supervisor')
        .where('status', isEqualTo: 'approved');

    return Scaffold(
      appBar: AppBar(title: const Text('Select Supervisor')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search supervisor',
                    hintText: 'Search by name, email, or ID',
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
                      label: Text(_sortAZ ? 'Sort A-Z' : 'Sort Z-A'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: supervisorsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                      child: Text('Failed to load supervisors.'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final supervisors = _filterAndSort(snapshot.data?.docs ?? []);

                if (supervisors.isEmpty) {
                  return const Center(child: Text('No supervisors found.'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: supervisors.length,
                  itemBuilder: (context, index) {
                    final doc = supervisors[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final name = data['name'] ?? data['id'] ?? 'Supervisor';
                    final email = data['email'] ?? '-';
                    final current = data['currentStudents'] ?? 0;
                    final max = data['maxStudents'] ?? 0;
                    final isFull = current >= max;

                    return Card(
                      color: isFull ? Colors.grey.shade300 : null,
                      child: ListTile(
                        enabled: !isFull,
                        leading: CircleAvatar(
                          backgroundColor: isFull
                              ? Colors.grey
                              : Theme.of(context).colorScheme.primary,
                          child: const Icon(Icons.supervisor_account,
                              color: Colors.white),
                        ),
                        title: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFull ? Colors.grey.shade700 : null,
                          ),
                        ),
                        subtitle: Text(
                          email,
                          style: TextStyle(
                            color: isFull ? Colors.grey.shade600 : null,
                          ),
                        ),
                        trailing: Text(
                          '$current/$max',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isFull ? Colors.red : Colors.green,
                          ),
                        ),
                        onTap: isFull
                            ? null
                            : () {
                                Navigator.pop(
                                  context,
                                  SelectedSupervisor(
                                    uid: doc.id,
                                    name: name,
                                    email: email,
                                    currentStudents: current,
                                    maxStudents: max,
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
