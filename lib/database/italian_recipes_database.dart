import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ItalianRecipesDatabase {
  static final ItalianRecipesDatabase instance = ItalianRecipesDatabase._internal();
  factory ItalianRecipesDatabase() => instance;
  ItalianRecipesDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'ricette_complete.db');

    // Delete database file if it exists to ensure clean schema
    if (await databaseExists(path)) {
      await File(path).delete();
    }

    final db = await openDatabase(path);
    
    // Drop table if it exists to ensure clean schema
    try {
      await db.execute('DROP TABLE IF EXISTS ricette');
    } catch (e) {
      print('Error dropping table: $e');
    }
    
    // Crea tabella ricette con schema completo
    await db.execute('''
      CREATE TABLE ricette (
        id TEXT PRIMARY KEY,
        nome TEXT NOT NULL,
        ingredienti TEXT NOT NULL,
        note TEXT,
        immagine TEXT,
        categoria TEXT,
        sottocategoria TEXT,
        calorie INTEGER,
        tempo_preparazione INTEGER,
        difficolta TEXT
      )
    ''');
    
    return db;
  }

  Future<void> insertItalianRecipes() async {
    final db = await database;
    
    // Controlla se ci sono già ricette nel database
    final existingRecipes = await db.query('ricette');
    if (existingRecipes.isNotEmpty) {
      print('Il database contiene già ${existingRecipes.length} ricette');
      return;
    }
    
    final recipes = _getItalianRecipes();
    
    for (final recipe in recipes) {
      await db.insert('ricette', recipe);
    }
    
    print('Inserite ${recipes.length} ricette italiane nel database');
  }

  List<Map<String, dynamic>> _getItalianRecipes() {
    return [
      // Antipasti (10 ricette)
      {
        'id': 'antipasti_1',
        'nome': 'Bruschetta al pomodoro',
        'ingredienti': jsonEncode([
          {'name': 'Pane tostato', 'amount': 4, 'unit': 'fette'},
          {'name': 'Pomodori maturi', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Basilico fresco', 'amount': 10, 'unit': 'foglie'},
          {'name': 'Olio extra vergine', 'amount': 2, 'unit': 'cucchiai'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Tostare il pane e condirlo con pomodori tagliati a cubetti, basilico e olio',
        'immagine': 'https://images.unsplash.com/photo-1572695157366-5e585ab2b69f?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Bruschette',
      },
      {
        'id': 'antipasti_2',
        'nome': 'Caprese',
        'ingredienti': jsonEncode([
          {'name': 'Mozzarella', 'amount': 250, 'unit': 'g'},
          {'name': 'Pomodori', 'amount': 3, 'unit': 'pezzi'},
          {'name': 'Basilico', 'amount': 1, 'unit': 'mazzetto'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Tagliare mozzarella e pomodori a fette, disporre alternati con basilico',
        'immagine': 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Insalate',
      },
      {
        'id': 'antipasti_3',
        'nome': 'Carpaccio di manzo',
        'ingredienti': jsonEncode([
          {'name': 'Manzo', 'amount': 200, 'unit': 'g'},
          {'name': 'Rucola', 'amount': 50, 'unit': 'g'},
          {'name': 'Parmigiano', 'amount': 30, 'unit': 'g'},
          {'name': 'Limone', 'amount': 1, 'unit': 'succo'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
        ]),
        'note': 'Affettare la carne finemente, condire con limone, olio e parmigiano',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Carpaccio',
      },
      {
        'id': 'antipasti_4',
        'nome': 'Frittata di erbe',
        'ingredienti': jsonEncode([
          {'name': 'Uova', 'amount': 4, 'unit': 'pezzi'},
          {'name': 'Erbe aromatiche', 'amount': 50, 'unit': 'g'},
          {'name': 'Parmigiano', 'amount': 30, 'unit': 'g'},
          {'name': 'Burro', 'amount': 20, 'unit': 'g'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Sbattere le uova con le erbe e il parmigiano, cuocere in padella',
        'immagine': 'https://images.unsplash.com/photo-1525351484163-7529414395d8?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Uova',
      },
      {
        'id': 'antipasti_5',
        'nome': 'Prosciutto e melone',
        'ingredienti': jsonEncode([
          {'name': 'Prosciutto crudo', 'amount': 100, 'unit': 'g'},
          {'name': 'Melone', 'amount': 1, 'unit': 'pezzo'},
          {'name': 'Pepe nero', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Tagliare il melone a fette, avvolgere con il prosciutto',
        'immagine': 'https://images.unsplash.com/photo-1626200419199-391ae4be7a41?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Salumi',
      },
      {
        'id': 'antipasti_6',
        'nome': 'Insalata di mare',
        'ingredienti': jsonEncode([
          {'name': 'Polpo', 'amount': 300, 'unit': 'g'},
          {'name': 'Gamberi', 'amount': 200, 'unit': 'g'},
          {'name': 'Calamari', 'amount': 200, 'unit': 'g'},
          {'name': 'Limone', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
        ]),
        'note': 'Cuocere il pesce, condire con limone e olio',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'antipasti_7',
        'nome': 'Crostini al fegato',
        'ingredienti': jsonEncode([
          {'name': 'Fegato di pollo', 'amount': 200, 'unit': 'g'},
          {'name': 'Cipolla', 'amount': 1, 'unit': 'pezzo'},
          {'name': 'Vino rosso', 'amount': 100, 'unit': 'ml'},
          {'name': 'Pane tostato', 'amount': 20, 'unit': 'fette'},
          {'name': 'Burro', 'amount': 30, 'unit': 'g'},
        ]),
        'note': 'Cuocere il fegato con cipolla e vino, spalmare sul pane tostato',
        'immagine': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Crostini',
      },
      {
        'id': 'antipasti_8',
        'nome': 'Sformato di zucchine',
        'ingredienti': jsonEncode([
          {'name': 'Zucchine', 'amount': 500, 'unit': 'g'},
          {'name': 'Uova', 'amount': 3, 'unit': 'pezzi'},
          {'name': 'Parmigiano', 'amount': 50, 'unit': 'g'},
          {'name': 'Pangrattato', 'amount': 30, 'unit': 'g'},
          {'name': 'Burro', 'amount': 30, 'unit': 'g'},
        ]),
        'note': 'Grattugiare le zucchine, mescolare con uova e parmigiano, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1476718406336-bb5a9690ee2b?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Sformati',
      },
      {
        'id': 'antipasti_9',
        'nome': 'Tartare di salmone',
        'ingredienti': jsonEncode([
          {'name': 'Salmone fresco', 'amount': 200, 'unit': 'g'},
          {'name': 'Limone', 'amount': 1, 'unit': 'succo'},
          {'name': 'Capperi', 'amount': 10, 'unit': 'pezzi'},
          {'name': 'Erba cipollina', 'amount': 5, 'unit': 'steli'},
          {'name': 'Olio extra vergine', 'amount': 2, 'unit': 'cucchiai'},
        ]),
        'note': 'Tagliare il salmone a cubetti, condire con limone, capperi e erba cipollina',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'antipasti_10',
        'nome': 'Focaccia genovese',
        'ingredienti': jsonEncode([
          {'name': 'Farina', 'amount': 500, 'unit': 'g'},
          {'name': 'Acqua', 'amount': 300, 'unit': 'ml'},
          {'name': 'Lievito', 'amount': 10, 'unit': 'g'},
          {'name': 'Olio extra vergine', 'amount': 50, 'unit': 'ml'},
          {'name': 'Sale grosso', 'amount': 10, 'unit': 'g'},
        ]),
        'note': 'Impastare farina, acqua e lievito, lasciare lievitare, condire con olio e sale',
        'immagine': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Pane',
      },
      // Primi (15 ricette)
      {
        'id': 'primi_1',
        'nome': 'Spaghetti alla carbonara',
        'ingredienti': jsonEncode([
          {'name': 'Spaghetti', 'amount': 400, 'unit': 'g'},
          {'name': 'Guanciale', 'amount': 150, 'unit': 'g'},
          {'name': 'Uova', 'amount': 4, 'unit': 'pezzi'},
          {'name': 'Pecorino romano', 'amount': 80, 'unit': 'g'},
          {'name': 'Pepe nero', 'amount': 2, 'unit': 'pizzichi'},
        ]),
        'note': 'Cuocere la pasta, saltare con guanciale croccante, unire uova e pecorino',
        'immagine': 'https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_2',
        'nome': 'Pasta al pomodoro',
        'ingredienti': jsonEncode([
          {'name': 'Pasta', 'amount': 400, 'unit': 'g'},
          {'name': 'Pomodori San Marzano', 'amount': 500, 'unit': 'g'},
          {'name': 'Basilico', 'amount': 10, 'unit': 'foglie'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
          {'name': 'Aglio', 'amount': 2, 'unit': 'spicchi'},
        ]),
        'note': 'Cuocere i pomodori con aglio e olio, condire la pasta',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_3',
        'nome': 'Risotto alla milanese',
        'ingredienti': jsonEncode([
          {'name': 'Riso Arborio', 'amount': 300, 'unit': 'g'},
          {'name': 'Zafferano', 'amount': 1, 'unit': 'bustina'},
          {'name': 'Brodo vegetale', 'amount': 1, 'unit': 'litro'},
          {'name': 'Burro', 'amount': 50, 'unit': 'g'},
          {'name': 'Parmigiano', 'amount': 80, 'unit': 'g'},
        ]),
        'note': 'Tostare il riso, aggiungere brodo poco alla volta, mantecare con burro e parmigiano',
        'immagine': 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c1?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Riso',
      },
      {
        'id': 'primi_4',
        'nome': 'Pasta alle vongole',
        'ingredienti': jsonEncode([
          {'name': 'Linguine', 'amount': 400, 'unit': 'g'},
          {'name': 'Vongole', 'amount': 1, 'unit': 'kg'},
          {'name': 'Aglio', 'amount': 3, 'unit': 'spicchi'},
          {'name': 'Prezzemolo', 'amount': 1, 'unit': 'mazzetto'},
          {'name': 'Vino bianco', 'amount': 100, 'unit': 'ml'},
        ]),
        'note': 'Aprire le vongole in padella con aglio e vino, condire la pasta',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_5',
        'nome': 'Lasagne al forno',
        'ingredienti': jsonEncode([
          {'name': 'Sfoglia fresca', 'amount': 12, 'unit': 'foglie'},
          {'name': 'Ragù di manzo', 'amount': 500, 'unit': 'g'},
          {'name': 'Besciamella', 'amount': 500, 'unit': 'ml'},
          {'name': 'Parmigiano', 'amount': 100, 'unit': 'g'},
          {'name': 'Burro', 'amount': 30, 'unit': 'g'},
        ]),
        'note': 'Alternare sfoglia, ragù e besciamella, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1574868760432-f944a914d5b2?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta al forno',
      },
      {
        'id': 'primi_6',
        'nome': 'Gnocchi al pomodoro',
        'ingredienti': jsonEncode([
          {'name': 'Gnocchi di patate', 'amount': 500, 'unit': 'g'},
          {'name': 'Pomodoro', 'amount': 400, 'unit': 'g'},
          {'name': 'Basilico', 'amount': 8, 'unit': 'foglie'},
          {'name': 'Parmigiano', 'amount': 50, 'unit': 'g'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
        ]),
        'note': 'Cuocere gli gnocchi, condire con sugo di pomodoro e basilico',
        'immagine': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Gnocchi',
      },
      {
        'id': 'primi_7',
        'nome': 'Pasta alla norma',
        'ingredienti': jsonEncode([
          {'name': 'Maccheroni', 'amount': 400, 'unit': 'g'},
          {'name': 'Melanzane', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Pomodoro', 'amount': 400, 'unit': 'g'},
          {'name': 'Ricotta salata', 'amount': 50, 'unit': 'g'},
          {'name': 'Basilico', 'amount': 10, 'unit': 'foglie'},
        ]),
        'note': 'Friggere le melanzane, condire la pasta con pomodoro e melanzane',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_8',
        'nome': 'Ravioli di ricotta',
        'ingredienti': jsonEncode([
          {'name': 'Ravioli freschi', 'amount': 400, 'unit': 'g'},
          {'name': 'Burro', 'amount': 60, 'unit': 'g'},
          {'name': 'Salvia', 'amount': 5, 'unit': 'foglie'},
          {'name': 'Parmigiano', 'amount': 50, 'unit': 'g'},
          {'name': 'Noce moscata', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Cuocere i ravioli, saltare con burro e salvia, spolverare parmigiano',
        'immagine': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta fresca',
      },
      {
        'id': 'primi_9',
        'nome': 'Minestrone',
        'ingredienti': jsonEncode([
          {'name': 'Fagiolini', 'amount': 100, 'unit': 'g'},
          {'name': 'Carote', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Patate', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Zucchine', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Pasta', 'amount': 100, 'unit': 'g'},
        ]),
        'note': 'Cuocere le verdure in brodo, aggiungere la pasta a fine cottura',
        'immagine': 'https://images.unsplash.com/photo-1547592166-23acbe3a624b?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Zuppe',
      },
      {
        'id': 'primi_10',
        'nome': 'Pasta cacio e pepe',
        'ingredienti': jsonEncode([
          {'name': 'Spaghetti', 'amount': 400, 'unit': 'g'},
          {'name': 'Pecorino romano', 'amount': 100, 'unit': 'g'},
          {'name': 'Pepe nero', 'amount': 3, 'unit': 'pizzichi'},
          {'name': 'Acqua di cottura', 'amount': 100, 'unit': 'ml'},
        ]),
        'note': 'Creare una crema con pecorino e acqua di cottura, condire la pasta',
        'immagine': 'https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_11',
        'nome': 'Orecchiette alle cime di rapa',
        'ingredienti': jsonEncode([
          {'name': 'Orecchiette', 'amount': 400, 'unit': 'g'},
          {'name': 'Cime di rapa', 'amount': 500, 'unit': 'g'},
          {'name': 'Aglio', 'amount': 2, 'unit': 'spicchi'},
          {'name': 'Peperoncino', 'amount': 1, 'unit': 'pezzo'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
        ]),
        'note': 'Cuocere le cime di rapa, saltare con aglio e peperoncino, condire la pasta',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_12',
        'nome': 'Risotto ai funghi',
        'ingredienti': jsonEncode([
          {'name': 'Riso Carnaroli', 'amount': 300, 'unit': 'g'},
          {'name': 'Funghi porcini', 'amount': 200, 'unit': 'g'},
          {'name': 'Brodo vegetale', 'amount': 1, 'unit': 'litro'},
          {'name': 'Burro', 'amount': 40, 'unit': 'g'},
          {'name': 'Parmigiano', 'amount': 60, 'unit': 'g'},
        ]),
        'note': 'Saltare i funghi, tostare il riso, completare con brodo, mantecare',
        'immagine': 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c1?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Riso',
      },
      {
        'id': 'primi_13',
        'nome': 'Pasta alla puttanesca',
        'ingredienti': jsonEncode([
          {'name': 'Spaghetti', 'amount': 400, 'unit': 'g'},
          {'name': 'Pomodori', 'amount': 400, 'unit': 'g'},
          {'name': 'Acciughe', 'amount': 6, 'unit': 'filetti'},
          {'name': 'Capperi', 'amount': 20, 'unit': 'g'},
          {'name': 'Olive nere', 'amount': 50, 'unit': 'g'},
        ]),
        'note': 'Cuocere il sugo con pomodoro, acciughe, capperi e olive',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_14',
        'nome': 'Tortellini in brodo',
        'ingredienti': jsonEncode([
          {'name': 'Tortellini freschi', 'amount': 300, 'unit': 'g'},
          {'name': 'Brodo di carne', 'amount': 1, 'unit': 'litro'},
          {'name': 'Parmigiano', 'amount': 40, 'unit': 'g'},
          {'name': 'Noce moscata', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Cuocere i tortellini nel brodo bollente, servire con parmigiano',
        'immagine': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta fresca',
      },
      {
        'id': 'primi_15',
        'nome': 'Pasta e fagioli',
        'ingredienti': jsonEncode([
          {'name': 'Pasta mista', 'amount': 200, 'unit': 'g'},
          {'name': 'Fagioli borlotti', 'amount': 300, 'unit': 'g'},
          {'name': 'Pomodoro', 'amount': 200, 'unit': 'g'},
          {'name': 'Rosmarino', 'amount': 2, 'unit': 'rametti'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
        ]),
        'note': 'Cuocere i fagioli, aggiungere pomodoro e pasta',
        'immagine': 'https://images.unsplash.com/photo-1547592166-23acbe3a624b?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Zuppe',
      },
      // Secondi (15 ricette)
      {
        'id': 'secondi_1',
        'nome': 'Bistecca alla fiorentina',
        'ingredienti': jsonEncode([
          {'name': 'Manzo', 'amount': 800, 'unit': 'g'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
          {'name': 'Sale grosso', 'amount': 10, 'unit': 'g'},
          {'name': 'Pepe nero', 'amount': 2, 'unit': 'pizzichi'},
        ]),
        'note': 'Cuocere la bistecca alla griglia, condire con sale e pepe',
        'immagine': 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_2',
        'nome': 'Pollo alla cacciatora',
        'ingredienti': jsonEncode([
          {'name': 'Pollo', 'amount': 1, 'unit': 'kg'},
          {'name': 'Pomodori', 'amount': 400, 'unit': 'g'},
          {'name': 'Cipolla', 'amount': 1, 'unit': 'pezzo'},
          {'name': 'Vino rosso', 'amount': 200, 'unit': 'ml'},
          {'name': 'Rosmarino', 'amount': 2, 'unit': 'rametti'},
        ]),
        'note': 'Saltare il pollo con cipolla, aggiungere pomodoro e vino',
        'immagine': 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pollame',
      },
      {
        'id': 'secondi_3',
        'nome': 'Saltimbocca alla romana',
        'ingredienti': jsonEncode([
          {'name': 'Vitello', 'amount': 400, 'unit': 'g'},
          {'name': 'Prosciutto crudo', 'amount': 100, 'unit': 'g'},
          {'name': 'Salvia', 'amount': 8, 'unit': 'foglie'},
          {'name': 'Burro', 'amount': 40, 'unit': 'g'},
          {'name': 'Vino bianco', 'amount': 100, 'unit': 'ml'},
        ]),
        'note': 'Avvolgere la carne con prosciutto e salvia, cuocere con burro e vino',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_4',
        'nome': 'Pesce al cartoccio',
        'ingredienti': jsonEncode([
          {'name': 'Orata', 'amount': 600, 'unit': 'g'},
          {'name': 'Pomodori', 'amount': 200, 'unit': 'g'},
          {'name': 'Limone', 'amount': 1, 'unit': 'pezzo'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
          {'name': 'Prezzemolo', 'amount': 1, 'unit': 'mazzetto'},
        ]),
        'note': 'Disporre il pesce con pomodori e limone nella carta, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_5',
        'nome': 'Arista di maiale',
        'ingredienti': jsonEncode([
          {'name': 'Maiale', 'amount': 800, 'unit': 'g'},
          {'name': 'Rosmarino', 'amount': 3, 'unit': 'rametti'},
          {'name': 'Aglio', 'amount': 4, 'unit': 'spicchi'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
          {'name': 'Vino bianco', 'amount': 150, 'unit': 'ml'},
        ]),
        'note': 'Marinare la carne, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1432139555190-58524dae6a55?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_6',
        'nome': 'Cotoletta alla milanese',
        'ingredienti': jsonEncode([
          {'name': 'Vitello', 'amount': 400, 'unit': 'g'},
          {'name': 'Uova', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Pangrattato', 'amount': 100, 'unit': 'g'},
          {'name': 'Burro', 'amount': 60, 'unit': 'g'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Impanare la carne, friggere nel burro',
        'immagine': 'https://images.unsplash.com/photo-1632778149955-e80f8ceca2e8?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_7',
        'nome': 'Polpette al sugo',
        'ingredienti': jsonEncode([
          {'name': 'Manzo macinato', 'amount': 500, 'unit': 'g'},
          {'name': 'Pangrattato', 'amount': 100, 'unit': 'g'},
          {'name': 'Uova', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Pomodoro', 'amount': 500, 'unit': 'g'},
          {'name': 'Parmigiano', 'amount': 50, 'unit': 'g'},
        ]),
        'note': 'Formare le polpette, cuocere nel sugo di pomodoro',
        'immagine': 'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_8',
        'nome': 'Calamari fritti',
        'ingredienti': jsonEncode([
          {'name': 'Calamari', 'amount': 500, 'unit': 'g'},
          {'name': 'Farina', 'amount': 150, 'unit': 'g'},
          {'name': 'Uova', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Olio per friggere', 'amount': 500, 'unit': 'ml'},
          {'name': 'Limone', 'amount': 2, 'unit': 'pezzi'},
        ]),
        'note': 'Tagliare i calamari ad anelli, impanare, friggere',
        'immagine': 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_9',
        'nome': 'Coniglio alla cacciatora',
        'ingredienti': jsonEncode([
          {'name': 'Coniglio', 'amount': 1, 'unit': 'kg'},
          {'name': 'Olive taggiasche', 'amount': 100, 'unit': 'g'},
          {'name': 'Pomodoro', 'amount': 300, 'unit': 'g'},
          {'name': 'Vino rosso', 'amount': 150, 'unit': 'ml'},
          {'name': 'Rosmarino', 'amount': 2, 'unit': 'rametti'},
        ]),
        'note': 'Saltare il coniglio, aggiungere olive, pomodoro e vino',
        'immagine': 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_10',
        'nome': 'Salmone al forno',
        'ingredienti': jsonEncode([
          {'name': 'Salmone', 'amount': 600, 'unit': 'g'},
          {'name': 'Limone', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Erbe aromatiche', 'amount': 20, 'unit': 'g'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Condire il salmone con limone e erbe, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_11',
        'nome': 'Involtini di vitello',
        'ingredienti': jsonEncode([
          {'name': 'Vitello', 'amount': 400, 'unit': 'g'},
          {'name': 'Prosciutto cotto', 'amount': 100, 'unit': 'g'},
          {'name': 'Formaggio', 'amount': 100, 'unit': 'g'},
          {'name': 'Pomodoro', 'amount': 300, 'unit': 'g'},
          {'name': 'Burro', 'amount': 30, 'unit': 'g'},
        ]),
        'note': 'Arrotolare la carne con prosciutto e formaggio, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_12',
        'nome': 'Frittura di paranza',
        'ingredienti': jsonEncode([
          {'name': 'Pesce misto', 'amount': 600, 'unit': 'g'},
          {'name': 'Farina', 'amount': 150, 'unit': 'g'},
          {'name': 'Uova', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Olio per friggere', 'amount': 500, 'unit': 'ml'},
          {'name': 'Limone', 'amount': 2, 'unit': 'pezzi'},
        ]),
        'note': 'Impanare il pesce, friggere, servire con limone',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_13',
        'nome': 'Spezzatino di manzo',
        'ingredienti': jsonEncode([
          {'name': 'Manzo', 'amount': 600, 'unit': 'g'},
          {'name': 'Carote', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Cipolla', 'amount': 1, 'unit': 'pezzo'},
          {'name': 'Vino rosso', 'amount': 200, 'unit': 'ml'},
          {'name': 'Brodo', 'amount': 500, 'unit': 'ml'},
        ]),
        'note': 'Saltare la carne con verdure, aggiungere vino e brodo, cuocere a lungo',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_14',
        'nome': 'Tonno alla griglia',
        'ingredienti': jsonEncode([
          {'name': 'Tonno', 'amount': 500, 'unit': 'g'},
          {'name': 'Limone', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
          {'name': 'Rosmarino', 'amount': 2, 'unit': 'rametti'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Condire il tonno, grigliare, servire con limone',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_15',
        'nome': 'Fegato alla veneziana',
        'ingredienti': jsonEncode([
          {'name': 'Fegato di vitello', 'amount': 500, 'unit': 'g'},
          {'name': 'Cipolle', 'amount': 300, 'unit': 'g'},
          {'name': 'Burro', 'amount': 50, 'unit': 'g'},
          {'name': 'Vino bianco', 'amount': 100, 'unit': 'ml'},
          {'name': 'Prezzemolo', 'amount': 1, 'unit': 'mazzetto'},
        ]),
        'note': 'Saltare le cipolle, aggiungere il fegato, sfumare con vino',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      // Contorni (10 ricette)
      {
        'id': 'contorni_1',
        'nome': 'Insalata verde',
        'ingredienti': jsonEncode([
          {'name': 'Lattuga', 'amount': 200, 'unit': 'g'},
          {'name': 'Rucola', 'amount': 100, 'unit': 'g'},
          {'name': 'Pomodorini', 'amount': 10, 'unit': 'pezzi'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
          {'name': 'Aceto', 'amount': 1, 'unit': 'cucchiaio'},
        ]),
        'note': 'Lavare le verdure, condire con olio e aceto',
        'immagine': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Insalate',
      },
      {
        'id': 'contorni_2',
        'nome': 'Patate al forno',
        'ingredienti': jsonEncode([
          {'name': 'Patate', 'amount': 800, 'unit': 'g'},
          {'name': 'Rosmarino', 'amount': 3, 'unit': 'rametti'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Tagliare le patate a spicchi, condire con olio e rosmarino, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Patate',
      },
      {
        'id': 'contorni_3',
        'nome': 'Zucchine grigliate',
        'ingredienti': jsonEncode([
          {'name': 'Zucchine', 'amount': 500, 'unit': 'g'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
          {'name': 'Limone', 'amount': 1, 'unit': 'succo'},
          {'name': 'Menta', 'amount': 5, 'unit': 'foglie'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Tagliare le zucchine a fette, grigliare, condire con limone e menta',
        'immagine': 'https://images.unsplash.com/photo-1604909052743-94e838986d24?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_4',
        'nome': 'Melanzane grigliate',
        'ingredienti': jsonEncode([
          {'name': 'Melanzane', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
          {'name': 'Aglio', 'amount': 2, 'unit': 'spicchi'},
          {'name': 'Prezzemolo', 'amount': 1, 'unit': 'mazzetto'},
          {'name': 'Aceto', 'amount': 1, 'unit': 'cucchiaio'},
        ]),
        'note': 'Tagliare le melanzane a fette, grigliare, condire',
        'immagine': 'https://images.unsplash.com/photo-1598511757337-4f45c8e6b6ed?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_5',
        'nome': 'Carciofi alla romana',
        'ingredienti': jsonEncode([
          {'name': 'Carciofi', 'amount': 4, 'unit': 'pezzi'},
          {'name': 'Menta', 'amount': 5, 'unit': 'foglie'},
          {'name': 'Aglio', 'amount': 2, 'unit': 'spicchi'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
          {'name': 'Prezzemolo', 'amount': 1, 'unit': 'mazzetto'},
        ]),
        'note': 'Pulire i carciofi, cuocere in padella con menta e aglio',
        'immagine': 'https://images.unsplash.com/photo-1594282486552-e05c4f996b2b?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_6',
        'nome': 'Fagioli all\'uccelletto',
        'ingredienti': jsonEncode([
          {'name': 'Fagioli cannellini', 'amount': 400, 'unit': 'g'},
          {'name': 'Pomodoro', 'amount': 300, 'unit': 'g'},
          {'name': 'Salvia', 'amount': 4, 'unit': 'foglie'},
          {'name': 'Aglio', 'amount': 2, 'unit': 'spicchi'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
        ]),
        'note': 'Cuocere i fagioli con pomodoro, salvia e aglio',
        'immagine': 'https://images.unsplash.com/photo-1585937421612-70a008356f36?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Legumi',
      },
      {
        'id': 'contorni_7',
        'nome': 'Cicoria ripassata',
        'ingredienti': jsonEncode([
          {'name': 'Cicoria', 'amount': 500, 'unit': 'g'},
          {'name': 'Aglio', 'amount': 2, 'unit': 'spicchi'},
          {'name': 'Peperoncino', 'amount': 1, 'unit': 'pezzo'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
        ]),
        'note': 'Lessare la cicoria, saltare con aglio e peperoncino',
        'immagine': 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_8',
        'nome': 'Peperoni arrostiti',
        'ingredienti': jsonEncode([
          {'name': 'Peperoni', 'amount': 4, 'unit': 'pezzi'},
          {'name': 'Aglio', 'amount': 2, 'unit': 'spicchi'},
          {'name': 'Olio extra vergine', 'amount': 4, 'unit': 'cucchiai'},
          {'name': 'Aceto', 'amount': 1, 'unit': 'cucchiaio'},
          {'name': 'Prezzemolo', 'amount': 1, 'unit': 'mazzetto'},
        ]),
        'note': 'Arrostire i peperoni, spellarli, condire',
        'immagine': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_9',
        'nome': 'Cavolfiore al vapore',
        'ingredienti': jsonEncode([
          {'name': 'Cavolfiore', 'amount': 1, 'unit': 'pezzo'},
          {'name': 'Limone', 'amount': 1, 'unit': 'succo'},
          {'name': 'Olio extra vergine', 'amount': 3, 'unit': 'cucchiai'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Cuocere il cavolfiore al vapore, condire con limone e olio',
        'immagine': 'https://images.unsplash.com/photo-1567306226416-28f0efdc88ce?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_10',
        'nome': 'Purè di patate',
        'ingredienti': jsonEncode([
          {'name': 'Patate', 'amount': 800, 'unit': 'g'},
          {'name': 'Latte', 'amount': 200, 'unit': 'ml'},
          {'name': 'Burro', 'amount': 60, 'unit': 'g'},
          {'name': 'Noce moscata', 'amount': 1, 'unit': 'pizzico'},
          {'name': 'Sale', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Cuocere le patate, schiacciare, aggiungere latte e burro',
        'immagine': 'https://images.unsplash.com/photo-1576107118395-697d9dc97f79?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Patate',
      },
      // Dolci (10 ricette)
      {
        'id': 'dolci_1',
        'nome': 'Tiramisù',
        'ingredienti': jsonEncode([
          {'name': 'Savoiardi', 'amount': 24, 'unit': 'pezzi'},
          {'name': 'Mascarpone', 'amount': 500, 'unit': 'g'},
          {'name': 'Uova', 'amount': 6, 'unit': 'pezzi'},
          {'name': 'Zucchero', 'amount': 150, 'unit': 'g'},
          {'name': 'Caffè', 'amount': 300, 'unit': 'ml'},
        ]),
        'note': 'Montare mascarpone con uova e zucchero, inzuppare i savoiardi nel caffè',
        'immagine': 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci al cucchiaio',
      },
      {
        'id': 'dolci_2',
        'nome': 'Panna cotta',
        'ingredienti': jsonEncode([
          {'name': 'Panna fresca', 'amount': 500, 'unit': 'ml'},
          {'name': 'Zucchero', 'amount': 80, 'unit': 'g'},
          {'name': 'Gelatina', 'amount': 10, 'unit': 'g'},
          {'name': 'Vaniglia', 'amount': 1, 'unit': 'baccello'},
          {'name': 'Frutti di bosco', 'amount': 100, 'unit': 'g'},
        ]),
        'note': 'Sciogliere la gelatina, unire alla panna, versare negli stampi',
        'immagine': 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci al cucchiaio',
      },
      {
        'id': 'dolci_3',
        'nome': 'Crostata di frutta',
        'ingredienti': jsonEncode([
          {'name': 'Farina', 'amount': 300, 'unit': 'g'},
          {'name': 'Burro', 'amount': 150, 'unit': 'g'},
          {'name': 'Zucchero', 'amount': 100, 'unit': 'g'},
          {'name': 'Uova', 'amount': 2, 'unit': 'pezzi'},
          {'name': 'Marmellata', 'amount': 300, 'unit': 'g'},
        ]),
        'note': 'Preparare la pasta frolla, stenderla, farcire con marmellata',
        'immagine': 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Torte',
      },
      {
        'id': 'dolci_4',
        'nome': 'Torta caprese',
        'ingredienti': jsonEncode([
          {'name': 'Mandorle', 'amount': 200, 'unit': 'g'},
          {'name': 'Cioccolato', 'amount': 200, 'unit': 'g'},
          {'name': 'Zucchero', 'amount': 200, 'unit': 'g'},
          {'name': 'Uova', 'amount': 5, 'unit': 'pezzi'},
          {'name': 'Burro', 'amount': 150, 'unit': 'g'},
        ]),
        'note': 'Tritare mandorle e cioccolato, mescolare con uova e zucchero, cuocere',
        'immagine': 'https://images.unsplash.com/photo-1578985545062-69928b1d9587?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Torte',
      },
      {
        'id': 'dolci_5',
        'nome': 'Zuppa inglese',
        'ingredienti': jsonEncode([
          {'name': 'Uova', 'amount': 6, 'unit': 'pezzi'},
          {'name': 'Zucchero', 'amount': 200, 'unit': 'g'},
          {'name': 'Latte', 'amount': 500, 'unit': 'ml'},
          {'name': 'Alchermes', 'amount': 100, 'unit': 'ml'},
          {'name': 'Pan di spagna', 'amount': 1, 'unit': 'panetto'},
        ]),
        'note': 'Preparare la crema, bagnare il pan di spagna con alchermes',
        'immagine': 'https://images.unsplash.com/photo-1578985545062-6428a0291777?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci al cucchiaio',
      },
      {
        'id': 'dolci_6',
        'nome': 'Cannoli siciliani',
        'ingredienti': jsonEncode([
          {'name': 'Ricotta', 'amount': 500, 'unit': 'g'},
          {'name': 'Zucchero', 'amount': 100, 'unit': 'g'},
          {'name': 'Cialde', 'amount': 12, 'unit': 'pezzi'},
          {'name': 'Cioccolato', 'amount': 50, 'unit': 'g'},
          {'name': 'Canditi', 'amount': 50, 'unit': 'g'},
        ]),
        'note': 'Mescolare la ricetta con zucchero, riempire le cialde',
        'immagine': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci fritti',
      },
      {
        'id': 'dolci_7',
        'nome': 'Babà',
        'ingredienti': jsonEncode([
          {'name': 'Farina', 'amount': 300, 'unit': 'g'},
          {'name': 'Uova', 'amount': 5, 'unit': 'pezzi'},
          {'name': 'Zucchero', 'amount': 100, 'unit': 'g'},
          {'name': 'Lievito', 'amount': 10, 'unit': 'g'},
          {'name': 'Rum', 'amount': 100, 'unit': 'ml'},
        ]),
        'note': 'Preparare l\'impasto, cuocere, bagnare con rum',
        'immagine': 'https://images.unsplash.com/photo-1578985545062-6428a0291777?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci lievitati',
      },
      {
        'id': 'dolci_8',
        'nome': 'Gelato al pistacchio',
        'ingredienti': jsonEncode([
          {'name': 'Panna fresca', 'amount': 400, 'unit': 'ml'},
          {'name': 'Latte', 'amount': 300, 'unit': 'ml'},
          {'name': 'Zucchero', 'amount': 120, 'unit': 'g'},
          {'name': 'Pasta di pistacchio', 'amount': 80, 'unit': 'g'},
          {'name': 'Tuorli', 'amount': 4, 'unit': 'pezzi'},
        ]),
        'note': 'Preparare la base, aggiungere pasta di pistacchio, mantecare',
        'immagine': 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Gelati',
      },
      {
        'id': 'dolci_9',
        'nome': 'Sfogliatella',
        'ingredienti': jsonEncode([
          {'name': 'Semola', 'amount': 200, 'unit': 'g'},
          {'name': 'Ricotta', 'amount': 300, 'unit': 'g'},
          {'name': 'Zucchero', 'amount': 80, 'unit': 'g'},
          {'name': 'Canditi', 'amount': 50, 'unit': 'g'},
          {'name': 'Arancia candita', 'amount': 30, 'unit': 'g'},
        ]),
        'note': 'Preparare la sfoglia, farcire con ricetta e canditi',
        'immagine': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci da forno',
      },
      {
        'id': 'dolci_10',
        'nome': 'Affogato al caffè',
        'ingredienti': jsonEncode([
          {'name': 'Gelato alla vaniglia', 'amount': 2, 'unit': 'palline'},
          {'name': 'Caffè espresso', 'amount': 2, 'unit': 'tazze'},
          {'name': 'Amaretti', 'amount': 4, 'unit': 'pezzi'},
          {'name': 'Cacao amaro', 'amount': 1, 'unit': 'pizzico'},
        ]),
        'note': 'Versare il caffè caldo sul gelato, spolverare cacao',
        'immagine': 'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci al cucchiaio',
      },
    ];
  }
}
