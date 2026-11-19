import 'dart:math' as math;
import 'package:flutter/material.dart';

class RobotKinematicsPainter extends CustomPainter {
  final List<int> angles; // [0: Base, 1: Shoulder, 2: Elbow, 3: Gripper]
  final int convState; // 0=Stop, 1=Maju, 2=Mundur
  final bool isPlaying;

  RobotKinematicsPainter({
    required this.angles,
    required this.convState,
    required this.isPlaying,
  });

  // 3D to 2D Isometric Projection helper
  Offset _project3D(double x, double y, double z, double cx, double cy, double scale) {
    // 3D rotation: Iso 30 degrees
    const cos30 = 0.866025;
    const sin30 = 0.500000;
    final px = cx + (x - y) * cos30 * scale;
    final py = cy + (x + y) * sin30 * scale - z * scale;
    return Offset(px, py);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2 - 10;
    final cy = size.height / 2 + 15;
    const scale = 1.15;

    // 1. Draw 3D Ground Workbench Grid
    final gridPaint = Paint()
      ..color = const Color(0xFF1E2638).withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    for (double i = -60; i <= 60; i += 20) {
      final p1 = _project3D(-60, i, 0, cx, cy, scale);
      final p2 = _project3D(60, i, 0, cx, cy, scale);
      canvas.drawLine(p1, p2, gridPaint);

      final p3 = _project3D(i, -60, 0, cx, cy, scale);
      final p4 = _project3D(i, 60, 0, cx, cy, scale);
      canvas.drawLine(p3, p4, gridPaint);
    }

    // 2. Draw 3D Conveyor Belt (Positioned alongside the arm reach)
    final convColor = convState != 0 ? const Color(0xFF00E5FF) : const Color(0xFF334155);
    final convTop1 = _project3D(20, -50, 6, cx, cy, scale);
    final convTop2 = _project3D(42, -50, 6, cx, cy, scale);
    final convTop3 = _project3D(42, 50, 6, cx, cy, scale);
    final convTop4 = _project3D(20, 50, 6, cx, cy, scale);

    final convPath = Path()
      ..moveTo(convTop1.dx, convTop1.dy)
      ..lineTo(convTop2.dx, convTop2.dy)
      ..lineTo(convTop3.dx, convTop3.dy)
      ..lineTo(convTop4.dx, convTop4.dy)
      ..close();

    canvas.drawPath(convPath, Paint()..color = const Color(0xFF131D2E));
    canvas.drawPath(
      convPath,
      Paint()
        ..color = convColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Rollers along conveyor
    for (double cyVal = -40; cyVal <= 40; cyVal += 16) {
      final r1 = _project3D(22, cyVal, 6, cx, cy, scale);
      final r2 = _project3D(40, cyVal, 6, cx, cy, scale);
      canvas.drawLine(r1, r2, Paint()..color = const Color(0xFF475569)..strokeWidth = 1.2);
    }

    // Conveyor text indicator
    final convText = convState == 1 ? 'MAJU ▶' : convState == 2 ? '◀ MUNDUR' : 'CONVEYOR';
    final convTp = TextPainter(
      text: TextSpan(
        text: convText,
        style: TextStyle(
          color: convState != 0 ? const Color(0xFF00E5FF) : const Color(0xFF64748B),
          fontSize: 8.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final convLabelPos = _project3D(31, -45, 10, cx, cy, scale);
    convTp.paint(canvas, Offset(convLabelPos.dx - convTp.width / 2, convLabelPos.dy - 12));

    // 3. 3D Kinematics Calculation for Hacktuber Popsicle Robot Arm
    // Angles:
    // Base: 0 to 180 deg (Home: 90) -> Horizontally sweeps arm around Z-axis
    // Shoulder: 0 to 45 deg (Home: 0) -> Tilts lower boom up/down
    // Elbow: 30 to 180 deg (Home: 150) -> Tilts forearm forward/back
    // Gripper: 0 to 180 deg (Home: 180) -> Closes/opens string-pull jaws

    final baseDeg = angles[0].toDouble();
    final shoulderDeg = angles[1].toDouble();
    final elbowDeg = angles[2].toDouble();
    final gripDeg = angles[3].toDouble();

    // Base turntable angle (convert to radians in XY plane)
    // 90 deg = pointing along Y axis, 0 deg = pointing right, 180 deg = pointing left
    final baseRad = (baseDeg) * (math.pi / 180.0);
    final dirX = math.cos(baseRad);
    final dirY = math.sin(baseRad);

    // Robot Wooden Base Block
    const baseH = 12.0;
    final b1 = _project3D(-16, -16, 0, cx, cy, scale);
    final b2 = _project3D(16, -16, 0, cx, cy, scale);
    final b3 = _project3D(16, 16, 0, cx, cy, scale);
    final b4 = _project3D(-16, 16, 0, cx, cy, scale);
    final bt1 = _project3D(-16, -16, baseH, cx, cy, scale);
    final bt2 = _project3D(16, -16, baseH, cx, cy, scale);
    final bt3 = _project3D(16, 16, baseH, cx, cy, scale);
    final bt4 = _project3D(-16, 16, baseH, cx, cy, scale);

    // Draw Base Block 3D Sides
    final sidePaint = Paint()..color = const Color(0xFF131B2A);
    final baseOutline = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Front-left side
    final side1 = Path()
      ..moveTo(b1.dx, b1.dy)..lineTo(b2.dx, b2.dy)..lineTo(bt2.dx, bt2.dy)..lineTo(bt1.dx, bt1.dy)..close();
    canvas.drawPath(side1, sidePaint);
    canvas.drawPath(side1, baseOutline);

    // Front-right side
    final side2 = Path()
      ..moveTo(b2.dx, b2.dy)..lineTo(b3.dx, b3.dy)..lineTo(bt3.dx, bt3.dy)..lineTo(bt2.dx, bt2.dy)..close();
    canvas.drawPath(side2, sidePaint);
    canvas.drawPath(side2, baseOutline);

    // Base top surface
    final baseTopPath = Path()
      ..moveTo(bt1.dx, bt1.dy)..lineTo(bt2.dx, bt2.dy)..lineTo(bt3.dx, bt3.dy)..lineTo(bt4.dx, bt4.dy)..close();
    canvas.drawPath(baseTopPath, Paint()..color = const Color(0xFF1E293B));
    canvas.drawPath(baseTopPath, baseOutline);

    // Back reference points unused suppress
    if (b4.dx == 99999) canvas.drawCircle(b4, 1, sidePaint);
    // Shoulder Pivot Point P0 (at top of base servo horn)
    const p0z = baseH + 4.0;
    final p0 = _project3D(0, 0, p0z, cx, cy, scale);

    // Link 1: Shoulder Boom (Popsicle stick)
    // In this robot: 45 deg = upright, 0 deg = tilted forward
    final sElevRad = (40.0 + shoulderDeg * 0.9) * (math.pi / 180.0);
    const link1Len = 48.0;
    final r1 = link1Len * math.cos(sElevRad);
    final p1x = r1 * dirX;
    final p1y = r1 * dirY;
    final p1z = p0z + link1Len * math.sin(sElevRad);
    final p1 = _project3D(p1x, p1y, p1z, cx, cy, scale);

    // Link 2: Elbow Forearm (Popsicle stick)
    // Elbow servo relative angle: 90 deg = perpendicular, 180 deg = reached out, 30 deg = curled in
    final eAngleRel = (elbowDeg - 90.0) * 0.75;
    final eElevRad = (sElevRad - (math.pi / 2) + (eAngleRel * math.pi / 180.0));
    const link2Len = 46.0;
    final r2 = link2Len * math.cos(eElevRad);
    final p2x = p1x + r2 * dirX;
    final p2y = p1y + r2 * dirY;
    final p2z = p1z + link2Len * math.sin(eElevRad);
    final p2 = _project3D(p2x, p2y, p2z, cx, cy, scale);

    // End-Effector / Gripper (Jaws pulled by thread)
    const gripLen = 18.0;
    final p3x = p2x + gripLen * math.cos(eElevRad) * dirX;
    final p3y = p2y + gripLen * math.cos(eElevRad) * dirY;
    final p3z = p2z + gripLen * math.sin(eElevRad);
    final p3 = _project3D(p3x, p3y, p3z, cx, cy, scale);

    // Draw Link 1: Shoulder Popsicle Stick Beam (Warm Wood / Industrial Style)
    final stickPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 7.0
      ..strokeCap = StrokeCap.round;
    final stickCore = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(p0, p1, stickPaint);
    canvas.drawLine(p0, p1, stickCore);

    // Draw Link 2: Forearm Popsicle Stick Beam
    final stick2Paint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(p1, p2, stick2Paint);
    canvas.drawLine(p1, p2, stickCore);

    // Draw Joint Bearing Rivets
    void drawRivet(Offset pos, String label) {
      canvas.drawCircle(pos, 5.5, Paint()..color = const Color(0xFF0F172A));
      canvas.drawCircle(pos, 5.5, Paint()..color = const Color(0xFF00E5FF)..style = PaintingStyle.stroke..strokeWidth = 1.8);
      canvas.drawCircle(pos, 2, Paint()..color = const Color(0xFF00E5FF));

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 8, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(pos.dx + 7, pos.dy - 6));
    }

    drawRivet(p0, 'Base');
    drawRivet(p1, 'Bahu');
    drawRivet(p2, 'Siku');

    // Gripper: String-pulled clothespin jaws
    // 0 deg = clamp tightly closed, 180 deg = full open
    final jawSpread = (gripDeg / 180.0) * 11.0 + 2.0;

    // Perpendicular vector in horizontal plane
    final perpX = -dirY;
    final perpY = dirX;

    final jLeft = _project3D(p3x + perpX * jawSpread, p3y + perpY * jawSpread, p3z, cx, cy, scale);
    final jRight = _project3D(p3x - perpX * jawSpread, p3y - perpY * jawSpread, p3z, cx, cy, scale);

    final jawPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Wrist bar
    canvas.drawLine(jLeft, jRight, jawPaint);

    // Jaw tips pointing forward
    final tipLeft = _project3D(
      p3x + perpX * jawSpread + dirX * 9,
      p3y + perpY * jawSpread + dirY * 9,
      p3z - 4,
      cx,
      cy,
      scale,
    );
    final tipRight = _project3D(
      p3x - perpX * jawSpread + dirX * 9,
      p3y - perpY * jawSpread + dirY * 9,
      p3z - 4,
      cx,
      cy,
      scale,
    );

    canvas.drawLine(jLeft, tipLeft, jawPaint);
    canvas.drawLine(jRight, tipRight, jawPaint);

    // Pull-string line from servo to gripper (representing the thread)
    final threadPaint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.7)
      ..strokeWidth = 1.0;
    canvas.drawLine(p2, p3, threadPaint);

    // Gripper label
    final gTp = TextPainter(
      text: TextSpan(
        text: 'Capit: ${gripDeg.toInt()}°',
        style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    gTp.paint(canvas, Offset(p3.dx - gTp.width / 2, p3.dy + 8));
  }

  @override
  bool shouldRepaint(covariant RobotKinematicsPainter oldDelegate) {
    return oldDelegate.angles != angles ||
        oldDelegate.convState != convState ||
        oldDelegate.isPlaying != isPlaying;
  }
}
