import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../app_state.dart';
import '../models.dart';
import '../screens/recipe_editor.dart';
import '../utils/dates.dart';

/// Menu azioni ricetta (long press o menu ⋮).
void showRecipeActionSheet(
  BuildContext context,
  AppState state,
  Recipe recipe,
) {
  HapticFeedback.mediumImpact();
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => RecipeActionSheet(state: state, recipe: recipe),
  );
}

class RecipeActionSheet extends StatelessWidget {
  const RecipeActionSheet({
    super.key,
    required this.state,
    required this.recipe,
  });

  final AppState state;
  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[400],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              recipe.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.calendar_month, color: Color(0xFF8BA888)),
            title: const Text('Aggiungi al menu settimanale'),
            subtitle: const Text('Scegli giorno e pasto'),
            onTap: () {
              Navigator.pop(context);
              showDialog<void>(
                context: context,
                builder: (context) => AddToMenuDialog(state: state, recipe: recipe),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Modifica ricetta'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => RecipeEditorScreen(state: state, recipe: recipe),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: const Text('Duplica ricetta'),
            onTap: () {
              Navigator.pop(context);
              _duplicateRecipe(context, state, recipe);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text(
              'Elimina ricetta',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () {
              Navigator.pop(context);
              _confirmDeleteRecipe(context, state, recipe);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _duplicateRecipe(
    BuildContext context,
    AppState state,
    Recipe recipe,
  ) async {
    try {
      await state.upsertRecipe(
        id: const Uuid().v4(),
        title: '${recipe.title} (copia)',
        ingredients: recipe.ingredients,
        note: recipe.note,
        category: recipe.category,
        servingType: recipe.servingType,
        imageUrl: recipe.imageUrl,
        categoriaPrincipale: recipe.categoriaPrincipale,
        sottocategoria: recipe.sottocategoria,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Duplicata: ${recipe.title}'),
            backgroundColor: const Color(0xFF8BA888),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile duplicare: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmDeleteRecipe(
    BuildContext context,
    AppState state,
    Recipe recipe,
  ) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina ricetta'),
        content: Text('Eliminare "${recipe.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await state.deleteRecipe(recipe.id);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Eliminata: ${recipe.title}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

class AddToMenuDialog extends StatefulWidget {
  const AddToMenuDialog({super.key, required this.state, required this.recipe});

  final AppState state;
  final Recipe recipe;

  @override
  State<AddToMenuDialog> createState() => _AddToMenuDialogState();
}

class _AddToMenuDialogState extends State<AddToMenuDialog> {
  DateTime? selectedDay;
  MealType? selectedMeal;
  int numberOfServings = 1;
  bool addToExisting = false;

  @override
  Widget build(BuildContext context) {
    final days = weekDays(DateTime.now());

    return AlertDialog(
      title: Text('Aggiungi "${widget.recipe.title}" al menu'),
      content: SizedBox(
        width: 300,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Seleziona giorno e pasto:'),
              const SizedBox(height: 8),
              const Text('Giorno:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: days.map((day) {
                  final isSelected = selectedDay != null &&
                      selectedDay!.day == day.day &&
                      selectedDay!.month == day.month &&
                      selectedDay!.year == day.year;
                  return FilterChip(
                    label: Text(weekdayShortLabel(day)),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() => selectedDay = selected ? day : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text('Pasto:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: MealType.values.map((meal) {
                  return FilterChip(
                    label: Text(mealTypeLabel(meal)),
                    selected: selectedMeal == meal,
                    onSelected: (selected) {
                      setState(() => selectedMeal = selected ? meal : null);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
              const Text('Modalità:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Sostituisci'),
                    icon: Icon(Icons.refresh),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('Aggiungi'),
                    icon: Icon(Icons.add_circle),
                  ),
                ],
                selected: {addToExisting},
                onSelectionChanged: (selection) {
                  setState(() => addToExisting = selection.first);
                },
              ),
              const SizedBox(height: 8),
              const Text('Persone:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.people, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextFormField(
                      initialValue: numberOfServings.toString(),
                      decoration: const InputDecoration(
                        labelText: 'N°',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      keyboardType: TextInputType.number,
                      onChanged: (v) {
                        final value = int.tryParse(v);
                        if (value != null && value > 0) {
                          setState(() => numberOfServings = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          onPressed: (selectedDay == null || selectedMeal == null)
              ? null
              : () async {
                  final currentEntry =
                      widget.state.mealEntry(selectedDay!, selectedMeal!);
                  final List<MealItem> items;

                  if (addToExisting &&
                      currentEntry != null &&
                      !currentEntry.isEmpty) {
                    items = [
                      ...currentEntry.items,
                      MealItem(
                        recipeId: widget.recipe.id,
                        numberOfServings: numberOfServings,
                      ),
                    ];
                  } else {
                    items = [
                      MealItem(
                        recipeId: widget.recipe.id,
                        numberOfServings: numberOfServings,
                      ),
                    ];
                  }

                  await widget.state.setMealEntry(
                    selectedDay!,
                    selectedMeal!,
                    MealEntry(items: items),
                  );

                  if (context.mounted) {
                    Navigator.pop(context);
                    final actionText =
                        addToExisting ? 'aggiunta come portata' : 'aggiunta';
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '"${widget.recipe.title}" $actionText a '
                          '${mealTypeLabel(selectedMeal!)} di '
                          '${weekdayShortLabel(selectedDay!)}',
                        ),
                        backgroundColor: const Color(0xFF8BA888),
                      ),
                    );
                  }
                },
          child: const Text('Aggiungi'),
        ),
      ],
    );
  }
}
