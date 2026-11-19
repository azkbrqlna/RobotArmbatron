import 'package:flutter/material.dart';
import '../../controllers/robot_controller.dart';

class TimelineWidget extends StatelessWidget {
  final RobotController controller;

  const TimelineWidget({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final frames = controller.currentFrames;
    final isEditing = controller.isEditing;
    final editIdx = controller.editingIndex;
    final isPlaying = controller.isPlaying;
    final playIdx = controller.playIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sequence Switcher
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1522),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSeqTab(
                  'Sequence A',
                  controller.activeSeq == 'A',
                  () => controller.setActiveSeq('A'),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildSeqTab(
                  'Sequence B',
                  controller.activeSeq == 'B',
                  () => controller.setActiveSeq('B'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Waypoints Deck
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1522),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E293B)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Titik Gerakan',
                    style: TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${frames.length} Titik',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (frames.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => controller.clearAllFrames(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF450A0A),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFEF4444), width: 0.8),
                            ),
                            child: const Text(
                              'Hapus Semua',
                              style: TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Points horizontal list
              SizedBox(
                height: 70,
                child: frames.isEmpty
                    ? Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF090D15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF1E293B)),
                        ),
                        child: const Text(
                          'Belum ada titik. Tekan "+ Simpan Titik".',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                        ),
                      )
                    : ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: frames.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final frame = frames[index];
                          final isThisEditing = isEditing && editIdx == index;
                          final isThisPlaying = isPlaying && playIdx == index;

                          Color bgColor = const Color(0xFF161F30);
                          Color borderColor = const Color(0xFF334155);

                          if (isThisPlaying) {
                            bgColor = const Color(0xFF065F46);
                            borderColor = const Color(0xFF10B981);
                          } else if (isThisEditing) {
                            bgColor = const Color(0xFF1E3A8A);
                            borderColor = const Color(0xFF38BDF8);
                          }

                          return InkWell(
                            onTap: () => controller.selectFrameForEdit(index),
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 90,
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: borderColor,
                                  width: (isThisPlaying || isThisEditing) ? 1.8 : 1.0,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '#${index + 1}',
                                        style: TextStyle(
                                          color: isThisPlaying
                                              ? const Color(0xFF34D399)
                                              : Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => controller.deleteFrame(index),
                                        child: const Padding(
                                          padding: EdgeInsets.all(1),
                                          child: Icon(
                                            Icons.close,
                                            size: 11,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: frame.conv != 0
                                          ? const Color(0xFF0F2B3E)
                                          : const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      frame.convShortBadge,
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        fontWeight: FontWeight.bold,
                                        color: frame.conv != 0
                                            ? const Color(0xFF38BDF8)
                                            : const Color(0xFF94A3B8),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    '${frame.angles[0]}°/${frame.angles[3]}°',
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 8.5,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 8),

              // Info status konveyor yang akan disimpan bersama titik
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Konveyor titik: ${controller.recordedConvDirection == 0 ? "Nonaktif" : (controller.recordedConvDirection == 1 ? "Maju ▶" : "◀ Mundur")} (${(controller.recordedConvDurationMs / 1000.0).toStringAsFixed(1)}s)',
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Record / Edit Actions
              if (!isEditing) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0284C7),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text(
                          'Simpan Titik Ini',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: controller.recordFrame,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFF7F1D1D)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.undo, size: 14),
                        label: const Text('Undo', style: TextStyle(fontSize: 11)),
                        onPressed: frames.isEmpty ? null : controller.undoLastFrame,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF94A3B8),
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        onPressed: controller.cancelEdit,
                        child: const Text('Batal', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFF450A0A),
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        icon: const Icon(Icons.delete_forever, size: 15),
                        label: Text(
                          'Hapus #${editIdx + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: controller.deleteSelectedFrame,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.check, size: 15),
                        label: Text(
                          'Update #${editIdx + 1}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: controller.updateFrame,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Play / Stop Controls
        Row(
          children: [
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text(
                  'Mulai Gerakan (Loop)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: frames.isEmpty ? null : controller.startPlay,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.stop, size: 18),
                label: const Text(
                  'Stop',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: controller.stopPlay,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSeqTab(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}
