import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/data/current_user.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/status_chip.dart';

class StudentProgressDetailScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String studentEmail;

  const StudentProgressDetailScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
  });

  @override
  State<StudentProgressDetailScreen> createState() =>
      _StudentProgressDetailScreenState();
}

class _StudentProgressDetailScreenState
    extends State<StudentProgressDetailScreen> {
  final _commentController = TextEditingController();

  File? signedFile;
  String? signedFileName;

  bool _isSubmittingComment = false;
  bool _isUploadingSignedLog = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

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

  Future<void> _pickSignedPdf(StateSetter setSheetState) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null) return;

    setSheetState(() {
      signedFile = File(result.files.single.path!);
      signedFileName = result.files.single.name;
    });
  }

  Future<void> _submitSignedLog({
    required BuildContext context,
    required StateSetter setSheetState,
    required String logDocId,
    required Map<String, dynamic> data,
  }) async {
    if (signedFile == null || signedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose signed PDF first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setSheetState(() => _isUploadingSignedLog = true);

    try {
      final safeFileName =
          signedFileName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final storageRef = FirebaseStorage.instance.ref(
        'meeting_logs_signed/${data['studentUid']}/$logDocId-$safeFileName',
      );

      final uploadTask = await storageRef.putFile(signedFile!);
      final signedUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('meeting_logs')
          .doc(logDocId)
          .update({
        'signedFileName': safeFileName,
        'signedFileUrl': signedUrl,
        'signedFilePath': uploadTask.ref.fullPath,
        'status': 'Submitted to Moderator',
        'signedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Signed meeting log submitted to moderator.'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        signedFile = null;
        signedFileName = null;
      });
    } catch (e) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submit failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setSheetState(() => _isUploadingSignedLog = false);
    }
  }

  Future<void> _addComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      await FirebaseFirestore.instance.collection('progress_comments').add({
        'studentId': widget.studentId,
        'studentName': widget.studentName,
        'studentEmail': widget.studentEmail,
        'supervisorId': CurrentUser.uid,
        'supervisorName': CurrentUser.name,
        'comment': _commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _commentController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comment added'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add comment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  void _openMeetingLogDetail({
    required BuildContext context,
    required String logDocId,
    required Map<String, dynamic> data,
  }) {
    signedFile = null;
    signedFileName = null;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final status = data['status'] ?? '-';
            final canUploadSigned = status == 'Submitted to Supervisor';

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
                        data['meetingTitle'] ?? 'Meeting Log',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text('Week: ${data['weekNumber'] ?? '-'}'),
                      Text('Student: ${data['studentName'] ?? '-'}'),
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
                          data['originalFileName'] ?? 'Student Meeting Log',
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
                      if (data['signedFileUrl'] != null) ...[
                        const Divider(height: 28),
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
                      if (data['moderatorFeedback'] != null &&
                          data['moderatorFeedback'].toString().isNotEmpty) ...[
                        const Divider(height: 28),
                        Text(
                          'Moderator Feedback: ${data['moderatorFeedback']}',
                        ),
                      ],
                      if (canUploadSigned) ...[
                        const Divider(height: 28),
                        const Text(
                          'Upload Signed Meeting Log',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isUploadingSignedLog
                              ? null
                              : () => _pickSignedPdf(setSheetState),
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose Signed PDF'),
                        ),
                        const SizedBox(height: 10),
                        if (signedFileName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.picture_as_pdf,
                                  color: Colors.red,
                                ),

                                const SizedBox(width: 10),

                                Expanded(
                                  child: Text(
                                    signedFileName!,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Remove File',
                                  onPressed: () {
                                    setSheetState(() {
                                      signedFile = null;
                                      signedFileName = null;
                                    });

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Selected file removed'),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 50,
                          child: _isUploadingSignedLog
                              ? const Center(child: CircularProgressIndicator())
                              : ElevatedButton.icon(
                                  onPressed: () => _submitSignedLog(
                                    context: context,
                                    setSheetState: setSheetState,
                                    logDocId: logDocId,
                                    data: data,
                                  ),
                                  icon: const Icon(Icons.send),
                                  label: const Text(
                                    'Submit Signed Log to Moderator',
                                  ),
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
      },
    );
  }

  Widget _buildMeetingLogs() {
    final logsQuery = FirebaseFirestore.instance
        .collection('meeting_logs')
        .where('studentId', isEqualTo: widget.studentId)
        .where('supervisorId', isEqualTo: CurrentUser.uid);

    return StreamBuilder<QuerySnapshot>(
      stream: logsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.timeline_outlined),
              title: Text('No meeting logs submitted yet'),
            ),
          );
        }

        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aWeek = aData['weekNumber'] ?? 0;
          final bWeek = bData['weekNumber'] ?? 0;

          return bWeek.compareTo(aWeek);
        });

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '-';

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${data['weekNumber'] ?? '-'}'),
                ),
                title: Text(data['meetingTitle'] ?? 'Meeting Log'),
                subtitle: Text(
                  'Status: $status\n'
                  'Submitted: ${DateFormatter.formatTimestamp(data['submittedAt'])}',
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  color: _statusColor(status),
                ),
                isThreeLine: true,
                onTap: () {
                  _openMeetingLogDetail(
                    context: context,
                    logDocId: doc.id,
                    data: data,
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final proposalQuery = FirebaseFirestore.instance
        .collection('proposals')
        .where('studentId', isEqualTo: widget.studentId)
        .where('supervisorId', isEqualTo: CurrentUser.uid);

    final commentsQuery = FirebaseFirestore.instance
        .collection('progress_comments')
        .where('studentId', isEqualTo: widget.studentId)
        .where('supervisorId', isEqualTo: CurrentUser.uid);

    return Scaffold(
      appBar: AppBar(title: const Text('Student Progress Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(widget.studentName),
              subtitle: Text('${widget.studentId}\n${widget.studentEmail}'),
              isThreeLine: true,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Proposal',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          StreamBuilder<QuerySnapshot>(
            stream: proposalQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const EmptyState(
                  icon: Icons.description_outlined,
                  title: 'No Proposal',
                  message: 'No proposal found for this student.',
                );
              }

              final data = docs.first.data() as Map<String, dynamic>;

              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data['title'] ?? '-',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      StatusChip(status: data['status'] ?? 'Under Review'),
                      const SizedBox(height: 8),
                      Text(
                        'Submitted: ${DateFormatter.formatTimestamp(data['createdAt'])}',
                      ),
                      Text(
                        'Reviewed: ${DateFormatter.formatTimestamp(data['reviewedAt'])}',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Meeting Logs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          _buildMeetingLogs(),
          const SizedBox(height: 16),
          const Text(
            'Supervisor Comments',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Add progress comment',
              prefixIcon: Icon(Icons.comment),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 50,
            child: _isSubmittingComment
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    onPressed: _addComment,
                    icon: const Icon(Icons.send),
                    label: const Text('Add Comment'),
                  ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: commentsQuery.snapshots(),
            builder: (context, snapshot) {
              final docs = snapshot.data?.docs ?? [];

              if (docs.isEmpty) {
                return const Card(
                  child: ListTile(
                    leading: Icon(Icons.comment_outlined),
                    title: Text('No comments yet'),
                  ),
                );
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.comment),
                      title: Text(data['comment'] ?? '-'),
                      subtitle: Text(
                        DateFormatter.formatTimestamp(data['createdAt']),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
