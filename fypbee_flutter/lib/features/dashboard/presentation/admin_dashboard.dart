import 'package:flutter/material.dart';
import '../../../../core/data/current_user.dart';
import '../../admin/presentation/admin_approve_users_screen.dart';
import '../../admin/presentation/admin_create_account_screen.dart';
import '../../admin/presentation/admin_manage_users_screen.dart';
import '../../../../core/utils/logout_helper.dart';
import '../../../../core/widgets/dashboard_card.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  void _goTo(BuildContext context, Widget page) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
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
                    Icon(Icons.admin_panel_settings,
                        size: 48, color: Colors.white),
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
              'Admin Features',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DashboardCard(
              title: 'Approve Users',
              subtitle: 'Approve or reject student accounts',
              icon: Icons.verified_user,
              onTap: () => _goTo(context, const ApproveUsersScreen()),
            ),
            DashboardCard(
              title: 'Create Account',
              subtitle: 'Create user with specific role',
              icon: Icons.person_add,
              onTap: () => _goTo(context, const CreateAccountScreen()),
            ),
            DashboardCard(
              title: 'Manage Users',
              subtitle: 'Edit user information and roles',
              icon: Icons.manage_accounts,
              onTap: () => _goTo(context, const ManageUsersScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
