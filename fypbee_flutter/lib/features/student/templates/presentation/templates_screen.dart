import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  Future<void> _downloadFile(
    BuildContext context,
    String url,
  ) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    )) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open template'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _templateCard({
    required BuildContext context,
    required String title,
    required String description,
    required String url,
  }) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.description),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.download),
        onTap: () => _downloadFile(
          context,
          url,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Templates'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _templateCard(
            context: context,
            title: 'Proposal Template',
            description: 'Download proposal template',
            url:
                'https://firebasestorage.googleapis.com/v0/b/fypbee.firebasestorage.app/o/templates%2FFYP_Proposal_Template.docx?alt=media&token=30414438-13c0-487b-95e8-7f0ee30cd876',
          ),
          const SizedBox(height: 12),
          _templateCard(
            context: context,
            title: 'Meeting Log Template',
            description: 'Download meeting log template',
            url:
                'https://firebasestorage.googleapis.com/v0/b/fypbee.firebasestorage.app/o/templates%2FFYP_Meeting_Log_Template.pdf?alt=media&token=81f2a40f-0024-4454-8827-5670d3b536ea',
          ),
          const SizedBox(height: 12),
          _templateCard(
            context: context,
            title: 'Final Report Template',
            description: 'Download final report template',
            url:
                'https://firebasestorage.googleapis.com/v0/b/fypbee.firebasestorage.app/o/templates%2FFYP_Report_Template.docx?alt=media&token=8da27c7b-94d1-4ce5-9a69-8408789e473f',
          ),
        ],
      ),
    );
  }
}
