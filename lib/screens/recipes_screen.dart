import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../app_state.dart';
import '../models.dart';
import '../services/gemini_service.dart';
import '../services/storage_service.dart';
import '../utils/category_icons.dart';
import '../utils/dates.dart';
import '../database_helper.dart';
import '../utils/recipe_db_utils.dart';
import '../widgets/recipe_action_sheet.dart';
import 'recipe_editor.dart';
import 'recipe_detail_screen.dart';

String formatCount(int count) {
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return count.toString();
}

IconData getCategoryIcon(RecipeCategory category) {
  return CategoryIcons.forRecipeCategory(category);
}

RecipeCategory getRecipeCategory(Recipe recipe) {
  // Se la ricetta ha una categoria impostata, usala
  if (recipe.category != null) {
    return recipe.category!;
  }

  // Usa la categoria salvata nel database (es. Antipasti, Primi...)
  final fromDb = RecipeDbUtils.categoryFromName(recipe.categoriaPrincipale);
  if (fromDb != null) {
    return fromDb;
  }

  // Fallback su prefisso id (es. antipasti_1, primi_3)
  final id = recipe.id.toLowerCase();
  if (id.startsWith('antipasti_')) return RecipeCategory.antipasti;
  if (id.startsWith('primi_')) return RecipeCategory.primi;
  if (id.startsWith('secondi_')) return RecipeCategory.secondi;
  if (id.startsWith('dolci_')) return RecipeCategory.dolci;
  if (id.startsWith('contorni_')) return RecipeCategory.contorni;

  // Altrimenti, usa la logica basata sul titolo per le ricette predefinite
  final title = recipe.title.toLowerCase();

  if (id.contains('bruschetta') ||
      title.contains('bruschetta') ||
      id.startsWith('bruschetta_') ||
      title.contains('antipasto')) {
    return RecipeCategory.antipasti;
  }
  if (id.contains('pasta_') ||
      title.contains('pasta') ||
      title.contains('spaghetti') ||
      title.contains('risotto') ||
      title.contains('lasagne') ||
      title.contains('trenette')) {
    return RecipeCategory.primi;
  }
  if (id.contains('carne_') ||
      title.contains('pollo') ||
      title.contains('bistecca') ||
      title.contains('manzo') ||
      title.contains('maiale') ||
      title.contains('vitello') ||
      title.contains('coniglio') ||
      title.contains('salsiccia') ||
      title.contains('salmone') ||
      title.contains('orata') ||
      title.contains('spigola') ||
      title.contains('tonno') ||
      title.contains('baccalà') ||
      title.contains('polpo') ||
      title.contains('vongole')) {
    return RecipeCategory.secondi;
  }
  if (id.contains('contorno_') ||
      title.contains('insalata') ||
      title.contains('patate') ||
      title.contains('verdure') ||
      title.contains('carciofi') ||
      title.contains('melanzane') ||
      title.contains('zucchine') ||
      title.contains('peperoni')) {
    return RecipeCategory.contorni;
  }
  if (id.contains('dolce_') ||
      title.contains('tiramisù') ||
      title.contains('panna') ||
      title.contains('biscotto') ||
      title.contains('torta') ||
      title.contains('crostata') ||
      title.contains('cheesecake') ||
      title.contains('muffin')) {
    return RecipeCategory.dolci;
  }

  return RecipeCategory.altre;
}

enum SecondiSubCategory { carne, pesce }

SecondiSubCategory getSecondiSubCategory(Recipe recipe) {
  final title = recipe.title.toLowerCase();
  final id = recipe.id.toLowerCase();

  if (id.contains('carne_') ||
      title.contains('pollo') ||
      title.contains('bistecca') ||
      title.contains('manzo') ||
      title.contains('maiale') ||
      title.contains('vitello') ||
      title.contains('coniglio') ||
      title.contains('salsiccia')) {
    return SecondiSubCategory.carne;
  }
  if (id.contains('pesce_') ||
      title.contains('salmone') ||
      title.contains('orata') ||
      title.contains('spigola') ||
      title.contains('tonno') ||
      title.contains('baccalà') ||
      title.contains('polpo') ||
      title.contains('vongole')) {
    return SecondiSubCategory.pesce;
  }

  // Default a carne se non può essere determinato
  return SecondiSubCategory.carne;
}

class RecipesScreen extends StatefulWidget {
  const RecipesScreen({super.key, required this.state, this.pickMode = false});
  final AppState state;
  final bool pickMode;

  @override
  State<RecipesScreen> createState() => _RecipesScreenState();
}

class _RecipesScreenState extends State<RecipesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pickModeSearchController =
      TextEditingController();
  List<Recipe> _filteredRecipes = [];
  List<Recipe> _pickModeFilteredRecipes = [];
  List<Map<String, dynamic>> _dbRecipes = [];
  Map<String, List<Map<String, dynamic>>> _dbRecipesByCategory = {};
  bool _isLoadingDbRecipes = true;
  
  // Section visibility toggles
  bool _showFavoritesSection = true;
  bool _showTopOfWeekSection = true;
  bool _showGroupFavoritesSection = true;

  @override
  void initState() {
    super.initState();
    _filteredRecipes = [...widget.state.data.recipes];
    // Initialize pick mode filtered recipes
    final byId = <String, Recipe>{};
    for (final r in widget.state.data.recipes) {
      byId[r.id] = r;
    }
    _pickModeFilteredRecipes = byId.values.toList();

    // Load database recipes
    _loadDbRecipes();
    // Load section visibility preferences
    _loadSectionVisibility();
  }

  Future<void> _loadSectionVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showFavoritesSection = prefs.getBool('showFavoritesSection') ?? true;
      _showTopOfWeekSection = prefs.getBool('showTopOfWeekSection') ?? true;
      _showGroupFavoritesSection = prefs.getBool('showGroupFavoritesSection') ?? true;
    });
  }

  Future<void> _saveSectionVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showFavoritesSection', _showFavoritesSection);
    await prefs.setBool('showTopOfWeekSection', _showTopOfWeekSection);
    await prefs.setBool('showGroupFavoritesSection', _showGroupFavoritesSection);
  }

  Future<void> _loadDbRecipes() async {
    try {
      await DatabaseHelper.insertItalianRecipes();
      final db = await DatabaseHelper().database;
      final List<Map<String, dynamic>> ricette = await db.query('ricette');

      setState(() {
        _dbRecipes = ricette;
        _dbRecipesByCategory = {};
        for (final ricetta in ricette) {
          final categoria = RecipeDbUtils.getCategoryName(ricetta);
          if (categoria.isEmpty) continue;
          _dbRecipesByCategory.putIfAbsent(categoria, () => []).add(ricetta);
        }
        _isLoadingDbRecipes = false;
      });

      print("Caricate ${ricette.length} ricette dal database");
    } catch (e) {
      print("Errore durante il caricamento delle ricette dal database: $e");
      setState(() {
        _isLoadingDbRecipes = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pickModeSearchController.dispose();
    super.dispose();
  }
  
  /// Determina la dimensione del font per il titolo della ricetta in base alla lunghezza
  double _getRecipeTitleFontSize(String title) {
    if (title.length > 30) {
      return 9; // Font più piccolo per titoli molto lunghi
    } else if (title.length > 20) {
      return 10; // Font leggermente più piccolo per titoli lunghi
    } else {
      return 11; // Font normale per titoli brevi
    }
  }

  Future<void> _loadDatabaseRecipes(BuildContext context) async {
    try {
      // Insert Italian recipes into database
      print("DEBUG - Inserimento ricette italiane nel database...");
      await DatabaseHelper.insertItalianRecipes();
      print("DEBUG - Ricette italiane inserite");
      
      // Load recipes from database
      print("DEBUG - Caricamento ricette dal database...");
      final dbRecipes = await DatabaseHelper.getCleanRecipes();
      print("DEBUG - Caricate ${dbRecipes.length} ricette dal database");
      
      // Convert database recipes to Recipe objects and add to state
      int addedCount = 0;
      for (final dbRecipe in dbRecipes) {
        final recipe = RecipeDbUtils.recipeFromDbMap(dbRecipe);
        if (recipe.id.isEmpty || recipe.title.isEmpty) continue;

        // Add recipe only if it doesn't already exist
        if (!widget.state.data.recipes.any((r) => r.id == recipe.id)) {
          await widget.state.upsertRecipe(
            id: recipe.id,
            title: recipe.title,
            ingredients: recipe.ingredients,
            note: recipe.note,
            category: recipe.category,
            imageUrl: recipe.imageUrl,
            categoriaPrincipale: recipe.categoriaPrincipale,
            sottocategoria: recipe.sottocategoria,
          );
          addedCount++;
        }
      }
      
      print("DEBUG - Aggiunte $addedCount nuove ricette al ricettario");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Aggiunte $addedCount ricette dal database'),
            backgroundColor: const Color(0xFF8BA888),
          ),
        );
      }
    } catch (e) {
      print("DEBUG - Errore caricamento ricette: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento ricette: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _runFilter(String enteredKeyword) {
    List<Recipe> results = [];
    if (enteredKeyword.isEmpty) {
      results = [...widget.state.data.recipes];
    } else {
      results = widget.state.data.recipes
          .where((r) =>
              r.title.toLowerCase().contains(enteredKeyword.toLowerCase()))
          .toList();
    }
    setState(() {
      _filteredRecipes = results;
    });
  }

  void _runPickModeFilter(String enteredKeyword) {
    final allRecipes = widget.state.data.recipes;

    List<Recipe> results = [];
    if (enteredKeyword.isEmpty) {
      results = allRecipes;
    } else {
      final keyword = enteredKeyword.toLowerCase();
      results = allRecipes.where((r) {
        // Search by title
        if (r.title.toLowerCase().contains(keyword)) {
          return true;
        }
        // Search by category
        if (r.category != null &&
            r.category!.displayName.toLowerCase().contains(keyword)) {
          return true;
        }
        return false;
      }).toList();
    }
    setState(() {
      _pickModeFilteredRecipes = results;
    });
  }

  @override
  Widget build(BuildContext context) {
    final recipes = widget.pickMode
        ? [...widget.state.data.recipes]
        : [...widget.state.data.recipes];

    // Se in pickMode, usa il vecchio layout semplice
    if (widget.pickMode) {
      return _buildPickModeLayout(recipes);
    }

    // Layout normale con la nuova struttura a due blocchi
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Ricettario'),
        actions: [
          IconButton(
            onPressed: () => _showGeminiRecipeDialog(context),
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Genera ricetta con AI',
          ),
          IconButton(
            onPressed: () => _loadDatabaseRecipes(context),
            icon: const Icon(Icons.restaurant_menu),
            tooltip: 'Aggiungi ricette dal database',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => _runFilter(value),
              decoration: InputDecoration(
                labelText: 'Cerca ricetta...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          // Content
          Expanded(
            child: _searchController.text.isEmpty
                ? (recipes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.restaurant_menu,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Nessuna ricetta. Premi + per aggiungerne una.',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // BLOCCO SUPERIORE: Tre liste orizzontali
                            _buildFavoritesSection(),
                            _buildTopOfWeekSection(),
                            _buildAllTimeClassicsSection(),

                            const SizedBox(height: 24),

                            // BLOCCO INFERIORE: Griglia icone categorie
                            _buildCategoriesGrid(),

                            const SizedBox(height: 24),

                            // RICETTE DAL DATABASE DIVISE PER CATEGORIA
                            _buildDbRecipesSection(),
                          ],
                        ),
                      ))
                : _buildFilteredResults(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => RecipeEditorScreen(state: widget.state)),
          );
        },
        child: const Icon(Icons.add),
      ),
    ),
    );
  }

  Widget _buildFilteredResults() {
    if (_filteredRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nessuna ricetta trovata.',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16.0,
        crossAxisSpacing: 16.0,
        childAspectRatio: 0.75,
      ),
      itemCount: _filteredRecipes.length,
      itemBuilder: (context, index) {
        final recipe = _filteredRecipes[index];
        return _RecipeGridCard(
          recipe: recipe,
          state: widget.state,
          pickMode: widget.pickMode,
          onPick: null,
          onAddToMenu: null,
        );
      },
    );
  }

  Widget _buildFavoritesSection() {
    final favoriteRecipes = widget.state.getFavoriteRecipes();
    if (favoriteRecipes.isEmpty) return const SizedBox.shrink();

    return _SectionHeader(
      title: 'I Tuoi Preferiti',
      isVisible: _showFavoritesSection,
      onToggle: (value) {
        setState(() {
          _showFavoritesSection = value;
        });
        _saveSectionVisibility();
      },
      children: [
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: favoriteRecipes.length,
            itemBuilder: (context, index) {
              final recipe = favoriteRecipes[index];
              return _CompactRecipeCard(
                recipe: recipe,
                state: widget.state,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipe: recipe,
                        state: widget.state,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTopOfWeekSection() {
    // Mostra solo le ricette preferite della settimana corrente
    final now = DateTime.now();
    final weekStart = weekStartMonday(now);
    final weekEnd = weekStart.add(const Duration(days: 7));
    
    final favoriteRecipes = widget.state.getFavoriteRecipes();
    final thisWeekFavorites = favoriteRecipes.where((recipe) {
      // Try to extract timestamp from ID if it contains one
      final timestampMatch = RegExp(r'(\d{13})').firstMatch(recipe.id);
      if (timestampMatch != null) {
        final timestamp = int.tryParse(timestampMatch.group(1) ?? '');
        if (timestamp != null) {
          final recipeDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
          return recipeDate.isAfter(weekStart) && recipeDate.isBefore(weekEnd);
        }
      }
      // If no timestamp in ID, consider it as this week's recipe
      return true;
    }).toList();
    
    final topRecipes = thisWeekFavorites.take(5).toList();
    if (topRecipes.isEmpty) return const SizedBox.shrink();

    return _SectionHeader(
      title: 'Top della Settimana',
      isVisible: _showTopOfWeekSection,
      onToggle: (value) {
        setState(() {
          _showTopOfWeekSection = value;
        });
        _saveSectionVisibility();
      },
      children: [
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: topRecipes.length,
            itemBuilder: (context, index) {
              final recipe = topRecipes[index];
              return _CompactRecipeCard(
                recipe: recipe,
                state: widget.state,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipe: recipe,
                        state: widget.state,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllTimeClassicsSection() {
    // Mostra le ricette con più cuori/likes (Preferiti del Gruppo)
    final allRecipes = [...widget.state.data.recipes];
    final topVotedRecipes = [...allRecipes]
      ..sort((a, b) => b.likeCount.compareTo(a.likeCount));
    // Filter to show only recipes with at least 1 like
    final likedRecipes = topVotedRecipes.where((r) => r.likeCount > 0).toList();
    final topRecipes = likedRecipes.take(5).toList();
    if (topRecipes.isEmpty) return const SizedBox.shrink();

    return _SectionHeader(
      title: 'Preferiti del Gruppo',
      isVisible: _showGroupFavoritesSection,
      onToggle: (value) {
        setState(() {
          _showGroupFavoritesSection = value;
        });
        _saveSectionVisibility();
      },
      children: [
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: topRecipes.length,
            itemBuilder: (context, index) {
              final recipe = topRecipes[index];
              return _CompactRecipeCard(
                recipe: recipe,
                state: widget.state,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RecipeDetailScreen(
                        recipe: recipe,
                        state: widget.state,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoriesGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'Esplora per Categoria',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: CategoriaRicetta.categorie.map((categoria) {
              return _CategoryIconButton(
                categoria: categoria,
                onSubcategorySelected: (sottocategoria) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _SubcategoryRecipesScreen(
                        state: widget.state,
                        categoriaPrincipale: categoria.nome,
                        sottocategoria: sottocategoria,
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildPickModeLayout(List<Recipe> recipes) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scegli ricetta'),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _pickModeSearchController,
              onChanged: (value) => _runPickModeFilter(value),
              decoration: InputDecoration(
                labelText: 'Cerca ricetta o categoria (es. antipasti)...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          // Recipe Grid
          Expanded(
            child: _pickModeFilteredRecipes.isEmpty
                ? const Center(child: Text('Nessuna ricetta trovata.'))
                : GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16.0,
                      crossAxisSpacing: 16.0,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _pickModeFilteredRecipes.length,
                    itemBuilder: (context, index) {
                      final recipe = _pickModeFilteredRecipes[index];
                      return _RecipeGridCard(
                        recipe: recipe,
                        state: widget.state,
                        pickMode: widget.pickMode,
                        onPick: (recipe) async {
                          final alreadyInBook = widget.state.data.recipes
                              .any((r) => r.id == recipe.id);
                          if (!alreadyInBook) {
                            await widget.state.upsertRecipe(
                              id: recipe.id,
                              title: recipe.title,
                              ingredients: recipe.ingredients,
                              note: recipe.note,
                              category:
                                  recipe.category ?? getRecipeCategory(recipe),
                            );
                          }
                          if (context.mounted) {
                            Navigator.pop(context, recipe.id);
                          }
                        },
                        onAddToMenu: null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _showGeminiRecipeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _GeminiRecipeDialog(state: widget.state),
    );
  }

  Widget _buildDbRecipesSection() {
    if (_isLoadingDbRecipes) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_dbRecipes.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Center(
          child: Text('Nessuna ricetta trovata nel database.'),
        ),
      );
    }

    final categories = ['Antipasti', 'Primi', 'Secondi', 'Dolci'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: categories.map((category) {
        final recipes = _dbRecipesByCategory[category] ?? [];
        if (recipes.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                category,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8BA888),
                ),
              ),
            ),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  final recipe = recipes[index];
                  final title = RecipeDbUtils.getTitle(recipe);
                  final imageUrl = RecipeDbUtils.getImageUrl(recipe);
                  return Container(
                    width: 160,
                    margin: const EdgeInsets.only(right: 12),
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RecipeDetailScreen(
                                ricetta: recipe,
                                state: widget.state,
                              ),
                            ),
                          );
                        },
                        onLongPress: () {
                          final recipeObj = widget.state.recipeById(
                                recipe['id']?.toString() ?? '',
                              ) ??
                              RecipeDbUtils.recipeFromDbMap(recipe);
                          showRecipeActionSheet(
                            context,
                            widget.state,
                            recipeObj,
                          );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  imageUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: imageUrl,
                                          width: double.infinity,
                                          height: double.infinity,
                                          fit: BoxFit.cover,
                                          errorWidget: (context, url, error) {
                                            return Container(
                                              color: Colors.grey[300],
                                              child: const Icon(
                                                Icons.restaurant_menu,
                                                size: 48,
                                                color: Colors.grey,
                                              ),
                                            );
                                          },
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Icon(
                                            Icons.restaurant_menu,
                                            size: 48,
                                            color: Colors.grey,
                                          ),
                                        ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                title.isNotEmpty ? title : 'Ricetta',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.isVisible,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final bool isVisible;
  final ValueChanged<bool> onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Switch(
                value: isVisible,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
        if (isVisible) ...children,
      ],
    );
  }
}

class _CategoryIconButton extends StatelessWidget {
  const _CategoryIconButton({
    required this.categoria,
    required this.onSubcategorySelected,
  });

  final CategoriaRicetta categoria;
  final Function(String) onSubcategorySelected;

  IconData _getCategoryIcon(String nome) =>
      CategoryIcons.forName(nome);

  Color _getCategoryColor(String nome) => CategoryIcons.colorForName(nome);

  @override
  Widget build(BuildContext context) {
    final color = _getCategoryColor(categoria.nome);
    return PopupMenuButton<String>(
      icon: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getCategoryIcon(categoria.nome),
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              categoria.nome,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
      onSelected: onSubcategorySelected,
      itemBuilder: (context) {
        return categoria.sottocategorie.map((sottocategoria) {
          return PopupMenuItem<String>(
            value: sottocategoria,
            child: Text(sottocategoria),
          );
        }).toList();
      },
    );
  }
}

class _RecipeGridCard extends StatefulWidget {
  const _RecipeGridCard({
    required this.recipe,
    required this.state,
    required this.pickMode,
    required this.onPick,
    required this.onAddToMenu,
  });

  final Recipe recipe;
  final AppState state;
  final bool pickMode;
  final Future<void> Function(Recipe)? onPick;
  final VoidCallback? onAddToMenu;

  @override
  State<_RecipeGridCard> createState() => _RecipeGridCardState();
}

class _RecipeGridCardState extends State<_RecipeGridCard>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late AnimationController _tapAnimationController;
  late Animation<double> _tapScaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _tapAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _tapScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _tapAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _tapAnimationController.dispose();
    super.dispose();
  }

  bool get _isFavorite => widget.state.isFavorite(widget.recipe.id);

  void _toggleFavorite() {
    final wasFavorite = widget.state.isFavorite(widget.recipe.id);
    widget.state.toggleFavorite(widget.recipe.id);

    // Aggiorna il likeCount
    if (!wasFavorite) {
      widget.state.incrementLikeCount(widget.recipe.id);
    } else {
      widget.state.decrementLikeCount(widget.recipe.id);
    }

    // Force UI update
    setState(() {});

    _animationController.forward().then((_) {
      _animationController.reverse();
    });
  }

  void _showRecipeMenu() {
    showRecipeActionSheet(context, widget.state, widget.recipe);
  }

  Color _getDifficultyColor(String difficolta) {
    switch (difficolta.toLowerCase()) {
      case 'facile':
        return Colors.green;
      case 'media':
        return Colors.orange;
      case 'difficile':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _tapScaleAnimation,
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
        ),
        elevation: _isPressed ? 8.0 : 2.0,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(15.0),
            onTapDown: (_) {
              _tapAnimationController.forward();
            },
            onTapUp: (_) {
              _tapAnimationController.reverse();
            },
            onTapCancel: () {
              _tapAnimationController.reverse();
            },
            onTap: widget.pickMode
                ? () async => await widget.onPick?.call(widget.recipe)
                : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RecipeDetailScreen(
                          recipe: widget.recipe,
                          state: widget.state,
                        ),
                      ),
                    );
                  },
            onLongPress: () {
              HapticFeedback.mediumImpact();
              setState(() {
                _isPressed = true;
              });
              Future.delayed(const Duration(milliseconds: 100), () {
                setState(() {
                  _isPressed = false;
                });
              });
              _showRecipeMenu();
            },
            child: Container(
              decoration: BoxDecoration(
                color: _isPressed ? Colors.grey[200] : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Immagine placeholder con cuore preferito
                  Stack(
                    children: [
                      Hero(
                        tag: 'recipe_image_${widget.recipe.id}',
                        child: Container(
                          height: 110.0,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey[300]!,
                                Colors.grey[400]!,
                              ],
                            ),
                          ),
                          child: widget.recipe.imageUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: widget.recipe.imageUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  maxWidthDiskCache: 400,
                                  maxHeightDiskCache: 400,
                                  memCacheWidth: 400,
                                  memCacheHeight: 400,
                                  placeholder: (context, url) => Icon(
                                    Icons.restaurant,
                                    size: 48,
                                    color: Colors.grey[600],
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.restaurant,
                                    size: 48,
                                    color: Colors.grey[600],
                                  ),
                                )
                              : Icon(
                                  Icons.restaurant,
                                  size: 48,
                                  color: Colors.grey[600],
                                ),
                        ),
                      ),
                      // Cuore preferito nell'angolo in alto a destra
                      Positioned(
                        top: 8,
                        right: 8,
                        child: ScaleTransition(
                          scale: _scaleAnimation,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: Icon(
                                _isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: _isFavorite ? Colors.red : Colors.grey,
                              ),
                              onPressed: _toggleFavorite,
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Titolo
                        Text(
                          widget.recipe.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Calorie
                        if (widget.recipe.calorie != null)
                          Row(
                            children: [
                              Icon(
                                Icons.local_fire_department,
                                size: 12,
                                color: Colors.orange[700],
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.recipe.calorie} kcal',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 2),
                        // Tempo e difficoltà
                        if (widget.recipe.tempoPreparazione != null || widget.recipe.difficolta != null)
                          Row(
                            children: [
                              if (widget.recipe.tempoPreparazione != null) ...[
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.recipe.tempoPreparazione} min',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(width: 4),
                              ],
                              if (widget.recipe.difficolta != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _getDifficultyColor(widget.recipe.difficolta!),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    widget.recipe.difficolta!,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 2),
                        // Info ingredienti
                        Row(
                          children: [
                            Icon(
                              Icons.list,
                              size: 12,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.recipe.ingredients.length} ingredienti',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Bottone Vedi Ricetta
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: widget.pickMode
                                ? () async =>
                                    await widget.onPick?.call(widget.recipe)
                                : () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => RecipeEditorScreen(
                                            state: widget.state,
                                            recipe: widget.recipe),
                                      ),
                                    );
                                  },
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Vedi Ricetta',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GeminiRecipeDialog extends StatefulWidget {
  const _GeminiRecipeDialog({
    required this.state,
    this.targetDay,
    this.targetMealType,
  });
  final AppState state;
  final DateTime? targetDay;
  final MealType? targetMealType;

  @override
  State<_GeminiRecipeDialog> createState() => _GeminiRecipeDialogState();
}

class _GeminiRecipeDialogState extends State<_GeminiRecipeDialog> {
  final _ingredientsController = TextEditingController();
  final _urlController = TextEditingController();
  bool _isLoading = false;
  String? _generatedRecipe;
  Map<String, dynamic>? _structuredRecipe;
  bool _useUrlMode = false;
  String? _uploadedImageUrl;
  bool _isGeneratingImage = false;
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();

  @override
  void dispose() {
    _ingredientsController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _isGeneratingImage = true;
        });

        // Upload to Firebase Storage
        final imageUrl = await _storageService.uploadImage(
          File(image.path),
          'recipe_images',
        );

        setState(() {
          _uploadedImageUrl = imageUrl;
          _isGeneratingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto caricata con successo!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isGeneratingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore caricamento foto: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateImageWithGemini() async {
    if (_structuredRecipe == null) return;

    final promptImmagine = _structuredRecipe!['prompt_immagine'] as String?;
    if (promptImmagine == null || promptImmagine.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun prompt immagine disponibile'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isGeneratingImage = true;
    });

    try {
      final geminiService = GeminiService();
      final imageUrl =
          await geminiService.generaImmagineDaPrompt(promptImmagine);

      setState(() {
        _uploadedImageUrl = imageUrl;
        _isGeneratingImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Immagine generata con successo!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isGeneratingImage = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore generazione immagine: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Map<String, dynamic> _parseRecipeFromUrl(String recipeText, String url) {
    final lines = recipeText.split('\n');
    String? titolo;
    final ingredienti = <Map<String, dynamic>>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.startsWith('TITOLO:')) {
        titolo = trimmedLine.substring(7).trim();
      } else if (trimmedLine.startsWith('-')) {
        // Parse ingredient line: - [quantità] [unità] [ingrediente] - [reparto]
        final parts = trimmedLine.substring(1).trim().split(' - ');
        if (parts.length >= 2) {
          final ingredientPart = parts[0].trim();
          final categoryPart = parts[1].trim();

          // Parse ingredient: [quantità] [unità] [ingrediente]
          // Use regex to extract quantity, unit, and name
          final regex = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-zA-Z°]+)?\s*(.*)$');
          final match = regex.firstMatch(ingredientPart);

          String? quantity;
          String? unit;
          String? name;

          if (match != null) {
            quantity = match.group(1);
            unit = match.group(2);
            name = match.group(3)?.trim();

            // If name is empty, use the whole ingredient part
            if (name == null || name.isEmpty) {
              name = ingredientPart;
            }
          } else {
            // If regex doesn't match, use the whole ingredient part as name
            name = ingredientPart;
          }

          ingredienti.add({
            'nome': name,
            'quantita': quantity,
            'unita': unit,
            'categoria': categoryPart,
          });
        }
      }
    }

    return {
      'titolo': titolo ?? 'Ricetta da URL',
      'ingredienti': ingredienti,
      'procedimento': url, // Save URL in procedimento field for copyright
      'categoria': null,
    };
  }

  Future<void> _generateRecipe() async {
    if (_useUrlMode) {
      final urlText = _urlController.text.trim();
      if (urlText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inserisci un URL'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _generatedRecipe = null;
        _structuredRecipe = null;
      });

      try {
        final geminiService = GeminiService();
        final recipe = await geminiService.estraiRicettaDaUrl(urlText);

        // Parse the recipe to extract structured data
        final structuredRecipe = _parseRecipeFromUrl(recipe, urlText);

        setState(() {
          _structuredRecipe = structuredRecipe;
          _generatedRecipe = recipe;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      final ingredientsText = _ingredientsController.text.trim();
      if (ingredientsText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Inserisci almeno un ingrediente'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
        _generatedRecipe = null;
        _structuredRecipe = null;
      });

      try {
        final ingredients =
            ingredientsText.split(',').map((e) => e.trim()).toList();
        final geminiService = GeminiService();
        
        // Recupera ricette locali per il contesto
        final localRecipes = await DatabaseHelper.getLocalRecipesForGemini();
        
        // Recupera preferenze utente
        final userPrefs = await DatabaseHelper.getUserPreferences();
        
        final structuredRecipe =
            await geminiService.generaRicettaStrutturata(
              ingredients,
              eta: userPrefs?['eta'],
              obiettivoCalorico: userPrefs?['obiettivo_calorico'],
              tipoDieta: widget.state.data.dietType.displayName,
              allergie: widget.state.data.allergies,
              ricetteLocali: localRecipes,
            );

        setState(() {
          _structuredRecipe = structuredRecipe;
          _generatedRecipe = structuredRecipe['procedimento'];
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Errore: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveRecipe() async {
    if (_structuredRecipe == null) return;

    try {
      final titolo = _structuredRecipe!['titolo'] as String;
      final listaRaw = _structuredRecipe!['ingredienti'] as List<dynamic>;
      final ingredientiList = listaRaw.map((item) {
        return Map<String, dynamic>.from(item);
      }).toList();
      final procedimento = _structuredRecipe!['procedimento'] as String?;
      final categoriaStr = _structuredRecipe!['categoria'] as String?;
      final sottocategoriaStr = _structuredRecipe!['sottocategoria'] as String?;
      final promptImmagine = _structuredRecipe!['prompt_immagine'] as String?;

      // Check if recipe with same title already exists to avoid duplicates
      final existingRecipe = widget.state.data.recipes.firstWhere(
        (r) => r.title.toLowerCase() == titolo.toLowerCase(),
        orElse: () => widget.state.data.recipes.firstWhere(
          (r) => r.title.toLowerCase().contains(titolo.toLowerCase()) || 
                  titolo.toLowerCase().contains(r.title.toLowerCase()),
          orElse: () => widget.state.data.recipes.first,
        ),
      );
      
      if (existingRecipe.title.toLowerCase() == titolo.toLowerCase()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Questa ricetta esiste già!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        Navigator.pop(context);
        return;
      }

      // Converti gli ingredienti strutturati in oggetti Ingredient
      final ingredienti = ingredientiList.map((ing) {
        final qtyValue = ing['quantita'];
        double? qty;
        if (qtyValue is num) {
          qty = qtyValue.toDouble();
        } else if (qtyValue is String) {
          qty = double.tryParse(qtyValue);
        }

        // Mappa la categoria del supermercato a IngredientCategory
        final categoriaStr = ing['categoria'] as String? ?? 'altro';
        IngredientCategory mappedCategory;

        switch (categoriaStr.toLowerCase()) {
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

        return Ingredient(
          name: ing['nome'] as String,
          category: mappedCategory,
          quantity: qty,
          unit: ing['unita'] as String?,
        );
      }).toList();

      // Mappa la categoria stringa a RecipeCategory
      RecipeCategory? mappedCategory;
      if (categoriaStr != null) {
        final catLower = categoriaStr.toLowerCase();
        if (catLower.contains('primo')) {
          mappedCategory = RecipeCategory.primi;
        } else if (catLower.contains('secondo')) {
          mappedCategory = RecipeCategory.secondi;
        } else if (catLower.contains('contorno')) {
          mappedCategory = RecipeCategory.contorni;
        } else if (catLower.contains('antipasto')) {
          mappedCategory = RecipeCategory.antipasti;
        } else if (catLower.contains('dolce')) {
          mappedCategory = RecipeCategory.dolci;
        } else {
          mappedCategory = RecipeCategory.altre;
        }
      }

      // Always generate image automatically when Gemini creates recipe
      String? imageUrl;
      final geminiService = GeminiService();
      try {
        if (promptImmagine != null && promptImmagine.isNotEmpty) {
          imageUrl = await geminiService.generaImmagineDaPrompt(promptImmagine);
        } else {
          // Fallback to title-based image generation
          imageUrl = await geminiService.generaImmagineRicetta(titolo);
        }
      } catch (e) {
        debugPrint('Errore generazione immagine: $e');
      }

      // If user uploaded an image, use that instead
      if (_uploadedImageUrl != null) {
        imageUrl = _uploadedImageUrl;
      }

      // Crea una ricetta temporanea da passare all'editor con ID temporaneo unico
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final tempRecipe = Recipe(
        id: tempId,
        title: titolo,
        ingredients: ingredienti,
        note: procedimento,
        category: mappedCategory,
        imageUrl: imageUrl,
        categoriaPrincipale: categoriaStr,
        sottocategoria: sottocategoriaStr,
      );

      // Chiudi il dialogo corrente
      if (mounted) {
        Navigator.pop(context);
      }

      // Naviga all'editor con la ricetta popolata
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                RecipeEditorScreen(state: widget.state, recipe: tempRecipe),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Genera Ricetta con AI'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle tra modalità ingredienti e URL
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Ingredienti'),
                    icon: Icon(Icons.restaurant),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('URL'),
                    icon: Icon(Icons.link),
                  ),
                ],
                selected: {_useUrlMode},
                onSelectionChanged: (Set<bool> selection) {
                  setState(() {
                    _useUrlMode = selection.first;
                  });
                },
              ),
              const SizedBox(height: 16),

              if (_useUrlMode) ...[
                const Text(
                  'Inserisci l\'URL della ricetta:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  decoration: const InputDecoration(
                    hintText: 'es. https://sito-ricette.com/ricetta-pasta',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ] else ...[
                const Text(
                  'Inserisci gli ingredienti che hai disponibili (separati da virgola):',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _ingredientsController,
                  decoration: const InputDecoration(
                    hintText: 'es. uova, farina, latte, pomodoro',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else if (_generatedRecipe != null) ...[
                const Text(
                  'Ricetta generata:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: Text(_generatedRecipe!),
                ),
                const SizedBox(height: 16),

                // Image upload and generation section
                const Text(
                  'Foto del piatto:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (_uploadedImageUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: _uploadedImageUrl!,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                      errorWidget: (context, url, error) => const Icon(
                        Icons.error,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else ...[
                  Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant,
                            size: 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Nessuna foto',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingImage ? null : _pickImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Carica foto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8BA888),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isGeneratingImage
                            ? null
                            : _generateImageWithGemini,
                        icon: _isGeneratingImage
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: _isGeneratingImage
                            ? const Text('Generazione...')
                            : const Text('Genera con AI'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8BA888),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        if (_generatedRecipe != null)
          FilledButton(
            onPressed: _saveRecipe,
            child: const Text('Salva Ricetta'),
          )
        else
          FilledButton(
            onPressed: _isLoading ? null : _generateRecipe,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Genera'),
          ),
      ],
    );
  }
}

// Funzione pubblica per mostrare il dialogo Gemini con parametri opzionali
Future<void> showGeminiRecipeDialog(
  BuildContext context,
  AppState state,
  DateTime? targetDay,
  MealType? targetMealType,
) {
  return showDialog(
    context: context,
    builder: (context) => _GeminiRecipeDialog(
      state: state,
      targetDay: targetDay,
      targetMealType: targetMealType,
    ),
  );
}

// Widget per card compatte nelle liste orizzontali
class _CompactRecipeCard extends StatelessWidget {
  const _CompactRecipeCard({
    required this.recipe,
    required this.state,
    required this.onTap,
  });

  final Recipe recipe;
  final AppState state;
  final VoidCallback onTap;

  Color _getCompactDifficultyColor(String difficolta) {
    switch (difficolta.toLowerCase()) {
      case 'facile':
        return Colors.green;
      case 'media':
        return Colors.orange;
      case 'difficile':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => showRecipeActionSheet(context, state, recipe),
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Anteprima quadrata
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.grey[300]!,
                    Colors.grey[400]!,
                  ],
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: recipe.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CachedNetworkImage(
                        imageUrl: recipe.imageUrl!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        placeholder: (context, url) => Icon(
                          Icons.restaurant,
                          size: 32,
                          color: Colors.grey[600],
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.restaurant,
                          size: 32,
                          color: Colors.grey[600],
                        ),
                      ),
                    )
                  : Icon(
                      Icons.restaurant,
                      size: 32,
                      color: Colors.grey[600],
                    ),
            ),
            const SizedBox(height: 4),
            // Titolo ridotto
            Text(
              recipe.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Calorie
            if (recipe.calorie != null)
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 10,
                    color: Colors.orange[700],
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${recipe.calorie} kcal',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 2),
            // Tempo e difficoltà
            if (recipe.tempoPreparazione != null || recipe.difficolta != null)
              Row(
                children: [
                  if (recipe.tempoPreparazione != null) ...[
                    Icon(
                      Icons.access_time,
                      size: 10,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${recipe.tempoPreparazione} min',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                  if (recipe.difficolta != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: _getCompactDifficultyColor(recipe.difficolta!),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        recipe.difficolta!,
                        style: const TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 2),
            // Contatore voti
            Row(
              children: [
                const Icon(
                  Icons.favorite,
                  size: 12,
                  color: Colors.red,
                ),
                const SizedBox(width: 2),
                Text(
                  formatCount(recipe.likeCount),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Schermata per visualizzare ricette di una categoria specifica
class _CategoryRecipesScreen extends StatefulWidget {
  const _CategoryRecipesScreen({
    required this.state,
    required this.category,
  });

  final AppState state;
  final RecipeCategory category;

  @override
  State<_CategoryRecipesScreen> createState() => _CategoryRecipesScreenState();
}

class _CategoryRecipesScreenState extends State<_CategoryRecipesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  SecondiSubCategory _selectedSubCategory = SecondiSubCategory.carne;

  @override
  void initState() {
    super.initState();
    if (widget.category == RecipeCategory.secondi) {
      _tabController = TabController(length: 2, vsync: this);
      _tabController.addListener(() {
        setState(() {
          _selectedSubCategory = _tabController.index == 0
              ? SecondiSubCategory.carne
              : SecondiSubCategory.pesce;
        });
      });
    }
  }

  @override
  void dispose() {
    if (widget.category == RecipeCategory.secondi) {
      _tabController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allRecipes = widget.state.data.recipes
        .where((r) => getRecipeCategory(r) == widget.category)
        .toList();

    List<Recipe> recipes;
    if (widget.category == RecipeCategory.secondi) {
      recipes = allRecipes
          .where((r) => getSecondiSubCategory(r) == _selectedSubCategory)
          .toList();
    } else {
      recipes = allRecipes;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.displayName),
        bottom: widget.category == RecipeCategory.secondi
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Carne'),
                  Tab(text: 'Pesce'),
                ],
              )
            : null,
      ),
      body: recipes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Nessuna ricetta in questa categoria',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16.0,
                crossAxisSpacing: 16.0,
                childAspectRatio: 0.75,
              ),
              itemCount: recipes.length,
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return _RecipeGridCard(
                  recipe: recipe,
                  state: widget.state,
                  pickMode: false,
                  onPick: null,
                  onAddToMenu: () {
                    showDialog<void>(
                      context: context,
                      builder: (context) =>
                          AddToMenuDialog(state: widget.state, recipe: recipe),
                    );
                  },
                );
              },
            ),
    );
  }
}

// Screen per mostrare ricette filtrate per sottocategoria
class _SubcategoryRecipesScreen extends StatelessWidget {
  const _SubcategoryRecipesScreen({
    required this.state,
    required this.categoriaPrincipale,
    required this.sottocategoria,
  });

  final AppState state;
  final String categoriaPrincipale;
  final String sottocategoria;

  @override
  Widget build(BuildContext context) {
    final filteredRecipes = state.data.recipes.where((recipe) {
      return recipe.categoriaPrincipale == categoriaPrincipale &&
          recipe.sottocategoria == sottocategoria;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('$sottocategoria - $categoriaPrincipale'),
      ),
      body: filteredRecipes.isEmpty
          ? Center(
              child: Text('Nessuna ricetta trovata in $sottocategoria'),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: filteredRecipes.length,
              itemBuilder: (context, index) {
                final recipe = filteredRecipes[index];
                return _RecipeGridCard(
                  recipe: recipe,
                  state: state,
                  pickMode: false,
                  onPick: null,
                  onAddToMenu: null,
                );
              },
            ),
    );
  }
}
