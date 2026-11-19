import 'package:flutter/material.dart';
import '../../controllers/robot_controller.dart';

class ConveyorWidget extends StatelessWidget {
  final RobotController controller;
  final bool isAutoMode;

  const ConveyorWidget({
    super.key,
    required this.controller,
    this.isAutoMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!isAutoMode) {
      return _buildManualConveyor();
    }
    return _buildAutoRecordingConveyor();
  }

  // ==========================================
  // MODE MANUAL (Kontrol Langsung Tanpa Rekam)
  // ==========================================
  Widget _buildManualConveyor() {
    final state = controller.convState;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.conveyor_belt, size: 15, color: Color(0xFF38BDF8)),
                  SizedBox(width: 6),
                  Text(
                    'Conveyor Manual',
                    style: TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Text(
                state == 1
                    ? 'Maju'
                    : state == 2
                        ? 'Mundur'
                        : 'Berhenti',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: state == 0
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildManualBtn(
                  '◀ Mundur',
                  state == 2,
                  const Color(0xFF0284C7),
                  () => controller.setConveyor(2),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildManualBtn(
                  'Stop',
                  state == 0,
                  const Color(0xFFDC2626),
                  () => controller.setConveyor(0),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildManualBtn(
                  'Maju ▶',
                  state == 1,
                  const Color(0xFF059669),
                  () => controller.setConveyor(1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualBtn(
    String label,
    bool isActive,
    Color activeBg,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? activeBg : const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isActive ? activeBg : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // MODE OTOMATIS (Mode Rekam Waktu & Otomatisasi)
  // ==========================================
  Widget _buildAutoRecordingConveyor() {
    final isRecording = controller.isConvRecording;
    final isTesting = controller.isConvTesting;
    final dir = controller.recordedConvDirection;
    final elapsedMs = controller.convElapsedMs;
    final elapsedSec = (elapsedMs / 1000.0).toStringAsFixed(1);
    final convPhysicalState = controller.convState;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRecording
              ? const Color(0xFFEF4444)
              : isTesting
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFF1E293B),
          width: isRecording || isTesting ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.conveyor_belt,
                    size: 16,
                    color: isRecording
                        ? const Color(0xFFEF4444)
                        : const Color(0xFF38BDF8),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Rekam Konveyor',
                    style: TextStyle(
                      color: Color(0xFFF1F5F9),
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              _buildStatusBadge(isRecording, isTesting, convPhysicalState),
            ],
          ),

          const SizedBox(height: 10),

          // Selector Arah Konveyor
          Row(
            children: [
              Expanded(
                child: _buildDirTab(
                  'Nonaktif (0s)',
                  dir == 0,
                  Icons.power_settings_new,
                  const Color(0xFF64748B),
                  () => controller.setRecordedConvDirection(0),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildDirTab(
                  'Maju ▶',
                  dir == 1,
                  Icons.arrow_forward,
                  const Color(0xFF059669),
                  () => controller.setRecordedConvDirection(1),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildDirTab(
                  '◀ Mundur',
                  dir == 2,
                  Icons.arrow_back,
                  const Color(0xFF0284C7),
                  () => controller.setRecordedConvDirection(2),
                ),
              ),
            ],
          ),

          if (dir != 0) ...[
            const SizedBox(height: 10),

            // Timer Display Deck
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isRecording
                    ? const Color(0xFF450A0A)
                    : const Color(0xFF090D15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isRecording
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF1E293B),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRecording ? 'SEDANG MEREKAM WAKTU...' : 'DURASI TERCATAT:',
                        style: TextStyle(
                          color: isRecording
                              ? const Color(0xFFFCA5A5)
                              : const Color(0xFF94A3B8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            elapsedSec,
                            style: TextStyle(
                              color: isRecording
                                  ? const Color(0xFFEF4444)
                                  : elapsedMs > 0
                                      ? const Color(0xFF38BDF8)
                                      : const Color(0xFF64748B),
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'detik',
                            style: TextStyle(
                              color: isRecording
                                  ? const Color(0xFFFCA5A5)
                                  : const Color(0xFF64748B),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Quick Tune Buttons (+/- 0.5s & Reset)
                  if (!isRecording)
                    Row(
                      children: [
                        _buildFineTuneBtn('-0.5s', () {
                          controller.adjustRecordedConvDuration(-500);
                        }),
                        const SizedBox(width: 4),
                        _buildFineTuneBtn('+0.5s', () {
                          controller.adjustRecordedConvDuration(500);
                        }),
                        if (elapsedMs > 0) ...[
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.refresh, size: 16),
                            color: const Color(0xFF94A3B8),
                            tooltip: 'Reset Durasi',
                            onPressed: () =>
                                controller.resetRecordedConvDuration(),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Tombol Utama Rekam (Play Jalan / Stop Berhenti)
            if (!isRecording) ...[
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
                        'Play & Rekam Waktu',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => controller.startConvRecord(),
                    ),
                  ),
                  if (elapsedMs > 0) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 1,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF38BDF8),
                          side: const BorderSide(color: Color(0xFF0284C7)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(
                          isTesting ? Icons.stop : Icons.replay,
                          size: 14,
                        ),
                        label: Text(
                          isTesting ? 'Batal' : 'Tes Putar',
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () {
                          if (isTesting) {
                            controller.cancelConvTest();
                          } else {
                            controller.testPlayRecordedConv();
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.stop, size: 20),
                label: const Text(
                  'STOP & CATAT WAKTU (Simpan Durasi)',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () => controller.stopConvRecord(),
              ),
            ],
          ] else ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF090D15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Konveyor dinonaktifkan pada titik gerakan ini (durasi 0 detik).',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(
      bool isRecording, bool isTesting, int convPhysicalState) {
    if (isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF7F1D1D),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEF4444)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fiber_manual_record, color: Color(0xFFEF4444), size: 10),
            SizedBox(width: 4),
            Text(
              'REC JALAN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (isTesting) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF78350F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF59E0B)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt, color: Color(0xFFF59E0B), size: 11),
            SizedBox(width: 3),
            Text(
              'MENGETES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    if (convPhysicalState != 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF065F46),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: Text(
          convPhysicalState == 1 ? 'Maju' : 'Mundur',
          style: const TextStyle(
            color: Color(0xFF34D399),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF161F30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: const Text(
        'Standby',
        style: TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDirTab(String label, bool isSelected, IconData icon,
      Color activeColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.25)
              : const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFineTuneBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF161F30),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 9.5,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
