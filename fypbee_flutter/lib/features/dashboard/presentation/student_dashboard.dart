import 'package:flutter/material.dart';
import '../../student/proposal/presentation/submit_proposal_screen.dart';
import '../../student/proposal/presentation/proposal_status_screen.dart';
import '../../student/meeting_log/presentation/meeting_log_screen.dart';
import '../../time_usage/presentation/student_time_usage_screen.dart';
import '../../../../core/utils/logout_helper.dart';
import '../../../../core/widgets/dashboard_card.dart';
import '../../../../core/data/current_user.dart';
import '../../student/final_submission/presentation/final_submission_screen.dart';
import '../../student/templates/presentation/templates_screen.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  void _goTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => LogoutHelper.confirmLogout(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: primary,
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.hive_rounded, size: 48, color: Colors.white),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Welcome, ${(CurrentUser.name ?? "Student").toUpperCase()}\nManage your FYP activities here.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Student Features',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DashboardCard(
              title: 'Submit Proposal',
              subtitle: 'Create and submit your FYP proposal',
              icon: Icons.description,
              onTap: () => _goTo(context, const SubmitProposalScreen()),
            ),
            DashboardCard(
              title: 'Proposal Status',
              subtitle: 'Track approval, rejection, or modification status',
              icon: Icons.track_changes,
              onTap: () => _goTo(context, const ProposalStatusScreen()),
            ),
            DashboardCard(
              title: 'Meeting Log',
              subtitle: 'Submit meeting summary and action items',
              icon: Icons.note_add,
              onTap: () => _goTo(context, const MeetingLogScreen()),
            ),
            DashboardCard(
              title: 'Time Usage',
              subtitle: 'Track time spent on each project stage',
              icon: Icons.timer,
              onTap: () => _goTo(context, const StudentTimeUsageScreen()),
            ),
            DashboardCard(
              title: 'Final Submission',
              subtitle: 'Final submission for your FYP',
              icon: Icons.upload_file,
              onTap: () => _goTo(context, const FinalSubmissionScreen()),
            ),
            DashboardCard(
              title: 'Templates',
              subtitle: 'Download your FYP templates',
              icon: Icons.download,
              onTap: () => _goTo(context, const TemplatesScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
