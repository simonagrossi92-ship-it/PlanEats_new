import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../app_state.dart';
import '../models.dart';
import '../utils/category_helper.dart';
import '../services/image_service.dart';

String formatCount(int count) {
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return count.toString();
}

class RecipeEditorScreen extends StatefulWidget {
  const RecipeEditorScreen({super.key, required this.state, this.recipe});
  final AppState state;
  final Recipe? recipe;

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _IngredientDraft {
  _IngredientDraft({
    String name = '',
    this.category = IngredientCategory.dispensa,
    String qty = '',
    String unit = '',
    String note = '',
  })  : nameCtrl = TextEditingController(text: name),
        qtyCtrl = TextEditingController(text: qty),
        unitCtrl = TextEditingController(text: unit),
        noteCtrl = TextEditingController(text: note);

  final TextEditingController nameCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController unitCtrl;
  final TextEditingController noteCtrl;
  IngredientCategory category;

  void dispose() {
    nameCtrl.dispose();
    qtyCtrl.dispose();
    unitCtrl.dispose();
    noteCtrl.dispose();
  }
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _noteCtrl;
  late List<_IngredientDraft> _ingredients;
  RecipeCategory? _selectedCategory;
  File? _selectedImage;
  String? _existingImageUrl;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final r = widget.recipe;
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _noteCtrl = TextEditingController(text: r?.note ?? '');
    _selectedCategory = r?.category;
    _existingImageUrl = r?.imageUrl;
    _ingredients = (r?.ingredients ?? const [])
        .map(
          (i) => _IngredientDraft(
            name: i.name,
            category: i.category,
            qty: i.quantity?.toString() ?? '',
            unit: i.unit ?? '',
            note: i.note ?? '',
          ),
        )
        .toList();
    if (_ingredients.isEmpty) _ingredients = [_IngredientDraft()];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    for (final d in _ingredients) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _removeImage() async {
    setState(() {
      _selectedImage = null;
      _existingImageUrl = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.recipe != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifica ricetta' : 'Nuova ricetta'),
        actions: [
          if (isEdit)
            Row(
              children: [
                const Icon(
                  Icons.favorite,
                  size: 16,
                  color: Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  formatCount(widget.recipe!.likeCount),
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 8),
              ],
            ),
          IconButton(
            onPressed: _save,
            icon: const Icon(Icons.save),
            tooltip: 'Salva',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            // Image upload section
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isUploading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 8),
                          Text('Caricamento...'),
                        ],
                      ),
                    )
                  : _selectedImage != null
                      ? Stack(
                          children: [
                            Image.file(
                              _selectedImage!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: IconButton(
                                onPressed: _removeImage,
                                icon: const Icon(Icons.close),
                                color: Colors.white,
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black54,
                                ),
                              ),
                            ),
                          ],
                        )
                      : _existingImageUrl != null
                          ? Stack(
                              children: [
                                Image.network(
                                  _existingImageUrl!,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.restaurant, size: 48),
                                    );
                                  },
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    onPressed: _removeImage,
                                    icon: const Icon(Icons.close),
                                    color: Colors.white,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black54,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : InkWell(
                              onTap: _pickImage,
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate, size: 48),
                                    SizedBox(height: 8),
                                    Text('Aggiungi foto'),
                                  ],
                                ),
                              ),
                            ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Titolo',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Inserisci un titolo'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecipeCategory>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria',
                border: OutlineInputBorder(),
                helperText:
                    'Scegli in quale sezione del ricettario inserire questa ricetta',
              ),
              items: RecipeCategory.values.map((category) {
                return DropdownMenuItem<RecipeCategory>(
                  value: category,
                  child: Text(category.displayName),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (opzionale)',
                border: OutlineInputBorder(),
              ),
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Ingredienti (per 1 persona)',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _ingredients.add(_IngredientDraft())),
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._ingredients
                .asMap()
                .entries
                .map((e) => _ingredientCard(e.key, e.value)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Salva ricetta'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ingredientCard(int index, _IngredientDraft d) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: d.nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Ingrediente',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) {
                      final suggestedCat = suggestCategory(v);
                      if (suggestedCat != IngredientCategory.altro) {
                        setState(() => d.category = suggestedCat);
                      }
                      final suggestedUnit = suggestUnit(v);
                      if (suggestedUnit != null) {
                        setState(() => d.unitCtrl.text = suggestedUnit);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _ingredients.length <= 1
                      ? null
                      : () {
                          setState(() {
                            d.dispose();
                            _ingredients.removeAt(index);
                          });
                        },
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Rimuovi ingrediente',
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<IngredientCategory>(
              initialValue: d.category,
              decoration: const InputDecoration(
                labelText: 'Reparto',
                border: OutlineInputBorder(),
              ),
              items: IngredientCategory.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text(ingredientCategoryLabel(c)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => d.category = v!),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: d.qtyCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Quantità (opz.)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: d.unitCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Unità (opz.)',
                      hintText: 'g, kg, ml...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: d.noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note ingrediente (opz.)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final title = _titleCtrl.text.trim();
    final note = _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim();

    final ingredients = <Ingredient>[];
    for (final d in _ingredients) {
      final name = d.nameCtrl.text.trim();
      if (name.isEmpty) continue;
      final qtyRaw = d.qtyCtrl.text.trim().replaceAll(',', '.');
      final qty = double.tryParse(qtyRaw);
      final unit =
          d.unitCtrl.text.trim().isEmpty ? null : d.unitCtrl.text.trim();
      final inote =
          d.noteCtrl.text.trim().isEmpty ? null : d.noteCtrl.text.trim();
      ingredients.add(
        Ingredient(
          name: name,
          category: d.category,
          quantity: qty,
          unit: unit,
          note: inote,
        ),
      );
    }

    // Handle image upload
    String? imageUrl = _existingImageUrl;
    if (_selectedImage != null) {
      setState(() {
        _isUploading = true;
      });

      try {
        // Compress image
        final compressedImage =
            await ImageService.compressImage(_selectedImage!);
        // Upload to Firebase Storage
        final recipeId = widget.recipe?.id ??
            DateTime.now().millisecondsSinceEpoch.toString();
        imageUrl = await ImageService.uploadImage(compressedImage, recipeId);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Errore durante il caricamento dell\'immagine: $e')),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }

      setState(() {
        _isUploading = false;
      });
    } else if (_selectedImage == null && _existingImageUrl == null) {
      imageUrl = null;
    }

    final rid = await widget.state.upsertRecipe(
      id: widget.recipe?.id,
      title: title,
      ingredients: ingredients,
      note: note,
      category: _selectedCategory,
      imageUrl: imageUrl,
    );

    if (mounted) Navigator.pop(context, rid);
  }
}
