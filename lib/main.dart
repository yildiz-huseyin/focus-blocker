import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'screens/lock_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool isLocked = await StorageService.isCurrentlyLocked();
  runApp(FocusBlockerApp(initiallyLocked: isLocked));
}

class FocusBlockerApp extends StatefulWidget {
  final bool initiallyLocked;

  const FocusBlockerApp({Key? key, required this.initiallyLocked}) : super(key: key);

  @override
  State<FocusBlockerApp> createState() => _FocusBlockerAppState();
}

class _FocusBlockerAppState extends State<FocusBlockerApp> {
  late bool _isLocked;

  @override
  void initState() {
    super.initState();
    _isLocked = widget.initiallyLocked;
  }

  void _onLockTriggered() {
    setState(() {
      _isLocked = true;
    });
  }

  void _onUnlocked() {
    setState(() {
      _isLocked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Focus Blocker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F14),
        primaryColor: const Color(0xFFE50914),
        textTheme: GoogleFonts.interTextTheme(
          ThemeData(brightness: Brightness.dark).textTheme,
        ),
      ),
      home: _isLocked
          ? LockScreen(onUnlocked: _onUnlocked)
          : HomeScreen(onLockTriggered: _onLockTriggered),
    );
  }
}
