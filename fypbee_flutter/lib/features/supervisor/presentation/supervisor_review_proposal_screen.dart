import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/current_user.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_chip.dart';
import 'supervisor_proposal_decision_screen.dart';

class ReviewProposalScreen extends StatefulWidget {
  const ReviewProposalScreen({super.key});

  @override
  State<ReviewProposalScreen> createState() => _ReviewProposalScreenState();
}

class _ReviewProposalScreenState extends State<ReviewProposalScreen> {
  final _searchController = TextEditingController();

  bool _sortAZ = true;
  bool _showResponded = false;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _goToDecision(BuildContext context, String proposalDocId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DecisionScreen(proposalDocId: proposalDocId),
      ),
    );
  }

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

  List<QueryDocumentSnapshot> _filterAndSort(
    List<QueryDocumentSnapshot> proposals,
  ) {
    final search = _searchText.toLowerCase();

    final filtered = proposals.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final status = (data['status'] ?? '').toString();

      final respondedStatuses = [
        'Pending Moderator Approval',
        'Approved',
        'Rejected',
        'Requires Modification',
      ];

      if (!_showResponded && respondedStatuses.contains(status)) {
        return false;
      }

      final title = (data['title'] ?? '').toString().toLowerCase();
      final studentId = (data['studentId'] ?? '').toString().toLowerCase();
      final studentEmail =
          (data['studentEmail'] ?? '').toString().toLowerCase();
      final studentName = (data['studentName'] ?? '').toString().toLowerCase();

      return title.contains(search) ||
          studentId.contains(search) ||
          studentEmail.contains(search) ||
          studentName.contains(search) ||
          status.toLowerCase().contains(search);
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
    final supervisorUid = CurrentUser.uid;

    if (supervisorUid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Proposal')),
        body: const EmptyState(
          icon: Icons.error_outline,
          title: 'User Not Found',
          message: 'Please login again.',
        ),
      );
    }

    final proposalsQuery = FirebaseFirestore.instance
        .collection('proposals')
        .where('supervisorId', isEqualTo: supervisorUid);

    return Scaffold(
      appBar: AppBar(title: const Text('Review Proposal')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'Search proposal',
                    hintText: 'Search by title, student, ID, email, or status',
                  ),
                  onChanged: (value) {
                    setState(() => _searchText = value);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Row(
                      children: [
                        const Text('Show Responded'),
                        Switch(
                          value: _showResponded,
                          onChanged: (value) {
                            setState(() => _showResponded = value);
                          },
                        ),
                      ],
                    ),
                    const Spacer(),
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
                    message: 'Unable to load proposals.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final proposals = _filterAndSort(snapshot.data?.docs ?? []);

                if (proposals.isEmpty) {
                  return const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No Assigned Proposals',
                    message:
                        'Student proposals assigned to you will appear here.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: proposals.length,
                  itemBuilder: (context, index) {
                    final doc = proposals[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final title = data['title'] ?? '-';
                    final studentId = data['studentId'] ?? '-';
                    final studentEmail = data['studentEmail'] ?? '-';
                    final studentName = data['studentName'] ?? '-';
                    final description = data['description'] ?? '-';
                    final status = data['status'] ?? 'Under Review';
                    final feedback = data['feedback'] ?? '';

                    final proposalFileName =
                        data['proposalFileName'] ?? 'Proposal File';
                    final proposalFileUrl = data['proposalFileUrl'];

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text('Student Name: $studentName'),
                            Text('Student ID: $studentId'),
                            Text('Email: $studentEmail'),
                            const SizedBox(height: 12),
                            StatusChip(status: status),
                            const Divider(height: 28),
                            const Text(
                              'Short Description',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(description),
                            const SizedBox(height: 14),
                            const Text(
                              'Proposal File',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Card(
                              child: ListTile(
                                leading: const Icon(Icons.description),
                                title: Text(proposalFileName),
                                subtitle:
                                    const Text('Uploaded proposal document'),
                                trailing: const Icon(Icons.download),
                                onTap: () => _downloadFile(
                                  context,
                                  proposalFileUrl,
                                ),
                              ),
                            ),
                            if (feedback.toString().isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Text(
                                'Supervisor Feedback',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(feedback),
                            ],
                            if ((data['moderatorFeedback'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 14),
                              const Text(
                                'Moderator Feedback',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              Text(data['moderatorFeedback']),
                            ],
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: () => _goToDecision(context, doc.id),
                                icon: const Icon(Icons.rate_review),
                                label: const Text('Make Decision'),
                              ),
                            ),
                          ],
                        ),
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
