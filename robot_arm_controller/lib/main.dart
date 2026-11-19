import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'controllers/robot_controller.dart';
import 'services/bluetooth_service.dart';
import 'views/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI style (dark navigation bar & status bar)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF090D15),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  final btService = BluetoothService();
  final controller = RobotController(btService: btService);

  runApp(RobotArmApp(btService: btService, controller: controller));
}

class RobotArmApp extends StatelessWidget {
  final BluetoothService btService;
  final RobotController controller;

  const RobotArmApp({
    super.key,
    required this.btService,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Arm Robot Controller',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D15),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFFF59E0B),
          surface: Color(0xFF0F1522),
          error: Color(0xFFEF4444),
        ),
        fontFamily: 'Segoe UI',
      ),
      home: HomeScreen(btService: btService, controller: controller),
    );
  }
}
