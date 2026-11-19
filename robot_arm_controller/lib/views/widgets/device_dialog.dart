import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import '../../services/bluetooth_service.dart';

class DeviceDialog extends StatefulWidget {
  final BluetoothService btService;

  const DeviceDialog({super.key, required this.btService});

  static Future<void> show(BuildContext context, BluetoothService btService) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F1522),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DeviceDialog(btService: btService),
    );
  }

  @override
  State<DeviceDialog> createState() => _DeviceDialogState();
}

class _DeviceDialogState extends State<DeviceDialog> {
  List<BluetoothDevice> _devices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() => _isLoading = true);
    final devices = await widget.btService.getPairedDevices();
    if (mounted) {
      setState(() {
        _devices = devices;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.bluetooth, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Pilih Bluetooth ESP32',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFF1F5F9),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Color(0xFF38BDF8), size: 20),
                  onPressed: _loadDevices,
                ),
              ],
            ),
            const Text(
              'Pilih RobotArm_ESP32 dari daftar perangkat paired.',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF38BDF8),
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (_devices.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Column(
                  children: [
                    const Icon(Icons.bluetooth_searching, size: 40, color: Color(0xFF475569)),
                    const SizedBox(height: 10),
                    const Text(
                      'No bonded Bluetooth devices found.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E293B),
                        foregroundColor: const Color(0xFF38BDF8),
                        side: const BorderSide(color: Color(0xFF334155)),
                      ),
                      onPressed: () => FlutterBluetoothSerial.instance.openSettings(),
                      child: const Text('Open Android Bluetooth Settings'),
                    ),
                  ],
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _devices.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF1E293B), height: 1),
                  itemBuilder: (context, index) {
                    final device = _devices[index];
                    final isArm = device.name?.contains('Robot') == true ||
                        device.name?.contains('ESP') == true;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isArm
                              ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                              : const Color(0xFF1A2234),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isArm
                                ? const Color(0xFF0284C7).withValues(alpha: 0.4)
                                : const Color(0xFF334155),
                          ),
                        ),
                        child: Icon(
                          Icons.precision_manufacturing,
                          color: isArm ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        device.name ?? 'Unknown Node',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: isArm ? FontWeight.w900 : FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        device.address,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10,
                          fontFamily: 'monospace',
                        ),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              isArm ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await widget.btService.connect(device);
                        },
                        child: const Text('CONNECT', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
