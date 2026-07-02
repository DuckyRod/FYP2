class FypbeeRules {
  static bool isApprovedUser(String? status) {
    return status == 'approved';
  }

  static bool isBlockedUser(String? status) {
    return status == 'blocked';
  }

  static bool isValidRole(String? role) {
    return role == 'student' ||
        role == 'supervisor' ||
        role == 'moderator' ||
        role == 'admin';
  }

  static String dashboardForRole(String role) {
    switch (role) {
      case 'student':
        return 'StudentDashboard';
      case 'supervisor':
        return 'SupervisorDashboard';
      case 'moderator':
        return 'ModeratorDashboard';
      case 'admin':
        return 'AdminDashboard';
      default:
        return 'InvalidRole';
    }
  }

  static bool canSubmitProposal(String status) {
    return status != 'Under Review' &&
        status != 'Pending Moderator Approval' &&
        status != 'Approved';
  }

  static bool shouldDecreaseSupervisorCapacity({
    required String oldStatus,
    required String newStatus,
  }) {
    return newStatus == 'Rejected' && oldStatus != 'Rejected';
  }

  static bool isSupervisorFull({
    required int currentStudents,
    required int maxStudents,
  }) {
    return currentStudents >= maxStudents;
  }

  static bool isSupportedProposalFile(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx');
  }

  static bool isSupportedFinalSubmissionFile(String fileName) {
    final lower = fileName.toLowerCase();
    return lower.endsWith('.pdf') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.docx') ||
        lower.endsWith('.zip');
  }

  static String gradeFromMark(double mark) {
    if (mark >= 90) return 'A+';
    if (mark >= 80) return 'A';
    if (mark >= 70) return 'B';
    if (mark >= 60) return 'C';
    if (mark >= 50) return 'D';
    return 'F';
  }

  static String sanitizeFileName(String fileName) {
    return fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
  }

  static bool shouldShowProposalInReview({
    required String status,
    required bool showResponded,
  }) {
    final respondedStatuses = [
      'Pending Moderator Approval',
      'Approved',
      'Rejected',
      'Requires Modification',
    ];

    if (!showResponded && respondedStatuses.contains(status)) {
      return false;
    }

    return true;
  }
}
