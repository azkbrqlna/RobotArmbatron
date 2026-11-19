import 'dart:async';
import 'package:flutter/material.dart';
import '../../controllers/robot_controller.dart';

class DPadWidget extends StatefulWidget {
  final RobotController controller;

  const DPadWidget({super.key, required this.controller});

  @override
  State<DPadWidget> createState() => _DPadWidgetState();
}

class _DPadWidgetState extends State<DPadWidget> {
  Timer? _holdTimer;

  void _startHold(int id, int step) {
    _stopHold();
    widget.controller.stepServo(id, step);
    _holdTimer = Timer.periodic(const Duration(milliseconds: 40), (_) {
      widget.controller.stepServo(id, step);
    });
  }

  void _stopHold() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  @override
  void dispose() {
    _stopHold();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final angles = widget.controller.angles;

    return Column(
      children: [
        // D-Pad + Siku
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1522),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Left: D-Pad
              Column(
                children: [
                  const Text(
                    'Bahu & Base',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  _buildCrossPad(),
                ],
              ),

              Container(width: 1, height: 130, color: const Color(0xFF1E293B)),

              // Right: Siku
              Column(
                children: [
                  const Text(
                    'Siku',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${angles[2]}°',
                    style: const TextStyle(
                      color: Color(0xFF38BDF8),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRockerBtn(
                    icon: Icons.keyboard_arrow_up,
                    label: 'Naik',
                    onHoldStart: () => _startHold(2, 1),
                    onHoldEnd: _stopHold,
                  ),
                  const SizedBox(height: 6),
                  _buildRockerBtn(
                    icon: Icons.keyboard_arrow_down,
                    label: 'Turun',
                    onHoldStart: () => _startHold(2, -1),
                    onHoldEnd: _stopHold,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Capit / Gripper
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1522),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Capit (Gripper)',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${angles[3]}°',
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: const Color(0xFFF59E0B),
                  inactiveTrackColor: const Color(0xFF1E293B),
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                ),
                child: Slider(
                  value: angles[3].toDouble(),
                  min: 0,
                  max: 180,
                  onChanged: (val) {
                    widget.controller.setServoAngle(3, val.round());
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildQuickBtn(
                      'Tutup (0°)',
                      angles[3] <= 15,
                      () => widget.controller.setServoAngle(3, 0),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildQuickBtn(
                      '90°',
                      angles[3] >= 80 && angles[3] <= 100,
                      () => widget.controller.setServoAngle(3, 90),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildQuickBtn(
                      'Buka (180°)',
                      angles[3] >= 170,
                      () => widget.controller.setServoAngle(3, 180),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCrossPad() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF161F30),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF334155)),
            ),
          ),
          Positioned(
            top: 0,
            child: _buildPadBtn(
              icon: Icons.arrow_upward,
              onHoldStart: () => _startHold(1, -1),
              onHoldEnd: _stopHold,
            ),
          ),
          Positioned(
            bottom: 0,
            child: _buildPadBtn(
              icon: Icons.arrow_downward,
              onHoldStart: () => _startHold(1, 1),
              onHoldEnd: _stopHold,
            ),
          ),
          Positioned(
            left: 0,
            child: _buildPadBtn(
              icon: Icons.arrow_back,
              onHoldStart: () => _startHold(0, 1),
              onHoldEnd: _stopHold,
            ),
          ),
          Positioned(
            right: 0,
            child: _buildPadBtn(
              icon: Icons.arrow_forward,
              onHoldStart: () => _startHold(0, -1),
              onHoldEnd: _stopHold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPadBtn({
    required IconData icon,
    required VoidCallback onHoldStart,
    required VoidCallback onHoldEnd,
  }) {
    return GestureDetector(
      onTapDown: (_) => onHoldStart(),
      onTapUp: (_) => onHoldEnd(),
      onTapCancel: () => onHoldEnd(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Icon(icon, color: const Color(0xFF38BDF8), size: 18),
      ),
    );
  }

  Widget _buildRockerBtn({
    required IconData icon,
    required String label,
    required VoidCallback onHoldStart,
    required VoidCallback onHoldEnd,
  }) {
    return GestureDetector(
      onTapDown: (_) => onHoldStart(),
      onTapUp: (_) => onHoldEnd(),
      onTapCancel: () => onHoldEnd(),
      child: Container(
        width: 72,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF38BDF8), size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickBtn(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? const Color(0xFFF59E0B) : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.black : const Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      ),
    );
  }
}
