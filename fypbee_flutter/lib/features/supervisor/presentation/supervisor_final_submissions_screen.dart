import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/current_user.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';

class SupervisorFinalSubmissionsScreen extends StatefulWidget {
  const SupervisorFinalSubmissionsScreen({super.key});

  @override
  State<SupervisorFinalSubmissionsScreen> createState() =>
      _SupervisorFinalSubmissionsScreenState();
}

class _SupervisorFinalSubmissionsScreenState
    extends State<SupervisorFinalSubmissionsScreen> {
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
      final project = (student['proposalTitle'] ?? '').toString().toLowerCase();

      return name.contains(search) ||
          id.contains(search) ||
          email.contains(search) ||
          project.contains(search);
    }).toList();

    filtered.sort((a, b) {
      final aName = (a['studentName'] ?? '').toString().toLowerCase();
      final bName = (b['studentName'] ?? '').toString().toLowerCase();

      return _sortAZ ? aName.compareTo(bName) : bName.compareTo(aName);
    });

    return filtered;
  }

  Future<void> _downloadFile(BuildContext context, String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file available to download.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final uri = Uri.parse(fileUrl);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open file.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openSubmissionDetail({
    required BuildContext context,
    required Map<String, dynamic> student,
    required Map<String, dynamic>? submission,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        final hasSubmission = submission != null;
        final hasMark = hasSubmission && submission['mark'] != null;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    student['studentName'] ?? 'Unknown Student',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Student ID: ${student['studentId'] ?? '-'}'),
                  Text('Email: ${student['studentEmail'] ?? '-'}'),
                  Text('Project: ${student['proposalTitle'] ?? '-'}'),
                  const Divider(height: 28),
                  if (!hasSubmission) ...[
                    const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('No final submission yet'),
                      subtitle: Text(
                        'This student has not submitted the final project file.',
                      ),
                    ),
                  ] else ...[
                    ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(submission['fileName'] ?? 'Final Submission'),
                      subtitle: Text(
                        'Submitted At: ${DateFormatter.formatTimestamp(submission['submittedAt'])}\n'
                        'Last Updated: ${DateFormatter.formatTimestamp(submission['updatedAt'])}',
                      ),
                      isThreeLine: true,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => _downloadFile(
                          context,
                          submission['fileUrl'],
                        ),
                        icon: const Icon(Icons.download),
                        label: const Text('Download File'),
                      ),
                    ),
                    const Divider(height: 28),
                    const Text(
                      'Final Evaluation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!hasMark)
                      const Card(
                        child: ListTile(
                          leading: Icon(Icons.hourglass_empty),
                          title: Text('Mark Pending'),
                          subtitle: Text(
                            'This final submission has not been marked yet.',
                          ),
                        ),
                      )
                    else
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.grade),
                          title: Text(
                            'Mark: ${submission['mark']} (${submission['grade'] ?? '-'})',
                          ),
                          subtitle: Text(
                            'Comment: ${submission['moderatorComment'] ?? 'No comment'}\n'
                            'Marked By: ${submission['markedByName'] ?? '-'}\n'
                            'Marked At: ${DateFormatter.formatTimestamp(submission['markedAt'])}',
                          ),
                          isThreeLine: true,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final supervisorUid = CurrentUser.uid;

    if (supervisorUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Final Submissions')),
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
      appBar: AppBar(title: const Text('Final Submissions')),
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
                    hintText: 'Search by name, ID, email, or project',
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
              builder: (context, proposalSnapshot) {
                if (proposalSnapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Something Went Wrong',
                    message: 'Unable to load assigned students.',
                  );
                }

                if (proposalSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final proposalDocs = proposalSnapshot.data?.docs ?? [];

                if (proposalDocs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No Approved Students',
                    message:
                        'Moderator-approved students assigned to you will appear here.',
                  );
                }

                final Map<String, Map<String, dynamic>> students = {};

                for (final doc in proposalDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentId = data['studentId'] ?? '-';

                  students[studentId] = {
                    'studentId': studentId,
                    'studentName': data['studentName'] ?? 'Unknown Student',
                    'studentEmail': data['studentEmail'] ?? '-',
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

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('final_submissions')
                      .where('supervisorId', isEqualTo: supervisorUid)
                      .snapshots(),
                  builder: (context, submissionSnapshot) {
                    final submissionDocs = submissionSnapshot.data?.docs ?? [];

                    final Map<String, Map<String, dynamic>>
                        submissionsByStudent = {};

                    for (final doc in submissionDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final studentId = data['studentId'];

                      if (studentId != null) {
                        submissionsByStudent[studentId] = data;
                      }
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: studentList.length,
                      itemBuilder: (context, index) {
                        final student = studentList[index];
                        final studentId = student['studentId'];

                        final submission = submissionsByStudent[studentId];
                        final hasSubmission = submission != null;
                        final hasMark =
                            hasSubmission && submission['mark'] != null;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                hasMark
                                    ? Icons.grade
                                    : hasSubmission
                                        ? Icons.check_circle
                                        : Icons.hourglass_empty,
                              ),
                            ),
                            title: Text(
                              student['studentName'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${student['studentId']}\n'
                              'Project: ${student['proposalTitle']}',
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  hasSubmission ? 'Submitted' : 'None',
                                  style: TextStyle(
                                    color: hasSubmission
                                        ? Colors.green
                                        : Colors.grey,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (hasMark)
                                  Text(
                                    '${submission['mark']} (${submission['grade'] ?? '-'})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                            onTap: () {
                              _openSubmissionDetail(
                                context: context,
                                student: student,
                                submission: submission,
                              );
                            },
                          ),
                        );
                      },
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
