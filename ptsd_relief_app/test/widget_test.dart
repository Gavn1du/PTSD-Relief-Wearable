import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ptsd_relief_app/components/fall_detection_card.dart';
import 'package:ptsd_relief_app/services/bluetooth_connection.dart';

void main() {
  group('fall BLE protocol', () {
    test('parses a detected fall with its Raspberry Pi timestamp', () {
      final event = FallDetectionEvent.tryParse('FALL:TR:18bcfe56800\n');

      expect(event, isNotNull);
      expect(event!.kind, 'real_tripping');
      expect(event.recordedAt.millisecondsSinceEpoch, 1700000000000);
    });

    test('parses an active monitor status without a fall', () {
      final event = FallDetectionEvent.tryParse('FALL:OK:18bcfe56800');

      expect(event, isNotNull);
      expect(event!.detected, isFalse);
    });

    test('rejects malformed fall updates', () {
      expect(FallDetectionEvent.tryParse('FALL:TR:not-a-timestamp'), isNull);
      expect(FallDetectionEvent.tryParse('FALL:UNKNOWN:18bcfe56800'), isNull);
      expect(FallDetectionEvent.tryParse('BPM:72'), isNull);
    });
  });

  testWidgets('shows an urgent message for a possible fall', (tester) async {
    final event = FallDetectionEvent(
      kind: 'real_slipping',
      recordedAt: DateTime(2026, 8, 29, 14, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FallDetectionCard(
            isConnected: true,
            isMonitoring: true,
            lastFallEvent: event,
          ),
        ),
      ),
    );

    expect(find.text('Possible fall detected'), findsOneWidget);
    expect(find.textContaining('possible slipping event'), findsOneWidget);
    expect(
      find.textContaining('contact local emergency services'),
      findsOneWidget,
    );
  });
}
