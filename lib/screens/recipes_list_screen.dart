import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../database_helper.dart';
import '../utils/recipe_db_utils.dart';
import 'recipe_detail_screen.dart';

class RecipesListScreen extends StatefulWidget {
  const RecipesListScreen({super.key});

  @override
  State<RecipesListScreen> createState() => _RecipesListScreenState();
}

class _RecipesListScreenState extends State<RecipesListScreen> {
  List<Map<String, dynamic>> _antipasti = [];
  List<Map<String, dynamic>> _primi = [];
  List<Map<String, dynamic>> _secondi = [];
  List<Map<String, dynamic>> _dolci = [];
  bool _isLoading = true;
  bool _isAiLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    await DatabaseHelper.instance.initDatabase();
    await DatabaseHelper.insertItalianRecipes();

    final antipasti = await DatabaseHelper.getRecipesByCategory('Antipasti');
    final primi = await DatabaseHelper.getRecipesByCategory('Primi');
    final secondi = await DatabaseHelper.getRecipesByCategory('Secondi');
    final dolci = await DatabaseHelper.getRecipesByCategory('Dolci');

    if (!mounted) return;
    setState(() {
      _antipasti = antipasti;
      _primi = primi;
      _secondi = secondi;
      _dolci = dolci;
      _isLoading = false;
    });
  }

  void _showActionMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFFFFDF9),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.auto_awesome, color: Color(0xFFFF9F1C)),
              title: const Text(
                'Generatore AI',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Crea nuove ricette con l\'intelligenza artificiale'),
              onTap: _isAiLoading
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _avviaGenerazioneAI();
                    },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _avviaGenerazioneAI() async {
    if (_isAiLoading) return;

    setState(() {
      _isAiLoading = true;
    });

    try {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generazione AI completata')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore nella generazione AI: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ricettario'),
          backgroundColor: const Color(0xFF8BA888),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Antipasti'),
              Tab(text: 'Primi'),
              Tab(text: 'Secondi'),
              Tab(text: 'Dolci'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildRecipeList(_antipasti),
                  _buildRecipeList(_primi),
                  _buildRecipeList(_secondi),
                  _buildRecipeList(_dolci),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showActionMenu,
          backgroundColor: const Color(0xFF8BA888),
          child: const Icon(Icons.menu, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildRecipeList(List<Map<String, dynamic>> recipes) {
    if (recipes.isEmpty) {
      return const Center(
        child: Text('Nessuna ricetta trovata in questa categoria'),
      );
    }

    return ListView.builder(
      itemCount: recipes.length,
      itemBuilder: (context, index) {
        final ricetta = recipes[index];
        final imageUrl = RecipeDbUtils.getImageUrl(ricetta);
        final title = RecipeDbUtils.getTitle(ricetta);
        final description = RecipeDbUtils.getDescription(ricetta);

        return InkWell(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RecipeDetailScreen(
                  ricetta: ricetta,
                ),
              ),
            );
            // Refresh recipes when returning from detail screen
            _loadRecipes();
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(15)),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          height: 200,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholderImage(),
                        )
                      : _placeholderImage(),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isNotEmpty ? title : 'Ricetta',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _placeholderImage() {
    return Container(
      height: 200,
      color: Colors.grey[200],
      child: const Icon(Icons.restaurant_menu, size: 50, color: Colors.grey),
    );
  }
}
