import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/utils/date_formatter.dart';

class MeetingLogScreen extends StatefulWidget {
  const MeetingLogScreen({super.key});

  @override
  State<MeetingLogScreen> createState() => _MeetingLogScreenState();
}

class _MeetingLogScreenState extends State<MeetingLogScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weekController = TextEditingController();
  final _titleController = TextEditingController();

  File? selectedFile;
  String? selectedFileName;
  DateTime? selectedMeetingDate;
  bool isUploading = false;

  @override
  void dispose() {
    _weekController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> pickMeetingDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMeetingDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );

    if (picked != null) {
      setState(() {
        selectedMeetingDate = picked;
      });
    }
  }

  Future<void> pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
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

  Future<void> submitMeetingLog() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedMeetingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a meeting date.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    if (selectedFile == null || selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a PDF file first.')),
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
              'You can submit meeting log only after moderator approval.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final approvedProposal = approvedProposalSnapshot.docs.first.data();

      final meetingLogId =
          FirebaseFirestore.instance.collection('meeting_logs').doc().id;

      final safeFileName =
          selectedFileName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final storageRef = FirebaseStorage.instance.ref(
        'meeting_logs/${user.uid}/$meetingLogId-$safeFileName',
      );

      final uploadTask = await storageRef.putFile(selectedFile!);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('meeting_logs')
          .doc(meetingLogId)
          .set({
        'studentUid': user.uid,
        'studentId': userData?['studentId'],
        'studentName': userData?['name'],
        'studentEmail': user.email,
        'supervisorId': approvedProposal['supervisorId'],
        'supervisorName': approvedProposal['supervisorName'],
        'proposalTitle': approvedProposal['title'],
        'weekNumber': int.tryParse(_weekController.text.trim()) ?? 0,
        'meetingTitle': _titleController.text.trim(),
        'meetingDate': Timestamp.fromDate(selectedMeetingDate!),
        'originalFileName': safeFileName,
        'originalFileUrl': fileUrl,
        'originalFilePath': uploadTask.ref.fullPath,
        'signedFileName': null,
        'signedFileUrl': null,
        'signedFilePath': null,
        'status': 'Submitted to Supervisor',
        'submittedAt': FieldValue.serverTimestamp(),
        'signedAt': null,
        'moderatorReviewedAt': null,
        'moderatorFeedback': '',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meeting log submitted to supervisor.'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        selectedFile = null;
        selectedFileName = null;
        selectedMeetingDate = null;
        _weekController.clear();
        _titleController.clear();
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

  String _formatMeetingDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy').format(timestamp.toDate());
    }
    return 'N/A';
  }

  Widget _buildPreviousLogs(String studentUid) {
    final logsQuery = FirebaseFirestore.instance
        .collection('meeting_logs')
        .where('studentUid', isEqualTo: studentUid);

    return StreamBuilder<QuerySnapshot>(
      stream: logsQuery.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final logs = snapshot.data?.docs ?? [];

        logs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aWeek = aData['weekNumber'] ?? 0;
          final bWeek = bData['weekNumber'] ?? 0;

          return bWeek.compareTo(aWeek);
        });

        if (logs.isEmpty) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.history),
              title: Text('No meeting logs submitted yet'),
              subtitle: Text('Submitted meeting logs will appear here.'),
            ),
          );
        }

        return Column(
          children: logs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final status = data['status'] ?? '-';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text('${data['weekNumber'] ?? '-'}'),
                ),
                title: Text(data['meetingTitle'] ?? 'Meeting Log'),
                subtitle: Text(
                  'Status: $status\n'
                  'Meeting Date: ${_formatMeetingDate(data['meetingDate'])}\n'
                  'Submitted: ${DateFormatter.formatTimestamp(data['submittedAt'])}',
                ),
                isThreeLine: true,
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
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
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: () => downloadFile(data['originalFileUrl']),
                      child: const Icon(Icons.download),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Submit Meeting Log')),
        body: const Center(child: Text('Please login first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meeting Logs'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Submit New Meeting Log',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Meeting Title',
                        hintText: 'Example: Week 7 Meeting',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter meeting title';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _weekController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Week Number',
                        hintText: 'Example: 7',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter week number';
                        }

                        final week = int.tryParse(value.trim());

                        if (week == null || week <= 0) {
                          return 'Invalid week number';
                        }

                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: isUploading ? null : pickMeetingDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Meeting Date',
                          prefixIcon: Icon(Icons.calendar_month),
                          border: OutlineInputBorder(),
                        ),
                        child: Text(
                          selectedMeetingDate == null
                              ? 'Select meeting date'
                              : DateFormat('dd MMM yyyy')
                                  .format(selectedMeetingDate!),
                          style: TextStyle(
                            color: selectedMeetingDate == null
                                ? Colors.grey
                                : null,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: isUploading ? null : pickPdf,
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Choose Meeting Log PDF'),
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
                          borderRadius: BorderRadius.circular(10),
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
                              },
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: isUploading ? null : submitMeetingLog,
                        child: isUploading
                            ? const CircularProgressIndicator()
                            : const Text('Submit to Supervisor'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Previous Meeting Logs',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildPreviousLogs(user.uid),
        ],
      ),
    );
  }
}
