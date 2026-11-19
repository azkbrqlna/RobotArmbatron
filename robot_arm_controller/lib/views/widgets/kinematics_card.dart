import 'package:flutter/material.dart';
import '../../controllers/robot_controller.dart';
import 'robot_kinematics_painter.dart';

class KinematicsCard extends StatelessWidget {
  final RobotController controller;

  const KinematicsCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final angles = controller.angles;
    final conv = controller.convState;
    final isPlaying = controller.isPlaying;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isPlaying ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Simulasi Posisi',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isPlaying)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Text(
                      'LOOPING',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Canvas Preview
          SizedBox(
            height: 155,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
              child: CustomPaint(
                painter: RobotKinematicsPainter(
                  angles: angles,
                  convState: conv,
                  isPlaying: isPlaying,
                ),
              ),
            ),
          ),

          // Bottom Short Telemetry Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF090D15),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(11)),
              border: Border(top: BorderSide(color: Color(0xFF1E293B))),
            ),
            child: Row(
              children: [
                Expanded(child: _buildShortBadge('Base', '${angles[0]}°', const Color(0xFF38BDF8))),
                Expanded(child: _buildShortBadge('Bahu', '${angles[1]}°', const Color(0xFF38BDF8))),
                Expanded(child: _buildShortBadge('Siku', '${angles[2]}°', const Color(0xFF38BDF8))),
                Expanded(child: _buildShortBadge('Capit', '${angles[3]}°', const Color(0xFFF59E0B))),
                Expanded(
                  child: _buildShortBadge(
                    'Conv',
                    conv == 1
                        ? 'Maju'
                        : conv == 2
                            ? 'Mundur'
                            : 'Stop',
                    conv == 0 ? const Color(0xFF64748B) : const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortBadge(String label, String val, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 1),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            val,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}
