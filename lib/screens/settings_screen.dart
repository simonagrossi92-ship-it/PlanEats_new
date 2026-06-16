import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:planeats/database_helper.dart';
import 'package:planeats/app_state.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  bool _notifications = true;
  bool _recipePreview = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _notifications = prefs.getBool('notifications') ?? true;
      _recipePreview = prefs.getBool('recipePreview') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setBool('notifications', _notifications);
    await prefs.setBool('recipePreview', _recipePreview);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Impostazioni'),
      ),
      body: ListView(
        children: [
          // Profil e Personalizzazione
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'PROFILO E PERSONALIZZAZIONE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Modifica Profilo'),
            subtitle: const Text('Età, regione, stile di vita'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(state: widget.state),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.restaurant),
            title: const Text('Obiettivi Nutrizionali'),
            subtitle: const Text('Dieta leggera, bilanciata o sportiva'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement nutritional goals
            },
          ),
          const Divider(),

          // Preferenze App
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'PREFERENZE APP',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Modalità Scura'),
            subtitle: const Text('Attiva tema scuro'),
            trailing: Switch(
              value: _darkMode,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                });
                _saveSettings();
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifiche'),
            subtitle: const Text('Ricorda di fare la spesa'),
            trailing: Switch(
              value: _notifications,
              onChanged: (value) {
                setState(() {
                  _notifications = value;
                });
                _saveSettings();
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Mostra Anteprima Ricette'),
            subtitle: const Text('Visualizza immagini delle ricette'),
            trailing: Switch(
              value: _recipePreview,
              onChanged: (value) {
                setState(() {
                  _recipePreview = value;
                });
                _saveSettings();
              },
            ),
          ),
          const Divider(),

          // Gestione Dati
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'GESTIONE DATI',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.refresh),
            title: const Text('Resetta Database'),
            subtitle: const Text('Cancella tutte le ricette scaricate'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showResetDatabaseDialog();
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_upload),
            title: const Text('Esporta Dati'),
            subtitle: const Text('Salva copia del database'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement export
            },
          ),
          ListTile(
            leading: const Icon(Icons.file_download),
            title: const Text('Importa Dati'),
            subtitle: const Text('Carica copia del database'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement import
            },
          ),
          const Divider(),

          // Informazioni
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'INFORMAZIONI',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Versione App'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Aiuto e Supporto'),
            subtitle: const Text('FAQ e contatti'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement help/support
            },
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement privacy policy
            },
          ),
          ListTile(
            leading: const Icon(Icons.feedback),
            title: const Text('Segnala un problema'),
            subtitle: const Text('Invia feedback per migliorare l\'app'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Implement feedback
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showResetDatabaseDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resetta Database'),
        content: const Text(
          'Sei sicuro di voler cancellare tutte le ricette scaricate? Questa azione è irreversibile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _resetDatabase();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Resetta'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetDatabase() async {
    try {
      // Delete the database file
      final db = await DatabaseHelper.instance.database;
      await db.delete('ricette');
      await db.delete('profilo');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database resettato con successo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante il reset: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
