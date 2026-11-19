import 'package:flutter/material.dart';
import '../../controllers/robot_controller.dart';

class SliderViewWidget extends StatelessWidget {
  final RobotController controller;

  const SliderViewWidget({super.key, required this.controller});

  static const List<Map<String, dynamic>> _joints = [
    {'name': 'Base', 'color': Color(0xFF38BDF8)},
    {'name': 'Bahu', 'color': Color(0xFF38BDF8)},
    {'name': 'Siku', 'color': Color(0xFF38BDF8)},
    {'name': 'Capit', 'color': Color(0xFFF59E0B)},
  ];

  @override
  Widget build(BuildContext context) {
    final angles = controller.angles;

    return Column(
      children: List.generate(4, (index) {
        final j = _joints[index];
        final minLimit = RobotController.limits[index][0];
        final maxLimit = RobotController.limits[index][1];
        final curVal = angles[index];
        final color = j['color'] as Color;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1522),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top label & degree value
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${j['name']} ($minLimit° - $maxLimit°)',
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$curVal°',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),

              // Slider
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: color,
                  inactiveTrackColor: const Color(0xFF1E293B),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: curVal.toDouble().clamp(minLimit.toDouble(), maxLimit.toDouble()),
                  min: minLimit.toDouble(),
                  max: maxLimit.toDouble(),
                  onChanged: (val) {
                    controller.setServoAngle(index, val.round());
                  },
                ),
              ),

              // Step jog row
              Row(
                children: [
                  Expanded(child: _buildStepBtn('-5°', () => controller.stepServo(index, -5))),
                  const SizedBox(width: 4),
                  Expanded(child: _buildStepBtn('-1°', () => controller.stepServo(index, -1))),
                  const SizedBox(width: 4),
                  Expanded(child: _buildStepBtn('+1°', () => controller.stepServo(index, 1))),
                  const SizedBox(width: 4),
                  Expanded(child: _buildStepBtn('+5°', () => controller.stepServo(index, 5))),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildStepBtn(String text, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9.5,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
