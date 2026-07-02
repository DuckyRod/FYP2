import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';

class ModeratorMeetingLogsScreen extends StatefulWidget {
  const ModeratorMeetingLogsScreen({super.key});

  @override
  State<ModeratorMeetingLogsScreen> createState() =>
      _ModeratorMeetingLogsScreenState();
}

class _ModeratorMeetingLogsScreenState
    extends State<ModeratorMeetingLogsScreen> {
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
      final supervisor =
          (student['supervisorName'] ?? '').toString().toLowerCase();
      final project = (student['proposalTitle'] ?? '').toString().toLowerCase();

      return name.contains(search) ||
          id.contains(search) ||
          supervisor.contains(search) ||
          project.contains(search);
    }).toList();

    filtered.sort((a, b) {
      final aName = (a['studentName'] ?? '').toString().toLowerCase();
      final bName = (b['studentName'] ?? '').toString().toLowerCase();

      return _sortAZ ? aName.compareTo(bName) : bName.compareTo(aName);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final logsQuery = FirebaseFirestore.instance
        .collection('meeting_logs')
        .where('status', isEqualTo: 'Submitted to Moderator');

    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Logs')),
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
                    hintText: 'Search by student, ID, supervisor, or project',
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
              stream: logsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Something Went Wrong',
                    message: 'Unable to load meeting logs.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final logs = snapshot.data?.docs ?? [];

                if (logs.isEmpty) {
                  return const EmptyState(
                    icon: Icons.note_alt_outlined,
                    title: 'No Meeting Logs',
                    message:
                        'Signed meeting logs submitted by supervisors will appear here.',
                  );
                }

                final Map<String, Map<String, dynamic>> students = {};

                for (final doc in logs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final studentId = data['studentId'] ?? '-';

                  students[studentId] = {
                    'studentId': studentId,
                    'studentName': data['studentName'] ?? 'Unknown Student',
                    'supervisorName': data['supervisorName'] ?? '-',
                    'proposalTitle': data['proposalTitle'] ?? '-',
                    'logCount': (students[studentId]?['logCount'] ?? 0) + 1,
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
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(
                          student['studentName'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${student['studentId']}\n'
                          'Project: ${student['proposalTitle']}\n'
                          'Logs: ${student['logCount']}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ModeratorStudentMeetingLogsScreen(
                                studentId: student['studentId'],
                                studentName: student['studentName'],
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

class ModeratorStudentMeetingLogsScreen extends StatelessWidget {
  final String studentId;
  final String studentName;

  const ModeratorStudentMeetingLogsScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  Color _statusColor(String status) {
    switch (status) {
      case 'Submitted to Supervisor':
        return Colors.orange;
      case 'Submitted to Moderator':
        return Colors.blue;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _downloadFile(BuildContext context, String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No file available.'),
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

  void _openLogDetail({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) {
    final status = data['status'] ?? '-';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    data['meetingTitle'] ?? 'Meeting Log',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text('Week: ${data['weekNumber'] ?? '-'}'),
                  Text(
                    'Student: ${data['studentName'] ?? '-'} '
                    '(${data['studentId'] ?? '-'})',
                  ),
                  Text('Supervisor: ${data['supervisorName'] ?? '-'}'),
                  Text('Project: ${data['proposalTitle'] ?? '-'}'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _statusColor(status).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: _statusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Divider(height: 28),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.picture_as_pdf),
                    title: Text(
                      data['originalFileName'] ?? 'Original Meeting Log',
                    ),
                    subtitle: Text(
                      'Submitted: ${DateFormatter.formatTimestamp(data['submittedAt'])}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: () => _downloadFile(
                        context,
                        data['originalFileUrl'],
                      ),
                    ),
                  ),
                  const Divider(height: 28),
                  if (data['signedFileUrl'] == null)
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.info_outline),
                      title: Text('No signed file yet'),
                      subtitle: Text(
                        'Supervisor has not uploaded the signed meeting log.',
                      ),
                    )
                  else
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified),
                      title: Text(
                        data['signedFileName'] ?? 'Signed Meeting Log',
                      ),
                      subtitle: Text(
                        'Signed: ${DateFormatter.formatTimestamp(data['signedAt'])}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.download),
                        onPressed: () => _downloadFile(
                          context,
                          data['signedFileUrl'],
                        ),
                      ),
                    ),
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
    final logsQuery = FirebaseFirestore.instance
        .collection('meeting_logs')
        .where('studentId', isEqualTo: studentId)
        .where('status', isEqualTo: 'Submitted to Moderator');

    return Scaffold(
      appBar: AppBar(title: Text('$studentName Logs')),
      body: StreamBuilder<QuerySnapshot>(
        stream: logsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Something Went Wrong',
              message: 'Unable to load student meeting logs.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final logs = snapshot.data?.docs ?? [];

          if (logs.isEmpty) {
            return const EmptyState(
              icon: Icons.note_alt_outlined,
              title: 'No Meeting Logs',
              message: 'This student has no signed logs submitted yet.',
            );
          }

          logs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aWeek = aData['weekNumber'] ?? 0;
            final bWeek = bData['weekNumber'] ?? 0;

            return bWeek.compareTo(aWeek);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final data = logs[index].data() as Map<String, dynamic>;
              final status = data['status'] ?? '-';

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text('${data['weekNumber'] ?? '-'}'),
                  ),
                  title: Text(
                    data['meetingTitle'] ?? 'Meeting Log',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Status: $status\n'
                    'Signed: ${DateFormatter.formatTimestamp(data['signedAt'])}',
                  ),
                  isThreeLine: true,
                  trailing: Icon(
                    Icons.arrow_forward_ios,
                    color: _statusColor(status),
                  ),
                  onTap: () {
                    _openLogDetail(
                      context: context,
                      data: data,
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
