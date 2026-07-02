import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/data/current_user.dart';
import '../../../../core/widgets/empty_state.dart';
import 'supervisor_detail_meeting_log_screen.dart';

class MonitorProgressScreen extends StatefulWidget {
  const MonitorProgressScreen({super.key});

  @override
  State<MonitorProgressScreen> createState() => _MonitorProgressScreenState();
}

class _MonitorProgressScreenState extends State<MonitorProgressScreen> {
  final _searchController = TextEditingController();

  bool _sortAZ = true;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filterAndSort(
    List<Map<String, dynamic>> students,
  ) {
    final search = _searchText.toLowerCase();

    final filtered = students.where((student) {
      final name = (student['studentName'] ?? '').toString().toLowerCase();
      final id = (student['studentId'] ?? '').toString().toLowerCase();
      final email = (student['studentEmail'] ?? '').toString().toLowerCase();
      final proposal =
          (student['proposalTitle'] ?? '').toString().toLowerCase();
      final status = (student['proposalStatus'] ?? '').toString().toLowerCase();

      return name.contains(search) ||
          id.contains(search) ||
          email.contains(search) ||
          proposal.contains(search) ||
          status.contains(search);
    }).toList();

    filtered.sort((a, b) {
      final aName = (a['studentName'] ?? '').toString();
      final bName = (b['studentName'] ?? '').toString();

      return _sortAZ ? aName.compareTo(bName) : bName.compareTo(aName);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final supervisorUid = CurrentUser.uid;

    if (supervisorUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monitor Progress')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'User Not Found',
          message: 'Please login again.',
        ),
      );
    }

    final proposalsQuery = FirebaseFirestore.instance
        .collection('proposals')
        .where('supervisorId', isEqualTo: supervisorUid)
        .where('status', isEqualTo: 'Approved');

    return Scaffold(
      appBar: AppBar(title: const Text('Monitor Progress')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search student',
                    hintText: 'Search by name, ID, email, proposal, or status',
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
              stream: proposalsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Something Went Wrong',
                    message: 'Unable to load assigned students.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No Assigned Students',
                    message: 'Students assigned to you will appear here.',
                  );
                }

                final Map<String, Map<String, dynamic>> students = {};

                for (final doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentId = data['studentId'] ?? '-';

                  students[studentId] = {
                    'studentId': studentId,
                    'studentName': data['studentName'] ?? 'Unknown Student',
                    'studentEmail': data['studentEmail'] ?? '-',
                    'proposalStatus': data['status'] ?? '-',
                    'proposalTitle': data['title'] ?? '-',
                  };
                }

                final studentList = _filterAndSort(students.values.toList());

                if (studentList.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No Matching Students',
                    message: 'Try searching with another keyword.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: studentList.length,
                  itemBuilder: (context, index) {
                    final student = studentList[index];

                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(student['studentName']),
                        subtitle: Text(
                          '${student['studentId']}\n'
                          'Proposal: ${student['proposalTitle']}\n'
                          'Status: ${student['proposalStatus']}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudentProgressDetailScreen(
                                studentId: student['studentId'],
                                studentName: student['studentName'],
                                studentEmail: student['studentEmail'],
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
