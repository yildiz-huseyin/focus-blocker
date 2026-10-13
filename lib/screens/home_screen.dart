import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/native_bridge.dart';
import '../services/storage_service.dart';
import 'app_selector_screen.dart';
import 'analytics_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onLockTriggered;

  const HomeScreen({Key? key, required this.onLockTriggered}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedDuration = 25; // Varsayılan Pomodoro 25 dk
  List<String> _blockedApps = [];
  bool _whitelistMode = false;
  bool _hasOverlayPermission = false;
  bool _hasAccessibilityPermission = false;
  bool _hasPassword = false;

  final List<int> _presetDurations = [15, 25, 45, 60, 90, 120];

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final permissions = await NativeBridge.checkPermissions();
    final apps = await StorageService.getBlockedApps();
    final whitelist = await StorageService.isWhitelistMode();
    final passwordConfigured = await StorageService.hasPassword();

    if (mounted) {
      setState(() {
        _hasOverlayPermission = permissions['overlay'] ?? false;
        _hasAccessibilityPermission = permissions['accessibility'] ?? false;
        _blockedApps = apps;
        _whitelistMode = whitelist;
        _hasPassword = passwordConfigured;
      });
    }
  }

  void _showSetPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E1E28),
          title: const Text('Acil Durum Şifresi Belirle', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kırmızı acil durum butonuna basıldığında kilidi açabilmek için bu şifre gerekecek. Unutmayacağınız bir şifre girin:',
                style: TextStyle(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.black26,
                  hintText: "Yeni Şifre",
                  hintStyle: const TextStyle(color: Colors.white30),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                final text = passwordController.text.trim();
                if (text.isNotEmpty) {
                  await StorageService.setEmergencyPassword(text);
                  setState(() => _hasPassword = true);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Acil durum şifresi başarıyla kaydedildi!')),
                  );
                }
              },
              child: const Text('KAYDET', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startFocusSession() async {
    if (!_hasOverlayPermission || !_hasAccessibilityPermission) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.redAccent,
          content: Text('Lütfen önce gerekli erişilebilirlik ve overlay izinlerini verin!'),
        ),
      );
      return;
    }

    if (!_hasPassword) {
      _showSetPasswordDialog();
      return;
    }

    // Kilidi depola
    await StorageService.startLock(
      durationMinutes: _selectedDuration,
      blockedApps: _blockedApps,
      whitelistMode: _whitelistMode,
    );

    // Native servise kilidi bildir
    await NativeBridge.setLockStatus(
      isLocked: true,
      whitelistMode: _whitelistMode,
      blockedPackages: _blockedApps,
    );

    // İstatistiğe ekle
    await StorageService.addFocusTime(_selectedDuration);

    widget.onLockTriggered();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161E),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 8),
            Text(
              'FOCUS BLOCKER',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
            },
          ),
          IconButton(
            icon: Icon(Icons.key_rounded, color: _hasPassword ? Colors.greenAccent : Colors.redAccent),
            tooltip: 'Acil Şifresi',
            onPressed: _showSetPasswordDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İzinler Durumu
            if (!_hasOverlayPermission || !_hasAccessibilityPermission) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security_update_warning_rounded, color: Colors.redAccent),
                        SizedBox(width: 8),
                        Text(
                          'Sistem İzinleri Gerekli',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Uygulamaları anında engelleyebilmek için sistem izinlerini etkinleştirin:',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (!_hasOverlayPermission)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              await NativeBridge.requestOverlayPermission();
                              await Future.delayed(const Duration(seconds: 1));
                              _checkStatus();
                            },
                            child: const Text('Üste Çizme İzni', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        const SizedBox(width: 8),
                        if (!_hasAccessibilityPermission)
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              await NativeBridge.requestAccessibilityPermission();
                              await Future.delayed(const Duration(seconds: 1));
                              _checkStatus();
                            },
                            child: const Text('Erişilebilirlik İzni', style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Süre Seçici Kartı
            Text(
              'ODAKLANMA SÜRESİ',
              style: GoogleFonts.orbitron(color: Colors.white70, fontSize: 12, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetDurations.map((duration) {
                final isSelected = _selectedDuration == duration;
                return ChoiceChip(
                  label: Text(
                    '$duration dk',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: Colors.redAccent,
                  backgroundColor: const Color(0xFF1B1B26),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDuration = duration);
                    }
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 28),

            // Engellenecek Uygulamalar Kartı
            Text(
              'ENGEL LİSTESİ',
              style: GoogleFonts.orbitron(color: Colors.white70, fontSize: 12, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AppSelectorScreen()),
                );
                if (result != null) {
                  _checkStatus();
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B26),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.apps_rounded, color: Colors.redAccent, size: 28),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Yasaklı Uygulamalar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                              _blockedApps.isEmpty ? 'Henüz seçilmedi (Dokun)' : '${_blockedApps.length} uygulama seçildi',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // BÜYÜK KİLİTLE VE BAŞLAT BUTONU
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: Colors.redAccent.withOpacity(0.5),
                ),
                onPressed: _startFocusSession,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_clock_rounded, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      'TELEFONU KİLİTLE VE BAŞLA',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Kilit başladığında seçili uygulamalara erişilemez.\nKilidi erken kaldırmanın TEK yolu Acil Durum Şifresidir.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
