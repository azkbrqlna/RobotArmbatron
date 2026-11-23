import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/robot_frame.dart';
import '../services/bluetooth_service.dart';

class RobotController extends ChangeNotifier {
  final BluetoothService btService;
  StreamSubscription<String>? _rxSub;

  // Limits
  static const List<List<int>> limits = [
    [0, 180], // 0: Base
    [0, 45], // 1: Shoulder
    [30, 180], // 2: Elbow
    [0, 180], // 3: Gripper
  ];

  static const List<int> posHome = [90, 0, 150, 180];

  // Current Target State
  final List<int> _angles = List.from(posHome);
  int _convState = 0; // 0=Stop, 1=Maju, 2=Mundur

  // Conveyor Recording State for current frame
  int _recordedConvDirection = 1; // 0=Stop, 1=Maju, 2=Mundur
  int _recordedConvDurationMs = 0;
  bool _useIrSensor = false; // Mode tunggu sensor Infrared (durasi = -1)
  bool _isConvRecording = false;
  final Stopwatch _convStopwatch = Stopwatch();
  Timer? _convTicker;
  Timer? _convTestTimer;
  bool _isConvTesting = false;

  // Auto Sequence State
  String _activeSeq = 'A';
  List<RobotFrame> _framesA = [];
  List<RobotFrame> _framesB = [];
  int _editingIndex = -1;

  // Auto Playback state from ESP32
  bool _isPlaying = false;
  int _playIndex = 0;

  RobotController({required this.btService}) {
    _rxSub = btService.lineStream.listen(_handleIncomingLine);
    // Listen to connection changes
    btService.addListener(_onBtStateChanged);
  }

  // Getters
  List<int> get angles => List.unmodifiable(_angles);
  int get convState => _convState;
  int get recordedConvDirection => _recordedConvDirection;
  int get recordedConvDurationMs => _recordedConvDurationMs;
  bool get useIrSensor => _useIrSensor;
  bool get isConvRecording => _isConvRecording;
  bool get isConvTesting => _isConvTesting;
  int get convElapsedMs => _isConvRecording
      ? _convStopwatch.elapsedMilliseconds
      : (_recordedConvDurationMs == -1 ? 0 : _recordedConvDurationMs);
  double get convElapsedSeconds => convElapsedMs / 1000.0;

  String get activeSeq => _activeSeq;
  List<RobotFrame> get currentFrames =>
      _activeSeq == 'A' ? _framesA : _framesB;
  int get editingIndex => _editingIndex;
  bool get isEditing => _editingIndex >= 0;
  bool get isPlaying => _isPlaying;
  int get playIndex => _playIndex;

  void _onBtStateChanged() {
    if (btService.isConnected) {
      // Sync sequence frames and query current physical robot position on connect
      refreshFrames();
      btService.sendCommand('POS?');
    } else {
      _isPlaying = false;
      _editingIndex = -1;
      notifyListeners();
    }
  }

  void _handleIncomingLine(String line) {
    debugPrint('ESP32 Line: $line');

    if (line.startsWith('FRAMES:')) {
      // Format: FRAMES:<seq>:<count>:<csv frames>
      // e.g. FRAMES:A:2:90,45,90,180,0;90,40,95,120,1
      final parts = line.split(':');
      if (parts.length >= 4) {
        final seq = parts[1];
        final rawData = parts.sublist(3).join(':'); // the rest is frame csv
        final parsed = <RobotFrame>[];

        if (rawData.isNotEmpty) {
          final frameStrings = rawData.split(';');
          for (final fs in frameStrings) {
            final f = RobotFrame.fromCsv(fs.trim());
            if (f != null) parsed.add(f);
          }
        }

        if (seq == 'A') {
          _framesA = parsed;
        } else if (seq == 'B') {
          _framesB = parsed;
        }
        notifyListeners();
      }
    } else if (line.startsWith('STATUS:')) {
      // Format: STATUS:<isPlaying>:<playIndex>
      final parts = line.split(':');
      if (parts.length >= 3) {
        final play = (int.tryParse(parts[1]) ?? 0) == 1;
        final idx = int.tryParse(parts[2]) ?? 0;
        _isPlaying = play;
        _playIndex = idx;
        if (!_isPlaying) {
          _convState = 0;
        }
        notifyListeners();
      }
    } else if (line.startsWith('POS:')) {
      // Format: POS:<a0>,<a1>,<a2>,<a3>,<conv>
      final raw = line.substring(4);
      final parts = raw.split(',');
      if (parts.length >= 5) {
        for (int i = 0; i < 4; i++) {
          _angles[i] = int.tryParse(parts[i]) ?? _angles[i];
        }
        _convState = int.tryParse(parts[4]) ?? _convState;
        notifyListeners();
      }
    }
  }

  void setActiveSeq(String seq) {
    if (_activeSeq != seq) {
      _activeSeq = seq;
      _editingIndex = -1;
      refreshFrames();
      notifyListeners();
    }
  }

  void refreshFrames() {
    btService.sendCommand('GET:$_activeSeq');
  }

  /// Sets a specific servo angle with limit clamping and throttled BT sending
  void setServoAngle(int id, int val) {
    if (id < 0 || id >= 4) return;
    final clamped = val.clamp(limits[id][0], limits[id][1]);

    if (_angles[id] != clamped) {
      _angles[id] = clamped;
      _isPlaying = false; // manual action cancels auto
      notifyListeners();

      btService.sendThrottled('servo_$id', 'S:$id:$clamped');
    }
  }

  /// Increments or decrements servo (used by D-Pad)
  void stepServo(int id, int step) {
    if (id < 0 || id >= 4) return;
    setServoAngle(id, _angles[id] + step);
  }

  /// Set conveyor state: 0 (Stop), 1 (Maju), 2 (Mundur)
  void setConveyor(int state) {
    _convState = state;
    _isPlaying = false;
    notifyListeners();

    btService.sendCommand('C:$state');
  }

  // ==========================================
  // CONVEYOR RECORDING CONTROLS
  // ==========================================
  void setRecordedConvDirection(int dir) {
    if (_recordedConvDirection != dir) {
      _recordedConvDirection = dir;
      if (dir == 0) {
        _recordedConvDurationMs = 0;
        _useIrSensor = false;
      } else if (_useIrSensor) {
        _recordedConvDurationMs = -1;
      }
      notifyListeners();
    }
  }

  /// Aktifkan / nonaktifkan mode tunggu sensor Infrared (GPIO 33)
  void setUseIrSensor(bool val) {
    if (_useIrSensor != val) {
      _useIrSensor = val;
      if (val) {
        if (_isConvRecording) stopConvRecord();
        if (_isConvTesting) cancelConvTest();
        _recordedConvDurationMs = -1;
        if (_recordedConvDirection == 0) {
          _recordedConvDirection = 1; // Default ke Maju untuk sensor IR
        }
      } else {
        if (_recordedConvDurationMs == -1) {
          _recordedConvDurationMs = 0;
        }
      }
      notifyListeners();
    }
  }

  void setRecordedConvDurationMs(int ms) {
    _useIrSensor = (ms == -1);
    _recordedConvDurationMs = ms;
    notifyListeners();
  }

  void adjustRecordedConvDuration(int deltaMs) {
    if (_useIrSensor) {
      _useIrSensor = false;
      _recordedConvDurationMs = 0;
    }
    final next = (_recordedConvDurationMs + deltaMs).clamp(0, 120000); // Max 2 menit
    _recordedConvDurationMs = next;
    notifyListeners();
  }

  /// Mulai merekam durasi jalan konveyor (saat di play jalan)
  void startConvRecord() {
    if (_isConvRecording) return;
    if (_isConvTesting) cancelConvTest();

    final dir = _recordedConvDirection == 0 ? 1 : _recordedConvDirection;
    _recordedConvDirection = dir;

    _isConvRecording = true;
    _convStopwatch.reset();
    _convStopwatch.start();

    _convTicker?.cancel();
    _convTicker = Timer.periodic(const Duration(milliseconds: 50), (_) {
      notifyListeners();
    });

    // Jalankan konveyor secara fisik
    setConveyor(dir);
  }

  /// Berhenti merekam durasi jalan konveyor (saat di stop berhenti & waktu tercatat)
  void stopConvRecord() {
    if (!_isConvRecording) return;

    _convStopwatch.stop();
    _convTicker?.cancel();
    _convTicker = null;
    _recordedConvDurationMs = _convStopwatch.elapsedMilliseconds;
    _isConvRecording = false;

    // Hentikan konveyor secara fisik
    setConveyor(0);
    notifyListeners();
  }

  /// Toggle start/stop perekaman konveyor
  void toggleConvRecord() {
    if (_isConvRecording) {
      stopConvRecord();
    } else {
      startConvRecord();
    }
  }

  /// Tes putar konveyor sesuai durasi yang telah terekam
  void testPlayRecordedConv() {
    if (_recordedConvDurationMs <= 0 || _recordedConvDirection == 0) return;
    if (_isConvRecording) stopConvRecord();

    _isConvTesting = true;
    setConveyor(_recordedConvDirection);
    notifyListeners();

    _convTestTimer?.cancel();
    _convTestTimer = Timer(Duration(milliseconds: _recordedConvDurationMs), () {
      _isConvTesting = false;
      setConveyor(0);
      notifyListeners();
    });
  }

  /// Batalkan tes putar konveyor
  void cancelConvTest() {
    _convTestTimer?.cancel();
    _convTestTimer = null;
    _isConvTesting = false;
    setConveyor(0);
    notifyListeners();
  }

  /// Reset durasi perekaman konveyor ke 0
  void resetRecordedConvDuration() {
    if (_isConvRecording) {
      stopConvRecord();
    }
    cancelConvTest();
    _recordedConvDurationMs = 0;
    notifyListeners();
  }

  /// Return robot to default home position
  void goHome() {
    for (int i = 0; i < 4; i++) {
      setServoAngle(i, posHome[i]);
    }
    setConveyor(0);
  }

  /// Record current arm position and conveyor state into current sequence
  void recordFrame() {
    // Pastikan jika sedang merekam atau tes konveyor saat tombol simpan ditekan, stop dulu
    if (_isConvRecording) {
      stopConvRecord();
    }
    if (_isConvTesting) {
      cancelConvTest();
    }

    final dir = _recordedConvDirection;
    final dur = _useIrSensor ? -1 : _recordedConvDurationMs;

    final newFrame = RobotFrame(
      angles: List.from(_angles),
      conv: dir,
      convDurationMs: dur,
    );

    if (_activeSeq == 'A') {
      _framesA.add(newFrame);
    } else {
      _framesB.add(newFrame);
    }

    // Reset arah dan durasi untuk titik berikutnya
    _recordedConvDirection = 0;
    _recordedConvDurationMs = 0;
    _useIrSensor = false;
    notifyListeners();

    btService.sendCommand('SAVE:$_activeSeq:$dir:$dur');
  }

  /// Select a frame from timeline to preview and edit
  void selectFrameForEdit(int index) {
    final frames = currentFrames;
    if (index >= 0 && index < frames.length) {
      if (_isConvRecording) stopConvRecord();
      if (_isConvTesting) cancelConvTest();

      _editingIndex = index;
      final target = frames[index];

      // Move robot to this frame's saved position
      for (int i = 0; i < 4; i++) {
        setServoAngle(i, target.angles[i]);
      }

      // Load saved conveyor configuration for this frame
      _recordedConvDirection = target.conv;
      _recordedConvDurationMs = target.convDurationMs;
      _useIrSensor = (target.convDurationMs == -1);
      _isConvRecording = false;
      _convStopwatch.reset();

      // Standby konveyor di 0 agar tidak berputar liar saat edit
      setConveyor(0);
      notifyListeners();
    }
  }

  /// Cancel editing without saving
  void cancelEdit() {
    if (_isConvRecording) stopConvRecord();
    if (_isConvTesting) cancelConvTest();
    _editingIndex = -1;
    _recordedConvDirection = 0;
    _recordedConvDurationMs = 0;
    _useIrSensor = false;
    notifyListeners();
  }

  /// Save changes to the selected frame
  void updateFrame() {
    if (_isConvRecording) {
      stopConvRecord();
    }
    if (_isConvTesting) {
      cancelConvTest();
    }

    if (_editingIndex >= 0) {
      final list = _activeSeq == 'A' ? _framesA : _framesB;
      final dir = _recordedConvDirection;
      final dur = _useIrSensor ? -1 : _recordedConvDurationMs;

      if (_editingIndex < list.length) {
        list[_editingIndex] = RobotFrame(
          angles: List.from(_angles),
          conv: dir,
          convDurationMs: dur,
        );
      }
      final idxToUpdate = _editingIndex;
      _editingIndex = -1;
      _recordedConvDirection = 0;
      _recordedConvDurationMs = 0;
      _useIrSensor = false;
      notifyListeners();

      btService.sendCommand('UPD:$_activeSeq:$idxToUpdate:$dir:$dur');
    }
  }

  /// Delete a frame at a specific index
  void deleteFrame(int index) {
    final list = _activeSeq == 'A' ? _framesA : _framesB;
    if (index >= 0 && index < list.length) {
      final wasLast = (index == list.length - 1);
      list.removeAt(index);
      if (_editingIndex == index) {
        _editingIndex = -1;
      } else if (_editingIndex > index) {
        _editingIndex--;
      }
      notifyListeners();

      if (list.isEmpty) {
        clearAllFrames();
      } else {
        btService.sendCommand('DEL:$_activeSeq:$index');
        if (wasLast) {
          btService.sendCommand('UNDO:$_activeSeq');
        }
      }
    }
  }

  /// Delete currently selected frame
  void deleteSelectedFrame() {
    if (_editingIndex >= 0) {
      deleteFrame(_editingIndex);
    }
  }

  /// Clear all frames in active sequence
  void clearAllFrames() {
    if (_activeSeq == 'A') {
      _framesA.clear();
    } else {
      _framesB.clear();
    }
    _editingIndex = -1;
    notifyListeners();

    btService.sendCommand('CLEAR:$_activeSeq');
    for (int i = 0; i < 20; i++) {
      btService.sendCommand('UNDO:$_activeSeq');
    }
  }

  /// Undo / remove last recorded frame
  void undoLastFrame() {
    final list = _activeSeq == 'A' ? _framesA : _framesB;
    if (list.isNotEmpty) {
      list.removeLast();
      if (_editingIndex >= list.length) {
        _editingIndex = -1;
      }
      notifyListeners();

      if (list.isEmpty) {
        clearAllFrames();
      } else {
        btService.sendCommand('UNDO:$_activeSeq');
      }
    }
  }

  /// Start playback loop
  void startPlay() {
    cancelEdit();
    _isPlaying = true;
    notifyListeners();
    btService.sendCommand('PLAY:$_activeSeq');
  }

  /// Emergency stop playback & conveyor
  void stopPlay() {
    _isPlaying = false;
    _convState = 0;
    notifyListeners();
    btService.sendCommand('STOP');
  }

  @override
  void dispose() {
    _convTicker?.cancel();
    _convTestTimer?.cancel();
    _rxSub?.cancel();
    btService.removeListener(_onBtStateChanged);
    super.dispose();
  }
}
