import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
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
import 'providers/locale_provider.dart';
import 'services/notification_service.dart';
import 'package:workmanager/workmanager.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  Workmanager().executeTask((task, inputData) async {
    // Run in background: fetch data and update widget/notifications safely
    final provider = PrayerProvider();
    await provider.init(isBackground: true); 
    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ms');
  await initializeDateFormatting('en');
  await NotificationService.initialize();
  
  Workmanager().initialize(
    callbackDispatcher, 
  );
  Workmanager().registerPeriodicTask(
    "solat_malaysia_background_update",
    "background_update",
    frequency: const Duration(hours: 4), // Update every 4 hours
    existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PrayerProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
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
        builder: (context) {
          final l = this.context.read<LocaleProvider>();
          return AlertDialog(
          title: Text(l.t('update.title')),
          content: Text(l.t('update.body')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.t('update.later')),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                final Uri url = Uri.parse('https://www.research.maizzat.my/downloads/solat_malaysia_download.html');
                if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                  debugPrint('Could not launch update URL');
                }
              },
              child: Text(l.t('update.now')),
            ),
          ],
        );
        },
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
    final l = context.watch<LocaleProvider>();
    return Scaffold(
      appBar: AppBar(
        title: Text(l.t('app.title')),
      ),
      body: Container(
        decoration: Theme.of(context).brightness == Brightness.dark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0, -0.75),
                  radius: 1.1,
                  colors: [Color(0xFF00283F), AppTheme.bgDeep],
                ),
              )
            : null,
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: const Icon(Icons.home),
            label: l.t('nav.home'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore),
            label: l.t('nav.qibla'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.settings),
            label: l.t('nav.settings'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.info),
            label: l.t('nav.about'),
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
