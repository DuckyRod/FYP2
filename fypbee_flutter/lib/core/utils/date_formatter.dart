import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class DateFormatter {
  static String formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';

    if (timestamp is Timestamp) {
      final utcDate = timestamp.toDate().toUtc();
      final malaysiaDate = utcDate.add(const Duration(hours: 8));

      return '${DateFormat('dd MMM yyyy, hh:mm a').format(malaysiaDate)} MYT';
    }

    return 'N/A';
  }
}
