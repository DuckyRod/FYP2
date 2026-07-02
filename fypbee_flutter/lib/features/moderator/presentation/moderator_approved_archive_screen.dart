import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_chip.dart';

class ApprovedArchiveScreen extends StatefulWidget {
  const ApprovedArchiveScreen({super.key});

  @override
  State<ApprovedArchiveScreen> createState() => _ApprovedArchiveScreenState();
}

class _ApprovedArchiveScreenState extends State<ApprovedArchiveScreen> {
  final _searchController = TextEditingController();

  bool _sortAZ = true;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<QueryDocumentSnapshot> _filterAndSort(
    List<QueryDocumentSnapshot> proposals,
  ) {
    final search = _searchText.toLowerCase();

    final filtered = proposals.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final title = (data['title'] ?? '').toString().toLowerCase();
      final studentName = (data['studentName'] ?? '').toString().toLowerCase();
      final studentId = (data['studentId'] ?? '').toString().toLowerCase();
      final supervisorName =
          (data['supervisorName'] ?? '').toString().toLowerCase();

      return title.contains(search) ||
          studentName.contains(search) ||
          studentId.contains(search) ||
          supervisorName.contains(search);
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aTitle = (aData['title'] ?? '').toString().toLowerCase();
      final bTitle = (bData['title'] ?? '').toString().toLowerCase();

      return _sortAZ ? aTitle.compareTo(bTitle) : bTitle.compareTo(aTitle);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final approvedQuery = FirebaseFirestore.instance
        .collection('proposals')
        .where('status', isEqualTo: 'Approved');

    return Scaffold(
      appBar: AppBar(title: const Text('Approved Projects Archive')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search approved project',
                    hintText: 'Search by title, student, ID, or supervisor',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchText = value;
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _sortAZ = !_sortAZ;
                        });
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
              stream: approvedQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Something Went Wrong',
                    message: 'Unable to load approved projects.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final proposals = _filterAndSort(snapshot.data?.docs ?? []);

                if (proposals.isEmpty && _searchText.isNotEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No Matching Projects',
                    message: 'Try searching with another keyword.',
                  );
                }

                if (proposals.isEmpty) {
                  return const EmptyState(
                    icon: Icons.archive_outlined,
                    title: 'No Approved Projects',
                    message: 'Approved proposals will appear in this archive.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: proposals.length,
                  itemBuilder: (context, index) {
                    final data =
                        proposals[index].data() as Map<String, dynamic>;

                    final title = data['title'] ?? '-';
                    final studentName = data['studentName'] ?? '-';
                    final studentId = data['studentId'] ?? '-';
                    final supervisorName = data['supervisorName'] ?? '-';
                    final feedback = data['feedback'] ?? '';
                    final moderatorFeedback = data['moderatorFeedback'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.check_circle),
                        ),
                        title: Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Student: $studentName ($studentId)\n'
                          'Supervisor: $supervisorName\n'
                          'Supervisor Feedback: ${feedback.toString().isEmpty ? "No feedback" : feedback}\n'
                          'Moderator Feedback: ${moderatorFeedback.toString().isEmpty ? "No feedback" : moderatorFeedback}',
                        ),
                        trailing: const StatusChip(status: 'Approved'),
                        isThreeLine: true,
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
