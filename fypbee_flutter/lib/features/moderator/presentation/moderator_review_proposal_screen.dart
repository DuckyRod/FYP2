import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/current_user.dart';
import '../../../../core/widgets/empty_state.dart';

class ModeratorReviewProposalScreen extends StatefulWidget {
  const ModeratorReviewProposalScreen({super.key});

  @override
  State<ModeratorReviewProposalScreen> createState() =>
      _ModeratorReviewProposalScreenState();
}

class _ModeratorReviewProposalScreenState
    extends State<ModeratorReviewProposalScreen> {
  final _searchController = TextEditingController();
  final _feedbackController = TextEditingController();

  bool _sortAZ = true;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    _feedbackController.dispose();
    super.dispose();
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

  List<QueryDocumentSnapshot> _filterAndSort(List<QueryDocumentSnapshot> docs) {
    final search = _searchText.toLowerCase();

    final filtered = docs.where((doc) {
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

  Future<void> _submitModeratorDecision({
    required BuildContext sheetContext,
    required String proposalDocId,
    required String status,
  }) async {
    try {
      final proposalRef =
          FirebaseFirestore.instance.collection('proposals').doc(proposalDocId);

      final proposalSnapshot = await proposalRef.get();

      if (!proposalSnapshot.exists) {
        throw Exception('Proposal not found');
      }

      final proposalData = proposalSnapshot.data();

      final oldStatus = proposalData?['status'];
      final supervisorId = proposalData?['supervisorId'];

      await proposalRef.update({
        'status': status,
        'moderatorFeedback': _feedbackController.text.trim(),
        'moderatorReviewedAt': FieldValue.serverTimestamp(),
        'moderatorId': CurrentUser.uid,
        'moderatorName': CurrentUser.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (status == 'Rejected' &&
          oldStatus != 'Rejected' &&
          supervisorId != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(supervisorId)
            .update({
          'currentStudents': FieldValue.increment(-1),
        });
      }

      _feedbackController.clear();

      if (!sheetContext.mounted) return;

      Navigator.pop(sheetContext);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proposal marked as $status'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!sheetContext.mounted) return;

      ScaffoldMessenger.of(sheetContext).showSnackBar(
        SnackBar(
          content: Text('Failed to update proposal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openDecisionSheet({
    required BuildContext context,
    required String proposalDocId,
    required Map<String, dynamic> data,
  }) {
    _feedbackController.clear();

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    data['title'] ?? '-',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Student: ${data['studentName'] ?? '-'} (${data['studentId'] ?? '-'})',
                  ),
                  Text('Supervisor: ${data['supervisorName'] ?? '-'}'),
                  const Divider(height: 28),
                  const Text(
                    'Short Description',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(data['description'] ?? '-'),
                  const SizedBox(height: 16),
                  const Text(
                    'Proposal File',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.description),
                      title: Text(data['proposalFileName'] ?? 'Proposal File'),
                      subtitle: const Text('Uploaded proposal document'),
                      trailing: const Icon(Icons.download),
                      onTap: () => _downloadFile(
                        sheetContext,
                        data['proposalFileUrl'],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _feedbackController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Moderator Feedback',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _submitModeratorDecision(
                      sheetContext: sheetContext,
                      proposalDocId: proposalDocId,
                      status: 'Approved',
                    ),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve Proposal'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _submitModeratorDecision(
                      sheetContext: sheetContext,
                      proposalDocId: proposalDocId,
                      status: 'Requires Modification',
                    ),
                    icon: const Icon(Icons.edit),
                    label: const Text('Request Modification'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _submitModeratorDecision(
                      sheetContext: sheetContext,
                      proposalDocId: proposalDocId,
                      status: 'Rejected',
                    ),
                    icon: const Icon(Icons.close),
                    label: const Text('Reject Proposal'),
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
    final proposalsQuery = FirebaseFirestore.instance
        .collection('proposals')
        .where('status', isEqualTo: 'Pending Moderator Approval');

    return Scaffold(
      appBar: AppBar(title: const Text('Moderator Review Proposals')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search proposal',
                    hintText: 'Search by title, student, or supervisor',
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
                    message: 'Unable to load moderator review proposals.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final proposals = _filterAndSort(snapshot.data?.docs ?? []);

                if (proposals.isEmpty) {
                  return const EmptyState(
                    icon: Icons.assignment_outlined,
                    title: 'No Proposals for Review',
                    message: 'Supervisor-approved proposals will appear here.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: proposals.length,
                  itemBuilder: (context, index) {
                    final doc = proposals[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(
                          data['studentName'] ?? 'Unknown Student',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${data['studentId'] ?? '-'}\n'
                          'Proposal: ${data['title'] ?? '-'}\n'
                          'Supervisor: ${data['supervisorName'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          _openDecisionSheet(
                            context: context,
                            proposalDocId: doc.id,
                            data: data,
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
