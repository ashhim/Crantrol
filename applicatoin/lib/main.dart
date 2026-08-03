import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/device.dart';
import 'providers/auth_provider.dart';
import 'providers/device_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/relays_screen.dart';
import 'screens/sequences_screen.dart';
import 'screens/settings_screen.dart';
import 'services/app_environment.dart';
import 'services/firebase_service.dart';
import 'utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(DeviceAdapter());
  }
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(RelayAdapter());
  }

  try {
    await AppEnvironment.load();
    await FirebaseService().initialize();
  } catch (e) {
    debugPrint('Firebase Service initialization error: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
      ],
      child: MaterialApp(
        title: 'CRANTROL',
        theme: AppTheme.darkTheme,
        debugShowCheckedModeBanner: false,
        home: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            if (authProvider.isAuthenticated) {
              return const HomeScreen();
            }
            return const LoginScreen();
          },
        ),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
          '/settings': (context) {
            final deviceId =
                ModalRoute.of(context)?.settings.arguments as String?;
            return SettingsScreen(deviceId: deviceId ?? 'device_001');
          },
        },
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  static const String _deviceId = 'device_001';

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const DashboardScreen(deviceId: _deviceId),
      const RelaysScreen(deviceId: _deviceId),
      const SequencesScreen(deviceId: _deviceId),
      const SettingsScreen(deviceId: _deviceId),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(_selectedIndex),
          child: pages[_selectedIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.panelColor,
          border: const Border(
            top: BorderSide(color: Color(0xFF1A2332), width: 1),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: const Color(0xFF00E676),
          unselectedItemColor: const Color(0xFF5A6A7A),
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.orbitron(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: GoogleFonts.orbitron(
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
          onTap: (index) => setState(() => _selectedIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded),
              label: 'DASHBOARD',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.toggle_on_outlined),
              label: 'RELAYS',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.view_list_rounded),
              label: 'SEQUENCES',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),
              label: 'SETTINGS',
            ),
          ],
        ),
      ),
    );
  }
}
