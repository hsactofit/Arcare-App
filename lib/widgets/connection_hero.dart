import 'dart:io';
import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'glass_card.dart';

class ConnectionHero extends StatelessWidget {
  final bool isConnected;
  final bool isDemoMode;
  final bool isSyncing;
  final HealthConnectSdkStatus? sdkStatus;
  final DateTime? lastSynced;
  final VoidCallback onSync;
  final VoidCallback onDisconnect;
  final VoidCallback onConnect;
  final VoidCallback onDemo;
  final VoidCallback onShowDownloadRationale;

  const ConnectionHero({
    super.key,
    required this.isConnected,
    required this.isDemoMode,
    required this.isSyncing,
    required this.sdkStatus,
    required this.lastSynced,
    required this.onSync,
    required this.onDisconnect,
    required this.onConnect,
    required this.onDemo,
    required this.onShowDownloadRationale,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (isConnected) {
      return GlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      "✓",
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDemoMode ? "Simulated Demo Active" : "Connected to Health Services",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isDemoMode
                            ? "Displaying static mockup info."
                            : "Wellness data is synced automatically.",
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: isSyncing ? null : onSync,
                    child: isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text("Sync Now", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: isDark ? Colors.white24 : Colors.black12, width: 1.2),
                      ),
                    ),
                    onPressed: onDisconnect,
                    child: Text(
                      "Disconnect",
                      style: TextStyle(
                        color: isDark ? Colors.white : Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (lastSynced != null) ...[
              const SizedBox(height: 10),
              Text(
                "Last sync: ${lastSynced!.hour.toString().padLeft(2, '0')}:${lastSynced!.minute.toString().padLeft(2, '0')}:${lastSynced!.second.toString().padLeft(2, '0')}",
                style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
              ),
            ]
          ],
        ),
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Sync Your Health Data",
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            "Connect to import steps, heart rate, sleep metrics, active calories, body weight, blood pressure, hydration, and nutrition directly from ${Platform.isIOS ? 'Apple HealthKit' : 'Google Health Connect'}.",
            style: const TextStyle(color: Colors.grey, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 24),
          
          if (isSyncing)
            const Center(child: CircularProgressIndicator())
          else if (Platform.isAndroid && sdkStatus == HealthConnectSdkStatus.sdkUnavailable)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: const Row(
                    children: [
                      Text("⚠️", style: TextStyle(fontSize: 20)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Health Connect app is not installed on this device.",
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: onShowDownloadRationale,
                  child: const Text("Download Health Connect", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            )
          else ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onConnect,
              child: const Text("Connect Health Services", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: const BorderSide(color: Colors.blue, width: 1.2),
              ),
              onPressed: onDemo,
              child: const Text("Try Demo Mode", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ]
        ],
      ),
    );
  }
}
