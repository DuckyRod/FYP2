import 'package:flutter_test/flutter_test.dart';
import 'package:fypbee/core/utils/fypbee_rules.dart';

void main() {
  group('User Authentication Rules', () {
    test('Approved user can access system', () {
      expect(FypbeeRules.isApprovedUser('approved'), true);
    });

    test('Pending user cannot access system', () {
      expect(FypbeeRules.isApprovedUser('pending'), false);
    });

    test('Blocked user is detected correctly', () {
      expect(FypbeeRules.isBlockedUser('blocked'), true);
    });

    test('Invalid role is rejected', () {
      expect(FypbeeRules.isValidRole('guest'), false);
    });

    test('Student role redirects to student dashboard', () {
      expect(FypbeeRules.dashboardForRole('student'), 'StudentDashboard');
    });

    test('Supervisor role redirects to supervisor dashboard', () {
      expect(FypbeeRules.dashboardForRole('supervisor'), 'SupervisorDashboard');
    });

    test('Moderator role redirects to moderator dashboard', () {
      expect(FypbeeRules.dashboardForRole('moderator'), 'ModeratorDashboard');
    });

    test('Admin role redirects to admin dashboard', () {
      expect(FypbeeRules.dashboardForRole('admin'), 'AdminDashboard');
    });
  });

  group('Proposal Management Rules', () {
    test('Student cannot submit when proposal is under review', () {
      expect(FypbeeRules.canSubmitProposal('Under Review'), false);
    });

    test('Student cannot submit when proposal is approved', () {
      expect(FypbeeRules.canSubmitProposal('Approved'), false);
    });

    test('Student can resubmit after proposal is rejected', () {
      expect(FypbeeRules.canSubmitProposal('Rejected'), true);
    });

    test('Supervisor capacity decreases when proposal is newly rejected', () {
      expect(
        FypbeeRules.shouldDecreaseSupervisorCapacity(
          oldStatus: 'Under Review',
          newStatus: 'Rejected',
        ),
        true,
      );
    });

    test('Supervisor capacity does not decrease twice for rejected proposal', () {
      expect(
        FypbeeRules.shouldDecreaseSupervisorCapacity(
          oldStatus: 'Rejected',
          newStatus: 'Rejected',
        ),
        false,
      );
    });

    test('Supervisor is full when current students equal max students', () {
      expect(
        FypbeeRules.isSupervisorFull(currentStudents: 5, maxStudents: 5),
        true,
      );
    });

    test('Supervisor is not full when current students below max students', () {
      expect(
        FypbeeRules.isSupervisorFull(currentStudents: 3, maxStudents: 5),
        false,
      );
    });
  });

  group('File Validation Rules', () {
    test('PDF proposal file is accepted', () {
      expect(FypbeeRules.isSupportedProposalFile('proposal.pdf'), true);
    });

    test('DOCX proposal file is accepted', () {
      expect(FypbeeRules.isSupportedProposalFile('proposal.docx'), true);
    });

    test('EXE proposal file is rejected', () {
      expect(FypbeeRules.isSupportedProposalFile('virus.exe'), false);
    });

    test('ZIP final submission file is accepted', () {
      expect(FypbeeRules.isSupportedFinalSubmissionFile('final.zip'), true);
    });

    test('PNG final submission file is rejected', () {
      expect(FypbeeRules.isSupportedFinalSubmissionFile('image.png'), false);
    });

    test('Unsafe file name is sanitized', () {
      expect(
        FypbeeRules.sanitizeFileName('my proposal final!!.pdf'),
        'my_proposal_final__.pdf',
      );
    });
  });

  group('Final Mark Rules', () {
    test('Mark 95 returns A+', () {
      expect(FypbeeRules.gradeFromMark(95), 'A+');
    });

    test('Mark 85 returns A', () {
      expect(FypbeeRules.gradeFromMark(85), 'A');
    });

    test('Mark 75 returns B', () {
      expect(FypbeeRules.gradeFromMark(75), 'B');
    });

    test('Mark 65 returns C', () {
      expect(FypbeeRules.gradeFromMark(65), 'C');
    });

    test('Mark 55 returns D', () {
      expect(FypbeeRules.gradeFromMark(55), 'D');
    });

    test('Mark 40 returns F', () {
      expect(FypbeeRules.gradeFromMark(40), 'F');
    });
  });

  group('Supervisor Review Filter Rules', () {
    test('Approved proposal is hidden when showResponded is false', () {
      expect(
        FypbeeRules.shouldShowProposalInReview(
          status: 'Approved',
          showResponded: false,
        ),
        false,
      );
    });

    test('Rejected proposal is hidden when showResponded is false', () {
      expect(
        FypbeeRules.shouldShowProposalInReview(
          status: 'Rejected',
          showResponded: false,
        ),
        false,
      );
    });

    test('Under Review proposal is shown when showResponded is false', () {
      expect(
        FypbeeRules.shouldShowProposalInReview(
          status: 'Under Review',
          showResponded: false,
        ),
        true,
      );
    });

    test('Approved proposal is shown when showResponded is true', () {
      expect(
        FypbeeRules.shouldShowProposalInReview(
          status: 'Approved',
          showResponded: true,
        ),
        true,
      );
    });
  });
}