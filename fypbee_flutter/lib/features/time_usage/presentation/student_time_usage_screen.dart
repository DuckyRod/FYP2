import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../../core/data/current_user.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';

class StudentTimeUsageScreen extends StatelessWidget {
  const StudentTimeUsageScreen({super.key});

  String _formatDuration(DateTime? start, DateTime? end) {
    if (start == null || end == null) return 'N/A';

    final duration = end.difference(start);

    if (duration.inDays > 0) {
      return '${duration.inDays} day(s), ${duration.inHours % 24} hour(s)';
    }

    if (duration.inHours > 0) {
      return '${duration.inHours} hour(s), ${duration.inMinutes % 60} minute(s)';
    }

    return '${duration.inMinutes} minute(s)';
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _timelineItem({
    required String date,
    required String title,
    required String subtitle,
    required bool isFirst,
    required bool isLast,
    required bool isCompleted,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 85,
            child: Text(
              date,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                color: isCompleted ? Colors.black87 : Colors.grey,
                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              if (!isFirst)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
              CircleAvatar(
                radius: 7,
                backgroundColor: isCompleted ? Colors.green : Colors.grey,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: Colors.grey.shade300,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isCompleted ? FontWeight.bold : FontWeight.normal,
                      color: isCompleted ? Colors.black87 : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isCompleted ? Colors.black54 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  DateTime? _toDate(dynamic timestamp) {
    if (timestamp is Timestamp) return timestamp.toDate();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final studentId = CurrentUser.id;
    final studentUid = CurrentUser.uid;

    if (studentId == null || studentUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Time Usage')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'User Not Found',
          message: 'Please login again.',
        ),
      );
    }

    final proposalQuery = FirebaseFirestore.instance
        .collection('proposals')
        .where('studentId', isEqualTo: studentId)
        .limit(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Time Usage')),
      body: FutureBuilder<QuerySnapshot>(
        future: proposalQuery.get(),
        builder: (context, proposalSnapshot) {
          if (proposalSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final proposalDocs = proposalSnapshot.data?.docs ?? [];

          if (proposalDocs.isEmpty) {
            return const EmptyState(
              icon: Icons.timeline,
              title: 'No Timeline Available',
              message: 'Submit a proposal first to view your project timeline.',
            );
          }

          final proposal = proposalDocs.first.data() as Map<String, dynamic>;

          final proposalSubmittedAt = _toDate(proposal['createdAt']);
          final supervisorReviewedAt = _toDate(proposal['reviewedAt']);
          final moderatorReviewedAt = _toDate(proposal['moderatorReviewedAt']);

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('meeting_logs')
                .where('studentUid', isEqualTo: studentUid)
                .get(),
            builder: (context, meetingSnapshot) {
              final meetingDocs = meetingSnapshot.data?.docs ?? [];

              meetingDocs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>;
                final bData = b.data() as Map<String, dynamic>;

                final aWeek = aData['weekNumber'] ?? 0;
                final bWeek = bData['weekNumber'] ?? 0;

                return aWeek.compareTo(bWeek);
              });

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('final_submissions')
                    .where('studentUid', isEqualTo: studentUid)
                    .limit(1)
                    .get(),
                builder: (context, finalSnapshot) {
                  final finalDocs = finalSnapshot.data?.docs ?? [];

                  Map<String, dynamic>? finalSubmission;

                  if (finalDocs.isNotEmpty) {
                    finalSubmission =
                        finalDocs.first.data() as Map<String, dynamic>;
                  }

                  final finalSubmittedAt =
                      _toDate(finalSubmission?['submittedAt']);
                  final markedAt = _toDate(finalSubmission?['markedAt']);

                  final latestDate = markedAt ??
                      finalSubmittedAt ??
                      moderatorReviewedAt ??
                      supervisorReviewedAt ??
                      proposalSubmittedAt;

                  final totalDuration = _formatDuration(
                    proposalSubmittedAt,
                    latestDate,
                  );

                  final reviewDuration = _formatDuration(
                    proposalSubmittedAt,
                    moderatorReviewedAt,
                  );

                  final completedMeetingLogs = meetingDocs.length;

                  final timelineItems = <Map<String, dynamic>>[
                    {
                      'date': proposalSubmittedAt,
                      'title': 'Proposal Submitted',
                      'subtitle': proposal['title'] ?? '-',
                      'completed': proposalSubmittedAt != null,
                    },
                    {
                      'date': supervisorReviewedAt,
                      'title': 'Supervisor Reviewed Proposal',
                      'subtitle': 'Status: ${proposal['status'] ?? '-'}',
                      'completed': supervisorReviewedAt != null,
                    },
                    {
                      'date': moderatorReviewedAt,
                      'title': 'Moderator Approved Proposal',
                      'subtitle': 'Proposal officially approved',
                      'completed': moderatorReviewedAt != null,
                    },
                  ];

                  for (final doc in meetingDocs) {
                    final data = doc.data() as Map<String, dynamic>;

                    timelineItems.add({
                      'date': _toDate(data['submittedAt']),
                      'title': 'Meeting Log Week ${data['weekNumber'] ?? '-'}',
                      'subtitle':
                          '${data['meetingTitle'] ?? 'Meeting Log'} - ${data['status'] ?? '-'}',
                      'completed': data['submittedAt'] != null,
                    });
                  }

                  if (finalSubmittedAt != null) {
                    timelineItems.add({
                      'date': finalSubmittedAt,
                      'title': 'Final Project Submitted',
                      'subtitle': finalSubmission?['fileName'] ?? '-',
                      'completed': true,
                    });
                  }

                  if (markedAt != null) {
                    timelineItems.add({
                      'date': markedAt,
                      'title': 'Final Mark Released',
                      'subtitle':
                          'Mark: ${finalSubmission?['mark']} (${finalSubmission?['grade'] ?? '-'})',
                      'completed': true,
                    });
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      const Text(
                        'Progress Summary',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _summaryCard(
                        title: 'Total Project Duration',
                        value: totalDuration,
                        icon: Icons.timer,
                      ),
                      _summaryCard(
                        title: 'Proposal Review Duration',
                        value: reviewDuration,
                        icon: Icons.rate_review,
                      ),
                      _summaryCard(
                        title: 'Meeting Logs Submitted',
                        value: '$completedMeetingLogs log(s)',
                        icon: Icons.note_alt,
                      ),
                      _summaryCard(
                        title: 'Final Submission',
                        value:
                            finalSubmittedAt == null ? 'Pending' : 'Submitted',
                        icon: Icons.upload_file,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Project Timeline',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...timelineItems.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;

                        final date = item['date'] as DateTime?;

                        return _timelineItem(
                          date: date == null
                              ? '-'
                              : DateFormatter.formatTimestamp(
                                  Timestamp.fromDate(date),
                                ),
                          title: item['title'],
                          subtitle: item['subtitle'],
                          isFirst: index == 0,
                          isLast: index == timelineItems.length - 1,
                          isCompleted: item['completed'] == true,
                        );
                      }),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
