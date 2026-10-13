import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/native_bridge.dart';
import '../services/storage_service.dart';

class LockScreen extends StatefulWidget {
  final VoidCallback onUnlocked;
  final String? blockedAppName;

  const LockScreen({
    Key? key,
    required this.onUnlocked,
    this.blockedAppName,
  }) : super(key: key);

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with SingleTickerProviderStateMixin {
  late Timer _timer;
  int _remainingSeconds = 0;
  bool _isLoading = true;
  late AnimationController _pulseController;

  final List<String> _motivationalQuotes = [
    "Hedeflerin, geçici zevklerinden daha değerli.",
    "Şu an pes edersen, yarın yine aynı yerde olacaksın.",
    "Dikkat dağıtıcılar başarısız insanların kaçışıdır.",
    "Zor olduğunu biliyorsun, bu yüzden herkes başaramıyor.",
    "O telefona dokunma. Geleceğini inşa ediyorsun.",
    "Disiplin, ne hissettiğinden bağımsız olarak yapılması gerekeni yapmaktır."
  ];
  late String _currentQuote;

  @override
  void initState() {
    super.initState();
    _currentQuote = (_motivationalQuotes..shuffle()).first;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _initTimer();
  }

  Future<void> _initTimer() async {
    final seconds = await StorageService.getRemainingSeconds();
    if (mounted) {
      setState(() {
        _remainingSeconds = seconds;
        _isLoading = false;
      });
    }

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        await _finishNaturally();
      } else {
        if (mounted) {
          setState(() {
            _remainingSeconds--;
          });
        }
      }
    });
  }

  Future<void> _finishNaturally() async {
    await StorageService.stopLock(isEmergency: false);
    await NativeBridge.setLockStatus(
      isLocked: false,
      whitelistMode: false,
      blockedPackages: [],
    );
    widget.onUnlocked();
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  String _formatTime(int totalSeconds) {
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showEmergencyUnlockDialog() {
    final TextEditingController passwordController = TextEditingController();
    String? errorText;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Colors.redAccent, width: 2),
              ),
              title: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    'KIRMIZI BUTON: ACİL KİLİT ÇÖZME',
                    style: GoogleFonts.orbitron(
                      color: Colors.redAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: min(MainAxisSize.min, MainAxisSize.values.length as MainAxisSize),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bu kilidi yalnızca acil durumlarda açmalısınız. Lütfen Acil Durum Şifrenizi girin:",
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Colors.white, letterSpacing: 3),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.black38,
                      hintText: "••••••••",
                      hintStyle: const TextStyle(color: Colors.white24),
                      errorText: errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.redAccent),
                      ),
                      prefixIcon: const Icon(Icons.lock, color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('VAZGEÇ / ODAKLANMAYA DÖN', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final entered = passwordController.text.trim();
                    final isValid = await StorageService.verifyPassword(entered);
                    if (isValid) {
                      Navigator.of(ctx).pop();
                      await StorageService.stopLock(isEmergency: true);
                      await NativeBridge.setLockStatus(
                        isLocked: false,
                        whitelistMode: false,
                        blockedPackages: [],
                      );
                      widget.onUnlocked();
                    } else {
                      setDialogState(() {
                        errorText = "HATALI ŞİFRE! Kilit kaldırılamaz.";
                      });
                    }
                  },
                  child: const Text('KİLİDİ ZORLA KALDIR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Android geri tuşunu engellemek için PopScope (veya WillPopScope)
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF0D0D11),
        body: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Üst Başlık & Kilit Göstergesi
                      Column(
                        children: [
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(30),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lock_rounded, color: Colors.redAccent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'KATI ODAK MODU AKTİF',
                                  style: GoogleFonts.orbitron(
                                    color: Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.blockedAppName != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              "${widget.blockedAppName} engellendi!",
                              style: const TextStyle(color: Colors.white54, fontSize: 13),
                            ),
                          ]
                        ],
                      ),

                      // Sayaç & Motivasyon Kartı
                      Column(
                        children: [
                          Text(
                            _formatTime(_remainingSeconds),
                            style: GoogleFonts.orbitron(
                              color: Colors.white,
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "KALAN SÜRE",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 13,
                              letterSpacing: 3,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 40),
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16161E),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.format_quote_rounded, color: Colors.amber, size: 30),
                                const SizedBox(height: 8),
                                Text(
                                  _currentQuote,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 15,
                                    height: 1.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // ALT KISIM: BÜYÜK KIRMIZI ACİL DURUM BUTONU
                      Column(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, child) {
                              return Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.red.withOpacity(0.3 * _pulseController.value),
                                      blurRadius: 30 * _pulseController.value,
                                      spreadRadius: 10 * _pulseController.value,
                                    )
                                  ],
                                ),
                                child: child,
                              );
                            },
                            child: SizedBox(
                              width: 100,
                              height: 100,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE50914),
                                  shape: const CircleBorder(),
                                  elevation: 10,
                                  padding: EdgeInsets.zero,
                                  side: const BorderSide(color: Colors.white30, width: 2),
                                ),
                                onPressed: _showEmergencyUnlockDialog,
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 36),
                                    SizedBox(height: 4),
                                    Text(
                                      "ACİL KİLİT",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            "Acil Çıkış için Kırmızı Butona Dokunun (Şifre Gerekir)",
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
