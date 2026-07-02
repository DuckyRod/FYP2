import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/date_formatter.dart';

class FinalSubmissionScreen extends StatefulWidget {
  const FinalSubmissionScreen({super.key});

  @override
  State<FinalSubmissionScreen> createState() => _FinalSubmissionScreenState();
}

class _FinalSubmissionScreenState extends State<FinalSubmissionScreen> {
  File? selectedFile;
  String? selectedFileName;
  bool isUploading = false;

  Future<void> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'zip'],
    );

    if (result == null) return;

    setState(() {
      selectedFile = File(result.files.single.path!);
      selectedFileName = result.files.single.name;
    });
  }

  Future<void> downloadFile(String? fileUrl) async {
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
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open file.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> submitFinalProject({
    String? existingDocId,
    String? oldFilePath,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (selectedFile == null || selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first.')),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final userData = userDoc.data();

      final approvedProposalSnapshot = await FirebaseFirestore.instance
          .collection('proposals')
          .where('studentId', isEqualTo: userData?['studentId'])
          .where('status', isEqualTo: 'Approved')
          .limit(1)
          .get();

      if (approvedProposalSnapshot.docs.isEmpty) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'You can submit final project only after proposal approval.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final approvedProposal = approvedProposalSnapshot.docs.first.data();

      final submissionId = existingDocId ??
          FirebaseFirestore.instance.collection('final_submissions').doc().id;

      final safeFileName =
          selectedFileName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      if (oldFilePath != null && oldFilePath.isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(oldFilePath).delete();
        } catch (_) {}
      }

      final storageRef = FirebaseStorage.instance.ref(
        'final_submissions/${user.uid}/$submissionId-$safeFileName',
      );

      final uploadTask = await storageRef.putFile(selectedFile!);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      final data = {
        'studentUid': user.uid,
        'studentId': userData?['studentId'],
        'studentName': userData?['name'],
        'studentEmail': user.email,
        'supervisorId': approvedProposal['supervisorId'],
        'supervisorName': approvedProposal['supervisorName'],
        'proposalTitle': approvedProposal['title'],
        'fileName': safeFileName,
        'fileUrl': fileUrl,
        'filePath': uploadTask.ref.fullPath,
        'status': 'Submitted',
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (existingDocId == null) {
        data['submittedAt'] = FieldValue.serverTimestamp();
      }

      await FirebaseFirestore.instance
          .collection('final_submissions')
          .doc(submissionId)
          .set(data, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existingDocId == null
                ? 'Final project submitted successfully.'
                : 'Final project resubmitted successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        selectedFile = null;
        selectedFileName = null;
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Submit failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  Widget _markSection(Map<String, dynamic> data) {
    final hasMark = data['mark'] != null;

    if (!hasMark) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.hourglass_empty),
          title: Text('Mark Pending'),
          subtitle: Text('Your final report has not been marked yet.'),
        ),
      );
    }

    return Card(
      child: ListTile(
        leading: const Icon(Icons.grade),
        title: Text('Mark: ${data['mark']} (${data['grade'] ?? '-'})'),
        subtitle: Text(
          'Comment: ${data['moderatorComment'] ?? 'No comment'}\n'
          'Marked At: ${DateFormatter.formatTimestamp(data['markedAt'])}',
        ),
        isThreeLine: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Final Submission')),
        body: const Center(child: Text('Please login first.')),
      );
    }

    final submissionQuery = FirebaseFirestore.instance
        .collection('final_submissions')
        .where('studentUid', isEqualTo: user.uid)
        .limit(1);

    return Scaffold(
      appBar: AppBar(title: const Text('Final Submission')),
      body: StreamBuilder<QuerySnapshot>(
        stream: submissionQuery.snapshots(),
        builder: (context, snapshot) {
          final docs = snapshot.data?.docs ?? [];
          final hasSubmission = docs.isNotEmpty;

          String? existingDocId;
          String? oldFilePath;
          Map<String, dynamic>? data;

          if (hasSubmission) {
            final doc = docs.first;
            existingDocId = doc.id;
            data = doc.data() as Map<String, dynamic>;
            oldFilePath = data['filePath'];
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasSubmission && data != null) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Submitted Final Project',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text('File: ${data['fileName'] ?? '-'}'),
                          const SizedBox(height: 6),
                          Text(
                            'Submitted At: ${DateFormatter.formatTimestamp(data['submittedAt'])}',
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Last Updated: ${DateFormatter.formatTimestamp(data['updatedAt'])}',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () => downloadFile(data?['fileUrl']),
                              icon: const Icon(Icons.download),
                              label: const Text('Download Submitted File'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _markSection(data),
                ] else ...[
                  const Text(
                    'Upload your final report or project file for moderator marking.',
                    style: TextStyle(fontSize: 16),
                  ),
                ],
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: isUploading ? null : pickFile,
                  icon: const Icon(Icons.attach_file),
                  label: Text(
                    hasSubmission
                        ? 'Choose New File for Resubmission'
                        : 'Choose File',
                  ),
                ),
                const SizedBox(height: 12),
                if (selectedFileName != null)
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
                          Icons.insert_drive_file,
                          color: Colors.blue,
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: Text(
                            selectedFileName!,
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
                            setState(() {
                              selectedFile = null;
                              selectedFileName = null;
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
                const Spacer(),
                ElevatedButton(
                  onPressed: isUploading
                      ? null
                      : () => submitFinalProject(
                            existingDocId: existingDocId,
                            oldFilePath: oldFilePath,
                          ),
                  child: isUploading
                      ? const CircularProgressIndicator()
                      : Text(
                          hasSubmission
                              ? 'Resubmit and Replace File'
                              : 'Submit Final Project',
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
