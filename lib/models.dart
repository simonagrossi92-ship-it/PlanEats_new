import 'dart:convert';

enum IngredientCategory {
  ortofrutta,
  carne,
  pesce,
  latticini,
  panetteria,
  surgelati,
  dispensa,
  bevande,
  prodottiAnimali,
  curaCasa,
  igienePersonale,
  altro,
}

enum DietType {
  nessuna('Nessuna dieta specifica'),
  vegetariana('Vegetariana'),
  vegana('Vegana'),
  mediterranea('Mediterranea'),
  chetogenica('Chetogenica'),
  paleo('Paleo'),
  senzaGlutine('Senza glutine'),
  senzaLattosio('Senza lattosio'),
  lowCarb('Low carb'),
  altri('Altra');

  const DietType(this.displayName);
  final String displayName;
}

enum AppUsageLevel {
  principiante('Principiante', 0),
  intermedio('Intermedio', 1),
  avanzato('Avanzato', 2),
  esperto('Esperto', 3);

  const AppUsageLevel(this.displayName, this.level);
  final String displayName;
  final int level;
}

class Badge {
  Badge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.earnedDate,
  });

  final String id;
  final String name;
  final String description;
  final String icon;
  final DateTime earnedDate;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'icon': icon,
        'earnedDate': earnedDate.toIso8601String(),
      };

  static Badge fromJson(Map<String, dynamic> json) => Badge(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? '🏆',
        earnedDate: DateTime.parse(
            json['earnedDate'] as String? ?? DateTime.now().toIso8601String()),
      );

  String get formattedDate {
    final day = earnedDate.day.toString().padLeft(2, '0');
    final month = earnedDate.month.toString().padLeft(2, '0');
    final year = earnedDate.year;
    return '$day/$month/$year';
  }
}

enum ExpenseCategory {
  alimentari,
  casa,
  ristoranti,
  trasporti,
  salute,
  intrattenimento,
  abbigliamento,
}

String ingredientCategoryLabel(IngredientCategory c) {
  switch (c) {
    case IngredientCategory.ortofrutta:
      return 'Ortofrutta';
    case IngredientCategory.carne:
      return 'Carne';
    case IngredientCategory.pesce:
      return 'Pesce';
    case IngredientCategory.latticini:
      return 'Latticini';
    case IngredientCategory.panetteria:
      return 'Panetteria';
    case IngredientCategory.surgelati:
      return 'Surgelati';
    case IngredientCategory.dispensa:
      return 'Dispensa';
    case IngredientCategory.bevande:
      return 'Bevande';
    case IngredientCategory.prodottiAnimali:
      return 'Prodotti per animali';
    case IngredientCategory.curaCasa:
      return 'Cura della casa';
    case IngredientCategory.igienePersonale:
      return 'Igiene personale';
    case IngredientCategory.altro:
      return 'Altro';
  }
}

String expenseCategoryLabel(ExpenseCategory c) {
  switch (c) {
    case ExpenseCategory.alimentari:
      return 'Alimentari';
    case ExpenseCategory.casa:
      return 'Cura della casa';
    case ExpenseCategory.ristoranti:
      return 'Sgarri / Ristoranti';
    case ExpenseCategory.trasporti:
      return 'Trasporti';
    case ExpenseCategory.salute:
      return 'Salute';
    case ExpenseCategory.intrattenimento:
      return 'Intrattenimento';
    case ExpenseCategory.abbigliamento:
      return 'Abbigliamento';
  }
}

String expenseCategoryEmoji(ExpenseCategory c) {
  switch (c) {
    case ExpenseCategory.alimentari:
      return '🍏';
    case ExpenseCategory.casa:
      return '🧴';
    case ExpenseCategory.ristoranti:
      return '🍕';
    case ExpenseCategory.trasporti:
      return '🚗';
    case ExpenseCategory.salute:
      return '💊';
    case ExpenseCategory.intrattenimento:
      return '🎬';
    case ExpenseCategory.abbigliamento:
      return '👕';
  }
}

IngredientCategory ingredientCategoryFromString(String? s) {
  if (s == null) return IngredientCategory.altro;
  return IngredientCategory.values.firstWhere(
    (e) => e.name == s,
    orElse: () => IngredientCategory.altro,
  );
}

// Mappa IngredientCategory a ExpenseCategory per conversione spesa -> spese
ExpenseCategory mapIngredientToExpenseCategory(
    IngredientCategory ingredientCategory) {
  switch (ingredientCategory) {
    case IngredientCategory.ortofrutta:
    case IngredientCategory.carne:
    case IngredientCategory.pesce:
    case IngredientCategory.latticini:
    case IngredientCategory.panetteria:
    case IngredientCategory.surgelati:
    case IngredientCategory.dispensa:
    case IngredientCategory.bevande:
      return ExpenseCategory.alimentari;
    case IngredientCategory.curaCasa:
    case IngredientCategory.prodottiAnimali:
      return ExpenseCategory.casa;
    case IngredientCategory.igienePersonale:
      return ExpenseCategory.salute;
    case IngredientCategory.altro:
      return ExpenseCategory.alimentari;
  }
}

class Ingredient {
  Ingredient({
    required this.name,
    required this.category,
    this.quantity,
    this.unit,
    this.note,
  });

  final String name;
  final IngredientCategory category;
  final double? quantity;
  final String? unit;
  final String? note;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category.name,
        'quantity': quantity,
        'unit': unit,
        'note': note,
      };

  static Ingredient fromJson(Map<String, dynamic> json) => Ingredient(
        name: (json['name'] as String?) ?? '',
        category: ingredientCategoryFromString(json['category'] as String?),
        quantity: (json['quantity'] is num)
            ? (json['quantity'] as num).toDouble()
            : null,
        unit: json['unit'] as String?,
        note: json['note'] as String?,
      );
}

class Recipe {
  Recipe({
    required this.id,
    required this.title,
    required this.ingredients,
    this.note,
    this.category,
    this.servingType = ServingType.persone,
    this.likeCount = 0,
    this.imageUrl,
    this.categoriaPrincipale,
    this.sottocategoria,
    this.calorie,
    this.tempoPreparazione,
    this.difficolta,
    this.motivazione,
    this.tipo, // 'Ricettario' or 'Generata'
  });

  final String id;
  final String title;
  final List<Ingredient> ingredients;
  final String? note;
  final RecipeCategory? category;
  final ServingType servingType;
  final int likeCount;
  final String? imageUrl;
  final String? categoriaPrincipale;
  final String? sottocategoria;
  final int? calorie;
  final int? tempoPreparazione; // in minuti
  final String? difficolta; // facile, media, difficile
  final String? motivazione; // spiegazione della scelta
  final String? tipo; // 'Ricettario' or 'Generata'

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'ingredients': jsonEncode(ingredients.map((e) => e.toJson()).toList()),
        'note': note,
        'category': category?.name,
        'servingType': servingType.name,
        'likeCount': likeCount,
        'imageUrl': imageUrl,
        'categoriaPrincipale': categoriaPrincipale,
        'sottocategoria': sottocategoria,
        'calorie': calorie,
        'tempoPreparazione': tempoPreparazione,
        'difficolta': difficolta,
        'motivazione': motivazione,
        'tipo': tipo,
      };

  static Recipe fromJson(Map<String, dynamic> json) {
    List<Ingredient> ingredientsList = [];
    
    // Handle ingredients - can be either a JSON string or a list
    if (json['ingredients'] != null) {
      try {
        if (json['ingredients'] is String) {
          // If it's a string, decode it
          final decoded = jsonDecode(json['ingredients'] as String);
          if (decoded is List) {
            ingredientsList = decoded
                .whereType<Map>()
                .map((e) => Ingredient.fromJson(e.cast<String, dynamic>()))
                .toList();
          }
        } else if (json['ingredients'] is List) {
          // If it's already a list, use it directly
          ingredientsList = (json['ingredients'] as List)
              .whereType<Map>()
              .map((e) => Ingredient.fromJson(e.cast<String, dynamic>()))
              .toList();
        }
      } catch (e) {
        // If parsing fails, use empty list
        ingredientsList = [];
      }
    }
    
    return Recipe(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        ingredients: ingredientsList,
        note: json['note'] as String?,
        category: json['category'] != null
            ? RecipeCategory.values.firstWhere(
                (c) => c.name == json['category'],
                orElse: () => RecipeCategory.altre,
              )
            : null,
        servingType: json['servingType'] != null
            ? ServingType.values.firstWhere(
                (c) => c.name == json['servingType'],
                orElse: () => ServingType.persone,
              )
            : ServingType.persone,
        likeCount: (json['likeCount'] as int?) ?? 0,
        imageUrl: json['imageUrl'] as String?,
        categoriaPrincipale: json['categoriaPrincipale'] as String?,
        sottocategoria: json['sottocategoria'] as String?,
        calorie: json['calorie'] as int?,
        tempoPreparazione: json['tempoPreparazione'] as int?,
        difficolta: json['difficolta'] as String?,
        motivazione: json['motivazione'] as String?,
        tipo: json['tipo'] as String?,
    );
  }
}

enum RecipeCategory {
  antipasti('Antipasti'),
  primi('Primi Piatti'),
  secondi('Secondi'),
  contorni('Contorni'),
  dolci('Dolci'),
  altre('Altre Ricette'),
  preferiti('I miei preferiti'),
  topSettimana('Top della settimana');

  const RecipeCategory(this.displayName);
  final String displayName;
}

class CategoriaRicetta {
  CategoriaRicetta({
    required this.nome,
    required this.sottocategorie,
  });

  final String nome;
  final List<String> sottocategorie;

  // Lista delle categorie principali con le loro sottocategorie
  static final List<CategoriaRicetta> categorie = [
    CategoriaRicetta(
      nome: 'Antipasti',
      sottocategorie: [
        'Crudité',
        'Fritti',
        'Stuzzichini',
        'Bruschette',
        'Tartine'
      ],
    ),
    CategoriaRicetta(
      nome: 'Primi Piatti',
      sottocategorie: ['Pasta', 'Riso', 'Zuppe', 'Gnocchi', 'Crespelle'],
    ),
    CategoriaRicetta(
      nome: 'Secondi',
      sottocategorie: ['Carne', 'Pesce', 'Uova', 'Legumi', 'Formaggi'],
    ),
    CategoriaRicetta(
      nome: 'Contorni',
      sottocategorie: ['Verdure', 'Insalate', 'Patate', 'Legumi'],
    ),
    CategoriaRicetta(
      nome: 'Dolci',
      sottocategorie: ['Torte', 'Biscotti', 'Gelati', 'Mousse', 'Frutta'],
    ),
    CategoriaRicetta(
      nome: 'Altre Ricette',
      sottocategorie: ['Salse', 'Conservazioni', 'Bevande', 'Altro'],
    ),
  ];

  // Ottieni sottocategorie per una categoria principale
  static List<String> getSottocategorie(String categoriaPrincipale) {
    final categoria = categorie.firstWhere(
      (c) => c.nome == categoriaPrincipale,
      orElse: () => CategoriaRicetta(
        nome: categoriaPrincipale,
        sottocategorie: [],
      ),
    );
    return categoria.sottocategorie;
  }

  // Converti da RecipeCategory enum a nome stringa
  static String fromRecipeCategory(RecipeCategory category) {
    switch (category) {
      case RecipeCategory.antipasti:
        return 'Antipasti';
      case RecipeCategory.primi:
        return 'Primi Piatti';
      case RecipeCategory.secondi:
        return 'Secondi';
      case RecipeCategory.contorni:
        return 'Contorni';
      case RecipeCategory.dolci:
        return 'Dolci';
      case RecipeCategory.altre:
        return 'Altre Ricette';
      case RecipeCategory.preferiti:
        return 'I miei preferiti';
      case RecipeCategory.topSettimana:
        return 'Top della settimana';
    }
  }
}

enum ServingType {
  persone('Persone'),
  porzioni('Porzioni'),
  torta('Torta'),
  teglia('Teglia'),
  bottiglia('Bottiglia'),
  vassoio('Vassoio');

  const ServingType(this.displayName);
  final String displayName;
}

enum MealType { colazione, pranzo, cena, snack }

String mealTypeLabel(MealType t) {
  switch (t) {
    case MealType.colazione:
      return 'Colazione';
    case MealType.pranzo:
      return 'Pranzo';
    case MealType.cena:
      return 'Cena';
    case MealType.snack:
      return 'Extra / Snack';
  }
}

class MealItem {
  MealItem({this.recipeId, this.customTitle, this.numberOfServings = 1});

  final String? recipeId;
  final String? customTitle;
  final int numberOfServings;

  bool get isEmpty =>
      (recipeId == null || recipeId!.isEmpty) &&
      (customTitle == null || customTitle!.trim().isEmpty);

  String displayTitle({Recipe? recipe}) {
    if (recipeId != null && recipe != null) return recipe.title;
    if (customTitle != null && customTitle!.trim().isNotEmpty) {
      return customTitle!.trim();
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
        'recipeId': recipeId,
        'customTitle': customTitle,
        'numberOfServings': numberOfServings,
      };

  static MealItem fromJson(Map<String, dynamic> json) {
    // Gestione sicura per dati vecchi che potrebbero non avere tutti i campi
    try {
      return MealItem(
        recipeId: json['recipeId'] as String?,
        customTitle: json['customTitle'] as String?,
        numberOfServings: (json['numberOfServings'] as int?) ?? 1,
      );
    } catch (e) {
      // In caso di errore, ritorna un MealItem vuoto con valori di default
      return MealItem(
        recipeId: json['recipeId'] as String?,
        customTitle: json['customTitle'] as String?,
        numberOfServings: 1,
      );
    }
  }
}

class MealEntry {
  MealEntry({this.items = const []});

  final List<MealItem> items;

  bool get isEmpty => items.isEmpty || items.every((item) => item.isEmpty);

  List<String> displayTitles({Map<String, Recipe>? recipes}) {
    return items
        .map((item) => item.displayTitle(
            recipe: item.recipeId != null && recipes != null
                ? recipes[item.recipeId]
                : null))
        .where((title) => title.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toJson() => {
        'items': items.map((e) => e.toJson()).toList(),
      };

  static MealEntry fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List?;
    final items = itemsJson
            ?.map((e) => MealItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return MealEntry(items: items);
  }

  // Metodi di compatibilità per il codice esistente
  String? get recipeId => items.isNotEmpty ? items.first.recipeId : null;
  String? get customTitle => items.isNotEmpty ? items.first.customTitle : null;

  String displayTitle({Recipe? recipe}) {
    if (items.isEmpty) return '';
    return items.first.displayTitle(recipe: recipe);
  }
}

class CustomProduct {
  CustomProduct({
    required this.name,
    required this.category,
    required this.price,
    required this.isWeight,
    this.unit,
    this.priceUnit,
    this.note,
  });

  final String name;
  final IngredientCategory category;
  final double price;
  final bool isWeight;
  final String? unit;
  final String? priceUnit;
  final String? note;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category.name,
        'price': price,
        'isWeight': isWeight,
        'unit': unit,
        'priceUnit': priceUnit,
        'note': note,
      };

  static CustomProduct fromJson(Map<String, dynamic> json) => CustomProduct(
        name: (json['name'] as String?) ?? '',
        category: ingredientCategoryFromString(json['category'] as String?),
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        isWeight: json['isWeight'] == true,
        unit: json['unit'] as String?,
        priceUnit: json['priceUnit'] as String?,
        note: json['note'] as String?,
      );
}

class ExpenseRecord {
  ExpenseRecord({
    required this.amount,
    required this.dateTime,
    this.note,
    this.category = ExpenseCategory.alimentari,
  });

  final double amount;
  final DateTime dateTime;
  final String? note;
  final ExpenseCategory category;

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'dateTime': dateTime.toIso8601String(),
        'note': note,
        'category': category.name,
      };

  static ExpenseRecord fromJson(Map<String, dynamic> json) => ExpenseRecord(
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        dateTime: DateTime.parse(
            json['dateTime'] as String? ?? DateTime.now().toIso8601String()),
        note: json['note'] as String?,
        category: json['category'] != null
            ? ExpenseCategory.values.firstWhere(
                (e) => e.name == json['category'],
                orElse: () => ExpenseCategory.alimentari,
              )
            : ExpenseCategory.alimentari,
      );

  String get formattedDate {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final year = dateTime.year;
    return '$day/$month/$year';
  }

  String get formattedTime {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get formattedDateTime => '$formattedDate $formattedTime';
}

enum BudgetStatus { verde, giallo, rosso }

class MonthlyBudget {
  MonthlyBudget({
    required this.year,
    required this.month,
    required this.amount,
    this.yellowThreshold = 0.8,
    this.redThreshold = 0.95,
  });

  final int year;
  final int month;
  final double amount;
  final double yellowThreshold;
  final double redThreshold;

  BudgetStatus getStatus(double currentSpending) {
    final percentage = currentSpending / amount;
    if (percentage >= redThreshold) return BudgetStatus.rosso;
    if (percentage >= yellowThreshold) return BudgetStatus.giallo;
    return BudgetStatus.verde;
  }

  double getRemainingAmount(double currentSpending) {
    return (amount - currentSpending).clamp(0.0, double.infinity);
  }

  double getPercentageUsed(double currentSpending) {
    return (currentSpending / amount).clamp(0.0, 1.0);
  }

  String get monthLabel {
    const months = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre'
    ];
    return months[month - 1];
  }

  String get monthKey => '$year-${month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'year': year,
        'month': month,
        'amount': amount,
        'yellowThreshold': yellowThreshold,
        'redThreshold': redThreshold,
      };

  static MonthlyBudget fromJson(Map<String, dynamic> json) => MonthlyBudget(
        year: (json['year'] as int?) ?? DateTime.now().year,
        month: (json['month'] as int?) ?? DateTime.now().month,
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        yellowThreshold: (json['yellowThreshold'] as num?)?.toDouble() ?? 0.8,
        redThreshold: (json['redThreshold'] as num?)?.toDouble() ?? 0.95,
      );
}

class ArchivedItem {
  ArchivedItem({
    required this.id,
    required this.name,
    required this.category,
    required this.archivedDate,
    this.quantity,
    this.unit,
    this.estimatedPrice,
    this.note,
  });

  final String id;
  final String name;
  final IngredientCategory category;
  final DateTime archivedDate;
  final double? quantity;
  final String? unit;
  final double? estimatedPrice;
  final String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'archivedDate': archivedDate.toIso8601String(),
        'quantity': quantity,
        'unit': unit,
        'estimatedPrice': estimatedPrice,
        'note': note,
      };

  static ArchivedItem fromJson(Map<String, dynamic> json) => ArchivedItem(
        id: json['id'] as String? ?? '',
        name: (json['name'] as String?) ?? '',
        category: ingredientCategoryFromString(json['category'] as String?),
        archivedDate: DateTime.parse(json['archivedDate'] as String? ??
            DateTime.now().toIso8601String()),
        quantity: (json['quantity'] is num)
            ? (json['quantity'] as num).toDouble()
            : null,
        unit: json['unit'] as String?,
        estimatedPrice: (json['estimatedPrice'] is num)
            ? (json['estimatedPrice'] as num).toDouble()
            : null,
        note: json['note'] as String?,
      );

  String get formattedDate {
    final day = archivedDate.day.toString().padLeft(2, '0');
    final month = archivedDate.month.toString().padLeft(2, '0');
    final year = archivedDate.year;
    return '$day/$month/$year';
  }

  String get formattedTime {
    final hour = archivedDate.hour.toString().padLeft(2, '0');
    final minute = archivedDate.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get formattedDateTime => '$formattedDate $formattedTime';
}

class PlanEatsData {
  PlanEatsData({
    required this.recipes,
    required this.weekPlans,
    required this.shoppingChecks,
    this.extraShoppingItems = const {},
    this.generatedShoppingList = const {},
    this.customProducts = const {},
    this.expenseRecords = const [],
    this.monthlyBudgets = const {},
    this.archivedItems = const [],
    this.favoriteRecipeIds = const [],
    this.estimatedPrices = const {},
    this.username = '',
    this.email = '',
    this.dietType = DietType.nessuna,
    this.allergies = const [],
    this.appUsageLevel = AppUsageLevel.principiante,
    this.badges = const [],
  });

  final List<Recipe> recipes;

  /// weekPlans: { "YYYY-MM-DD" : { "colazione": {..}, "pranzo": {..}, ... } }
  final Map<String, Map<String, MealEntry>> weekPlans;

  /// shoppingChecks: { "YYYY-MM-DD" (lunedì) : { "itemKey": true/false } }
  final Map<String, Map<String, bool>> shoppingChecks;

  /// extraShoppingItems: { "YYYY-MM-DD" (lunedì) : [Ingredient, Ingredient, ...] }
  final Map<String, List<Ingredient>> extraShoppingItems;

  /// generatedShoppingList: { "YYYY-MM-DD" (lunedì) : [Ingredient, Ingredient, ...] }
  final Map<String, List<Ingredient>> generatedShoppingList;

  /// customProducts: { "nome_prodotto_minusc": CustomProduct }
  final Map<String, CustomProduct> customProducts;

  /// expenseRecords: [ExpenseRecord, ExpenseRecord, ...]
  final List<ExpenseRecord> expenseRecords;

  /// monthlyBudgets: { "YYYY-MM": MonthlyBudget }
  final Map<String, MonthlyBudget> monthlyBudgets;

  /// archivedItems: [ArchivedItem, ArchivedItem, ...]
  final List<ArchivedItem> archivedItems;

  /// favoriteRecipeIds: [recipeId, recipeId, ...]
  final List<String> favoriteRecipeIds;

  /// estimatedPrices: { "YYYY-MM-DD" (lunedì) : "12.50" }
  final Map<String, String> estimatedPrices;

  /// username: nome utente dell'utente
  final String username;

  /// email: email dell'utente
  final String email;

  /// dietType: tipo di dieta dell'utente
  final DietType dietType;

  /// allergies: lista delle allergie dell'utente
  final List<String> allergies;

  /// appUsageLevel: livello di utilizzo dell'app
  final AppUsageLevel appUsageLevel;

  /// badges: badge conquistati dall'utente
  final List<Badge> badges;

  factory PlanEatsData.empty() => PlanEatsData(
        recipes: <Recipe>[],
        weekPlans: <String, Map<String, MealEntry>>{},
        shoppingChecks: <String, Map<String, bool>>{},
        extraShoppingItems: const {},
        generatedShoppingList: const {},
        customProducts: const {},
        expenseRecords: const [],
        monthlyBudgets: const {},
        archivedItems: const [],
        favoriteRecipeIds: const [],
        estimatedPrices: const {},
      );

  Map<String, dynamic> toJson() => {
        'recipes': recipes.map((e) => e.toJson()).toList(),
        'weekPlans': weekPlans.map(
          (day, meals) =>
              MapEntry(day, meals.map((k, v) => MapEntry(k, v.toJson()))),
        ),
        'shoppingChecks':
            shoppingChecks.map((week, checks) => MapEntry(week, checks)),
        'extraShoppingItems': extraShoppingItems.map(
          (week, items) =>
              MapEntry(week, items.map((e) => e.toJson()).toList()),
        ),
        'generatedShoppingList': generatedShoppingList.map(
          (week, items) =>
              MapEntry(week, items.map((e) => e.toJson()).toList()),
        ),
        'customProducts': customProducts.map(
          (key, product) => MapEntry(key, product.toJson()),
        ),
        'expenseRecords': expenseRecords.map((e) => e.toJson()).toList(),
        'monthlyBudgets': monthlyBudgets.map(
          (key, budget) => MapEntry(key, budget.toJson()),
        ),
        'archivedItems': archivedItems.map((e) => e.toJson()).toList(),
        'favoriteRecipeIds': favoriteRecipeIds,
        'estimatedPrices': estimatedPrices,
        'username': username,
        'email': email,
        'dietType': dietType.name,
        'allergies': allergies,
        'appUsageLevel': appUsageLevel.name,
        'badges': badges.map((e) => e.toJson()).toList(),
      };

  static PlanEatsData fromJson(Map<String, dynamic> json) {
    final recipes = ((json['recipes'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Recipe.fromJson(e.cast<String, dynamic>()))
        .toList();

    final weekPlansRaw = (json['weekPlans'] as Map?) ?? {};
    final weekPlans = <String, Map<String, MealEntry>>{};
    for (final entry in weekPlansRaw.entries) {
      final day = entry.key.toString();
      final mealsRaw = entry.value;
      if (mealsRaw is Map) {
        weekPlans[day] = mealsRaw.map((k, v) => MapEntry(k.toString(),
            MealEntry.fromJson((v as Map).cast<String, dynamic>())));
      }
    }

    final shoppingChecksRaw = (json['shoppingChecks'] as Map?) ?? {};
    final shoppingChecks = <String, Map<String, bool>>{};
    for (final entry in shoppingChecksRaw.entries) {
      final week = entry.key.toString();
      final checksRaw = entry.value;
      if (checksRaw is Map) {
        shoppingChecks[week] =
            checksRaw.map((k, v) => MapEntry(k.toString(), v == true));
      }
    }

    final extraShoppingItemsRaw = (json['extraShoppingItems'] as Map?) ?? {};
    final extraShoppingItems = <String, List<Ingredient>>{};
    for (final entry in extraShoppingItemsRaw.entries) {
      final week = entry.key.toString();
      final itemsRaw = entry.value;
      if (itemsRaw is List) {
        extraShoppingItems[week] = itemsRaw
            .whereType<Map>()
            .map((e) => Ingredient.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }

    final generatedShoppingListRaw =
        (json['generatedShoppingList'] as Map?) ?? {};
    final generatedShoppingList = <String, List<Ingredient>>{};
    for (final entry in generatedShoppingListRaw.entries) {
      final week = entry.key.toString();
      final itemsRaw = entry.value;
      if (itemsRaw is List) {
        generatedShoppingList[week] = itemsRaw
            .whereType<Map>()
            .map((e) => Ingredient.fromJson(e.cast<String, dynamic>()))
            .toList();
      }
    }

    // Caricamento customProducts
    final customProductsRaw = (json['customProducts'] as Map?) ?? {};
    final customProducts = <String, CustomProduct>{};
    for (final entry in customProductsRaw.entries) {
      try {
        final product =
            CustomProduct.fromJson(entry.value as Map<String, dynamic>);
        customProducts[entry.key] = product;
      } catch (e) {
        // Ignora prodotti corrotti
        continue;
      }
    }

    // Caricamento expenseRecords
    final expenseRecordsRaw = (json['expenseRecords'] as List?) ?? [];
    final expenseRecords = <ExpenseRecord>[];
    for (final item in expenseRecordsRaw) {
      try {
        final record = ExpenseRecord.fromJson(item as Map<String, dynamic>);
        expenseRecords.add(record);
      } catch (e) {
        // Ignora record corrotti
        continue;
      }
    }

    // Caricamento monthlyBudgets
    final monthlyBudgetsRaw = (json['monthlyBudgets'] as Map?) ?? {};
    final monthlyBudgets = <String, MonthlyBudget>{};
    for (final entry in monthlyBudgetsRaw.entries) {
      try {
        final budget =
            MonthlyBudget.fromJson(entry.value as Map<String, dynamic>);
        monthlyBudgets[entry.key] = budget;
      } catch (e) {
        // Ignora budget corrotti
        continue;
      }
    }

    // Caricamento archivedItems
    final archivedItemsRaw = (json['archivedItems'] as List?) ?? [];
    final archivedItems = <ArchivedItem>[];
    for (final item in archivedItemsRaw) {
      try {
        final archivedItem =
            ArchivedItem.fromJson(item as Map<String, dynamic>);
        archivedItems.add(archivedItem);
      } catch (e) {
        // Ignora item corrotti
        continue;
      }
    }

    // Caricamento estimatedPrices
    final estimatedPricesRaw = (json['estimatedPrices'] as Map?) ?? {};
    final estimatedPrices = <String, String>{};
    for (final entry in estimatedPricesRaw.entries) {
      estimatedPrices[entry.key.toString()] = entry.value.toString();
    }

    return PlanEatsData(
      recipes: recipes,
      weekPlans: weekPlans,
      shoppingChecks: shoppingChecks,
      extraShoppingItems: extraShoppingItems,
      generatedShoppingList: generatedShoppingList,
      customProducts: customProducts,
      expenseRecords: expenseRecords,
      monthlyBudgets: monthlyBudgets,
      archivedItems: archivedItems,
      favoriteRecipeIds: ((json['favoriteRecipeIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      estimatedPrices: estimatedPrices,
      username: (json['username'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      dietType: DietType.values.firstWhere(
        (e) => e.name == json['dietType'],
        orElse: () => DietType.nessuna,
      ),
      allergies: ((json['allergies'] as List?) ?? const [])
          .whereType<String>()
          .toList(),
      appUsageLevel: AppUsageLevel.values.firstWhere(
        (e) => e.name == json['appUsageLevel'],
        orElse: () => AppUsageLevel.principiante,
      ),
      badges: ((json['badges'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => Badge.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(toJson());
}
