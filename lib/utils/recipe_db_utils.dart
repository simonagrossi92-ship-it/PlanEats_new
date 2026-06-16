import 'dart:convert';

import '../models.dart';
import 'ingredient_utils.dart';

/// Normalizza i campi delle ricette lette dal database SQLite,
/// supportando sia lo schema interno (nome, immagine, note)
/// sia quello arricchito dallo script Python (titolo, immagine_url, descrizione).
class RecipeDbUtils {
  static String getTitle(Map<String, dynamic> recipe) {
    final value = recipe['nome'] ?? recipe['titolo'];
    return value?.toString().trim() ?? '';
  }

  static String getImageUrl(Map<String, dynamic> recipe) {
    final value = recipe['immagine'] ?? recipe['immagine_url'];
    return value?.toString().trim() ?? '';
  }

  static String getDescription(Map<String, dynamic> recipe) {
    final value =
        recipe['note'] ?? recipe['descrizione'] ?? recipe['procedimento'];
    return value?.toString().trim() ?? '';
  }

  static String getCategoryName(Map<String, dynamic> recipe) {
    return recipe['categoria']?.toString().trim() ?? '';
  }

  static RecipeCategory? categoryFromName(String? categoria) {
    if (categoria == null || categoria.isEmpty) return null;

    switch (categoria.toLowerCase()) {
      case 'antipasti':
        return RecipeCategory.antipasti;
      case 'primi':
      case 'primi piatti':
        return RecipeCategory.primi;
      case 'secondi':
        return RecipeCategory.secondi;
      case 'contorni':
        return RecipeCategory.contorni;
      case 'dolci':
        return RecipeCategory.dolci;
      case 'altre':
      case 'altre ricette':
      case 'altro':
        return RecipeCategory.altre;
      default:
        return null;
    }
  }

  static List<Ingredient> parseIngredients(dynamic raw) {
    if (raw == null) return [];

    try {
      dynamic decoded = raw;
      if (raw is String) {
        decoded = raw.isEmpty ? [] : jsonDecode(raw);
      }
      if (decoded is! List) return [];

      return decoded.whereType<Map>().map((item) {
        final map = Map<String, dynamic>.from(item);

        final name = map['name'] ?? map['nome'] ?? map['ingrediente'] ?? map['ingredient'];
        map['name'] = name;
        if (map['quantity'] == null && map['amount'] != null) {
          map['quantity'] = map['amount'];
        }
        map['quantity'] ??= map['quantita'] ?? map['qty'];
        map['unit'] ??= map['unita'];

        return Ingredient.fromJson(map);
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Recipe recipeFromDbMap(Map<String, dynamic> dbRecipe) {
    final categoria = getCategoryName(dbRecipe);
    final imageUrl = getImageUrl(dbRecipe);
    final rawIngredients = parseIngredients(dbRecipe['ingredienti']);
    final ingredients =
        IngredientUtils.scaleToOnePerson(rawIngredients);

    int? calorie;
    if (dbRecipe['calorie'] != null) {
      calorie = ((dbRecipe['calorie'] as num) /
              IngredientUtils.databaseRecipeServings)
          .round();
    }

    return Recipe(
      id: dbRecipe['id']?.toString() ?? '',
      title: getTitle(dbRecipe),
      ingredients: ingredients,
      note: getDescription(dbRecipe),
      category: categoryFromName(categoria),
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      categoriaPrincipale: categoria.isEmpty ? null : categoria,
      sottocategoria: dbRecipe['sottocategoria']?.toString(),
      calorie: calorie,
      tempoPreparazione: dbRecipe['tempo_preparazione'] as int?,
      difficolta: dbRecipe['difficolta']?.toString(),
      tipo: 'Ricettario',
      servingType: ServingType.persone,
    );
  }
}
