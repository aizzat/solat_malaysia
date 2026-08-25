import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prayer_provider.dart';
import '../utils/jakim_zones.dart';
import '../theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedState;
  String? _selectedZone;

  @override
  Widget build(BuildContext context) {
    return Consumer<PrayerProvider>(
      builder: (context, provider, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Location Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.petronasBlue,
              ),
            ),
            const SizedBox(height: 16),
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
                          'Manual JAKIM Zone Selection',
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
               const Text(
                'Current Detection Info',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.petronasBlue,
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
