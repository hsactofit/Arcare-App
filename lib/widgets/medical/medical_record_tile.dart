import 'package:flutter/material.dart';
import '../../services/health_service.dart';
import 'medical_record_detail_dialog.dart';

class MedicalRecordTile extends StatelessWidget {
  final MedicalRecord record;

  const MedicalRecordTile({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final status = record.status;
    final isAlert = status == "Flagged" || status == "Critical";

    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => MedicalRecordDetailDialog(record: record),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isAlert ? Colors.red : Colors.blue).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  record.category == "Immunization"
                      ? "💉"
                      : record.category == "Cardiology"
                          ? "❤️"
                          : "📄",
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${record.category} • ${record.provider}",
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                  decoration: BoxDecoration(
                    color: (isAlert ? Colors.red : Colors.green).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: isAlert ? Colors.redAccent : Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${record.date.month}/${record.date.day}/${record.date.year}",
                  style: const TextStyle(color: Colors.grey, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
