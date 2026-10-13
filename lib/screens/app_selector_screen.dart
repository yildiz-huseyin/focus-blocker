import 'package:flutter/material.dart';
import '../services/native_bridge.dart';
import '../services/storage_service.dart';

class AppSelectorScreen extends StatefulWidget {
  const AppSelectorScreen({Key? key}) : super(key: key);

  @override
  State<AppSelectorScreen> createState() => _AppSelectorScreenState();
}

class _AppSelectorScreenState extends State<AppSelectorScreen> {
  List<Map<String, String>> _installedApps = [];
  Set<String> _selectedPackages = {};
  bool _isLoading = true;
  String _searchQuery = "";

  // Sık engellenen popüler uygulamalar için hazır paket isimleri
  final List<Map<String, String>> _popularApps = [
    {'appName': 'Instagram', 'packageName': 'com.instagram.android'},
    {'appName': 'TikTok', 'packageName': 'com.zhiliaoapp.musically'},
    {'appName': 'YouTube', 'packageName': 'com.google.android.youtube'},
    {'appName': 'Twitter / X', 'packageName': 'com.twitter.android'},
    {'appName': 'Facebook', 'packageName': 'com.facebook.katana'},
    {'appName': 'Snapchat', 'packageName': 'com.snapchat.android'},
    {'appName': 'WhatsApp', 'packageName': 'com.whatsapp'},
    {'appName': 'Telegram', 'packageName': 'org.telegram.messenger'},
    {'appName': 'Reddit', 'packageName': 'com.reddit.frontpage'},
    {'appName': 'Netflix', 'packageName': 'com.netflix.mediaclient'},
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final savedBlocked = await StorageService.getBlockedApps();
    final apps = await NativeBridge.getInstalledApps();

    setState(() {
      _selectedPackages = savedBlocked.toSet();
      // Eğer cihazdan çekilen liste boşsa (örn: emülatör veya izin verilmemişse) popüler listeyi göster
      _installedApps = apps.isNotEmpty ? apps : _popularApps;
      _isLoading = false;
    });
  }

  void _saveAndPop() async {
    final prefsList = _selectedPackages.toList();
    final isWhitelist = await StorageService.isWhitelistMode();
    await StorageService.startLock(
      durationMinutes: 0,
      blockedApps: prefsList,
      whitelistMode: isWhitelist,
    );
    if (mounted) {
      Navigator.pop(context, prefsList);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _installedApps.where((app) {
      final name = app['appName']?.toLowerCase() ?? '';
      final pkg = app['packageName']?.toLowerCase() ?? '';
      return name.contains(_searchQuery.toLowerCase()) || pkg.contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16161E),
        title: const Text('Engellenecek Uygulamalar', style: TextStyle(fontSize: 18, color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.greenAccent),
            onPressed: _saveAndPop,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFF1E1E28),
                      hintText: "Uygulama ara...",
                      hintStyle: const TextStyle(color: Colors.white38),
                      prefixIcon: const Icon(Icons.search, color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "${_selectedPackages.length} uygulama seçildi",
                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedPackages.length == filteredApps.length) {
                              _selectedPackages.clear();
                            } else {
                              _selectedPackages.addAll(filteredApps.map((e) => e['packageName']!));
                            }
                          });
                        },
                        child: Text(
                          _selectedPackages.length == filteredApps.length ? "Tümünü Kaldır" : "Tümünü Seç",
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = filteredApps[index];
                      final pkg = app['packageName']!;
                      final isSelected = _selectedPackages.contains(pkg);

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF2B1B22) : const Color(0xFF181822),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? Colors.redAccent.withOpacity(0.5) : Colors.transparent,
                          ),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.white10,
                            child: Icon(
                              Icons.android,
                              color: isSelected ? Colors.redAccent : Colors.white60,
                            ),
                          ),
                          title: Text(
                            app['appName'] ?? pkg,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            pkg,
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Checkbox(
                            activeColor: Colors.redAccent,
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedPackages.add(pkg);
                                } else {
                                  _selectedPackages.remove(pkg);
                                }
                              });
                            },
                          ),
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedPackages.remove(pkg);
                              } else {
                                _selectedPackages.add(pkg);
                              }
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
