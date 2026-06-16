import 'package:flutter/material.dart';

import '../models.dart';

/// Icone e colori per le categorie del ricettario.
abstract final class CategoryIcons {
  static IconData forName(String nome) {
    final lower = nome.toLowerCase();
    if (lower.contains('antipasto')) return Icons.set_meal_outlined;
    if (lower.contains('primo')) return Icons.rice_bowl_outlined;
    if (lower.contains('secondo')) return Icons.dinner_dining_outlined;
    if (lower.contains('contorno')) return Icons.spa_outlined;
    if (lower.contains('dolce')) return Icons.icecream_outlined;
    if (lower.contains('bevanda')) return Icons.local_cafe_outlined;
    if (lower.contains('snack')) return Icons.cookie_outlined;
    if (lower.contains('colazione')) return Icons.free_breakfast_outlined;
    if (lower.contains('altro')) return Icons.menu_book_outlined;
    return Icons.restaurant_menu_outlined;
  }

  static IconData forRecipeCategory(RecipeCategory category) {
    switch (category) {
      case RecipeCategory.antipasti:
        return Icons.set_meal_outlined;
      case RecipeCategory.primi:
        return Icons.rice_bowl_outlined;
      case RecipeCategory.secondi:
        return Icons.dinner_dining_outlined;
      case RecipeCategory.contorni:
        return Icons.spa_outlined;
      case RecipeCategory.dolci:
        return Icons.icecream_outlined;
      case RecipeCategory.altre:
        return Icons.menu_book_outlined;
      case RecipeCategory.preferiti:
        return Icons.favorite_outline;
      case RecipeCategory.topSettimana:
        return Icons.star_outline;
    }
  }

  static Color colorForName(String nome) {
    final lower = nome.toLowerCase();
    if (lower.contains('antipasto')) return const Color(0xFFE6A817);
    if (lower.contains('primo')) return const Color(0xFF5B8DEF);
    if (lower.contains('secondo')) return const Color(0xFFD97745);
    if (lower.contains('contorno')) return const Color(0xFF6BA368);
    if (lower.contains('dolce')) return const Color(0xFFE07A9F);
    if (lower.contains('bevanda')) return const Color(0xFF8B6BB8);
    if (lower.contains('snack')) return const Color(0xFF9E7B5B);
    if (lower.contains('colazione')) return const Color(0xFFDB9B4D);
    return const Color(0xFF8BA888);
  }
}
