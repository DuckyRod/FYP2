import 'package:flutter/material.dart';
import '../../moderator/presentation/moderator_approved_archive_screen.dart';
import '../../../../core/utils/logout_helper.dart';
import '../../../../core/widgets/dashboard_card.dart';
import '../../../../core/data/current_user.dart';
import '../../moderator/presentation/moderator_final_submissions_screen.dart';
import '../../moderator/presentation/moderator_review_proposal_screen.dart';
import '../../moderator/presentation/moderator_meeting_logs_screen.dart';

class ModeratorDashboard extends StatelessWidget {
  const ModeratorDashboard({super.key});

  void _goTo(BuildContext context, Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moderator Dashboard'),
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
                      Icons.admin_panel_settings,
                      size: 48,
                      color: Colors.white,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Welcome, ${(CurrentUser.name ?? "Moderator").toUpperCase()}\nMonitor approved projects and archive records.',
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
              'Moderator Features',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DashboardCard(
              title: 'Review Proposals',
              subtitle: 'Review proposals approved by supervisors',
              icon: Icons.rate_review,
              onTap: () =>
                  _goTo(context, const ModeratorReviewProposalScreen()),
            ),
            DashboardCard(
              title: 'Approved Projects Archive',
              subtitle: 'View approved project records',
              icon: Icons.archive,
              onTap: () => _goTo(context, const ApprovedArchiveScreen()),
            ),
            DashboardCard(
              title: 'Meeting Logs',
              subtitle: 'View signed meeting logs',
              icon: Icons.note_alt,
              onTap: () => _goTo(context, const ModeratorMeetingLogsScreen()),
            ),
            DashboardCard(
              title: 'Final Submissions',
              subtitle: 'View all student final submissions',
              icon: Icons.folder_copy,
              onTap: () =>
                  _goTo(context, const ModeratorFinalSubmissionsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
