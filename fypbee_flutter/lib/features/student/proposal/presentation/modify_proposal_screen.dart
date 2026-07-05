import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ModifyProposalScreen extends StatefulWidget {
  final String proposalDocId;
  final Map<String, dynamic> proposalData;

  const ModifyProposalScreen({
    super.key,
    required this.proposalDocId,
    required this.proposalData,
  });

  @override
  State<ModifyProposalScreen> createState() => _ModifyProposalScreenState();
}

class _ModifyProposalScreenState extends State<ModifyProposalScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  File? selectedFile;
  String? selectedFileName;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    _titleController = TextEditingController(
      text: widget.proposalData['title'] ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.proposalData['description'] ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String? _required(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required';
    }
    return null;
  }

  Future<void> _pickProposalFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );

    if (result == null) return;

    setState(() {
      selectedFile = File(result.files.single.path!);
      selectedFileName = result.files.single.name;
    });
  }

  Future<void> _submitModification() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedFile == null || selectedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload the revised proposal file'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final oldFilePath = widget.proposalData['proposalFilePath'];

      if (oldFilePath != null && oldFilePath.toString().isNotEmpty) {
        try {
          await FirebaseStorage.instance.ref(oldFilePath).delete();
        } catch (_) {
          // Ignore old file delete error.
        }
      }

      final safeFileName =
          selectedFileName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final storageRef = FirebaseStorage.instance.ref(
        'proposal_files_modified/${widget.proposalDocId}/$safeFileName',
      );

      final uploadTask = await storageRef.putFile(selectedFile!);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('proposals')
          .doc(widget.proposalDocId)
          .update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'proposalFileName': safeFileName,
        'proposalFileUrl': fileUrl,
        'proposalFilePath': uploadTask.ref.fullPath,
        'status': 'Under Review',
        'feedback': '',
        'moderatorFeedback': '',
        'reviewedAt': null,
        'moderatorReviewedAt': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposal modified and resubmitted'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to modify proposal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final oldFeedback = widget.proposalData['feedback'] ?? '';
    final oldModeratorFeedback = widget.proposalData['moderatorFeedback'] ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Modify Proposal')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (oldFeedback.toString().isNotEmpty) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.feedback),
                    title: const Text('Supervisor Feedback'),
                    subtitle: Text(oldFeedback),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (oldModeratorFeedback.toString().isNotEmpty) ...[
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.feedback_outlined),
                    title: const Text('Moderator Feedback'),
                    subtitle: Text(oldModeratorFeedback),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _titleController,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Project Title',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                validator: _required,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Short Description',
                  prefixIcon: Icon(Icons.description),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _pickProposalFile,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Choose Revised Proposal File'),
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
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description,
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
                                onPressed: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          selectedFile = null;
                                          selectedFileName = null;
                                        });
                                      },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      const Text(
                        'Accepted: PDF, DOC, DOCX',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        onPressed: _submitModification,
                        icon: const Icon(Icons.upload),
                        label: const Text('Resubmit Proposal'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
