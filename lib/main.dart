import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'dart:ui' show PlatformDispatcher;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'app_state.dart';
import 'database_helper.dart';
import 'screens/menu_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/recipes_screen.dart';
import 'screens/recipes_list_screen.dart';
import 'screens/shopping_screen.dart';
import 'screens/report_screen.dart';
import 'screens/archive_screen.dart';
import 'screens/saved_plans_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Login anonimo per abilitare l'autenticazione Firebase
  try {
    await FirebaseAuth.instance.signInAnonymously();
  } catch (e) {
    // Ignora errori di login anonimo
  }

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    return false;
  };
  runApp(const PlanEatsApp());
}

class PlanEatsApp extends StatefulWidget {
  const PlanEatsApp({super.key});

  @override
  State<PlanEatsApp> createState() => _PlanEatsAppState();
}

class _PlanEatsAppState extends State<PlanEatsApp> {
  final AppState _state = AppState();

  @override
  void initState() {
    super.initState();
    _state.init();
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanEats',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8BA888), // Verde Salvia
          primary: const Color(0xFF8BA888),
          surface: const Color(0xFFFDF5E6), // Old Lace (#FDF5E6)
        ),
        scaffoldBackgroundColor: const Color(0xFFFDF5E6), // Sfondo Old Lace
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFDF5E6),
          elevation: 0,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF8BA888).withValues(alpha: 0.2),
          height: 80, // Altezza fissa per la barra di navigazione
        ),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('it', 'IT'),
        Locale('en', 'US'),
      ],
      home: AnimatedBuilder(
        animation: _state,
        builder: (context, _) {
          if (!_state.isReady) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return HomeShell(state: _state);
        },
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0; // default: Menù
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final profile = await DatabaseHelper.instance.getProfile();
    if (mounted) {
      setState(() {
        _profileData = profile;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      MenuScreen(state: widget.state),
      ShoppingScreen(state: widget.state),
      RecipesScreen(state: widget.state),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('PlanEats'),
        backgroundColor: const Color(0xFFFDF5E6),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFF8BA888),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () {
                          // TODO: Implementare caricamento foto
                        },
                        child: Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 3,
                            ),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFF8BA888),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'PlanEats',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.state.data.email.isNotEmpty 
                                  ? widget.state.data.email 
                                  : 'user@example.com',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 14,
                              ),
                            ),
                            if (_profileData != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.cake, color: Colors.white70, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _profileData!['eta'] != null 
                                        ? '${_profileData!['eta']} anni' 
                                        : '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(Icons.location_on, color: Colors.white70, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    _profileData!['regione'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.restaurant_menu_outlined),
              title: const Text('Menu settimanale'),
              selected: _index == 0,
              onTap: () {
                setState(() => _index = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart_outlined),
              title: const Text('Spesa'),
              selected: _index == 1,
              onTap: () {
                setState(() => _index = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Ricettario'),
              selected: _index == 2,
              onTap: () {
                setState(() => _index = 2);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('Profilo'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(state: widget.state),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Report Spese'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportScreen(state: widget.state),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('I miei piani salvati'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SavedPlansScreen(state: widget.state),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive),
              title: const Text('Archivio prodotti'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ArchiveScreen(state: widget.state),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Impostazioni'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsScreen(state: widget.state),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.red, size: 16),
              onTap: () {
                Navigator.pop(context);
                // TODO: Implementare logout
              },
            ),
          ],
        ),
      ),
      body: pages[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withValues(alpha: 0.1), // Ombra leggermente più marcata
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          elevation: 8, // Aggiunta elevazione alla NavigationBar stessa
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.restaurant_menu_outlined),
              selectedIcon: Icon(Icons.restaurant_menu),
              label: 'Menù',
            ),
            NavigationDestination(
              icon: Icon(Icons.shopping_cart_outlined),
              selectedIcon: Icon(Icons.shopping_cart),
              label: 'Spesa',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Ricettario',
            ),
          ],
        ),
      ),
    );
  }
}
