import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart';
import 'services/update_service.dart';
import 'screens/about_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/qibla_screen.dart';
import 'providers/prayer_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((task, inputData) async {
    // Run in background: fetch data and update widget/notifications
    final provider = PrayerProvider();
    await provider.init(); 
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize();
  
  Workmanager().initialize(
    callbackDispatcher, 
    isInDebugMode: false,
  );
  Workmanager().registerPeriodicTask(
    "solat_malaysia_background_update",
    "background_update",
    frequency: const Duration(hours: 4), // Update every 4 hours
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrayerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const SolatMalaysiaApp(),
    ),
  );
}

class SolatMalaysiaApp extends StatelessWidget {
  const SolatMalaysiaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Solat Malaysia',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Defer both init() and update check until after the first frame.
    // This guarantees the Android Activity is fully resumed before
    // Geolocator.requestPermission() is called — fixing the first-install
    // blank screen where the permission dialog never appeared.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (mounted) {
          await context.read<PrayerProvider>().init();
          await NotificationService.requestPermissions();
          _checkForUpdates();
        }
      });
    });
  }

  Future<void> _checkForUpdates() async {
    final hasUpdate = await UpdateService.checkForUpdate();
    if (hasUpdate && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Available'),
          content: const Text('A new version of Solat Malaysia is available. Would you like to download it now?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final Uri url = Uri.parse('https://www.research.maizzat.my/downloads/solat_malaysia_download.html');
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  debugPrint('Could not launch update URL');
                }
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      );
    }
  }

  static const List<Widget> _pages = <Widget>[
    HomeScreen(),
    QiblaScreen(),
    SettingsScreen(),
    AboutScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solat Malaysia'),
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.explore),
            label: 'Qibla',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'About',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: AppTheme.petronasGreen,
        unselectedItemColor: Colors.grey.shade600,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        onTap: _onItemTapped,
      ),
    );
  }
}
