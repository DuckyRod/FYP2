import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;

  const StatusChip({
    super.key,
    required this.status,
  });

  Color _color() {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      case 'Requires Modification':
        return Colors.orange;
      case 'Under Review':
        return Colors.blueGrey;
      default:
        return Colors.grey;
    }
  }

  IconData _icon() {
    switch (status) {
      case 'Approved':
        return Icons.check_circle;
      case 'Rejected':
        return Icons.cancel;
      case 'Requires Modification':
        return Icons.edit_note;
      case 'Under Review':
        return Icons.hourglass_top;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return Chip(
      avatar: Icon(_icon(), color: Colors.white, size: 18),
      label: Text(
        status,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: color,
    );
  }
}
