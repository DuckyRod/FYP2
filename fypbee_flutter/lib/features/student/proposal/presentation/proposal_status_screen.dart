import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/current_user.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_chip.dart';
import 'modify_proposal_screen.dart';

class ProposalStatusScreen extends StatelessWidget {
  const ProposalStatusScreen({super.key});

  Future<void> _downloadFile(BuildContext context, String? fileUrl) async {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No proposal file available.'),
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
          content: Text('Could not open proposal file.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentId = CurrentUser.id;

    if (studentId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Proposal Status')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'User Not Found',
          message: 'Please login again.',
        ),
      );
    }

    final proposalsQuery = FirebaseFirestore.instance
        .collection('proposals')
        .where('studentId', isEqualTo: studentId);

    return Scaffold(
      appBar: AppBar(title: const Text('Proposal Status')),
      body: StreamBuilder<QuerySnapshot>(
        stream: proposalsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Something Went Wrong',
              message: 'Unable to load proposal status.',
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final proposals = snapshot.data?.docs ?? [];

          if (proposals.isEmpty) {
            return const EmptyState(
              icon: Icons.description_outlined,
              title: 'No Proposal Submitted',
              message:
                  'Submit your FYP proposal first to view its status here.',
            );
          }

          proposals.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;

            final aTime = aData['createdAt'] as Timestamp?;
            final bTime = bData['createdAt'] as Timestamp?;

            if (aTime == null || bTime == null) return 0;
            return bTime.compareTo(aTime);
          });

          final latestDoc = proposals.first;
          final latest = latestDoc.data() as Map<String, dynamic>;
          final previous = proposals.skip(1).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Latest Proposal',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _ProposalCard(
                docId: latestDoc.id,
                data: latest,
                onDownload: (url) => _downloadFile(context, url),
              ),
              if (previous.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Previous Submissions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                ...previous.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  return _ProposalCard(
                    docId: doc.id,
                    data: data,
                    onDownload: (url) => _downloadFile(context, url),
                  );
                }),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ProposalCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final void Function(String? fileUrl) onDownload;

  const _ProposalCard({
    required this.docId,
    required this.data,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title'] ?? '-';
    final supervisorName = data['supervisorName'] ?? '-';
    final status = data['status'] ?? 'Under Review';
    final description = data['description'] ?? '-';
    final feedback = data['feedback'] ?? '';

    final fileName = data['proposalFileName'] ?? 'Proposal File';
    final fileUrl = data['proposalFileUrl'];

    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    final reviewedAt = data['reviewedAt'];
    final moderatorReviewedAt = data['moderatorReviewedAt'];

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Supervisor: $supervisorName'),
            const SizedBox(height: 12),
            StatusChip(status: status),
            const Divider(height: 28),
            Text(
              'Submitted At: ${DateFormatter.formatTimestamp(createdAt)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Last Updated: ${DateFormatter.formatTimestamp(updatedAt)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Supervisor Reviewed At: ${DateFormatter.formatTimestamp(reviewedAt)}',
            ),
            const SizedBox(height: 4),
            Text(
              'Moderator Reviewed At: ${DateFormatter.formatTimestamp(moderatorReviewedAt)}',
            ),
            const Divider(height: 28),
            const Text(
              'Short Description',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(description),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.description),
                title: Text(fileName),
                subtitle: const Text('Uploaded proposal document'),
                trailing: const Icon(Icons.download),
                onTap: () => onDownload(fileUrl),
              ),
            ),
            if (feedback.toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Supervisor Feedback',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(feedback),
            ],
            if ((data['moderatorFeedback'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Moderator Feedback',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(data['moderatorFeedback']),
            ],
            if (status == 'Requires Modification') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModifyProposalScreen(
                          proposalDocId: docId,
                          proposalData: data,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                  label: const Text('Modify Proposal'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
