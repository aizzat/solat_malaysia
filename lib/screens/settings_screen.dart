import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/prayer_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/jakim_zones.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedState;
  String? _selectedZone;
  String _selectedSound = 'default';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadSound();
  }

  Future<void> _loadSound() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      String saved = prefs.getString('notification_sound') ?? 'default';
      if (saved == 'takbir') saved = 'default';
      _selectedSound = saved;
    });
  }

  Future<void> _saveSound(String sound) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notification_sound', sound);
    setState(() {
      _selectedSound = sound;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocation(PrayerProvider provider) async {
    if (_searchController.text.trim().isEmpty) return;
    
    setState(() { _isSearching = true; });
    final locationService = LocationService();
    final result = await locationService.searchLocation(_searchController.text);
    
    setState(() { _isSearching = false; });
    
    if (result != null && result.latitude != null && result.longitude != null) {
      provider.setManualCoordinates(result.latitude!, result.longitude!, result.city ?? _searchController.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location set to ${result.city}')));
        _searchController.clear();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location not found.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.petronasGreen : AppTheme.petronasBlue;

    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Appearance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<ThemeMode>(
                  decoration: const InputDecoration(labelText: 'Theme', border: InputBorder.none),
                  value: themeProvider.themeMode,
                  items: const [
                    DropdownMenuItem(value: ThemeMode.system, child: Text('System Default')),
                    DropdownMenuItem(value: ThemeMode.light, child: Text('Light Mode')),
                    DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark Mode')),
                  ],
                  onChanged: (val) {
                    if (val != null) themeProvider.setThemeMode(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: SwitchListTile(
                activeColor: AppTheme.petronasGreen,
                title: const Text('Use 24-hour Time Format'),
                subtitle: const Text('Display time in 24-hour format instead of AM/PM'),
                value: provider.use24HourFormat,
                onChanged: (val) {
                  provider.setUse24HourFormat(val);
                },
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Notifications',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Notification Sound', border: InputBorder.none),
                  value: _selectedSound,
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('System Default')),
                    DropdownMenuItem(value: 'beep', child: Text('Short Beep')),
                    DropdownMenuItem(value: 'chime', child: Text('Chime')),
                  ],
                  onChanged: (val) {
                    if (val != null) _saveSound(val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.notifications_active, color: AppTheme.petronasGreen),
                title: const Text('Test Notification & Sound'),
                subtitle: const Text('Sends a test notification in 5 seconds.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () async {
                  try {
                    await NotificationService.testNotification();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test notification will appear in 5 seconds.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'Location Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      activeColor: AppTheme.petronasGreen,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Auto-detect Location (GPS)'),
                      subtitle: const Text('Uses device GPS to determine best API and Zone.'),
                      value: provider.useAutoDetect,
                      onChanged: (val) {
                        provider.setUseAutoDetect(val);
                      },
                    ),
                    if (!provider.useAutoDetect) ...[
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'International Manual Setup',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                hintText: 'Enter City or Country...',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onSubmitted: (_) => _searchLocation(provider),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _isSearching
                              ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator()))
                              : IconButton(
                                  icon: const Icon(Icons.search, color: AppTheme.petronasGreen),
                                  onPressed: () => _searchLocation(provider),
                                ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Malaysia JAKIM Zone Selection',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'State'),
                        value: _selectedState,
                        items: JakimZones.stateZones.keys.map((state) {
                          return DropdownMenuItem(
                            value: state,
                            child: Text(state),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedState = val;
                            _selectedZone = JakimZones.stateZones[val!]?.first['code'];
                          });
                          if (_selectedZone != null) {
                            provider.setManualZone(_selectedZone!);
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_selectedState != null)
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(labelText: 'Zone'),
                          value: _selectedZone,
                          isExpanded: true,
                          items: JakimZones.stateZones[_selectedState]!.map((zoneInfo) {
                            return DropdownMenuItem(
                              value: zoneInfo['code'],
                              child: Text('${zoneInfo['code']} - ${zoneInfo['name']}'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedZone = val;
                            });
                            if (val != null) {
                              provider.setManualZone(val);
                            }
                          },
                        ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            if (provider.locationResult != null) ...[
               Text(
                'Current Detection Info',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Is Malaysia: ${provider.locationResult!.isMalaysia ? "Yes" : "No"}'),
                      Text('Country: ${provider.locationResult!.country ?? "Unknown"}'),
                      Text('City/Area: ${provider.locationResult!.city ?? "Unknown"}'),
                      if (provider.locationResult!.jakimZoneCode != null)
                        Text('JAKIM Zone: ${provider.locationResult!.jakimZoneCode}'),
                    ],
                  ),
                ),
              )
            ]
          ],
        );
      },
    );
  }
}
