import 'package:flutter/material.dart';
import 'package:planeats/app_state.dart';
import 'package:planeats/models.dart';
import 'package:planeats/database_helper.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

/// Schermata Profilo con UI/UX migliorata seguendo Material Design 3
/// Organizza le informazioni dell'utente in sezioni chiare con design pulito
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Controller per i campi di input
  late TextEditingController _usernameController;
  late TextEditingController _emailController;
  late TextEditingController _allergiesController;
  late TextEditingController _ageController;
  late TextEditingController _pesoController;
  late TextEditingController _altezzaController;
  late TextEditingController _obiettivoCaloricoController;
  
  // Variabili di stato per dropdown e selezioni
  DietType? _selectedDietType;
  String? _selectedRegion;
  String? _selectedGenere;
  String? _selectedLivelloAttivita;
  String? _selectedObiettivo;
  
  // Variabili per calcoli calorie
  int _calculatedCalories = 2000;
  int? _calculatedBMR;
  int? _calculatedTDEE;
  bool _isManualEdit = false;
  
  // Foto profilo
  File? _profilePhoto;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Liste per dropdown
  final List<String> _italianRegions = [
    'Abruzzo', 'Basilicata', 'Calabria', 'Campania', 'Emilia-Romagna',
    'Friuli-Venezia Giulia', 'Lazio', 'Liguria', 'Lombardia', 'Marche',
    'Molise', 'Piemonte', 'Puglia', 'Sardegna', 'Sicilia', 'Toscana',
    'Trentino-Alto Adige', 'Umbria', "Valle d'Aosta", 'Veneto'
  ];

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
    _usernameController =
        TextEditingController(text: widget.state.data.username);
    _emailController = TextEditingController(text: widget.state.data.email);
    _allergiesController =
        TextEditingController(text: widget.state.data.allergies.join(', '));
    _selectedDietType = widget.state.data.dietType;
    _ageController = TextEditingController();
    _pesoController = TextEditingController();
    _altezzaController = TextEditingController();
    _obiettivoCaloricoController = TextEditingController();
    _loadAllProfileData();
  }

  Future<void> _loadAllProfileData() async {
    await DatabaseHelper.instance.initDatabase();
    final profile = await DatabaseHelper.instance.getProfile();
    final prefs = await DatabaseHelper.getUserPreferences();

    if (!mounted) return;
    setState(() {
      final eta = prefs?['eta'] ?? profile?['eta'];
      if (eta != null) {
        _ageController.text = eta.toString();
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

      _selectedRegion = profile?['regione'] as String?;
    });
    _calculateCalories();
    
    // Load profile photo
    _loadProfilePhoto();
  }
  
  Future<void> _loadProfilePhoto() async {
    final photoPath = await DatabaseHelper.getProfilePhoto();
    if (photoPath != null && File(photoPath).existsSync()) {
      setState(() {
        _profilePhoto = File(photoPath);
      });
    }
  }
  
  Future<void> _pickProfilePhoto() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );
      
      if (image != null) {
        setState(() {
          _profilePhoto = File(image.path);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore durante la selezione della foto: $e')),
        );
      }
    }
  }

  void _calculateCalories() {
    final peso = DatabaseHelper.parseDoubleIt(_pesoController.text);
    final altezza = DatabaseHelper.parseIntIt(_altezzaController.text);
    final eta = DatabaseHelper.parseIntIt(_ageController.text);
    final livelloAttivita = _selectedLivelloAttivita ?? 'Sedentario';
    final obiettivo = _selectedObiettivo ?? 'Mantenere';

    if (peso != null &&
        altezza != null &&
        eta != null &&
        _selectedGenere != null) {
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
    } else {
      setState(() {
        _calculatedBMR = null;
        _calculatedTDEE = null;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _allergiesController.dispose();
    _ageController.dispose();
    _pesoController.dispose();
    _altezzaController.dispose();
    _obiettivoCaloricoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDF5E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8BA888),
        elevation: 0,
        title: const Text(
          'Profilo',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con foto profilo
            _buildHeader(),
            const SizedBox(height: 30),
            
            // Sezione Informazioni Utente
            _buildSectionTitle('Informazioni Utente'),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _usernameController,
              label: 'Nome Utente',
              icon: Icons.person,
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            // Foto profilo upload
            _buildProfilePhotoUpload(),
            const SizedBox(height: 30),
            
            // Sezione Tipo di Dieta
            _buildSectionTitle('Tipo di Dieta'),
            const SizedBox(height: 16),
            _buildDietDropdown(),
            const SizedBox(height: 30),
            
            // Sezione Allergie
            _buildSectionTitle('Allergie'),
            const SizedBox(height: 16),
            _buildAllergiesField(),
            const SizedBox(height: 30),
            
            // Sezione Informazioni Personali
            _buildSectionTitle('Informazioni Personali'),
            const SizedBox(height: 16),
            // Età e Peso in Row
            Row(
              children: [
                Expanded(
                  child: _buildInputField(
                    controller: _ageController,
                    label: 'Età',
                    icon: Icons.cake,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateCalories(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInputField(
                    controller: _pesoController,
                    label: 'Peso (kg)',
                    icon: Icons.monitor_weight,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _calculateCalories(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInputField(
              controller: _altezzaController,
              label: 'Altezza (cm)',
              icon: Icons.height,
              keyboardType: TextInputType.number,
              onChanged: (_) => _calculateCalories(),
            ),
            const SizedBox(height: 16),
            _buildGenderDropdown(),
            const SizedBox(height: 16),
            _buildRegionDropdown(),
            const SizedBox(height: 30),
            
            // Sezione Livello di Attività
            _buildSectionTitle('Livello di Attività'),
            const SizedBox(height: 16),
            _buildActivityDropdown(),
            const SizedBox(height: 30),
            
            // Sezione Obiettivo
            _buildSectionTitle('Obiettivo'),
            const SizedBox(height: 16),
            _buildGoalDropdown(),
            const SizedBox(height: 30),
            
            // Sezione Calorie
            _buildCaloriesSection(),
            const SizedBox(height: 30),
            
            // Pulsante Salva
            _buildSaveButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  /// Widget riutilizzabile per i campi di input
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        prefixIcon: Icon(icon, color: const Color(0xFF8BA888)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: const Color(0xFF8BA888), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
  
  /// Widget per il titolo delle sezioni
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
  
  /// Header con foto profilo
  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickProfilePhoto,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[200],
                border: Border.all(
                  color: const Color(0xFF8BA888),
                  width: 3,
                ),
              ),
              child: _profilePhoto != null
                  ? ClipOval(
                      child: Image.file(
                        _profilePhoto!,
                        fit: BoxFit.cover,
                        width: 120,
                        height: 120,
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      size: 50,
                      color: Colors.grey,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Tocca per caricare la foto',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
  
  /// Widget per il caricamento foto profilo
  Widget _buildProfilePhotoUpload() {
    return const SizedBox.shrink(); // Già incluso nell'header
  }
  
  /// Dropdown per Tipo di Dieta
  Widget _buildDietDropdown() {
    return DropdownButtonFormField<DietType>(
      value: _selectedDietType,
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.restaurant, color: const Color(0xFF8BA888)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: const Color(0xFF8BA888), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      items: DietType.values.map((DietType type) {
        return DropdownMenuItem<DietType>(
          value: type,
          child: Text(type.displayName),
        );
      }).toList(),
      onChanged: (DietType? newValue) {
        if (newValue != null) {
          setState(() {
            _selectedDietType = newValue;
          });
        }
      },
    );
  }
  
  /// Campo per le allergie
  Widget _buildAllergiesField() {
    return TextField(
      controller: _allergiesController,
      decoration: InputDecoration(
        labelText: 'Allergie (separate da virgola)',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        hintText: 'es. arachidi, latte, uova',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: const Color(0xFF8BA888), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
  
  /// Dropdown per Genere
  Widget _buildGenderDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedGenere,
      decoration: InputDecoration(
        labelText: 'Genere',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.person, color: const Color(0xFF8BA888)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: const Color(0xFF8BA888), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
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
    );
  }
  
  /// Dropdown per Regione
  Widget _buildRegionDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedRegion,
      decoration: InputDecoration(
        labelText: 'Regione',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.location_on, color: const Color(0xFF8BA888)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: const Color(0xFF8BA888), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      hint: const Text('Seleziona Regione'),
      items: _italianRegions.map((region) {
        return DropdownMenuItem<String>(
          value: region,
          child: Text(region),
        );
      }).toList(),
      onChanged: (String? newValue) {
        setState(() {
          _selectedRegion = newValue;
        });
      },
    );
  }
  
  /// Dropdown per Livello di Attività
  Widget _buildActivityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedLivelloAttivita,
          decoration: InputDecoration(
            labelText: 'Livello di attività',
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.directions_run, color: const Color(0xFF8BA888)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: const Color(0xFF8BA888), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          hint: const Text('Seleziona livello di attività'),
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
      ],
    );
  }
  
  /// Dropdown per Obiettivo
  Widget _buildGoalDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedObiettivo,
      decoration: InputDecoration(
        labelText: 'Obiettivo',
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Icon(Icons.flag, color: const Color(0xFF8BA888)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: const Color(0xFF8BA888), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      hint: const Text('Seleziona obiettivo'),
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
    );
  }
  
  /// Sezione Calorie
  Widget _buildCaloriesSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8BA888).withOpacity(0.3),
              const Color(0xFF8BA888).withOpacity(0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(20.0),
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
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: const Color(0xFF8BA888)),
                  onPressed: () {
                    setState(() {
                      _isManualEdit = true;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_calculatedBMR != null && _calculatedTDEE != null) ...[
              _buildCalorieDetailRow(
                'BMR (Mifflin-St Jeor)',
                '$_calculatedBMR kcal',
                'Calorie a riposo assoluto',
              ),
              const SizedBox(height: 8),
              _buildCalorieDetailRow(
                'TDEE (consumo totale)',
                '$_calculatedTDEE kcal',
                'BMR × ${DatabaseHelper.fattoreAttivita(_selectedLivelloAttivita ?? 'Sedentario')}',
              ),
              if (_selectedObiettivo != null &&
                  _selectedObiettivo != 'Mantenere') ...[
                const SizedBox(height: 8),
                _buildCalorieDetailRow(
                  'Aggiustamento obiettivo',
                  _selectedObiettivo == 'Perdere peso' ? '-500 kcal' : '+500 kcal',
                  _selectedObiettivo!,
                ),
              ],
              const Divider(height: 24),
            ],
            if (_isManualEdit)
              TextField(
                controller: _obiettivoCaloricoController,
                decoration: InputDecoration(
                  labelText: 'Calorie (modifica manuale)',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
                keyboardType: TextInputType.number,
              )
            else
              Center(
                child: Text(
                  '$_calculatedCalories kcal',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF8BA888),
                  ),
                ),
              ),
            if (!_isManualEdit)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Calcolato con la formula Mifflin-St Jeor',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  /// Pulsante Salva
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8BA888),
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Modifica Profilo',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
  
  /// Riga dettaglio calorie
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
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[700],
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
            color: const Color(0xFF8BA888),
          ),
        ),
      ],
    );
  }
  
  /// Metodo per salvare il profilo
  Future<void> _saveProfile() async {
    try {
      // Salva username ed email
      await widget.state.updateUsername(_usernameController.text);
      await widget.state.updateEmail(_emailController.text);

      // Salva tipo di dieta
      if (_selectedDietType != null) {
        await widget.state.updateDietType(_selectedDietType!);
      }

      // Salva allergie
      final allergiesList = _allergiesController.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await widget.state.updateAllergies(allergiesList);

      // Salva dati profilo (età e regione)
      final eta = DatabaseHelper.parseIntIt(_ageController.text);
      final peso = DatabaseHelper.parseDoubleIt(_pesoController.text);
      final altezza = DatabaseHelper.parseIntIt(_altezzaController.text);
      final obiettivoCalorico =
          int.tryParse(_obiettivoCaloricoController.text.trim()) ??
              _calculatedCalories;

      await DatabaseHelper.instance.saveProfile(eta, _selectedRegion);

      // Salva peso se presente (indipendentemente dagli altri campi)
      if (peso != null) {
        await DatabaseHelper.saveUserProfileField('peso', peso);
      }

      // Salva altezza se presente
      if (altezza != null) {
        await DatabaseHelper.saveUserProfileField('altezza', altezza);
      }

      // Salva età se presente
      if (eta != null) {
        await DatabaseHelper.saveUserProfileField('eta', eta);
      }

      // Salva genere se presente
      if (_selectedGenere != null) {
        await DatabaseHelper.saveUserProfileField('genere', _selectedGenere);
      }

      // Verifica campi obbligatori per calcolo nutrizionale completo
      final missing = <String>[];
      if (eta == null) missing.add('età');
      if (peso == null) missing.add('peso');
      if (altezza == null) missing.add('altezza');
      if (_selectedGenere == null) missing.add('genere');

      if (missing.isEmpty) {
        // Tutti i campi obbligatori sono presenti, salva preferenze complete
        await DatabaseHelper.saveUserPreferences(
          peso: peso!,
          altezza: altezza!,
          eta: eta!,
          genere: _selectedGenere!,
          obiettivoCalorico: obiettivoCalorico,
          livelloAttivita: _selectedLivelloAttivita,
          obiettivo: _selectedObiettivo,
        );
        
        // Salva foto profilo
        if (_profilePhoto != null) {
          await DatabaseHelper.saveProfilePhoto(_profilePhoto!.path);
        }
      } else {
        // Salva i campi che sono presenti anche se non tutti sono completi
        await DatabaseHelper.savePartialUserPreferences(
          peso: peso,
          altezza: altezza,
          eta: eta,
          genere: _selectedGenere,
          obiettivoCalorico: obiettivoCalorico,
          livelloAttivita: _selectedLivelloAttivita,
          obiettivo: _selectedObiettivo,
        );
      }

      // Mostra messaggio di successo
      if (mounted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profilo salvato con successo'),
              backgroundColor: const Color(0xFF8BA888),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore durante il salvataggio: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
