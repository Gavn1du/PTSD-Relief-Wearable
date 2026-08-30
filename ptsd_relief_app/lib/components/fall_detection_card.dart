import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:ptsd_relief_app/services/bluetooth_connection.dart';

class FallDetectionCard extends StatelessWidget {
  const FallDetectionCard({
    super.key,
    required this.isConnected,
    required this.isMonitoring,
    required this.lastFallEvent,
  });

  final bool isConnected;
  final bool isMonitoring;
  final FallDetectionEvent? lastFallEvent;

  @override
  Widget build(BuildContext context) {
    final fall = lastFallEvent;
    final hasFall = fall != null;
    final color =
        hasFall
            ? Colors.red.shade700
            : isConnected && isMonitoring
            ? Colors.green.shade700
            : Colors.blueGrey.shade600;
    final icon =
        hasFall
            ? Icons.warning_amber_rounded
            : isConnected && isMonitoring
            ? Icons.health_and_safety_outlined
            : Icons.sensors_off_outlined;

    return Semantics(
      liveRegion: hasFall,
      label: hasFall ? 'Possible fall detected' : 'Fall detection status',
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fall detection',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          _statusTitle,
                          style: GoogleFonts.poppins(
                            color: color,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _statusBody,
                style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
              ),
              if (hasFall) ...[
                const SizedBox(height: 10),
                Text(
                  'Check on the wearer. If they may be injured or unresponsive, contact local emergency services.',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _statusTitle {
    if (lastFallEvent != null) return 'Possible fall detected';
    if (!isConnected) return 'Wearable disconnected';
    if (isMonitoring) return 'Monitoring active';
    return 'Waiting for sensor status';
  }

  String get _statusBody {
    final fall = lastFallEvent;
    if (fall != null) {
      final time = DateFormat('MMM d, h:mm a').format(fall.recordedAt);
      final disconnectedNote =
          isConnected ? '' : ' The wearable is now disconnected.';
      return 'The wearable detected a possible ${fall.description} event at $time.$disconnectedNote';
    }
    if (!isConnected) {
      return 'Connect the VitalLink Helper to receive accelerometer-based fall updates.';
    }
    if (isMonitoring) {
      return 'No fall-like event has been reported in the current wearable session.';
    }
    return 'The wearable is connected. Waiting for its accelerometer monitor to respond.';
  }
}
