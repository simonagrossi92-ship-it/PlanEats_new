import 'dart:convert';
import 'package:http/http.dart' as http;

class TranslationService {
  // Simple translation dictionary for common food terms
  static const Map<String, String> _foodDictionary = {
    'pasta': 'pasta',
    'pizza': 'pizza',
    'rice': 'riso',
    'chicken': 'pollo',
    'beef': 'manzo',
    'fish': 'pesce',
    'salad': 'insalata',
    'soup': 'zuppa',
    'bread': 'pane',
    'cake': 'torta',
    'cookie': 'biscotto',
    'sandwich': 'panino',
    'burger': 'hamburger',
    'fries': 'patatine',
    'steak': 'bistecca',
    'roast': 'arrosto',
    'grilled': 'alla griglia',
    'baked': 'al forno',
    'fried': 'fritto',
    'boiled': 'bollito',
    'fresh': 'fresco',
    'spicy': 'piccante',
    'sweet': 'dolce',
    'salty': 'salato',
    'sour': 'acido',
    'bitter': 'amaro',
    'creamy': 'cremoso',
    'crispy': 'croccante',
    'tender': 'tenero',
    'juicy': 'succoso',
    'dry': 'asciutto',
    'hot': 'caldo',
    'cold': 'freddo',
    'warm': 'tiepido',
    'delicious': 'delizioso',
    'tasty': 'saporito',
    'yummy': 'buono',
    'homemade': 'fatto in casa',
    'traditional': 'tradizionale',
    'classic': 'classico',
    'modern': 'moderno',
    'simple': 'semplice',
    'easy': 'facile',
    'quick': 'veloce',
    'healthy': 'salutare',
    'organic': 'biologico',
    'vegetarian': 'vegetariano',
    'vegan': 'vegano',
    'gluten-free': 'senza glutine',
    'dairy-free': 'senza latticini',
    'breakfast': 'colazione',
    'lunch': 'pranzo',
    'dinner': 'cena',
    'snack': 'spuntino',
    'appetizer': 'antipasto',
    'main course': 'piatto principale',
    'side dish': 'contorno',
    'dessert': 'dolce',
    'drink': 'bevanda',
    'sauce': 'salsa',
    'dressing': 'condimento',
    'spice': 'spezia',
    'herb': 'erba aromatica',
    'vegetable': 'verdura',
    'fruit': 'frutta',
    'meat': 'carne',
    'seafood': 'frutti di mare',
    'cheese': 'formaggio',
    'egg': 'uovo',
    'milk': 'latte',
    'butter': 'burro',
    'oil': 'olio',
    'salt': 'sale',
    'pepper': 'pepe',
    'sugar': 'zucchero',
    'flour': 'farina',
    'water': 'acqua',
    'wine': 'vino',
    'beer': 'birra',
    'coffee': 'caffè',
    'tea': 'tè',
    'juice': 'succo',
    'lemon': 'limone',
    'orange': 'arancia',
    'apple': 'mela',
    'banana': 'banana',
    'tomato': 'pomodoro',
    'onion': 'cipolla',
    'garlic': 'aglio',
    'potato': 'patata',
    'carrot': 'carota',
    'cucumber': 'cetriolo',
    'bell pepper': 'peperone',
    'mushroom': 'fungo',
    'spinach': 'spinacio',
    'broccoli': 'broccoli',
    'cauliflower': 'cavolfiore',
    'cabbage': 'cavolo',
    'lettuce': 'lattuga',
    'beans': 'fagioli',
    'peas': 'piselli',
    'corn': 'mais',
    'noodles': 'noodles',
    'tortilla': 'tortilla',
    'wrap': 'wrap',
    'taco': 'taco',
    'burrito': 'burrito',
    'quesadilla': 'quesadilla',
    'sushi': 'sushi',
    'ramen': 'ramen',
    'curry': 'curry',
    'stir-fry': 'saltato',
    'grill': 'griglia',
    'barbecue': 'barbecue',
    'smoked': 'affumicato',
    'pickled': 'sottaceto',
    'canned': 'in scatola',
    'frozen': 'surgelato',
    'dried': 'essiccato',
    'raw': 'crudo',
    'cooked': 'cotto',
    'seasoned': 'condito',
    'marinated': 'marinato',
    'glazed': 'glassato',
    'breaded': 'impanato',
    'stuffed': 'farcito',
    'topped': 'guarnito',
    'filled': 'ripieno',
    'wrapped': 'avvolto',
    'rolled': 'arrotolato',
    'sliced': 'affettato',
    'chopped': 'tritato',
    'diced': 'a dadini',
    'minced': 'tritato finemente',
    'crushed': 'schiacciato',
    'mashed': 'schiacciato',
    'pureed': 'passato',
    'blended': 'frullato',
    'whisked': 'sbattuto',
    'beaten': 'sbattuto',
    'folded': 'incorporato',
    'mixed': 'mescolato',
    'combined': 'combinato',
    'separated': 'separato',
    'divided': 'diviso',
  };

  // Simple translation using dictionary
  String translateSimple(String text) {
    final words = text.toLowerCase().split(' ');
    final translatedWords = words.map((word) {
      // Remove punctuation
      final cleanWord = word.replaceAll(RegExp(r'[^\w]'), '');
      return _foodDictionary[cleanWord] ?? word;
    }).toList();

    return translatedWords.join(' ');
  }

  // Improved translation with common food phrases
  String translateFoodPhrase(String text) {
    final lowerText = text.toLowerCase();

    // Common food phrases
    final phrases = {
      'chicken breast': 'petto di pollo',
      'chicken thighs': 'cosce di pollo',
      'beef steak': 'bistecca di manzo',
      'pork chops': 'braciole di maiale',
      'ground beef': 'manzo macinato',
      'olive oil': 'olio d\'oliva',
      'vegetable oil': 'olio vegetale',
      'sea salt': 'sale marino',
      'black pepper': 'pepe nero',
      'red pepper': 'peperoncino',
      'green pepper': 'peperone verde',
      'sweet potato': 'patata dolce',
      'red onion': 'cipolla rossa',
      'yellow onion': 'cipolla gialla',
      'white onion': 'cipolla bianca',
      'garlic clove': 'spicchio d\'aglio',
      'fresh basil': 'basilico fresco',
      'fresh parsley': 'prezzemolo fresco',
      'fresh rosemary': 'rosmarino fresco',
      'dried oregano': 'origano secco',
      'parmesan cheese': 'parmigiano',
      'mozzarella cheese': 'mozzarella',
      'cheddar cheese': 'cheddar',
      'cream cheese': 'formaggio spalmabile',
      'ricotta cheese': 'ricotta',
      'gorgonzola cheese': 'gorgonzola',
      'heavy cream': 'panna da cucina',
      'whipping cream': 'panna da montare',
      'whole milk': 'latte intero',
      'skim milk': 'latte scremato',
      'almond milk': 'latte di mandorla',
      'coconut milk': 'latte di cocco',
      'soy milk': 'latte di soia',
      'all-purpose flour': 'farina 00',
      'bread flour': 'farina per pane',
      'whole wheat flour': 'farina integrale',
      'corn flour': 'farina di mais',
      'brown sugar': 'zucchero bruno',
      'white sugar': 'zucchero bianco',
      'powdered sugar': 'zucchero a velo',
      'cane sugar': 'zucchero di canna',
      'honey': 'miele',
      'maple syrup': 'sciroppo d\'acero',
      'vanilla extract': 'estratto di vaniglia',
      'baking powder': 'lievito in polvere',
      'baking soda': 'bicarbonato',
      'yeast': 'lievito',
      'egg yolk': 'tuorlo d\'uovo',
      'egg white': 'albume',
      'large egg': 'uovo grande',
      'medium egg': 'uovo medio',
      'small egg': 'uovo piccolo',
      'boiled egg': 'uovo sodo',
      'fried egg': 'uovo fritto',
      'scrambled eggs': 'uova strapazzate',
      'tomato sauce': 'salsa di pomodoro',
      'marinara sauce': 'salsa marinara',
      'bolognese sauce': 'ragù alla bolognese',
      'pesto sauce': 'salsa pesto',
      'alfredo sauce': 'salsa alfredo',
      'carbonara sauce': 'salsa carbonara',
      'white sauce': 'salsa bianca',
      'red sauce': 'salsa rossa',
      'meat sauce': 'salsa di carne',
      'cream sauce': 'salsa alla panna',
      'cheese sauce': 'salsa al formaggio',
      'garlic bread': 'pane all\'aglio',
      'french bread': 'pane francese',
      'italian bread': 'pane italiano',
      'sourdough bread': 'pane lievitato naturalmente',
      'whole wheat bread': 'pane integrale',
      'white bread': 'pane bianco',
      'bread crumbs': 'pangrattato',
      'bread crumb': 'briciola di pane',
      'pasta salad': 'insalata di pasta',
      'potato salad': 'insalata di patate',
      'chicken salad': 'insalata di pollo',
      'fruit salad': 'insalata di frutta',
      'green salad': 'insalata verde',
      'caesar salad': 'insalata cesare',
      'greek salad': 'insalata greca',
      'mixed greens': 'insalata mista',
      'iceberg lettuce': 'lattuga iceberg',
      'romaine lettuce': 'lattuga romana',
      'butter lettuce': 'lattuga burro',
      'leaf lettuce': 'lattuga a foglia',
      'arugula': 'ruchetta',
      'spinach leaves': 'foglie di spinacio',
      'kale': 'cavolo nero',
      'broccoli florets': 'cimette di broccoli',
      'cauliflower florets': 'cimette di cavolfiore',
      'green beans': 'fagiolini',
      'string beans': 'fagiolini',
      'snap peas': 'piselli mangiatutto',
      'snow peas': 'piselli snow',
      'sweet corn': 'mais dolce',
      'corn kernels': 'grani di mais',
      'baby corn': 'mais baby',
      'mushroom caps': 'cappucci di funghi',
      'mushroom stems': 'gambo di funghi',
      'button mushrooms': 'funghi champignon',
      'portobello mushrooms': 'funghi portobello',
      'shiitake mushrooms': 'funghi shiitake',
      'oyster mushrooms': 'funghi ostrica',
      'dried mushrooms': 'funghi secchi',
      'fresh mushrooms': 'funghi freschi',
      'chicken wings': 'ali di pollo',
      'chicken drumsticks': 'cosce di pollo',
      'whole chicken': 'pollo intero',
      'boneless chicken': 'pollo disossato',
      'skinless chicken': 'pollo senza pelle',
      'ground chicken': 'pollo macinato',
      'beef tenderloin': 'filetto di manzo',
      'beef ribs': 'costine di manzo',
      'beef brisket': 'petto di manzo',
      'beef chuck': 'spalla di manzo',
      'beef round': 'fesa di manzo',
      'beef sirloin': 'sirloin di manzo',
      'pork loin': 'lonza di maiale',
      'pork ribs': 'costine di maiale',
      'pork shoulder': 'spalla di maiale',
      'pork belly': 'pancetta di maiale',
      'ground pork': 'maiale macinato',
      'bacon strips': 'strisce di bacon',
      'bacon bits': 'briciole di bacon',
      'pancetta': 'pancetta',
      'prosciutto': 'prosciutto',
      'salami': 'salame',
      'ham': 'prosciutto cotto',
      'sausage links': 'salsicce',
      'italian sausage': 'salsiccia italiana',
      'breakfast sausage': 'salsiccia da colazione',
      'bratwurst': 'bratwurst',
      'chorizo': 'chorizo',
      'fish fillet': 'filetto di pesce',
      'fish steak': 'bistecca di pesce',
      'salmon fillet': 'filetto di salmone',
      'tuna steak': 'bistecca di tonno',
      'cod fillet': 'filetto di merluzzo',
      'halibut fillet': 'filetto di halibut',
      'tilapia fillet': 'filetto di tilapia',
      'shrimp': 'gamberi',
      'prawns': 'gamberoni',
      'scallops': 'capasante',
      'mussels': 'cozze',
      'clams': 'vongole',
      'oysters': 'ostriche',
      'lobster': 'aragosta',
      'crab': 'granchio',
      'crab legs': 'zampe di granchio',
      'calamari': 'calamari',
      'octopus': 'polpo',
      'squid': 'calamaro',
    };

    // Check for exact phrase matches first
    for (final phrase in phrases.entries) {
      if (lowerText.contains(phrase.key)) {
        return lowerText.replaceAll(phrase.key, phrase.value);
      }
    }

    // Fall back to word-by-word translation
    return translateSimple(text);
  }

  // Translate using LibreTranslate (free API)
  Future<String> translateWithLibre(String text,
      {String from = 'en', String to = 'it'}) async {
    try {
      final response = await http.post(
        Uri.parse('https://libretranslate.de/translate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'q': text,
          'source': from,
          'target': to,
          'format': 'text',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['translatedText'] ?? text;
      } else {
        // Fallback to simple translation
        return translateSimple(text);
      }
    } catch (e) {
      // Fallback to simple translation on error
      return translateSimple(text);
    }
  }

  // Main translation method - tries phrase translation first, then API, falls back to dictionary
  Future<String> translate(String text) async {
    // If text is already in Italian (contains Italian characters), return as is
    if (RegExp(r'[àèéìòù]').hasMatch(text.toLowerCase())) {
      return text;
    }

    // Try phrase translation first
    final phraseTranslation = translateFoodPhrase(text);
    if (phraseTranslation != text) {
      return phraseTranslation;
    }

    // Try API translation
    return await translateWithLibre(text);
  }
}
