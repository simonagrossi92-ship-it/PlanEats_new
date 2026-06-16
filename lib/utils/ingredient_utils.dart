import '../models.dart';

class IngredientUtils {
  /// Porzioni di default per le ricette precaricate nel database SQLite.
  static const int databaseRecipeServings = 4;

  /// Converte gli ingredienti da [fromServings] persone a dosi per 1 persona.
  static List<Ingredient> scaleToOnePerson(
    List<Ingredient> ingredients, {
    int fromServings = databaseRecipeServings,
  }) {
    if (fromServings <= 1) return ingredients;
    return ingredients
        .map((i) => scaleIngredientToOnePerson(i, fromServings: fromServings))
        .toList();
  }

  static Ingredient scaleIngredientToOnePerson(
    Ingredient ingredient, {
    int fromServings = databaseRecipeServings,
  }) {
    if (fromServings <= 1 || ingredient.quantity == null) {
      return ingredient;
    }

    final scaled = roundQuantityForUnit(
      ingredient.quantity! / fromServings,
      unit: ingredient.unit,
      isSeasoning: _isSeasoningUnit(ingredient.unit),
    );

    return Ingredient(
      name: ingredient.name,
      category: ingredient.category,
      quantity: scaled,
      unit: ingredient.unit,
      note: ingredient.note,
    );
  }

  static bool _isSeasoningUnit(String? unit) {
    final u = unit?.toLowerCase().trim() ?? '';
    return u.contains('pizzic') ||
        u == 'q.b.' ||
        u == 'qb' ||
        u.contains('q.b');
  }

  /// Arrotonda quantità per visualizzazione/cottura per 1 persona.
  static double roundQuantityForUnit(
    double value, {
    String? unit,
    bool isSeasoning = false,
  }) {
    if (value <= 0) return value;
    if (isSeasoning || _isSeasoningUnit(unit)) return 1;

    final u = unit?.toLowerCase().trim() ?? '';
    final isCount = u.contains('pezz') ||
        u.contains('spicch') ||
        u.contains('fett') ||
        u.contains('fogli') ||
        u.contains('uov') ||
        u.contains('mazzetto') ||
        u.contains('steli') ||
        u.contains('ramett') ||
        u.contains('bustina') ||
        u == 'litro' ||
        u == 'l';

    if (isCount) {
      if (value >= 1) return value.roundToDouble();
      if (value >= 0.5) return 0.5;
      return double.parse(value.toStringAsFixed(2));
    }

    if (value >= 100) {
      return (value / 10).roundToDouble() * 10;
    }
    if (value >= 10) {
      return (value / 5).roundToDouble() * 5;
    }
    if (value >= 1) {
      return (value * 2).roundToDouble() / 2;
    }
    return double.parse(value.toStringAsFixed(1));
  }

  static String formatQuantity(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    if ((value * 2).roundToDouble() == value * 2) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }

  /// Parse ingredient string to extract name, quantity, and unit
  /// Expected format: "Nome, quantitàunità" (e.g., "Farina, 200g")
  static Map<String, dynamic> parseIngredient(String ingredient) {
    final parts = ingredient.split(',');
    if (parts.length < 2) {
      return {
        'name': ingredient.trim(),
        'quantity': 0,
        'unit': '',
      };
    }

    final name = parts[0].trim();
    final quantityPart = parts[1].trim();
    
    // Extract numeric value and unit
    final regex = RegExp(r'(\d+\.?\d*)\s*([a-zA-Z]*)');
    final match = regex.firstMatch(quantityPart);
    
    if (match != null) {
      final quantity = double.tryParse(match.group(1) ?? '0') ?? 0;
      final unit = match.group(2) ?? '';
      return {
        'name': name,
        'quantity': quantity,
        'unit': unit.toLowerCase(),
      };
    }
    
    return {
      'name': name,
      'quantity': 0,
      'unit': '',
    };
  }

  /// Sum quantities of ingredients with the same name and unit
  /// Returns a map of ingredient names to their total quantities with units
  static Map<String, Map<String, double>> sumIngredients(List<String> ingredients) {
    final Map<String, Map<String, double>> totals = {};
    
    for (final ingredient in ingredients) {
      final parsed = parseIngredient(ingredient);
      final name = parsed['name'] as String;
      final quantity = parsed['quantity'] as double;
      final unit = parsed['unit'] as String;
      
      if (!totals.containsKey(name)) {
        totals[name] = {};
      }
      
      if (!totals[name]!.containsKey(unit)) {
        totals[name]![unit] = 0;
      }
      
      totals[name]![unit] = totals[name]![unit]! + quantity;
    }
    
    return totals;
  }

  /// Convert units for summation
  /// Basic conversions for common cooking units
  static double convertUnit(double value, String fromUnit, String toUnit) {
    final conversions = {
      // Weight conversions (base: grams)
      'g': 1.0,
      'kg': 1000.0,
      'mg': 0.001,
      'oz': 28.3495,
      'lb': 453.592,
      
      // Volume conversions (base: ml)
      'ml': 1.0,
      'l': 1000.0,
      'cl': 10.0,
      'dl': 100.0,
      'cup': 236.588,
      'tbsp': 14.7868,
      'tsp': 4.92892,
      
      // Count units (no conversion)
      'pezzi': 1.0,
      'unità': 1.0,
      '': 1.0,
    };
    
    final fromFactor = conversions[fromUnit.toLowerCase()] ?? 1.0;
    final toFactor = conversions[toUnit.toLowerCase()] ?? 1.0;
    
    // Convert to base unit, then to target unit
    final baseValue = value * fromFactor;
    return baseValue / toFactor;
  }

  /// Format ingredient for display
  static String formatIngredient(String name, double quantity, String unit) {
    // Round to 2 decimal places if needed
    final displayQuantity = quantity == quantity.truncate() 
        ? quantity.toInt() 
        : quantity.toStringAsFixed(2);
    
    return '$name, $displayQuantity$unit';
  }

  /// Sum ingredients from multiple recipes and return formatted list
  static List<String> sumAndFormatIngredients(List<List<String>> recipeIngredients) {
    final allIngredients = recipeIngredients.expand((list) => list).toList();
    final totals = sumIngredients(allIngredients);
    
    final result = <String>[];
    totals.forEach((name, units) {
      units.forEach((unit, quantity) {
        result.add(formatIngredient(name, quantity, unit));
      });
    });
    
    return result;
  }
}
