import 'package:flutter/material.dart';
import '../../services/health_service.dart';
import '../glass_card.dart';
import 'medical_record_tile.dart';

class MedicalRecordsSection extends StatelessWidget {
  final HealthData healthData;
  final VoidCallback onProvideConsentPressed;
  final VoidCallback onRevokeConsentPressed;

  const MedicalRecordsSection({
    super.key,
    required this.healthData,
    required this.onProvideConsentPressed,
    required this.onRevokeConsentPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (!healthData.medicalRecordsConsented) {
      // Locked State
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, color: Colors.redAccent, size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Medical & Clinical Records",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        "Explicit consent required to access clinical reports.",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Your medical files, vaccinations, and lab results are protected under HIPAA/GDPR standards. "
              "We process clinical records locally on your device. Access is disabled until you provide explicit authorization.",
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              icon: const Icon(Icons.assignment_ind, color: Colors.white),
              label: const Text(
                "Provide Explicit Consent",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              onPressed: onProvideConsentPressed,
            ),
          ],
        ),
      );
    }

    // Unlocked State
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_turned_in, color: Colors.green, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Medical Records",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text(
                        "Synced securely with explicit consent",
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.lock_open, color: Colors.green),
                tooltip: "Consent Active - Tap to Revoke",
                onPressed: onRevokeConsentPressed,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (healthData.medicalRecords.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                "No medical records found in device database.",
                style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: healthData.medicalRecords.length,
              separatorBuilder: (context, index) => const Divider(height: 16),
              itemBuilder: (context, index) {
                final record = healthData.medicalRecords[index];
                return MedicalRecordTile(record: record);
              },
            ),
          const SizedBox(height: 16),
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            icon: const Icon(Icons.no_accounts),
            label: const Text("Revoke Explicit Consent", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: onRevokeConsentPressed,
          ),
        ],
      ),
    );
  }
}
