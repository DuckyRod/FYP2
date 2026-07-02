import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class DecisionScreen extends StatefulWidget {
  final String proposalDocId;

  const DecisionScreen({
    super.key,
    required this.proposalDocId,
  });

  @override
  State<DecisionScreen> createState() => _DecisionScreenState();
}

class _DecisionScreenState extends State<DecisionScreen> {
  final _feedbackController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitDecision(String status) async {
    setState(() => _isLoading = true);

    try {
      final proposalRef = FirebaseFirestore.instance
          .collection('proposals')
          .doc(widget.proposalDocId);

      final proposalSnapshot = await proposalRef.get();

      if (!proposalSnapshot.exists) {
        throw Exception('Proposal not found');
      }

      final proposalData = proposalSnapshot.data();

      final oldStatus = proposalData?['status'];
      final supervisorId = proposalData?['supervisorId'];

      await proposalRef.update({
        'status': status,
        'feedback': _feedbackController.text.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
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

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Proposal marked as $status'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update proposal: $e'),
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
    final proposalRef = FirebaseFirestore.instance
        .collection('proposals')
        .doc(widget.proposalDocId);

    return Scaffold(
      appBar: AppBar(title: const Text('Proposal Decision')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: proposalRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Failed to load proposal.'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Proposal not found.'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          final title = data['title'] ?? '-';
          final status = data['status'] ?? 'Under Review';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.description),
                    title: Text(title),
                    subtitle: Text('Current status: $status'),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _feedbackController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Feedback / Comments',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: () =>
                              _submitDecision('Pending Moderator Approval'),
                          child: const Text('Approve and Forward to Moderator'),
                        ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : () => _submitDecision('Requires Modification'),
                    child: const Text('Request Modification'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading ? null : () => _submitDecision('Rejected'),
                    child: const Text('Reject'),
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
