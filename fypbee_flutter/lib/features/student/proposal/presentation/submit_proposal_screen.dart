import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

import '../data/repositories/proposal_repository.dart';
import '../domain/entities/proposal.dart';
import 'proposal_success_screen.dart';
import '../../../../core/data/current_user.dart';
import '../domain/entities/selected_supervisor.dart';
import 'select_supervisor_screen.dart';

class SubmitProposalScreen extends StatefulWidget {
  const SubmitProposalScreen({super.key});

  @override
  State<SubmitProposalScreen> createState() => _SubmitProposalScreenState();
}

class _SubmitProposalScreenState extends State<SubmitProposalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _proposalRepository = ProposalRepository();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  SelectedSupervisor? _selectedSupervisor;

  File? selectedFile;
  String? selectedFileName;

  bool _isLoading = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSupervisor == null) {
      _showError('Please select a supervisor');
      return;
    }

    if (_selectedSupervisor!.isFull) {
      _showError('Selected supervisor has reached the maximum student limit');
      return;
    }

    if (selectedFile == null || selectedFileName == null) {
      _showError('Please upload your proposal file');
      return;
    }

    final canSubmit = await _canSubmitProposal();

    if (!canSubmit) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already have an active proposal submission.'),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    setState(() => _isLoading = true);

    try {
      final proposalDoc =
          FirebaseFirestore.instance.collection('proposals').doc();

      final proposalId = proposalDoc.id;

      final safeFileName =
          selectedFileName!.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');

      final storageRef = FirebaseStorage.instance.ref(
        'proposal_files/${CurrentUser.uid}/$proposalId-$safeFileName',
      );

      final uploadTask = await storageRef.putFile(selectedFile!);
      final fileUrl = await uploadTask.ref.getDownloadURL();

      final proposal = Proposal(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        studentUid: CurrentUser.uid ?? 'Unknown UID',
        studentId: CurrentUser.id ?? 'Unknown Student',
        studentName: CurrentUser.name ?? 'Unknown Student',
        studentEmail: CurrentUser.email ?? 'Unknown Email',
        supervisorId: _selectedSupervisor!.uid,
        supervisorName: _selectedSupervisor!.name,
        proposalFileName: safeFileName,
        proposalFileUrl: fileUrl,
        proposalFilePath: uploadTask.ref.fullPath,
      );

      await _proposalRepository.submitProposalWithId(
        proposalId: proposalId,
        proposal: proposal,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProposalSuccessScreen(proposal: proposal),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('Failed to submit proposal: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _canSubmitProposal() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('proposals')
        .where('studentId', isEqualTo: CurrentUser.id)
        .get();

    if (snapshot.docs.isEmpty) return true;

    for (final doc in snapshot.docs) {
      final status = doc.data()['status'];

      if (status == 'Under Review' ||
          status == 'Pending Moderator Approval' ||
          status == 'Approved') {
        return false;
      }
    }

    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Proposal'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                validator: _required,
                decoration: const InputDecoration(
                  labelText: 'Project Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                validator: _required,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Short Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.supervisor_account),
                  title: Text(
                    _selectedSupervisor == null
                        ? 'Select Supervisor'
                        : _selectedSupervisor!.name,
                  ),
                  subtitle: Text(
                    _selectedSupervisor == null
                        ? 'Choose an available supervisor'
                        : 'Capacity: ${_selectedSupervisor!.currentStudents}/${_selectedSupervisor!.maxStudents}',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () async {
                    final result = await Navigator.push<SelectedSupervisor>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelectSupervisorScreen(),
                      ),
                    );

                    if (result != null) {
                      setState(() => _selectedSupervisor = result);
                    }
                  },
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
                          label: const Text('Choose Proposal File'),
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
                        onPressed: _submit,
                        icon: const Icon(Icons.send),
                        label: const Text('Submit Proposal'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
