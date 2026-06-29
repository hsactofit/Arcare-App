import 'package:flutter/material.dart';

class MedicalConsentSheet extends StatefulWidget {
  final Future<void> Function() onAuthorize;

  const MedicalConsentSheet({super.key, required this.onAuthorize});

  @override
  State<MedicalConsentSheet> createState() => _MedicalConsentSheetState();
}

class _MedicalConsentSheetState extends State<MedicalConsentSheet> {
  bool _isChecked = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.security, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            "Consent Form: Medical Records Sync",
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            "By enabling Medical & Health Records synchronization, you explicitly consent and authorize the application to:",
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _consentPoint("1. Retrieve your clinical records, lab test reports, immunizations, and cardiology (ECG) data from your secure on-device health database."),
          _consentPoint("2. Process and cache this telemetry locally for offline visual dashboards. Your data will never be sent to any cloud backend or shared with third parties without your explicit intent."),
          _consentPoint("3. Understand that you can withdraw and revoke this consent at any time, which immediately deletes all local cache and locks medical records views."),
          const SizedBox(height: 20),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text(
              "I explicitly consent to allow wellnessconnect to access my secure medical records.",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            value: _isChecked,
            activeColor: Colors.blue,
            onChanged: (val) {
              setState(() {
                _isChecked = val ?? false;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Decline"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: !_isChecked
                      ? null
                      : () async {
                          Navigator.pop(context);
                          await widget.onAuthorize();
                        },
                  child: const Text(
                    "Agree & Authorize",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _consentPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("• ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
