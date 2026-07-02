import 'package:cloud_firestore/cloud_firestore.dart';

class Proposal {
  final String title;
  final String description;

  final String studentId;
  final String studentName;
  final String studentEmail;

  final String supervisorId;
  final String supervisorName;

  final String? proposalFileName;
  final String? proposalFileUrl;
  final String? proposalFilePath;

  final String studentUid;

  String status;
  String feedback;

  Proposal({
    required this.title,
    required this.description,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.supervisorId,
    required this.supervisorName,
    required this.studentUid,
    this.proposalFileName,
    this.proposalFileUrl,
    this.proposalFilePath,
    this.status = 'Under Review',
    this.feedback = '',
  });
}
