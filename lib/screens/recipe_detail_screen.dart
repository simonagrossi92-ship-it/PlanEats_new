import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../app_state.dart';
import '../database_helper.dart';
import '../models.dart';
import '../utils/ingredient_utils.dart';
import '../utils/recipe_db_utils.dart';
import '../widgets/recipe_action_sheet.dart';
import 'recipe_editor.dart';

class RecipeDetailScreen extends StatefulWidget {
  final Map<String, dynamic>? ricetta;
  final Recipe? recipe;
  final AppState? state;

  const RecipeDetailScreen({
    super.key,
    this.ricetta,
    this.recipe,
    this.state,
  }) : assert(ricetta != null || recipe != null);

  @override
  State<RecipeDetailScreen> createState() => _RecipeDetailScreenState();
}

class _RecipeDetailScreenState extends State<RecipeDetailScreen> {
  Recipe? _recipe;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    if (widget.ricetta != null) {
      setState(() {
        _recipe = RecipeDbUtils.recipeFromDbMap(widget.ricetta!);
      });
      return;
    }

    final initial = widget.recipe!;
    setState(() {
      _recipe = initial;
      _isLoading = initial.ingredients.isEmpty &&
          (initial.note == null || initial.note!.trim().isEmpty);
    });

    if (!_isLoading) return;

    final dbRow = await DatabaseHelper.getRecipeById(initial.id);
    if (!mounted || dbRow == null) {
      setState(() => _isLoading = false);
      return;
    }

    setState(() {
      _recipe = RecipeDbUtils.recipeFromDbMap(dbRow);
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_recipe == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final recipe = _recipe!;
    final imageUrl = recipe.imageUrl ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio Ricetta'),
        actions: [
          if (widget.state != null && _recipe != null)
            IconButton(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Azioni ricetta',
              onPressed: () => showRecipeActionSheet(
                context,
                widget.state!,
                _recipe!,
              ),
            ),
          if (widget.state != null)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Modifica',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => RecipeEditorScreen(
                      state: widget.state!,
                      recipe: recipe,
                    ),
                  ),
                );
                await _loadRecipe();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GestureDetector(
              onLongPress: widget.state != null && _recipe != null
                  ? () => showRecipeActionSheet(
                        context,
                        widget.state!,
                        _recipe!,
                      )
                  : null,
              child: SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (imageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      height: 260,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholderImage(),
                    )
                  else
                    _placeholderImage(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          recipe.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (recipe.categoriaPrincipale != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            [
                              recipe.categoriaPrincipale,
                              recipe.sottocategoria,
                            ].whereType<String>().join(' · '),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        const Text(
                          'Ingredienti (per 1 persona)',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (recipe.ingredients.isEmpty)
                          Text(
                            'Nessun ingrediente disponibile',
                            style: TextStyle(color: Colors.grey[600]),
                          )
                        else
                          ...recipe.ingredients.map(_ingredientTile),
                        const SizedBox(height: 24),
                        const Text(
                          'Procedimento',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          recipe.note?.trim().isNotEmpty == true
                              ? recipe.note!.trim()
                              : 'Procedimento non disponibile',
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: recipe.note?.trim().isNotEmpty == true
                                ? Colors.black87
                                : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      height: 260,
      width: double.infinity,
      color: Colors.grey[200],
      child: const Icon(Icons.restaurant_menu, size: 80, color: Colors.grey),
    );
  }

  Widget _ingredientTile(Ingredient ing) {
    final qty = ing.quantity;
    final hasQty = qty != null && qty > 0;
    final unit = ing.unit?.trim();
    final detail = hasQty
        ? '${_formatQuantity(qty)}${unit != null && unit.isNotEmpty ? ' $unit' : ''}'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 16, color: Colors.black87),
                children: [
                  TextSpan(
                    text: ing.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (detail != null)
                    TextSpan(
                      text: ' — $detail',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatQuantity(double value) {
    return IngredientUtils.formatQuantity(value);
  }
}
