import 'package:flutter/material.dart';
import '../domain/entities/proposal.dart';
import 'proposal_status_screen.dart';

class ProposalSuccessScreen extends StatelessWidget {
  final Proposal proposal;

  const ProposalSuccessScreen({
    super.key,
    required this.proposal,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submission Success'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle,
                size: 90,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'Proposal Submitted Successfully',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your proposal has been sent to your supervisor for review.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProposalStatusScreen(),
                      ),
                    );
                  },
                  child: const Text('View Proposal Status'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
