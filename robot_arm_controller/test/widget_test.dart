import 'package:flutter_test/flutter_test.dart';
import 'package:robot_arm_controller/models/robot_frame.dart';

void main() {
  test('RobotFrame parse CSV and format test without duration', () {
    const csv = '90,40,85,160,1';
    final frame = RobotFrame.fromCsv(csv);
    expect(frame, isNotNull);
    expect(frame!.angles, [90, 40, 85, 160]);
    expect(frame.conv, 1);
    expect(frame.convDurationMs, 0);
    expect(frame.convLabel, 'Maju ▶');
    expect(frame.toCsv(), '90,40,85,160,1,0');
  });

  test('RobotFrame parse CSV and format test with duration', () {
    const csv = '90,40,85,160,1,3500';
    final frame = RobotFrame.fromCsv(csv);
    expect(frame, isNotNull);
    expect(frame!.angles, [90, 40, 85, 160]);
    expect(frame.conv, 1);
    expect(frame.convDurationMs, 3500);
    expect(frame.convLabel, 'Maju ▶ (3.5s)');
    expect(frame.toCsv(), csv);
  });
}
