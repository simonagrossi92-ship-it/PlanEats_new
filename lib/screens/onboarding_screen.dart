import 'package:flutter/material.dart';
import '../database_helper.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pesoController = TextEditingController();
  final _altezzaController = TextEditingController();
  final _etaController = TextEditingController();
  final _obiettivoCaloricoController = TextEditingController();
  
  String? _selectedGenere;
  String? _selectedLivelloAttivita;
  String? _selectedObiettivo;
  int _calculatedCalories = 2000;
  int? _calculatedBMR;
  int? _calculatedTDEE;
  bool _isManualEdit = false;

  final List<String> _generi = ['Uomo', 'Donna'];
  final List<String> _livelliAttivita = [
    'Sedentario',
    'Leggermente attivo',
    'Moderatamente attivo',
    'Molto attivo',
    'Atleta',
  ];

  static const Map<String, String> _descrizioniAttivita = {
    'Sedentario': 'Ufficio, poco esercizio (×1.2)',
    'Leggermente attivo': 'Esercizio 1-3 volte/settimana (×1.375)',
    'Moderatamente attivo': 'Esercizio 3-5 volte/settimana (×1.55)',
    'Molto attivo': 'Esercizio 6-7 volte/settimana (×1.725)',
    'Atleta': 'Allenamento intenso ogni giorno (×1.9)',
  };
  final List<String> _obiettivi = [
    'Perdere peso',
    'Mantenere',
    'Aumentare massa'
  ];

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
  }

  Future<void> _loadExistingPreferences() async {
    await DatabaseHelper.instance.initDatabase();
    final profile = await DatabaseHelper.instance.getProfile();
    final prefs = await DatabaseHelper.getUserPreferences();
    if (prefs != null || profile != null) {
      setState(() {
        final eta = prefs?['eta'] ?? profile?['eta'];
        if (eta != null) {
          _etaController.text = eta.toString();
        }
        if (prefs != null) {
          if (prefs['peso'] != null) {
            _pesoController.text = prefs['peso'].toString();
          }
          if (prefs['altezza'] != null) {
            _altezzaController.text = prefs['altezza'].toString();
          }
          _selectedGenere = prefs['genere'] as String?;
          final livello = prefs['livello_attivita'] as String?;
          _selectedLivelloAttivita = livello == 'Estremamente attivo'
              ? 'Atleta'
              : livello;
          _selectedObiettivo = prefs['obiettivo'] as String?;
          if (prefs['obiettivo_calorico'] != null) {
            _obiettivoCaloricoController.text =
                prefs['obiettivo_calorico'].toString();
            _calculatedCalories = prefs['obiettivo_calorico'] as int;
          }
        }
      });
      _calculateCalories();
    }
  }

  void _calculateCalories() {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }
    final peso = DatabaseHelper.parseDoubleIt(_pesoController.text);
    final altezza = DatabaseHelper.parseIntIt(_altezzaController.text);
    final eta = DatabaseHelper.parseIntIt(_etaController.text);
    final livelloAttivita = _selectedLivelloAttivita ?? 'Sedentario';
    final obiettivo = _selectedObiettivo ?? 'Mantenere';

    if (_selectedGenere != null && peso != null && altezza != null && eta != null) {
      final bmr = DatabaseHelper.calcolaBMR(
        peso: peso,
        altezza: altezza,
        eta: eta,
        genere: _selectedGenere!,
      );
      final tdee = DatabaseHelper.calcolaTDEE(
        bmr: bmr,
        livelloAttivita: livelloAttivita,
      );
      final calories = DatabaseHelper.calcolaObiettivoCalorico(
        bmr: bmr,
        obiettivo: obiettivo,
        livelloAttivita: livelloAttivita,
      );

      setState(() {
        _calculatedBMR = bmr.round();
        _calculatedTDEE = tdee;
        _calculatedCalories = calories;
        if (!_isManualEdit) {
          _obiettivoCaloricoController.text = calories.toString();
        }
      });
    }
  }

  Future<void> _savePreferences() async {
    if (_formKey.currentState!.validate()) {
      final peso = DatabaseHelper.parseDoubleIt(_pesoController.text);
      final altezza = DatabaseHelper.parseIntIt(_altezzaController.text);
      final eta = DatabaseHelper.parseIntIt(_etaController.text);
      final obiettivoCalorico =
          int.tryParse(_obiettivoCaloricoController.text.trim()) ??
              _calculatedCalories;

      if (_selectedGenere == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seleziona il genere')),
        );
        return;
      }

      if (peso == null || altezza == null || eta == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inserisci peso, altezza ed età validi')),
        );
        return;
      }

      await DatabaseHelper.instance.saveProfile(eta, null);
      await DatabaseHelper.saveUserPreferences(
        peso: peso,
        altezza: altezza,
        eta: eta,
        genere: _selectedGenere!,
        obiettivoCalorico: obiettivoCalorico,
        livelloAttivita: _selectedLivelloAttivita,
        obiettivo: _selectedObiettivo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferenze salvate con successo'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _pesoController.dispose();
    _altezzaController.dispose();
    _etaController.dispose();
    _obiettivoCaloricoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configura il tuo profilo nutrizionale'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Salta per ora'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Informazioni Personali',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pesoController,
                decoration: const InputDecoration(
                  labelText: 'Peso (kg)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monitor_weight),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci il peso';
                  }
                  final peso = double.tryParse(value);
                  if (peso == null || peso < 30 || peso > 300) {
                    return 'Inserisci un peso valido (30-300 kg)';
                  }
                  return null;
                },
                onChanged: (_) => _calculateCalories(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _altezzaController,
                decoration: const InputDecoration(
                  labelText: 'Altezza (cm)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.height),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci l\'altezza';
                  }
                  final altezza = int.tryParse(value);
                  if (altezza == null || altezza < 100 || altezza > 250) {
                    return 'Inserisci un\'altezza valida (100-250 cm)';
                  }
                  return null;
                },
                onChanged: (_) => _calculateCalories(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _etaController,
                decoration: const InputDecoration(
                  labelText: 'Età',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.cake),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Inserisci l\'età';
                  }
                  final eta = int.tryParse(value);
                  if (eta == null || eta < 16 || eta > 100) {
                    return 'Inserisci un\'età valida (16-100 anni)';
                  }
                  return null;
                },
                onChanged: (_) => _calculateCalories(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedGenere,
                decoration: const InputDecoration(
                  labelText: 'Genere',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                items: _generi.map((genere) {
                  return DropdownMenuItem<String>(
                    value: genere,
                    child: Text(genere),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedGenere = value;
                  });
                  _calculateCalories();
                },
                validator: (value) {
                  if (value == null) {
                    return 'Seleziona il genere';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              const Text(
                'Livello di Attività',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedLivelloAttivita,
                decoration: const InputDecoration(
                  labelText: 'Livello di attività',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.directions_run),
                ),
                items: _livelliAttivita.map((livello) {
                  return DropdownMenuItem<String>(
                    value: livello,
                    child: Text(livello),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedLivelloAttivita = value;
                    _isManualEdit = false;
                  });
                  _calculateCalories();
                },
              ),
              if (_selectedLivelloAttivita != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _descrizioniAttivita[_selectedLivelloAttivita!] ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              const Text(
                'Obiettivo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedObiettivo,
                decoration: const InputDecoration(
                  labelText: 'Obiettivo',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: _obiettivi.map((obiettivo) {
                  return DropdownMenuItem<String>(
                    value: obiettivo,
                    child: Text(obiettivo),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedObiettivo = value;
                    _isManualEdit = false;
                  });
                  _calculateCalories();
                },
              ),
              const SizedBox(height: 24),
              Card(
                color: Colors.green[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Obiettivo Calorico Giornaliero',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () {
                              setState(() {
                                _isManualEdit = true;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_calculatedBMR != null && _calculatedTDEE != null) ...[
                        _buildCalorieDetailRow(
                          'BMR (Mifflin-St Jeor)',
                          '$_calculatedBMR kcal',
                          'Calorie a riposo assoluto',
                        ),
                        const SizedBox(height: 4),
                        _buildCalorieDetailRow(
                          'TDEE (consumo totale)',
                          '$_calculatedTDEE kcal',
                          'BMR × ${DatabaseHelper.fattoreAttivita(_selectedLivelloAttivita ?? 'Sedentario')}',
                        ),
                        if (_selectedObiettivo != null &&
                            _selectedObiettivo != 'Mantenere') ...[
                          const SizedBox(height: 4),
                          _buildCalorieDetailRow(
                            'Aggiustamento obiettivo',
                            _selectedObiettivo == 'Perdere peso' ? '-500 kcal' : '+500 kcal',
                            _selectedObiettivo!,
                          ),
                        ],
                        const Divider(height: 24),
                      ],
                      if (_isManualEdit)
                        TextFormField(
                          controller: _obiettivoCaloricoController,
                          decoration: const InputDecoration(
                            labelText: 'Calorie (modifica manuale)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Inserisci le calorie';
                            }
                            final calories = int.tryParse(value);
                            if (calories == null || calories < 1000 || calories > 5000) {
                              return 'Inserisci un valore valido (1000-5000)';
                            }
                            return null;
                          },
                        )
                      else
                        Text(
                          '$_calculatedCalories kcal',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      if (!_isManualEdit)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Calcolato con la formula Mifflin-St Jeor',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'I calcoli forniti sono stime basate su formule standard e non sostituiscono il parere di un medico o professionista.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _savePreferences,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Salva Preferenze',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalorieDetailRow(String label, String value, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
