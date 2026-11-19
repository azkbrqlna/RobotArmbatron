import 'package:flutter/material.dart';
import '../controllers/robot_controller.dart';
import '../services/bluetooth_service.dart';
import 'widgets/conveyor_widget.dart';
import 'widgets/device_dialog.dart';
import 'widgets/kinematics_card.dart';
import 'widgets/slider_view_widget.dart';
import 'widgets/timeline_widget.dart';

class HomeScreen extends StatefulWidget {
  final BluetoothService btService;
  final RobotController controller;

  const HomeScreen({
    super.key,
    required this.btService,
    required this.controller,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _mainTab = 0; // 0 = Manual, 1 = Otomatis

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.btService, widget.controller]),
      builder: (context, _) {
        final isConnected = widget.btService.isConnected;
        final isConnecting = widget.btService.status == BtConnectionStatus.connecting;

        return Scaffold(
          backgroundColor: const Color(0xFF090D15),
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F1522),
            elevation: 0,
            titleSpacing: 14,
            title: const Text(
              'Robot Arm & Conveyor',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFF1F5F9),
              ),
            ),
            actions: [
              // Home Button
              IconButton(
                tooltip: 'Posisi Awal',
                icon: const Icon(Icons.home, color: Color(0xFF38BDF8), size: 22),
                onPressed: () {
                  widget.controller.goHome();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Robot kembali ke posisi awal.'),
                      duration: Duration(seconds: 1),
                      backgroundColor: Color(0xFF1E293B),
                    ),
                  );
                },
              ),

              // Bluetooth Button
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () {
                    if (isConnected) {
                      _showDisconnectDialog();
                    } else {
                      DeviceDialog.show(context, widget.btService);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isConnected
                          ? const Color(0xFF065F46)
                          : isConnecting
                              ? const Color(0xFF78350F)
                              : const Color(0xFF161F30),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isConnected
                            ? const Color(0xFF10B981)
                            : isConnecting
                                ? Colors.amber
                                : const Color(0xFF334155),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                          size: 14,
                          color: isConnected ? const Color(0xFF34D399) : Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isConnected ? 'Terhubung' : isConnecting ? '...' : 'Connect',
                          style: TextStyle(
                            color: isConnected ? Colors.white : const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      // Kinematic Visualizer
                      KinematicsCard(controller: widget.controller),

                      const SizedBox(height: 8),

                      // Manual vs Otomatis Switcher
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
                              child: _buildTabBtn(
                                'Manual',
                                _mainTab == 0,
                                () {
                                  setState(() => _mainTab = 0);
                                  widget.controller.stopPlay();
                                },
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: _buildTabBtn(
                                'Otomatis',
                                _mainTab == 1,
                                () {
                                  setState(() => _mainTab = 1);
                                  widget.controller.refreshFrames();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Tab Views
                      if (_mainTab == 0) _buildManualView() else _buildAutoView(),
                    ],
                  ),
                ),
              ),

              // Bottom Status Bar
              _buildCleanStatusBar(isConnected),
            ],
          ),
        );
      },
    );
  }

  Widget _buildManualView() {
    return Column(
      children: [
        SliderViewWidget(controller: widget.controller),
        const SizedBox(height: 8),
        ConveyorWidget(
          controller: widget.controller,
          isAutoMode: false,
        ),
      ],
    );
  }

  Widget _buildAutoView() {
    return Column(
      children: [
        TimelineWidget(controller: widget.controller),
        const SizedBox(height: 8),
        ConveyorWidget(
          controller: widget.controller,
          isAutoMode: true,
        ),
        const SizedBox(height: 8),
        SliderViewWidget(controller: widget.controller),
      ],
    );
  }

  Widget _buildTabBtn(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
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
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }


  Widget _buildCleanStatusBar(bool isConnected) {
    String text;
    Color dotColor;

    if (!isConnected) {
      text = 'Bluetooth Belum Terhubung';
      dotColor = Colors.orange;
    } else if (widget.controller.isPlaying) {
      text = 'Siklus Berjalan (Titik #${widget.controller.playIndex + 1})';
      dotColor = const Color(0xFF10B981);
    } else if (widget.controller.isEditing) {
      text = 'Mengedit Titik #${widget.controller.editingIndex + 1}';
      dotColor = const Color(0xFF38BDF8);
    } else {
      text = 'Siap (Terhubung ke ${widget.btService.connectedDeviceName ?? "ESP32"})';
      dotColor = const Color(0xFF10B981);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1522),
        border: Border(top: BorderSide(color: Color(0xFF1E293B))),
      ),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: dotColor,
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDisconnectDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F1522),
        title: const Text('Putuskan Bluetooth?', style: TextStyle(color: Colors.white, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.pop(ctx);
              widget.btService.disconnect();
            },
            child: const Text('Putuskan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
