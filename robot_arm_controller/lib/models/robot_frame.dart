class RobotFrame {
  final List<int> angles; // [base, shoulder, elbow, gripper]
  final int conv; // 0=Stop, 1=Maju, 2=Mundur
  final int convDurationMs; // Durasi jalan konveyor dalam milidetik (0 = default/tanpa timer)

  const RobotFrame({
    required this.angles,
    required this.conv,
    this.convDurationMs = 0,
  });

  RobotFrame copyWith({
    List<int>? angles,
    int? conv,
    int? convDurationMs,
  }) {
    return RobotFrame(
      angles: angles ?? List.from(this.angles),
      conv: conv ?? this.conv,
      convDurationMs: convDurationMs ?? this.convDurationMs,
    );
  }

  // Parse string e.g. "90,45,90,180,0" atau "90,45,90,180,1,3500"
  static RobotFrame? fromCsv(String csv) {
    final parts = csv.split(',');
    if (parts.length >= 5) {
      final a0 = int.tryParse(parts[0]) ?? 90;
      final a1 = int.tryParse(parts[1]) ?? 0;
      final a2 = int.tryParse(parts[2]) ?? 150;
      final a3 = int.tryParse(parts[3]) ?? 180;
      final c = int.tryParse(parts[4]) ?? 0;
      final dur = parts.length >= 6 ? (int.tryParse(parts[5]) ?? 0) : 0;
      return RobotFrame(
        angles: [a0, a1, a2, a3],
        conv: c,
        convDurationMs: dur,
      );
    }
    return null;
  }

  String toCsv() {
    return '${angles[0]},${angles[1]},${angles[2]},${angles[3]},$conv,$convDurationMs';
  }

  double get durationSeconds => convDurationMs / 1000.0;

  bool get isIrMode => convDurationMs == -1;

  String get convLabel {
    if (isIrMode) {
      if (conv == 1) return 'Maju ▶ (Sensor IR)';
      if (conv == 2) return '◀ Mundur (Sensor IR)';
      return 'Stop ⏹';
    }
    final durText = convDurationMs > 0 ? ' (${durationSeconds.toStringAsFixed(1)}s)' : '';
    switch (conv) {
      case 1:
        return 'Maju ▶$durText';
      case 2:
        return '◀ Mundur$durText';
      default:
        return 'Stop ⏹';
    }
  }

  String get convShortBadge {
    if (isIrMode) {
      if (conv == 1) return '▶ Sensor IR';
      if (conv == 2) return '◀ Sensor IR';
      return '■ Stop';
    }
    if (conv == 1) {
      return convDurationMs > 0 ? '▶ ${durationSeconds.toStringAsFixed(1)}s' : '▶ Maju';
    } else if (conv == 2) {
      return convDurationMs > 0 ? '◀ ${durationSeconds.toStringAsFixed(1)}s' : '◀ Mundur';
    } else {
      return '■ Stop';
    }
  }
}
