import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

import '../app_state.dart';
import '../models.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../utils/dates.dart';
import '../database_helper.dart';
import 'recipe_editor.dart';
import 'recipes_screen.dart';

Color getMealColor(BuildContext context, MealType type) {
  switch (type) {
    case MealType.colazione:
      return const Color(0xFFFFD54F); // Amber 300
    case MealType.pranzo:
      return const Color(0xFF81D4FA); // Light Blue 200
    case MealType.cena:
      return const Color(0xFF9FA8DA); // Indigo 200
    case MealType.snack:
      return Colors.black87; // Nero per pasti opzionali/snack
  }
}

Color getMealSurfaceColor(BuildContext context, MealType type) {
  switch (type) {
    case MealType.colazione:
    case MealType.pranzo:
    case MealType.cena:
      return Colors.white;
    case MealType.snack:
      return Colors.white; // Anche lo snack bianco come gli altri
  }
}

Color _getCategoryColor(IngredientCategory category) {
  switch (category) {
    case IngredientCategory.ortofrutta:
      return Colors.green;
    case IngredientCategory.carne:
      return Colors.red;
    case IngredientCategory.pesce:
      return Colors.blue;
    case IngredientCategory.latticini:
      return Colors.orange;
    case IngredientCategory.panetteria:
      return Colors.brown;
    case IngredientCategory.surgelati:
      return Colors.cyan;
    case IngredientCategory.dispensa:
      return Colors.amber;
    case IngredientCategory.bevande:
      return Colors.purple;
    case IngredientCategory.prodottiAnimali:
      return Colors.teal;
    case IngredientCategory.curaCasa:
      return Colors.lime;
    case IngredientCategory.igienePersonale:
      return Colors.pink;
    case IngredientCategory.altro:
      return Colors.grey;
  }
}

Color getMealOnColor(BuildContext context, MealType type) {
  switch (type) {
    case MealType.colazione:
      return const Color(0xFF5D4037); // Brown 800
    case MealType.pranzo:
      return const Color(0xFF01579B); // Light Blue 900
    case MealType.cena:
      return const Color(0xFF1A237E); // Indigo 900
    case MealType.snack:
      return Colors.white; // Testo bianco su sfondo nero per l'icona snack
  }
}

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.state});
  final AppState state;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen>
    with SingleTickerProviderStateMixin {
  TabController? _tabController;
  final GeminiService _geminiService = GeminiService();
  final StorageService _storageService = StorageService();
  final ImagePicker _imagePicker = ImagePicker();
  bool _dontShowProfileReminder = false;
  List<DateTime> _plannedDates = [];

  // Costanti per le categorie per ridurre la dimensione del prompt
  static const String _categorieInstructions = '''
Categorie valide: Antipasti, Primi Piatti, Secondi, Contorni, Dolci, Altre Ricette
Sottocategorie Antipasti: Crudité, Fritti, Stuzzichini, Bruschette, Tartine
Sottocategorie Primi Piatti: Pasta, Riso, Zuppe, Gnocchi, Crespelle
Sottocategorie Secondi: Carne, Pesce, Uova, Legumi, Formaggi
Sottocategorie Contorni: Verdure, Insalate, Patate, Legumi
Sottocategorie Dolci: Torte, Biscotti, Gelati, Mousse, Frutta
Sottocategorie Altre Ricette: Salse, Conservazioni, Bevande, Altro
Categorie ingredienti: ortofrutta, carne, pesce, latticini, panetteria, surgelati, dispensa, bevande
''';

  @override
  void initState() {
    super.initState();
    _loadPlannedDates();
  }

  Future<void> _loadPlannedDates() async {
    // Load planned dates from database
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> results = await db.rawQuery(
      'SELECT DISTINCT data FROM menu_pianificato ORDER BY data ASC'
    );
    
    if (mounted) {
      setState(() {
        _plannedDates = results.map((row) {
          final parts = row['data'].toString().split('-');
          return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }).toList();
      });
    }
    
    // Add 7 days of current week (Mon-Sun) if not present
    await _addCurrentWeekDays();
    
    if (mounted) {
      setState(() {
        // Set up TabController with the number of planned dates
        _tabController = TabController(length: _plannedDates.length, vsync: this);
        
        // Find the current day's index
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        for (int i = 0; i < _plannedDates.length; i++) {
          final day = DateTime(_plannedDates[i].year, _plannedDates[i].month, _plannedDates[i].day);
          if (day.isAtSameMomentAs(today)) {
            _tabController!.index = i;
            break;
          }
        }
      });
    }
  }

  Future<void> _addCurrentWeekDays() async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();
    
    // Find Monday of current week
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    
    // Add days from Monday to Sunday
    for (int i = 0; i < 7; i++) {
      final day = monday.add(Duration(days: i));
      final dateStr = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      
      // Check if date already exists
      final existing = await db.query(
        'menu_pianificato',
        where: 'data = ?',
        whereArgs: [dateStr],
      );
      
      if (existing.isEmpty) {
        // Add the date to the database (empty entry)
        await db.insert('menu_pianificato', {
          'data': dateStr,
          'ricetta_id': '',
          'pasto': '',
        });
        
        if (mounted) {
          setState(() {
            _plannedDates.add(day);
          });
        }
      }
    }
  }

  Future<void> _addPlannedDate() async {
    // Show dialog to choose between single day or date range
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aggiungi giorni'),
        content: const Text('Vuoi aggiungere un singolo giorno o un intervallo di giorni?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'single'),
            child: const Text('Singolo giorno'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'range'),
            child: const Text('Intervallo di giorni'),
          ),
        ],
      ),
    );

    if (choice == 'single') {
      await _addSingleDate();
    } else if (choice == 'range') {
      await _addDateRange();
    }
  }

  Future<void> _addSingleDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
      locale: const Locale('it', 'IT'),
      helpText: 'Seleziona data',
    );

    if (selectedDate != null) {
      final db = await DatabaseHelper.instance.database;
      final dateStr = '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
      
      final existing = await db.query(
        'menu_pianificato',
        where: 'data = ?',
        whereArgs: [dateStr],
      );
      
      if (existing.isEmpty) {
        await db.insert('menu_pianificato', {
          'data': dateStr,
          'ricetta_id': '',
          'pasto': '',
        });
        
        await _loadPlannedDates();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Giorno aggiunto con successo'),
              backgroundColor: Color(0xFF8BA888),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Questo giorno è già presente'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _addDateRange() async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(
        start: DateTime.now(),
        end: DateTime.now().add(const Duration(days: 6)),
      ),
      locale: const Locale('it', 'IT'),
      saveText: 'Aggiungi',
    );

    if (dateRange != null) {
      final db = await DatabaseHelper.instance.database;
      final startDate = dateRange.start;
      final endDate = dateRange.end;
      
      int addedCount = 0;
      
      // Add all dates in the range
      for (var date = startDate; date.isBefore(endDate.add(const Duration(days: 1))); date = date.add(const Duration(days: 1))) {
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final existing = await db.query(
          'menu_pianificato',
          where: 'data = ?',
          whereArgs: [dateStr],
        );
        
        if (existing.isEmpty) {
          // Add the date to the database (empty entry)
          await db.insert('menu_pianificato', {
            'data': dateStr,
            'ricetta_id': '',
            'pasto': '',
          });
          addedCount++;
        }
      }
      
      // Reload planned dates to update UI immediately
      await _loadPlannedDates();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$addedCount date aggiunte con successo'),
            backgroundColor: const Color(0xFF8BA888),
          ),
        );
      }
    }
  }

  Future<void> _deletePlannedDate(DateTime date) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina data'),
        content: Text('Vuoi eliminare il menu del ${date.day}/${date.month}/${date.year}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        'menu_pianificato',
        where: 'data = ?',
        whereArgs: [dateStr],
      );
      
      await _loadPlannedDates();
    }
  }

  Future<void> _archiveMenu(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archivia Menu'),
        content: const Text('Verranno cancellati i giorni passati e salvati nei "I miei piani salvati". Premere OK per confermare.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF8BA888)),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get all dates that are older than today
      final oldMenus = await db.query(
        'menu_pianificato',
        where: 'data < ?',
        whereArgs: ['${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}'],
      );
      
      if (oldMenus.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nessun menu vecchio da archiviare'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Archive the old menus
      for (final menu in oldMenus) {
        await db.insert(
          'menu_archiviati',
          {
            'data': menu['data'],
            'ricetta_id': menu['ricetta_id'],
            'pasto': menu['pasto'],
            'data_archiviazione': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          },
        );
      }
      
      // Delete old menus from main table
      await db.delete(
        'menu_pianificato',
        where: 'data < ?',
        whereArgs: ['${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}'],
      );
      
      // Reload planned dates
      await _loadPlannedDates();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${oldMenus.length} menu archiviati'),
            backgroundColor: const Color(0xFF8BA888),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _showGeminiMenu() async {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset buttonPosition = button.localToGlobal(Offset.zero);
    final Size buttonSize = button.size;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        buttonPosition.dx,
        buttonPosition.dy + buttonSize.height,
        buttonPosition.dx + buttonSize.width,
        buttonPosition.dy,
      ),
      items: [
        const PopupMenuItem<String>(
          value: 'menu',
          child: Row(
            children: [
              Icon(Icons.auto_awesome_motion, color: Colors.amber),
              SizedBox(width: 12),
              Text('Genera Menu'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'advice',
          child: Row(
            children: [
              Icon(Icons.auto_awesome, color: Colors.amber),
              SizedBox(width: 12),
              Text('Consiglio AI'),
            ],
          ),
        ),
      ],
    );

    if (selected == 'menu') {
      _generateDailyMenu();
    } else if (selected == 'advice') {
      _showGeminiAdvice();
    }
  }

  void _showGeminiAdvice() async {
    if (_tabController == null) return;
    final currentDay = _plannedDates[_tabController!.index];
    final recipes = {for (final r in widget.state.data.recipes) r.id: r};

    // Collect meals for the current day
    final mealDescriptions = <String>[];
    for (final mealType in MealType.values) {
      final entry = widget.state.mealEntry(currentDay, mealType);
      if (entry != null && !entry.isEmpty) {
        final titles = entry.displayTitles(recipes: recipes);
        mealDescriptions
            .add('${mealTypeLabel(mealType)}: ${titles.join(', ')}');
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: DraggableScrollableSheet(
              initialChildSize: 0.5,
              minChildSize: 0.3,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Drag handle
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      // Header with better visual hierarchy
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.auto_awesome,
                                  color: Colors.amber,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Consiglio AI',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.grey[850],
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                              iconSize: 24,
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Content
                      Expanded(
                        child: FutureBuilder<String>(
                          future: _getGeminiAdvice(mealDescriptions),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const CircularProgressIndicator(
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Sto pensando...',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (snapshot.hasError) {
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        size: 48,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Ops, riprova tra poco',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey[700],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        snapshot.error.toString(),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }

                            return SingleChildScrollView(
                              controller: scrollController,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 10, 20, 40),
                              child: MarkdownBody(
                                data: _cleanMarkdown(snapshot.data ??
                                    'Nessun consiglio disponibile.'),
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: Colors.grey[800],
                                  ),
                                  h1: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  h2: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  h3: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                  listBullet: const TextStyle(
                                    color: Colors.amber,
                                  ),
                                  strong: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<String> _getGeminiAdvice(List<String> mealDescriptions) async {
    try {
      String prompt;
      if (mealDescriptions.isEmpty) {
        prompt = '''
        Sei un assistente nutrizionale. Il menu della giornata è vuoto.
        Suggerisci un'idea generale per una giornata alimentare equilibrata.
        Sii conciso e pratico (massimo 100 parole).
        Rispondi in italiano.
        ''';
      } else {
        prompt = '''
        Sei un assistente nutrizionale. Ecco il menu della giornata:
        ${mealDescriptions.join('\n')}

        Analizza questo menu e dai un consiglio nutrizionale specifico.
        Sii conciso e pratico (massimo 100 parole).
        Rispondi in italiano.
        ''';
      }

      final response = await _geminiService.chiediAGemini(prompt);
      return response;
    } catch (e) {
      throw Exception('Errore durante la richiesta: $e');
    }
  }

  String _cleanMarkdown(String text) {
    // Remove escape characters and clean up the markdown
    return text
        .replaceAll(r'\n', '\n') // Fix escaped newlines
        .replaceAll(r'\*', '*') // Fix escaped asterisks
        .replaceAll(r'\_', '_') // Fix escaped underscores
        .replaceAll(r'\#', '#') // Fix escaped hashes
        .replaceAll(r'\-', '-') // Fix escaped hyphens
        .trim(); // Remove leading/trailing whitespace
  }

  Future<void> _pickImage(DateTime day, MealType type) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image == null) return;

      final entry = widget.state.mealEntry(day, type);
      if (entry == null || entry.isEmpty) return;

      final firstItem = entry.items.first;
      if (firstItem.recipeId == null || firstItem.recipeId!.isEmpty) return;

      // Upload image to Firebase Storage
      final imageUrl = await _storageService.uploadImage(
        File(image.path),
        firstItem.recipeId!,
      );

      if (imageUrl != null) {
        // Update recipe with image URL
        final recipe = widget.state.data.recipes.firstWhere(
          (r) => r.id == firstItem.recipeId,
        );

        await widget.state.upsertRecipe(
          id: recipe.id,
          title: recipe.title,
          ingredients: recipe.ingredients,
          note: recipe.note,
          category: recipe.category,
          imageUrl: imageUrl,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Immagine caricata con successo')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento immagine: $e')),
        );
      }
    }
  }

  void _generateDailyMenu() async {
    // Check if user has profile info and show reminder if needed
    final hasDietInfo = widget.state.data.dietType != DietType.nessuna;
    final hasAllergies = widget.state.data.allergies.isNotEmpty;

    if (!_dontShowProfileReminder && !hasDietInfo && !hasAllergies) {
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) {
            bool dontShow = false;
            return AlertDialog(
              title: const Text('Aggiorna il tuo profilo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Per generare ricette personalizzate, aggiorna il tuo profilo con le tue allergie e preferenze dietetiche.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: dontShow,
                        onChanged: (value) {
                          setDialogState(() {
                            dontShow = value ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text('Non mostrare più questo messaggio'),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dontShowProfileReminder = dontShow;
                    });
                    Navigator.pop(context, true);
                  },
                  child: const Text('Continua'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _dontShowProfileReminder = dontShow;
                    });
                    Navigator.pop(context, false);
                  },
                  child: const Text('Aggiorna profilo'),
                ),
              ],
            );
          },
        ),
      );

      if (shouldContinue == false) {
        // Navigate to profile screen (you'll need to implement this)
        return;
      }
    }

    // Ask for number of people
    if (!mounted) return;
    final controller = TextEditingController(text: '1');
    final numberOfPeople = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Per quante persone?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Inserisci il numero di persone per il menu:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Es. 2',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (value) {
                final num = int.tryParse(value);
                if (num != null && num > 0) {
                  Navigator.pop(context, num);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              final num = int.tryParse(controller.text);
              if (num != null && num > 0) {
                Navigator.pop(context, num);
              }
            },
            child: const Text('Genera'),
          ),
        ],
      ),
    );

    if (numberOfPeople == null || numberOfPeople <= 0) {
      return;
    }

    // Show loading dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.amber),
                const SizedBox(height: 16),
                Text('Generando menu per $numberOfPeople persone...'),
                const SizedBox(height: 8),
                Text(
                  'Incluso generazione immagini',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Build dietary constraints string
      String dietaryConstraints = '';
      if (widget.state.data.dietType != DietType.nessuna) {
        dietaryConstraints +=
            'Dieta: ${widget.state.data.dietType.displayName}. ';
      }
      if (widget.state.data.allergies.isNotEmpty) {
        dietaryConstraints +=
            'Allergie: ${widget.state.data.allergies.join(', ')}. ';
      }

      final peopleStr = numberOfPeople.toString();
      final prompt = 'Agisci come un esperto nutrizionista. Genera un menu giornaliero bilanciato (Colazione, Pranzo, Cena) per $peopleStr persone.\n' +
          '$dietaryConstraints\n' +
          'Restituisci la risposta ESCLUSIVAMENTE in formato JSON con questa struttura:\n' +
          '{\n' +
          '  "colazione": {"nome": "...", "categoria": "...", "sottocategoria": "...", "ingredienti": [{"nome": "...", "quantita": 100, "unita": "gr", "categoria": "..."}], "prompt_immagine": "..."},\n' +
          '  "pranzo": {"nome": "...", "categoria": "...", "sottocategoria": "...", "ingredienti": [{"nome": "...", "quantita": 200, "unita": "gr", "categoria": "..."}], "prompt_immagine": "..."},\n' +
          '  "cena": {"nome": "...", "categoria": "...", "sottocategoria": "...", "ingredienti": [{"nome": "...", "quantita": 150, "unita": "gr", "categoria": "..."}], "prompt_immagine": "..."}\n' +
          '}\n' +
          '\n' +
          _categorieInstructions +
          '\n' +
          'prompt_immagine: Professional food photography, high resolution, natural daylight, describe texture and colors, rustic background. Usa unità: gr, ml, pezzi.\n' +
          'NON aggiungere testo fuori dal JSON. NON usare markdown. Rispondi in italiano.';

      // Add timeout to prevent indefinite loading
      final response = await _geminiService.chiediAGemini(prompt).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Timeout nella generazione del menu');
        },
      );

      // Clean the response to extract JSON between curly braces
      final cleanedJson = _extractJson(response);

      // Parse JSON with error handling
      Map<String, dynamic> menuData;
      try {
        menuData = jsonDecode(cleanedJson);
        
        // Check for server error responses
        if (menuData.containsKey('errore')) {
          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(menuData['errore'])),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore nel parsing della risposta: $e')),
          );
        }
        return;
      }

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
      }

      // Generate and insert recipes with correct number of servings
      await _insertGeneratedMenu(menuData, numberOfPeople);

      // Show confirmation dialog to save recipes
      if (mounted) {
        final shouldSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Salvare le ricette?'),
            content: const Text(
              'Vuoi salvare le ricette generate nel ricettario con le dosi per una persona?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sì, salva'),
              ),
            ],
          ),
        );

        if (shouldSave == true) {
          // Save recipes to recipe book (always for 1 person)
          await _saveGeneratedRecipesToBook(menuData);
        }

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(shouldSave == true
                  ? 'Menu generato per $numberOfPeople persone e ricette salvate!'
                  : 'Menu generato per $numberOfPeople persone!'),
              backgroundColor: const Color(0xFF8BA888),
            ),
          );
        }
      }
    } on TimeoutException catch (e) {
      // Close loading dialog on timeout
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Timeout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog on any other error
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nella generazione del menu: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _extractJson(String response) {
    // Find the first { and last }
    final firstBrace = response.indexOf('{');
    final lastBrace = response.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return response.substring(firstBrace, lastBrace + 1);
    }

    // If no braces found, return the original response
    return response;
  }

  Future<void> _insertGeneratedMenu(
      Map<String, dynamic> menuData, int numberOfPeople) async {
    if (_tabController == null) return;
    final currentDay = _plannedDates[_tabController!.index];

    // Process each meal type
    final mealTypes = {
      'colazione': MealType.colazione,
      'pranzo': MealType.pranzo,
      'cena': MealType.cena,
    };

    // First pass: create all recipes without images
    final recipeData = <String, Map<String, dynamic>>{};

    for (final entry in mealTypes.entries) {
      final key = entry.key;
      final mealType = entry.value;

      if (menuData.containsKey(key)) {
        final mealInfo = menuData[key] as Map<String, dynamic>;
        final nome = mealInfo['nome'] as String?;
        final categoriaStr = mealInfo['categoria'] as String?;
        final sottocategoriaStr = mealInfo['sottocategoria'] as String?;
        final ingredientiList = mealInfo['ingredienti'] as List<dynamic>?;
        final promptImmagine = mealInfo['prompt_immagine'] as String?;

        if (nome != null && ingredientiList != null) {
          // Create ingredients with quantities and units
          final ingredients = ingredientiList.map((ing) {
            if (ing is Map<String, dynamic>) {
              final nomeIng = ing['nome'] as String?;
              final quantita = ing['quantita'];
              final unita = ing['unita'] as String?;
              final categoriaIng = ing['categoria'] as String?;

              // Mappa la categoria del supermercato a IngredientCategory
              IngredientCategory mappedCategory = IngredientCategory.altro;
              if (categoriaIng != null) {
                final catLower = categoriaIng.toLowerCase();
                switch (catLower) {
                  case 'ortofrutta':
                  case 'verdura':
                  case 'frutta':
                    mappedCategory = IngredientCategory.ortofrutta;
                    break;
                  case 'carne':
                    mappedCategory = IngredientCategory.carne;
                    break;
                  case 'pesce':
                    mappedCategory = IngredientCategory.pesce;
                    break;
                  case 'latticini':
                  case 'formaggio':
                  case 'latte':
                    mappedCategory = IngredientCategory.latticini;
                    break;
                  case 'panetteria':
                  case 'pane':
                    mappedCategory = IngredientCategory.panetteria;
                    break;
                  case 'surgelati':
                  case 'congelato':
                    mappedCategory = IngredientCategory.surgelati;
                    break;
                  case 'dispensa':
                  case 'pasta':
                  case 'riso':
                    mappedCategory = IngredientCategory.dispensa;
                    break;
                  case 'bevande':
                  case 'acqua':
                  case 'vino':
                    mappedCategory = IngredientCategory.bevande;
                    break;
                  default:
                    mappedCategory = IngredientCategory.altro;
                }
              }

              return Ingredient(
                name: nomeIng ?? ing.toString(),
                category: mappedCategory,
                quantity: quantita is num ? quantita.toDouble() : null,
                unit: unita,
              );
            } else {
              return Ingredient(
                name: ing.toString(),
                category: IngredientCategory.altro,
              );
            }
          }).toList();

          // Map categoria string to RecipeCategory enum
          RecipeCategory mappedCategory = RecipeCategory.altre;
          if (categoriaStr != null) {
            final catLower = categoriaStr.toLowerCase();
            if (catLower.contains('antipasto')) {
              mappedCategory = RecipeCategory.antipasti;
            } else if (catLower.contains('primo')) {
              mappedCategory = RecipeCategory.primi;
            } else if (catLower.contains('secondo')) {
              mappedCategory = RecipeCategory.secondi;
            } else if (catLower.contains('contorno')) {
              mappedCategory = RecipeCategory.contorni;
            } else if (catLower.contains('dolce')) {
              mappedCategory = RecipeCategory.dolci;
            }
          }

          // Create recipe
          final recipeId = await widget.state.upsertRecipe(
            id: 'generated_${DateTime.now().millisecondsSinceEpoch}_$key',
            title: nome,
            ingredients: ingredients,
            note: 'Generato da AI con quantità',
            category: mappedCategory,
            categoriaPrincipale: categoriaStr,
            sottocategoria: sottocategoriaStr,
          );

          // Store recipe data for parallel image generation
          recipeData[key] = {
            'recipeId': recipeId,
            'nome': nome,
            'ingredients': ingredients,
            'note': 'Generato da AI con quantità',
            'category': mappedCategory,
            'categoriaPrincipale': categoriaStr,
            'sottocategoria': sottocategoriaStr,
            'promptImmagine': promptImmagine,
            'mealType': mealType,
          };
        }
      }
    }

    // Second pass: generate all images in parallel
    final imageFutures = recipeData.entries.map((entry) async {
      final key = entry.key;
      final data = entry.value;
      final nome = data['nome'] as String;
      final promptImmagine = data['promptImmagine'] as String?;

      String? imageUrl;
      if (promptImmagine != null && promptImmagine.isNotEmpty) {
        imageUrl = await _geminiService.generaImmagineDaPrompt(promptImmagine);
      } else {
        imageUrl = await _geminiService.generaImmagineRicetta(nome);
      }

      return MapEntry(key, imageUrl);
    });

    final imageResults = await Future.wait(imageFutures);

    // Third pass: update recipes with images and add to meal entries
    for (final entry in imageResults) {
      final key = entry.key;
      final imageUrl = entry.value;
      final data = recipeData[key]!;

      if (imageUrl != null) {
        await widget.state.upsertRecipe(
          id: data['recipeId'] as String,
          title: data['nome'] as String,
          ingredients: data['ingredients'] as List<Ingredient>,
          note: data['note'] as String,
          category: data['category'] as RecipeCategory,
          imageUrl: imageUrl,
          categoriaPrincipale: data['categoriaPrincipale'] as String?,
          sottocategoria: data['sottocategoria'] as String?,
        );
      }

      // Add to meal entry with correct number of servings
      final mealItem = MealItem(
        recipeId: data['recipeId'] as String,
        numberOfServings: numberOfPeople,
      );

      await widget.state.setMealEntry(
        currentDay,
        data['mealType'] as MealType,
        MealEntry(items: [mealItem]),
      );
    }
  }

  Future<void> _saveGeneratedRecipesToBook(
      Map<String, dynamic> menuData) async {
    // Process each meal type
    final mealTypes = {
      'colazione': MealType.colazione,
      'pranzo': MealType.pranzo,
      'cena': MealType.cena,
    };

    for (final entry in mealTypes.entries) {
      final key = entry.key;

      if (menuData.containsKey(key)) {
        final mealInfo = menuData[key] as Map<String, dynamic>;
        final nome = mealInfo['nome'] as String?;
        final categoriaStr = mealInfo['categoria'] as String?;
        final sottocategoriaStr = mealInfo['sottocategoria'] as String?;
        final ingredientiList = mealInfo['ingredienti'] as List<dynamic>?;
        final promptImmagine = mealInfo['prompt_immagine'] as String?;

        if (nome != null && ingredientiList != null) {
          // Create ingredients with quantities and units
          final ingredients = ingredientiList.map((ing) {
            if (ing is Map<String, dynamic>) {
              final nomeIng = ing['nome'] as String?;
              final quantita = ing['quantita'];
              final unita = ing['unita'] as String?;
              final categoriaIng = ing['categoria'] as String?;

              // Mappa la categoria del supermercato a IngredientCategory
              IngredientCategory mappedCategory = IngredientCategory.altro;
              if (categoriaIng != null) {
                final catLower = categoriaIng.toLowerCase();
                switch (catLower) {
                  case 'ortofrutta':
                  case 'verdura':
                  case 'frutta':
                    mappedCategory = IngredientCategory.ortofrutta;
                    break;
                  case 'carne':
                    mappedCategory = IngredientCategory.carne;
                    break;
                  case 'pesce':
                    mappedCategory = IngredientCategory.pesce;
                    break;
                  case 'latticini':
                  case 'formaggio':
                  case 'latte':
                    mappedCategory = IngredientCategory.latticini;
                    break;
                  case 'panetteria':
                  case 'pane':
                    mappedCategory = IngredientCategory.panetteria;
                    break;
                  case 'surgelati':
                  case 'congelato':
                    mappedCategory = IngredientCategory.surgelati;
                    break;
                  case 'dispensa':
                  case 'pasta':
                  case 'riso':
                    mappedCategory = IngredientCategory.dispensa;
                    break;
                  case 'bevande':
                  case 'acqua':
                  case 'vino':
                    mappedCategory = IngredientCategory.bevande;
                    break;
                  default:
                    mappedCategory = IngredientCategory.altro;
                }
              }

              return Ingredient(
                name: nomeIng ?? ing.toString(),
                category: mappedCategory,
                quantity: quantita is num ? quantita.toDouble() : null,
                unit: unita,
              );
            } else {
              return Ingredient(
                name: ing.toString(),
                category: IngredientCategory.altro,
              );
            }
          }).toList();

          // Map categoria string to RecipeCategory enum
          RecipeCategory mappedCategory = RecipeCategory.altre;
          if (categoriaStr != null) {
            final catLower = categoriaStr.toLowerCase();
            if (catLower.contains('antipasto')) {
              mappedCategory = RecipeCategory.antipasti;
            } else if (catLower.contains('primo')) {
              mappedCategory = RecipeCategory.primi;
            } else if (catLower.contains('secondo')) {
              mappedCategory = RecipeCategory.secondi;
            } else if (catLower.contains('contorno')) {
              mappedCategory = RecipeCategory.contorni;
            } else if (catLower.contains('dolce')) {
              mappedCategory = RecipeCategory.dolci;
            }
          }

          // Generate image for the recipe using prompt_immagine if available
          String? imageUrl;
          if (promptImmagine != null && promptImmagine.isNotEmpty) {
            imageUrl =
                await _geminiService.generaImmagineDaPrompt(promptImmagine);
          } else {
            // Fallback to title-based image generation
            imageUrl = await _geminiService.generaImmagineRicetta(nome);
          }

          // Save recipe to book with correct category and image
          await widget.state.upsertRecipe(
            id: 'generated_${DateTime.now().millisecondsSinceEpoch}_$key',
            title: nome,
            ingredients: ingredients,
            note: 'Generato da AI con quantità',
            category: mappedCategory,
            imageUrl: imageUrl,
            categoriaPrincipale: categoriaStr,
            sottocategoria: sottocategoriaStr,
          );
        }
      }
    }
  }

  void _generateShoppingList(BuildContext context) async {
    // Estrai gli ingredienti da tutte le ricette del menu
    final recipes = {for (final r in widget.state.data.recipes) r.id: r};
    final allIngredients = <String, Ingredient>{};

    // Raccogli tutti gli ingredienti dalle ricette del menu
    for (final day in _plannedDates) {
      for (final mealType in MealType.values) {
        final entry = widget.state.mealEntry(day, mealType);
        if (entry == null || entry.isEmpty) continue;

        for (final item in entry.items) {
          final recipeId = item.recipeId;
          if (recipeId == null || recipeId.isEmpty) continue;

          final recipe = recipes[recipeId];
          if (recipe == null) continue;

          // Aggiungi gli ingredienti della ricetta moltiplicati per le persone
          for (final ingredient in recipe.ingredients) {
            final key =
                '${ingredient.name.toLowerCase().trim()}|${ingredient.category.name}';

            // Moltiplica la quantità per il numero di persone
            final multipliedQuantity = ingredient.quantity != null
                ? ingredient.quantity! * item.numberOfServings
                : null;

            final multipliedIngredient = Ingredient(
              name: ingredient.name,
              category: ingredient.category,
              quantity: multipliedQuantity,
              unit: ingredient.unit,
              note: ingredient.note,
            );

            // Se l'ingrediente esiste già, somma le quantità
            if (allIngredients.containsKey(key)) {
              final existing = allIngredients[key]!;
              if (existing.quantity != null &&
                  multipliedQuantity != null &&
                  existing.unit == multipliedIngredient.unit) {
                allIngredients[key] = Ingredient(
                  name: existing.name,
                  category: existing.category,
                  quantity: existing.quantity! + multipliedQuantity,
                  unit: existing.unit,
                  note: existing.note,
                );
              }
            } else {
              allIngredients[key] = multipliedIngredient;
            }
          }
        }
      }
    }

    if (allIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Nessuna ricetta nel menu. Aggiungi prima delle ricette al menu!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Converti in lista e ordina per categoria e nome
    final ingredientList = allIngredients.values.toList()
      ..sort((a, b) {
        final catCompare = a.category.index.compareTo(b.category.index);
        if (catCompare != 0) return catCompare;
        return a.name.compareTo(b.name);
      });

    // Mostra dialog di conferma con checkbox per selezionare gli ingredienti
    final selectedIngredients = await showDialog<List<Ingredient>>(
      context: context,
      builder: (context) => _IngredientSelectionDialog(
        ingredients: ingredientList,
      ),
    );

    if (selectedIngredients != null && selectedIngredients.isNotEmpty) {
      try {
        await widget.state.generateShoppingList(
          selectedIngredients: selectedIngredients,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Lista della spesa generata! Vai alla scheda "Spesa" per vederla.'),
              backgroundColor: Color(0xFF8BA888),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore durante la generazione: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, child) {
        // Controlla se ci sono piatti programmati nella settimana
        bool hasMeals = false;
        for (final day in _plannedDates) {
          for (final mealType in MealType.values) {
            final entry = widget.state.mealEntry(day, mealType);
            if (entry != null && !entry.isEmpty) {
              hasMeals = true;
              break;
            }
          }
          if (hasMeals) break;
        }

        // Show loading state if tabController is not initialized
        if (_tabController == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Il mio menù'),
          ),
          body: Column(
            children: [
              const SizedBox(height: 16),
              // Day selector with circular chips
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: AnimatedBuilder(
                  animation: _tabController!,
                  builder: (context, child) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ...List.generate(_plannedDates.length, (index) {
                            final isSelected = _tabController!.index == index;
                            final day = _plannedDates[index];

                            // Check if day has meals
                            bool hasMeals = false;
                            for (final mealType in MealType.values) {
                              final entry = widget.state.mealEntry(day, mealType);
                              if (entry != null && !entry.isEmpty) {
                                hasMeals = true;
                                break;
                              }
                            }

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: GestureDetector(
                                onTap: () {
                                  _tabController?.animateTo(index);
                                },
                                onLongPress: () {
                                  _deletePlannedDate(day);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? const Color(0xFF8BA888)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF8BA888)
                                          : Colors.grey[300]!,
                                      width: 2,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: const Color(0xFF8BA888)
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 8,
                                              offset: const Offset(0, 4),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    children: [
                                      // Day name
                                      Text(
                                        weekdayShortLabel(day),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Date
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[900],
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      // Status indicator
                                      if (hasMeals)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Colors.white
                                                : const Color(0xFF8BA888),
                                            shape: BoxShape.circle,
                                          ),
                                        )
                                      else
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                          // Add "+" button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: GestureDetector(
                              onTap: _addPlannedDate,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8BA888),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: const Color(0xFF8BA888),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF8BA888)
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 28,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Visual divider
              Container(
                height: 1,
                color: Colors.grey[300],
              ),
              const SizedBox(height: 8),
              // TabBarView for meal list
              Expanded(
                child: _tabController != null
                    ? TabBarView(
                        controller: _tabController,
                        children: _plannedDates
                            .map((d) => _DayMenuView(
                                  state: widget.state,
                                  day: d,
                                  onGenerateShoppingList: () =>
                                      _generateShoppingList(context),
                                  onPickImage: _pickImage,
                                  onArchiveMenu: () => _archiveMenu(context),
                                ))
                            .toList(),
                      )
                    : const Center(child: CircularProgressIndicator()),
              ),
            ],
          ),
          floatingActionButton: GestureDetector(
            onLongPress: _showGeminiMenu,
            child: FloatingActionButton(
              onPressed: _showGeminiMenu,
              backgroundColor: Colors.amber,
              child: const Icon(Icons.auto_awesome),
            ),
          ),
        );
      },
    );
  }
}

class _DayMenuView extends StatelessWidget {
  const _DayMenuView({
    required this.state,
    required this.day,
    required this.onGenerateShoppingList,
    required this.onPickImage,
    required this.onArchiveMenu,
  });
  final AppState state;
  final DateTime day;
  final VoidCallback onGenerateShoppingList;
  final Function(DateTime, MealType) onPickImage;
  final VoidCallback onArchiveMenu;

  @override
  Widget build(BuildContext context) {
    final snack = state.mealEntry(day, MealType.snack);

    return ListView(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: 80, // Extra padding for FAB
      ),
      children: [
        _MealCard(
            state: state,
            day: day,
            type: MealType.colazione,
            icon: Icons.wb_sunny_outlined,
            onPickImage: () => onPickImage(day, MealType.colazione)),
        const SizedBox(height: 16),
        _MealCard(
            state: state,
            day: day,
            type: MealType.pranzo,
            icon: Icons.restaurant_outlined,
            onPickImage: () => onPickImage(day, MealType.pranzo)),
        const SizedBox(height: 16),
        _MealCard(
            state: state,
            day: day,
            type: MealType.cena,
            icon: Icons.nightlight_outlined,
            onPickImage: () => onPickImage(day, MealType.cena)),
        const SizedBox(height: 16),
        if (snack != null && !snack.isEmpty)
          _MealCard(
              state: state,
              day: day,
              type: MealType.snack,
              icon: Icons.cookie_outlined,
              onPickImage: () => onPickImage(day, MealType.snack))
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
            child: OutlinedButton.icon(
              onPressed: () => _openMealPicker(context,
                  state: state, day: day, type: MealType.snack),
              icon: const Icon(Icons.add, color: Colors.black87),
              label: const Text(
                'Aggiungi snack (opzionale)',
                style: TextStyle(color: Colors.black87),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black26),
              ),
            ),
          ),
        const SizedBox(height: 24),
        // Shopping list button
        Card(
          elevation: 2,
          child: InkWell(
            onTap: onGenerateShoppingList,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    color: Color(0xFF8BA888),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Genera Lista Spesa',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Archive menu button
        Card(
          elevation: 2,
          child: InkWell(
            onTap: onArchiveMenu,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(
                    Icons.archive_outlined,
                    color: Color(0xFF8BA888),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Archivia Menu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.state,
    required this.day,
    required this.type,
    required this.icon,
    required this.onPickImage,
  });

  final AppState state;
  final DateTime day;
  final MealType type;
  final IconData icon;
  final VoidCallback onPickImage;

  String _getMealPlaceholder(MealType type) {
    switch (type) {
      case MealType.colazione:
        return 'Cosa mangiamo a colazione?';
      case MealType.pranzo:
        return 'Cosa mangiamo a pranzo?';
      case MealType.cena:
        return 'Cosa mangiamo a cena?';
      case MealType.snack:
        return 'Nessuna selezione';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entry = state.mealEntry(day, type);
    final hasValue = entry != null && !entry.isEmpty;

    // Ottieni tutti i titoli dei piatti
    final recipes = {for (final r in state.data.recipes) r.id: r};
    final titles = hasValue
        ? entry.displayTitles(recipes: recipes)
        : [_getMealPlaceholder(type)];

    // Usa il primo titolo come titolo principale
    final title = titles.isNotEmpty ? titles.first : _getMealPlaceholder(type);

    // Ottieni la prima ricetta per l'immagine
    Recipe? firstRecipe;
    if (hasValue && entry.items.isNotEmpty) {
      final firstItemId = entry.items.first.recipeId;
      if (firstItemId != null) {
        firstRecipe = recipes[firstItemId];
      }
    }

    final surfaceColor = getMealSurfaceColor(context, type);
    final accentColor = getMealColor(context, type);
    final onAccentColor = getMealOnColor(context, type);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: hasValue
              ? accentColor.withValues(alpha: 0.5)
              : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          if (hasValue) {
            HapticFeedback.lightImpact();
            _openMealPicker(context, state: state, day: day, type: type);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mostra immagine se disponibile, altrimenti placeholder con pulsante upload
              if (firstRecipe?.imageUrl != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      firstRecipe!.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            icon,
                            size: 48,
                            color: onAccentColor.withValues(alpha: 0.5),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else if (hasValue) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Container(
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: 48,
                            color: onAccentColor.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: onPickImage,
                            icon: const Icon(Icons.add_photo_alternate),
                            label: const Text('Carica foto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: accentColor,
                              foregroundColor: onAccentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Header con tipo di pasto e pulsante edit
              Row(
                children: [
                  Expanded(
                    child: Text(
                      mealTypeLabel(type),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: onAccentColor.withValues(alpha: 0.8),
                          ),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _openMealPicker(context,
                          state: state, day: day, type: type);
                    },
                    icon: Icon(hasValue ? Icons.edit_outlined : Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: accentColor.withValues(alpha: 0.3),
                      foregroundColor: onAccentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: hasValue
                          ? Colors.black87
                          : Theme.of(context).colorScheme.outline,
                      fontWeight: hasValue ? FontWeight.w500 : null,
                    ),
              ),
              // Mostra tutti i piatti se ce ne sono più di uno
              if (hasValue && titles.length > 1) ...[
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: titles
                      .skip(1)
                      .map(
                        (additionalTitle) => Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            '• $additionalTitle',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.black54,
                                      fontSize: 12,
                                    ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum _MealPickAction { ricettario, nuovaRicetta, testo, gemini }

enum _MealAddMode { sostituisci, aggiungi }

int _lastNumberOfPeople = 1;

Future<void> _openMealPicker(
  BuildContext context, {
  required AppState state,
  required DateTime day,
  required MealType type,
}) async {
  final action = await showModalBottomSheet<_MealPickAction>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Ricettario'),
              subtitle: const Text('Scegli una ricetta esistente'),
              onTap: () => Navigator.pop(context, _MealPickAction.ricettario),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: const Text('Genera ricetta con AI'),
              subtitle: const Text(
                  'Crea una ricetta dagli ingredienti e aggiungila al pasto'),
              onTap: () => Navigator.pop(context, _MealPickAction.gemini),
            ),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Aggiungi nuova ricetta'),
              subtitle: const Text('Crea una ricetta e aggiungila al pasto'),
              onTap: () => Navigator.pop(context, _MealPickAction.nuovaRicetta),
            ),
            if (type == MealType.snack)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Scrivi manualmente'),
                subtitle: const Text('Inserisci un testo (es. Yogurt)'),
                onTap: () => Navigator.pop(context, _MealPickAction.testo),
              ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );

  if (action == null) return;

  try {
    String? recipeId;
    String? customTitle;
    final ctx = context;

    switch (action) {
      case _MealPickAction.ricettario:
        if (state.data.recipes.isEmpty) {
          if (ctx.mounted) {
            ScaffoldMessenger.of(ctx).showSnackBar(
              const SnackBar(
                content: Text('Il ricettario è vuoto. Crea prima una ricetta.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        recipeId = await Navigator.push<String?>(
          ctx,
          MaterialPageRoute(
            builder: (_) => RecipesScreen(state: state, pickMode: true),
          ),
        );
        if (!ctx.mounted) return;
        break;
      case _MealPickAction.gemini:
        await showGeminiRecipeDialog(ctx, state, day, type);
        if (!ctx.mounted) return;
        return;
      case _MealPickAction.nuovaRicetta:
        recipeId = await Navigator.push<String?>(
          ctx,
          MaterialPageRoute(
            builder: (_) => RecipeEditorScreen(state: state),
          ),
        );
        if (!ctx.mounted) return;
        break;
      case _MealPickAction.testo:
        customTitle = await _askSnackText(ctx);
        if (!ctx.mounted) return;
        break;
    }

    if ((recipeId == null || recipeId.isEmpty) &&
        (customTitle == null || customTitle.trim().isEmpty)) {
      return;
    }

    final currentEntry = state.mealEntry(day, type);
    final hasExisting = currentEntry != null && !currentEntry.isEmpty;

    _MealAddMode mode = _MealAddMode.sostituisci;
    if (hasExisting) {
      final pickedMode = await showDialog<_MealAddMode?>(
        context: ctx,
        builder: (context) {
          return AlertDialog(
            title: Text('${mealTypeLabel(type)} già compilato'),
            content: const Text('Vuoi sostituire o aggiungere come portata?'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _MealAddMode.sostituisci),
                child: const Text('Sostituisci'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, _MealAddMode.aggiungi),
                child: const Text('Aggiungi'),
              ),
            ],
          );
        },
      );
      if (!ctx.mounted) return;
      if (pickedMode == null) return;
      mode = pickedMode;
    }

    final servings = await _askNumberOfPeople(
      ctx,
      initialValue: _lastNumberOfPeople,
    );
    if (!ctx.mounted) return;
    if (servings == null) return;
    _lastNumberOfPeople = servings;

    final newItem = MealItem(
      recipeId: recipeId,
      customTitle: customTitle?.trim(),
      numberOfServings: servings,
    );

    final items = mode == _MealAddMode.aggiungi && hasExisting
        ? [...currentEntry.items, newItem]
        : [newItem];

    await state.setMealEntry(
      day,
      type,
      MealEntry(
        items: items,
      ),
    );
    HapticFeedback.lightImpact();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ricetta aggiunta a ${mealTypeLabel(type)}'),
          backgroundColor: const Color(0xFF8BA888),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<String?> _askSnackText(BuildContext context) async {
  final ctrl = TextEditingController();
  final result = await showDialog<String?>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Nome snack'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Testo',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final v = ctrl.text.trim();
              if (v.isEmpty) return;
              Navigator.pop(context, v);
            },
            child: const Text('Conferma'),
          ),
        ],
      );
    },
  );
  ctrl.dispose();
  return result;
}

Future<int?> _askNumberOfPeople(
  BuildContext context, {
  required int initialValue,
}) async {
  final ctrl = TextEditingController(text: initialValue.toString());
  final result = await showDialog<int?>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Numero di persone'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Persone',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(ctrl.text.trim());
              if (value == null || value <= 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('Conferma'),
          ),
        ],
      );
    },
  );
  ctrl.dispose();
  return result;
}

// Dialog per selezionare gli ingredienti da includere nella lista della spesa
class _IngredientSelectionDialog extends StatefulWidget {
  const _IngredientSelectionDialog({
    required this.ingredients,
  });

  final List<Ingredient> ingredients;

  @override
  State<_IngredientSelectionDialog> createState() =>
      _IngredientSelectionDialogState();
}

class _IngredientSelectionDialogState
    extends State<_IngredientSelectionDialog> {
  late Set<Ingredient> _selectedIngredients;

  @override
  void initState() {
    super.initState();
    _selectedIngredients = widget.ingredients.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Seleziona ingredienti'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Seleziona gli ingredienti da includere nella lista della spesa (${_selectedIngredients.length}/${widget.ingredients.length}):'),
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: widget.ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = widget.ingredients[index];
                  final isSelected = _selectedIngredients.contains(ingredient);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIngredients.add(ingredient);
                        } else {
                          _selectedIngredients.remove(ingredient);
                        }
                      });
                    },
                    title: Text(ingredient.name),
                    subtitle: ingredient.quantity != null
                        ? Text('${ingredient.quantity}${ingredient.unit ?? ''}')
                        : null,
                    secondary: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getCategoryColor(ingredient.category),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              _selectedIngredients = widget.ingredients.toSet();
            });
          },
          child: const Text('Seleziona tutti'),
        ),
        FilledButton(
          onPressed: _selectedIngredients.isEmpty
              ? null
              : () => Navigator.pop(context, _selectedIngredients.toList()),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF8BA888),
          ),
          child: Text('Genera (${_selectedIngredients.length})'),
        ),
      ],
    );
  }
}

class _DateMealPlanningScreen extends StatefulWidget {
  const _DateMealPlanningScreen({
    required this.state,
    required this.date,
  });

  final AppState state;
  final DateTime date;

  @override
  State<_DateMealPlanningScreen> createState() => _DateMealPlanningScreenState();
}

class _DateMealPlanningScreenState extends State<_DateMealPlanningScreen> {
  List<Map<String, dynamic>> _meals = [];

  @override
  void initState() {
    super.initState();
    _loadMeals();
  }

  Future<void> _loadMeals() async {
    final dateString = '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';
    final db = await DatabaseHelper.instance.database;
    final meals = await db.query(
      'menu_pianificato',
      where: 'data = ?',
      whereArgs: [dateString],
    );
    
    if (mounted) {
      setState(() {
        _meals = meals;
      });
    }
  }

  Future<void> _saveMeal(MealType mealType, String recipeId) async {
    final dateString = '${widget.date.year}-${widget.date.month.toString().padLeft(2, '0')}-${widget.date.day.toString().padLeft(2, '0')}';
    final pasto = mealType.toString().split('.').last;
    
    final db = await DatabaseHelper.instance.database;
    await db.insert(
      'menu_pianificato',
      {
        'data': dateString,
        'ricetta_id': recipeId,
        'pasto': pasto,
      },
    );
    
    await _loadMeals();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu del ${widget.date.day}/${widget.date.month}/${widget.date.year}'),
      ),
      body: _DayMenuView(
        state: widget.state,
        day: widget.date,
        onGenerateShoppingList: () {},
        onPickImage: (day, type) {},
        onArchiveMenu: () {},
      ),
    );
  }
}
