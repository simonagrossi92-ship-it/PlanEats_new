import '../models.dart';

IngredientCategory suggestCategory(String name) {
  final n = name.toLowerCase().trim();
  if (n.isEmpty) return IngredientCategory.altro;

  // Mappatura parole chiave -> Categoria
  final map = <IngredientCategory, List<String>>{
    IngredientCategory.ortofrutta: [
      'mela',
      'pera',
      'banana',
      'fragol',
      'arancia',
      'limone',
      'insalata',
      'pomodor',
      'zucchina',
      'melanzana',
      'carota',
      'cipolla',
      'aglio',
      'patata',
      'verdura',
      'frutta',
      'basilico',
      'prezzemolo',
      'spinaci',
      'broccoli',
      'cavolo',
      'peperon'
    ],
    IngredientCategory.carne: [
      'carne',
      'pollo',
      'manzo',
      'maiale',
      'tacchino',
      'salsiccia',
      'hamburger',
      'prosciutto',
      'salame',
      'speck',
      'bacon',
      'pancetta',
      'vitello',
      'bistecca'
    ],
    IngredientCategory.pesce: [
      'pesce',
      'tonno',
      'salmone',
      'merluzzo',
      'gamber',
      'calamar',
      'cozze',
      'vongole',
      'orata',
      'spigola',
      'pescespada',
      'baccalà'
    ],
    IngredientCategory.latticini: [
      'latte',
      'uova',
      'formaggio',
      'mozzarella',
      'parmigiano',
      'burro',
      'yogurt',
      'panna',
      'stracchino',
      'ricotta',
      'gorgonzola',
      'pecorino'
    ],
    IngredientCategory.panetteria: [
      'pane',
      'panino',
      'focaccia',
      'pizza',
      'biscott',
      'cracker',
      'fetta biscottata',
      'brioche',
      'cornetto',
      'grissin',
      'piadina'
    ],
    IngredientCategory.surgelati: [
      'surgelat',
      'congelat',
      'gelato',
      'piselli',
      'bastoncini'
    ],
    IngredientCategory.dispensa: [
      'pasta',
      'riso',
      'farina',
      'zucchero',
      'sale',
      'olio',
      'aceto',
      'passata',
      'pelati',
      'legumi',
      'lenticchie',
      'ceci',
      'fagioli',
      'caffè',
      'tè',
      'spezie',
      'miele',
      'marmellata',
      'cioccolato',
      'dado',
      'lievito'
    ],
    IngredientCategory.bevande: [
      'acqua',
      'vino',
      'birra',
      'succo',
      'bibita',
      'cola',
      'aranciata',
      'the'
    ],
  };

  for (final entry in map.entries) {
    for (final keyword in entry.value) {
      if (n.contains(keyword)) {
        return entry.key;
      }
    }
  }

  return IngredientCategory.altro;
}

String? suggestUnit(String name) {
  final n = name.toLowerCase().trim();
  if (n.isEmpty) return null;

  // Suggerimenti unità basati su parole chiave
  final map = <String, List<String>>{
    'pz': [
      'uov',
      'uovo',
      'uova',
      'limone',
      'yogurt',
      'pezzo',
      'pezzi',
      'lattina',
      'bottiglia',
      'confezione',
      'pacco',
      'pacchi',
      'vasetto',
      'cubetto',
      'dado'
    ],
    'g': [
      'pasta',
      'riso',
      'farina',
      'zucchero',
      'sale',
      'burro',
      'ricotta',
      'carne',
      'macinato',
      'pollo',
      'pesce',
      'tonno',
      'prosciutto',
      'salame',
      'formaggio',
      'mozzarella',
      'parmigiano',
      'pane',
      'biscott'
    ],
    'ml': [
      'latte',
      'panna',
      'acqua',
      'vino',
      'birra',
      'olio',
      'aceto',
      'succo',
      'cola'
    ],
    'kg': ['patate', 'mele', 'pere', 'arance', 'anguria', 'zucca'],
  };

  for (final entry in map.entries) {
    for (final keyword in entry.value) {
      if (n.contains(keyword)) {
        return entry.key;
      }
    }
  }

  return null;
}
