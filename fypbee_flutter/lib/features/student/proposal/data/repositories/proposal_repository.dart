import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/proposal.dart';

class ProposalRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> submitProposalWithId({
    required String proposalId,
    required Proposal proposal,
  }) async {
    await FirebaseFirestore.instance
        .collection('proposals')
        .doc(proposalId)
        .set({
      'title': proposal.title,
      'description': proposal.description,
      'studentUid': proposal.studentUid,
      'studentId': proposal.studentId,
      'studentEmail': proposal.studentEmail,
      'studentName': proposal.studentName,
      'supervisorId': proposal.supervisorId,
      'supervisorName': proposal.supervisorName,
      'proposalFileName': proposal.proposalFileName,
      'proposalFileUrl': proposal.proposalFileUrl,
      'proposalFilePath': proposal.proposalFilePath,
      'status': proposal.status,
      'feedback': proposal.feedback,
      'createdAt': FieldValue.serverTimestamp(),
      'submittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(proposal.supervisorId)
        .update({
      'currentStudents': FieldValue.increment(1),
    });
  }
}
