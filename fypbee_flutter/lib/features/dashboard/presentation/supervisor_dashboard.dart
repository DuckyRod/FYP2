import 'package:flutter/material.dart';
import '../../supervisor/presentation/supervisor_review_proposal_screen.dart';
import '../../supervisor/presentation/supervisor_meeting_log_screen.dart';
import '../../../../core/utils/logout_helper.dart';
import '../../../../core/widgets/dashboard_card.dart';
import '../../../../core/data/current_user.dart';
import '../../supervisor/presentation/supervisor_final_submissions_screen.dart';

class SupervisorDashboard extends StatelessWidget {
  const SupervisorDashboard({super.key});

  void _goTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisor Dashboard'),
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
                    Icon(
                      Icons.supervisor_account,
                      size: 48,
                      color: Colors.white,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Welcome, ${(CurrentUser.name ?? "Supervisor").toUpperCase()}\nReview proposals and monitor student progress.',
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
              'Supervisor Features',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DashboardCard(
              title: 'Review Proposal',
              subtitle: 'View student proposal details and feedback',
              icon: Icons.assignment,
              onTap: () => _goTo(context, const ReviewProposalScreen()),
            ),
            DashboardCard(
              title: 'Monitor Student Progress',
              subtitle: 'View logs, reports, and student progress',
              icon: Icons.analytics,
              onTap: () => _goTo(context, const MonitorProgressScreen()),
            ),
            DashboardCard(
              title: 'Final Submissions',
              subtitle: 'View student final project submissions',
              icon: Icons.upload_file,
              onTap: () =>
                  _goTo(context, const SupervisorFinalSubmissionsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
