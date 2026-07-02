import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/current_user.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';

class ModeratorFinalSubmissionsScreen extends StatefulWidget {
  const ModeratorFinalSubmissionsScreen({super.key});

  @override
  State<ModeratorFinalSubmissionsScreen> createState() =>
      _ModeratorFinalSubmissionsScreenState();
}

class _ModeratorFinalSubmissionsScreenState
    extends State<ModeratorFinalSubmissionsScreen> {
  final _searchController = TextEditingController();
  final _markController = TextEditingController();
  final _commentController = TextEditingController();

  bool _sortAZ = true;
  bool _isSavingMark = false;
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    _markController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  String _calculateGrade(double mark) {
    if (mark >= 90) return 'A+';
    if (mark >= 80) return 'A';
    if (mark >= 75) return 'A-';
    if (mark >= 70) return 'B+';
    if (mark >= 65) return 'B';
    if (mark >= 60) return 'B-';
    if (mark >= 55) return 'C+';
    if (mark >= 50) return 'C';
    if (mark >= 45) return 'D';
    return 'F';
  }

  List<QueryDocumentSnapshot> _filterAndSort(
    List<QueryDocumentSnapshot> submissions,
  ) {
    final search = _searchText.toLowerCase();

    final filtered = submissions.where((doc) {
      final data = doc.data() as Map<String, dynamic>;

      final studentName = (data['studentName'] ?? '').toString().toLowerCase();
      final studentId = (data['studentId'] ?? '').toString().toLowerCase();
      final supervisorName =
          (data['supervisorName'] ?? '').toString().toLowerCase();
      final proposalTitle =
          (data['proposalTitle'] ?? '').toString().toLowerCase();
      final fileName = (data['fileName'] ?? '').toString().toLowerCase();

      return studentName.contains(search) ||
          studentId.contains(search) ||
          supervisorName.contains(search) ||
          proposalTitle.contains(search) ||
          fileName.contains(search);
    }).toList();

    filtered.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;

      final aName = (aData['studentName'] ?? '').toString().toLowerCase();
      final bName = (bData['studentName'] ?? '').toString().toLowerCase();

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

  Future<void> _saveMark({
    required BuildContext context,
    required String submissionDocId,
  }) async {
    final mark = double.tryParse(_markController.text.trim());

    if (mark == null || mark < 0 || mark > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid mark between 0 and 100.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final grade = _calculateGrade(mark);

    setState(() => _isSavingMark = true);

    try {
      await FirebaseFirestore.instance
          .collection('final_submissions')
          .doc(submissionDocId)
          .update({
        'mark': mark,
        'grade': grade,
        'moderatorComment': _commentController.text.trim(),
        'markedBy': CurrentUser.uid,
        'markedByName': CurrentUser.name,
        'markedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mark saved successfully. Grade: $grade'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save mark: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSavingMark = false);
    }
  }

  void _openSubmissionDetail({
    required BuildContext context,
    required String submissionDocId,
    required Map<String, dynamic> data,
  }) {
    _markController.text = (data['mark'] ?? '').toString();
    _commentController.text = data['moderatorComment'] ?? '';

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final previewMark = double.tryParse(_markController.text.trim());
            final previewGrade =
                previewMark == null ? '-' : _calculateGrade(previewMark);

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
                        data['studentName'] ?? 'Unknown Student',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Student ID: ${data['studentId'] ?? '-'}'),
                      Text('Supervisor: ${data['supervisorName'] ?? '-'}'),
                      Text('Project: ${data['proposalTitle'] ?? '-'}'),
                      const Divider(height: 28),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.description),
                        title: Text(data['fileName'] ?? 'Final Submission'),
                        subtitle: Text(
                          'Submitted At: ${DateFormatter.formatTimestamp(data['submittedAt'])}\n'
                          'Last Updated: ${DateFormatter.formatTimestamp(data['updatedAt'])}',
                        ),
                        isThreeLine: true,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () => _downloadFile(
                            context,
                            data['fileUrl'],
                          ),
                          icon: const Icon(Icons.download),
                          label: const Text('Download File'),
                        ),
                      ),
                      const Divider(height: 32),
                      const Text(
                        'Moderator Marking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _markController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) {
                          setSheetState(() {});
                        },
                        decoration: const InputDecoration(
                          labelText: 'Mark (0 - 100)',
                          prefixIcon: Icon(Icons.score),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Auto Grade: $previewGrade',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Moderator Comment',
                          prefixIcon: Icon(Icons.comment),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 50,
                        child: _isSavingMark
                            ? const Center(child: CircularProgressIndicator())
                            : ElevatedButton.icon(
                                onPressed: () => _saveMark(
                                  context: context,
                                  submissionDocId: submissionDocId,
                                ),
                                icon: const Icon(Icons.save),
                                label: const Text('Save Mark'),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final submissionsQuery = FirebaseFirestore.instance
        .collection('final_submissions')
        .orderBy('submittedAt', descending: true);

    return Scaffold(
      appBar: AppBar(title: const Text('All Final Submissions')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    labelText: 'Search final submission',
                    hintText:
                        'Search by student, ID, supervisor, project, or file',
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
              stream: submissionsQuery.snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Something Went Wrong',
                    message: 'Unable to load final submissions.',
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final submissions = _filterAndSort(snapshot.data?.docs ?? []);

                if (submissions.isEmpty && _searchText.isNotEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off,
                    title: 'No Matching Submissions',
                    message: 'Try searching with another keyword.',
                  );
                }

                if (submissions.isEmpty) {
                  return const EmptyState(
                    icon: Icons.upload_file_outlined,
                    title: 'No Final Submissions',
                    message: 'All student final submissions will appear here.',
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: submissions.length,
                  itemBuilder: (context, index) {
                    final doc = submissions[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final hasMark = data['mark'] != null;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            hasMark ? Icons.grade : Icons.folder_copy,
                          ),
                        ),
                        title: Text(
                          data['studentName'] ?? 'Unknown Student',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${data['studentId'] ?? '-'}\n'
                          'Project: ${data['proposalTitle'] ?? '-'}\n'
                          'Supervisor: ${data['supervisorName'] ?? '-'}',
                        ),
                        isThreeLine: true,
                        trailing: Text(
                          hasMark
                              ? '${data['mark']} (${data['grade']})'
                              : 'Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: hasMark ? Colors.green : Colors.orange,
                          ),
                        ),
                        onTap: () {
                          _openSubmissionDetail(
                            context: context,
                            submissionDocId: doc.id,
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
