import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';

enum BtConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

class BluetoothService extends ChangeNotifier {
  final FlutterBluetoothSerial _bluetooth = FlutterBluetoothSerial.instance;

  BluetoothConnection? _connection;
  BtConnectionStatus _status = BtConnectionStatus.disconnected;
  String? _connectedDeviceName;
  String? _errorMessage;

  final StringBuffer _rxBuffer = StringBuffer();
  final StreamController<String> _lineStreamController =
      StreamController<String>.broadcast();

  // Outbound throttle queue
  final Map<String, String> _pendingKeyedCommands = {};
  Timer? _throttleTimer;
  static const int throttleIntervalMs = 50; // ~20 Hz smooth & stable rate

  BtConnectionStatus get status => _status;
  bool get isConnected => _status == BtConnectionStatus.connected;
  String? get connectedDeviceName => _connectedDeviceName;
  String? get errorMessage => _errorMessage;
  Stream<String> get lineStream => _lineStreamController.stream;

  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    // On Android 12+ (SDK >= 31), bluetoothConnect & bluetoothScan are required.
    // On Android <= 11 (SDK <= 30), legacy bluetooth is required.
    final connectGranted =
        statuses[Permission.bluetoothConnect]?.isGranted ?? false;
    final scanGranted =
        statuses[Permission.bluetoothScan]?.isGranted ?? false;
    final legacyBtGranted =
        statuses[Permission.bluetooth]?.isGranted ?? false;

    if (connectGranted && scanGranted) {
      return true;
    }
    if (legacyBtGranted) {
      return true;
    }

    return await Permission.bluetoothConnect.isGranted ||
        await Permission.bluetooth.isGranted;
  }

  Future<List<BluetoothDevice>> getPairedDevices() async {
    await requestPermissions();
    try {
      final isEnabled = await _bluetooth.isEnabled ?? false;
      if (!isEnabled) {
        await _bluetooth.requestEnable();
      }
      return await _bluetooth.getBondedDevices();
    } catch (e) {
      debugPrint('Error getting paired devices: $e');
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    await disconnect();

    _status = BtConnectionStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      _status = BtConnectionStatus.connected;
      _connectedDeviceName = device.name ?? device.address;
      notifyListeners();

      _connection!.input?.listen(
        _onDataReceived,
        onDone: () {
          disconnect();
        },
        onError: (err) {
          debugPrint('Bluetooth read error: $err');
          disconnect();
        },
      );

      return true;
    } catch (e) {
      debugPrint('Bluetooth connect error: $e');
      _status = BtConnectionStatus.error;
      _errorMessage = 'Gagal terhubung: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    _throttleTimer?.cancel();
    _pendingKeyedCommands.clear();
    _rxBuffer.clear();
    if (_connection != null) {
      try {
        await _connection!.close();
      } catch (_) {}
      _connection = null;
    }
    _status = BtConnectionStatus.disconnected;
    _connectedDeviceName = null;
    notifyListeners();
  }

  void _onDataReceived(Uint8List data) {
    final text = utf8.decode(data, allowMalformed: true);
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (char == '\n' || char == '\r') {
        if (_rxBuffer.isNotEmpty) {
          final line = _rxBuffer.toString().trim();
          _rxBuffer.clear();
          if (line.isNotEmpty) {
            _lineStreamController.add(line);
          }
        }
      } else {
        _rxBuffer.write(char);
      }
    }
  }

  /// Send immediate single command (for buttons, play, stop, record, etc.)
  void sendCommand(String cmd) {
    if (!isConnected || _connection == null) return;
    try {
      final line = cmd.endsWith('\n') ? cmd : '$cmd\n';
      _connection!.output.add(Uint8List.fromList(utf8.encode(line)));
    } catch (e) {
      debugPrint('Error sending command $cmd: $e');
    }
  }

  /// Throttled send for frequent continuous inputs (sliders / D-pad holding)
  /// key: e.g. "servo_0", value: "S:0:120"
  void sendThrottled(String key, String command) {
    _pendingKeyedCommands[key] = command;

    if (_throttleTimer == null || !_throttleTimer!.isActive) {
      _throttleTimer = Timer(
        const Duration(milliseconds: throttleIntervalMs),
        _flushPendingCommands,
      );
    }
  }

  void _flushPendingCommands() {
    if (!isConnected || _connection == null || _pendingKeyedCommands.isEmpty) {
      _pendingKeyedCommands.clear();
      return;
    }

    final commandsToSend = List<String>.from(_pendingKeyedCommands.values);
    _pendingKeyedCommands.clear();

    for (final cmd in commandsToSend) {
      sendCommand(cmd);
    }
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    _connection?.dispose();
    _lineStreamController.close();
    super.dispose();
  }
}
