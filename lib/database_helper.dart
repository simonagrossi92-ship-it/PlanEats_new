import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, 'ricette_complete.db');

    // Non copiare più dagli assets - lascia che italian_recipes_database.dart gestisca il database
    // if (!await databaseExists(path)) {
    //   ByteData data = await rootBundle.load('assets/ricette_complete.db');
    //   List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    //   await File(path).writeAsBytes(bytes);
    // }

    final db = await openDatabase(path);
    
    // italian_recipes_database.dart manages the ricette table schema
    // No need for ALTER TABLE here
    
    // Crea tabella profilo se non esiste
    await db.execute('''
      CREATE TABLE IF NOT EXISTS profilo (
        id INTEGER PRIMARY KEY,
        eta INTEGER,
        regione TEXT,
        foto_profilo TEXT
      )
    ''');
    
    // Crea tabella user_preferences se non esiste
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_preferences (
        id INTEGER PRIMARY KEY,
        peso REAL,
        altezza INTEGER,
        eta INTEGER,
        genere TEXT,
        livello_attivita TEXT,
        obiettivo TEXT,
        obiettivo_calorico INTEGER
      )
    ''');
    await _migrateUserPreferences(db);
    
    // Crea tabella ricette se non esiste
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ricette (
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
    
    // Crea tabella menu_pianificato per date-based menu
    await db.execute('''
      CREATE TABLE IF NOT EXISTS menu_pianificato (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        ricetta_id TEXT NOT NULL,
        pasto TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(data, ricetta_id, pasto)
      )
    ''');
    
    // Crea tabella menu_archiviati per archiviare i menu vecchi
    await db.execute('''
      CREATE TABLE IF NOT EXISTS menu_archiviati (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        ricetta_id TEXT NOT NULL,
        pasto TEXT NOT NULL,
        data_archiviazione TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    return db;
  }

  static Future<void> _migrateUserPreferences(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(user_preferences)');
    final columnNames = columns.map((c) => c['name'] as String).toSet();
    if (!columnNames.contains('livello_attivita')) {
      await db.execute(
        'ALTER TABLE user_preferences ADD COLUMN livello_attivita TEXT',
      );
    }
    if (!columnNames.contains('obiettivo')) {
      await db.execute(
        'ALTER TABLE user_preferences ADD COLUMN obiettivo TEXT',
      );
    }
  }

  // AGGIUNGI QUESTO METODO PER IL DEBUG
  static Future<void> debugPrintTableColumns() async {
    final db = await instance.database;

    // Prima mostra tutte le tabelle nel database
    final List<Map<String, dynamic>> tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;");

    print("=== TABELLE NEL DATABASE ===");
    print("Numero totale di tabelle: ${tables.length}");
    for (var table in tables) {
      print("  - ${table['name']}");
    }
    print("==============================");

    // Poi mostra le colonne della tabella ricette
    final List<Map<String, dynamic>> columns =
        await db.rawQuery("PRAGMA table_info(ricette)");

    print("--- ELENCO COLONNE DI 'ricette' ---");
    if (columns.isEmpty) {
      print("Tabella 'ricette' NON TROVATA!");
    } else {
      for (var col in columns) {
        print("Nome colonna: ${col['name']}");
      }
    }
  }

  // Funzione per leggere le ricette dal database
  static Future<List<Map<String, dynamic>>> getCleanRecipes() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> recipes = await db.query('ricette');

    print("Caricate ${recipes.length} ricette dal database");
    return recipes;
  }

  // Funzione per leggere le ricette per categoria
  static Future<List<Map<String, dynamic>>> getRecipesByCategory(String category) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> recipes = await db.query(
      'ricette',
      where: 'categoria = ?',
      whereArgs: [category],
    );

    print("Caricate ${recipes.length} ricette per categoria '$category' dal database");
    return recipes;
  }

  static Future<Map<String, dynamic>?> getRecipeById(String id) async {
    final db = await instance.database;
    final results = await db.query(
      'ricette',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  // Metodo pubblico per inizializzare il database
  Future<void> initDatabase() async {
    await database;
  }

  // Metodo per ottenere tutte le ricette
  static Future<List<Map<String, dynamic>>> getTutteLeRicette() async {
    return await getCleanRecipes();
  }

  // Metodo per inserire le ricette italiane nel database
  static Future<void> insertItalianRecipes() async {
    final db = await instance.database;
    
    // Get Italian recipe IDs
    final italianRecipes = _getItalianRecipes();
    final italianIds = italianRecipes.map((r) => r['id'].toString()).toSet();
    
    // Check if Italian recipes are already in database
    final existingRecipes = await db.query('ricette', columns: ['id']);
    final existingIds = existingRecipes.map((r) => r['id'].toString()).toSet();
    
    // Check if all Italian recipes are already present
    final missingIds = italianIds.difference(existingIds);
    if (missingIds.isEmpty) {
      print('Tutte le ${italianRecipes.length} ricette italiane sono già nel database');
      return;
    }
    
    // Insert only missing recipes
    int insertedCount = 0;
    for (final recipe in italianRecipes) {
      if (!existingIds.contains(recipe['id'].toString())) {
        await db.insert('ricette', recipe);
        insertedCount++;
      }
    }
    
    print('Inserite $insertedCount nuove ricette italiane nel database');
  }

  static List<Map<String, dynamic>> _getItalianRecipes() {
    return [
      // Antipasti (10 ricette)
      {
        'id': 'antipasti_1',
        'nome': 'Bruschetta al pomodoro',
        'ingredienti': '[{"name":"Pane tostato","amount":4,"unit":"fette"},{"name":"Pomodori maturi","amount":2,"unit":"pezzi"},{"name":"Basilico fresco","amount":10,"unit":"foglie"},{"name":"Olio extra vergine","amount":2,"unit":"cucchiai"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Tostare il pane e condirlo con pomodori tagliati a cubetti, basilico e olio',
        'immagine': 'https://images.unsplash.com/photo-1572695157366-5e585ab2b69f?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Bruschette',
      },
      {
        'id': 'antipasti_2',
        'nome': 'Caprese',
        'ingredienti': '[{"name":"Mozzarella","amount":250,"unit":"g"},{"name":"Pomodori","amount":3,"unit":"pezzi"},{"name":"Basilico","amount":1,"unit":"mazzetto"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Tagliare mozzarella e pomodori a fette, disporre alternati con basilico',
        'immagine': 'https://images.unsplash.com/photo-1608897013039-887f21d8c804?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Insalate',
      },
      {
        'id': 'antipasti_3',
        'nome': 'Carpaccio di manzo',
        'ingredienti': '[{"name":"Manzo","amount":200,"unit":"g"},{"name":"Rucola","amount":50,"unit":"g"},{"name":"Parmigiano","amount":30,"unit":"g"},{"name":"Limone","amount":1,"unit":"succo"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"}]',
        'note': 'Affettare la carne finemente, condire con limone, olio e parmigiano',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Carpaccio',
      },
      {
        'id': 'antipasti_4',
        'nome': 'Frittata di erbe',
        'ingredienti': '[{"name":"Uova","amount":4,"unit":"pezzi"},{"name":"Erbe aromatiche","amount":50,"unit":"g"},{"name":"Parmigiano","amount":30,"unit":"g"},{"name":"Burro","amount":20,"unit":"g"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Sbattere le uova con le erbe e il parmigiano, cuocere in padella',
        'immagine': 'https://images.unsplash.com/photo-1525351484163-7529414395d8?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Uova',
      },
      {
        'id': 'antipasti_5',
        'nome': 'Prosciutto e melone',
        'ingredienti': '[{"name":"Prosciutto crudo","amount":100,"unit":"g"},{"name":"Melone","amount":1,"unit":"pezzo"},{"name":"Pepe nero","amount":1,"unit":"pizzico"}]',
        'note': 'Tagliare il melone a fette, avvolgere con il prosciutto',
        'immagine': 'https://images.unsplash.com/photo-1626200419199-391ae4be7a41?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Salumi',
      },
      {
        'id': 'antipasti_6',
        'nome': 'Insalata di mare',
        'ingredienti': '[{"name":"Polpo","amount":300,"unit":"g"},{"name":"Gamberi","amount":200,"unit":"g"},{"name":"Calamari","amount":200,"unit":"g"},{"name":"Limone","amount":2,"unit":"pezzi"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"}]',
        'note': 'Cuocere il pesce, condire con limone e olio',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'antipasti_7',
        'nome': 'Crostini al fegato',
        'ingredienti': '[{"name":"Fegato di pollo","amount":200,"unit":"g"},{"name":"Cipolla","amount":1,"unit":"pezzo"},{"name":"Vino rosso","amount":100,"unit":"ml"},{"name":"Pane tostato","amount":20,"unit":"fette"},{"name":"Burro","amount":30,"unit":"g"}]',
        'note': 'Cuocere il fegato con cipolla e vino, spalmare sul pane tostato',
        'immagine': 'https://images.unsplash.com/photo-1504674900247-0877df9cc836?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Crostini',
      },
      {
        'id': 'antipasti_8',
        'nome': 'Sformato di zucchine',
        'ingredienti': '[{"name":"Zucchine","amount":500,"unit":"g"},{"name":"Uova","amount":3,"unit":"pezzi"},{"name":"Parmigiano","amount":50,"unit":"g"},{"name":"Pangrattato","amount":30,"unit":"g"},{"name":"Burro","amount":30,"unit":"g"}]',
        'note': 'Grattugiare le zucchine, mescolare con uova e parmigiano, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1476718406336-bb5a9690ee2b?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Sformati',
      },
      {
        'id': 'antipasti_9',
        'nome': 'Tartare di salmone',
        'ingredienti': '[{"name":"Salmone fresco","amount":200,"unit":"g"},{"name":"Limone","amount":1,"unit":"succo"},{"name":"Capperi","amount":10,"unit":"pezzi"},{"name":"Erba cipollina","amount":5,"unit":"steli"},{"name":"Olio extra vergine","amount":2,"unit":"cucchiai"}]',
        'note': 'Tagliare il salmone a cubetti, condire con limone, capperi e erba cipollina',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'antipasti_10',
        'nome': 'Focaccia genovese',
        'ingredienti': '[{"name":"Farina","amount":500,"unit":"g"},{"name":"Acqua","amount":300,"unit":"ml"},{"name":"Lievito","amount":10,"unit":"g"},{"name":"Olio extra vergine","amount":50,"unit":"ml"},{"name":"Sale grosso","amount":10,"unit":"g"}]',
        'note': 'Impastare farina, acqua e lievito, lasciare lievitare, condire con olio e sale',
        'immagine': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800',
        'categoria': 'Antipasti',
        'sottocategoria': 'Pane',
      },
      // Primi (15 ricette)
      {
        'id': 'primi_1',
        'nome': 'Spaghetti alla carbonara',
        'ingredienti': '[{"name":"Spaghetti","amount":400,"unit":"g"},{"name":"Guanciale","amount":150,"unit":"g"},{"name":"Uova","amount":4,"unit":"pezzi"},{"name":"Pecorino romano","amount":80,"unit":"g"},{"name":"Pepe nero","amount":2,"unit":"pizzichi"}]',
        'note': 'Cuocere la pasta, saltare con guanciale croccante, unire uova e pecorino',
        'immagine': 'https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_2',
        'nome': 'Pasta al pomodoro',
        'ingredienti': '[{"name":"Pasta","amount":400,"unit":"g"},{"name":"Pomodori San Marzano","amount":500,"unit":"g"},{"name":"Basilico","amount":10,"unit":"foglie"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"},{"name":"Aglio","amount":2,"unit":"spicchi"}]',
        'note': 'Cuocere i pomodori con aglio e olio, condire la pasta',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_3',
        'nome': 'Risotto alla milanese',
        'ingredienti': '[{"name":"Riso Arborio","amount":300,"unit":"g"},{"name":"Zafferano","amount":1,"unit":"bustina"},{"name":"Brodo vegetale","amount":1,"unit":"litro"},{"name":"Burro","amount":50,"unit":"g"},{"name":"Parmigiano","amount":80,"unit":"g"}]',
        'note': 'Tostare il riso, aggiungere brodo poco alla volta, mantecare con burro e parmigiano',
        'immagine': 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c1?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Riso',
      },
      {
        'id': 'primi_4',
        'nome': 'Pasta alle vongole',
        'ingredienti': '[{"name":"Linguine","amount":400,"unit":"g"},{"name":"Vongole","amount":1,"unit":"kg"},{"name":"Aglio","amount":3,"unit":"spicchi"},{"name":"Prezzemolo","amount":1,"unit":"mazzetto"},{"name":"Vino bianco","amount":100,"unit":"ml"}]',
        'note': 'Aprire le vongole in padella con aglio e vino, condire la pasta',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_5',
        'nome': 'Lasagne al forno',
        'ingredienti': '[{"name":"Sfoglia fresca","amount":12,"unit":"foglie"},{"name":"Ragù di manzo","amount":500,"unit":"g"},{"name":"Besciamella","amount":500,"unit":"ml"},{"name":"Parmigiano","amount":100,"unit":"g"},{"name":"Burro","amount":30,"unit":"g"}]',
        'note': 'Alternare sfoglia, ragù e besciamella, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1574868760432-f944a914d5b2?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta al forno',
      },
      {
        'id': 'primi_6',
        'nome': 'Gnocchi al pomodoro',
        'ingredienti': '[{"name":"Gnocchi di patate","amount":500,"unit":"g"},{"name":"Pomodoro","amount":400,"unit":"g"},{"name":"Basilico","amount":8,"unit":"foglie"},{"name":"Parmigiano","amount":50,"unit":"g"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"}]',
        'note': 'Cuocere gli gnocchi, condire con sugo di pomodoro e basilico',
        'immagine': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Gnocchi',
      },
      {
        'id': 'primi_7',
        'nome': 'Pasta alla norma',
        'ingredienti': '[{"name":"Maccheroni","amount":400,"unit":"g"},{"name":"Melanzane","amount":2,"unit":"pezzi"},{"name":"Pomodoro","amount":400,"unit":"g"},{"name":"Ricotta salata","amount":50,"unit":"g"},{"name":"Basilico","amount":10,"unit":"foglie"}]',
        'note': 'Friggere le melanzane, condire la pasta con pomodoro e melanzane',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_8',
        'nome': 'Ravioli di ricotta',
        'ingredienti': '[{"name":"Ravioli freschi","amount":400,"unit":"g"},{"name":"Burro","amount":60,"unit":"g"},{"name":"Salvia","amount":5,"unit":"foglie"},{"name":"Parmigiano","amount":50,"unit":"g"},{"name":"Noce moscata","amount":1,"unit":"pizzico"}]',
        'note': 'Cuocere i ravioli, saltare con burro e salvia, spolverare parmigiano',
        'immagine': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta fresca',
      },
      {
        'id': 'primi_9',
        'nome': 'Minestrone',
        'ingredienti': '[{"name":"Fagiolini","amount":100,"unit":"g"},{"name":"Carote","amount":2,"unit":"pezzi"},{"name":"Patate","amount":2,"unit":"pezzi"},{"name":"Zucchine","amount":2,"unit":"pezzi"},{"name":"Pasta","amount":100,"unit":"g"}]',
        'note': 'Cuocere le verdure in brodo, aggiungere la pasta a fine cottura',
        'immagine': 'https://images.unsplash.com/photo-1547592166-23acbe3a624b?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Zuppe',
      },
      {
        'id': 'primi_10',
        'nome': 'Pasta cacio e pepe',
        'ingredienti': '[{"name":"Spaghetti","amount":400,"unit":"g"},{"name":"Pecorino romano","amount":100,"unit":"g"},{"name":"Pepe nero","amount":3,"unit":"pizzichi"},{"name":"Acqua di cottura","amount":100,"unit":"ml"}]',
        'note': 'Creare una crema con pecorino e acqua di cottura, condire la pasta',
        'immagine': 'https://images.unsplash.com/photo-1612874742237-6526221588e3?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_11',
        'nome': 'Orecchiette alle cime di rapa',
        'ingredienti': '[{"name":"Orecchiette","amount":400,"unit":"g"},{"name":"Cime di rapa","amount":500,"unit":"g"},{"name":"Aglio","amount":2,"unit":"spicchi"},{"name":"Peperoncino","amount":1,"unit":"pezzo"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"}]',
        'note': 'Cuocere le cime di rapa, saltare con aglio e peperoncino, condire la pasta',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_12',
        'nome': 'Risotto ai funghi',
        'ingredienti': '[{"name":"Riso Carnaroli","amount":300,"unit":"g"},{"name":"Funghi porcini","amount":200,"unit":"g"},{"name":"Brodo vegetale","amount":1,"unit":"litro"},{"name":"Burro","amount":40,"unit":"g"},{"name":"Parmigiano","amount":60,"unit":"g"}]',
        'note': 'Saltare i funghi, tostare il riso, completare con brodo, mantecare',
        'immagine': 'https://images.unsplash.com/photo-1633964913295-ceb43826e7c1?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Riso',
      },
      {
        'id': 'primi_13',
        'nome': 'Pasta alla puttanesca',
        'ingredienti': '[{"name":"Spaghetti","amount":400,"unit":"g"},{"name":"Pomodori","amount":400,"unit":"g"},{"name":"Acciughe","amount":6,"unit":"filetti"},{"name":"Capperi","amount":20,"unit":"g"},{"name":"Olive nere","amount":50,"unit":"g"}]',
        'note': 'Cuocere il sugo con pomodoro, acciughe, capperi e olive',
        'immagine': 'https://images.unsplash.com/photo-1563379926898-05f4575a45d8?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta',
      },
      {
        'id': 'primi_14',
        'nome': 'Tortellini in brodo',
        'ingredienti': '[{"name":"Tortellini freschi","amount":300,"unit":"g"},{"name":"Brodo di carne","amount":1,"unit":"litro"},{"name":"Parmigiano","amount":40,"unit":"g"},{"name":"Noce moscata","amount":1,"unit":"pizzico"}]',
        'note': 'Cuocere i tortellini nel brodo bollente, servire con parmigiano',
        'immagine': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Pasta fresca',
      },
      {
        'id': 'primi_15',
        'nome': 'Pasta e fagioli',
        'ingredienti': '[{"name":"Pasta mista","amount":200,"unit":"g"},{"name":"Fagioli borlotti","amount":300,"unit":"g"},{"name":"Pomodoro","amount":200,"unit":"g"},{"name":"Rosmarino","amount":2,"unit":"rametti"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"}]',
        'note': 'Cuocere i fagioli, aggiungere pomodoro e pasta',
        'immagine': 'https://images.unsplash.com/photo-1547592166-23acbe3a624b?w=800',
        'categoria': 'Primi',
        'sottocategoria': 'Zuppe',
      },
      // Secondi (15 ricette)
      {
        'id': 'secondi_1',
        'nome': 'Bistecca alla fiorentina',
        'ingredienti': '[{"name":"Manzo","amount":800,"unit":"g"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"},{"name":"Sale grosso","amount":10,"unit":"g"},{"name":"Pepe nero","amount":2,"unit":"pizzichi"}]',
        'note': 'Cuocere la bistecca alla griglia, condire con sale e pepe',
        'immagine': 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_2',
        'nome': 'Pollo alla cacciatora',
        'ingredienti': '[{"name":"Pollo","amount":1,"unit":"kg"},{"name":"Pomodori","amount":400,"unit":"g"},{"name":"Cipolla","amount":1,"unit":"pezzo"},{"name":"Vino rosso","amount":200,"unit":"ml"},{"name":"Rosmarino","amount":2,"unit":"rametti"}]',
        'note': 'Saltare il pollo con cipolla, aggiungere pomodoro e vino',
        'immagine': 'https://images.unsplash.com/photo-1598103442097-8b74394b95c6?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pollame',
      },
      {
        'id': 'secondi_3',
        'nome': 'Saltimbocca alla romana',
        'ingredienti': '[{"name":"Vitello","amount":400,"unit":"g"},{"name":"Prosciutto crudo","amount":100,"unit":"g"},{"name":"Salvia","amount":8,"unit":"foglie"},{"name":"Burro","amount":40,"unit":"g"},{"name":"Vino bianco","amount":100,"unit":"ml"}]',
        'note': 'Avvolgere la carne con prosciutto e salvia, cuocere con burro e vino',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_4',
        'nome': 'Pesce al cartoccio',
        'ingredienti': '[{"name":"Orata","amount":600,"unit":"g"},{"name":"Pomodori","amount":200,"unit":"g"},{"name":"Limone","amount":1,"unit":"pezzo"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"},{"name":"Prezzemolo","amount":1,"unit":"mazzetto"}]',
        'note': 'Disporre il pesce con pomodori e limone nella carta, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_5',
        'nome': 'Arista di maiale',
        'ingredienti': '[{"name":"Maiale","amount":800,"unit":"g"},{"name":"Rosmarino","amount":3,"unit":"rametti"},{"name":"Aglio","amount":4,"unit":"spicchi"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"},{"name":"Vino bianco","amount":150,"unit":"ml"}]',
        'note': 'Marinare la carne, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1432139555190-58524dae6a55?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_6',
        'nome': 'Cotoletta alla milanese',
        'ingredienti': '[{"name":"Vitello","amount":400,"unit":"g"},{"name":"Uova","amount":2,"unit":"pezzi"},{"name":"Pangrattato","amount":100,"unit":"g"},{"name":"Burro","amount":60,"unit":"g"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Impanare la carne, friggere nel burro',
        'immagine': 'https://images.unsplash.com/photo-1632778149955-e80f8ceca2e8?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_7',
        'nome': 'Polpette al sugo',
        'ingredienti': '[{"name":"Manzo macinato","amount":500,"unit":"g"},{"name":"Pangrattato","amount":100,"unit":"g"},{"name":"Uova","amount":2,"unit":"pezzi"},{"name":"Pomodoro","amount":500,"unit":"g"},{"name":"Parmigiano","amount":50,"unit":"g"}]',
        'note': 'Formare le polpette, cuocere nel sugo di pomodoro',
        'immagine': 'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_8',
        'nome': 'Calamari fritti',
        'ingredienti': '[{"name":"Calamari","amount":500,"unit":"g"},{"name":"Farina","amount":150,"unit":"g"},{"name":"Uova","amount":2,"unit":"pezzi"},{"name":"Olio per friggere","amount":500,"unit":"ml"},{"name":"Limone","amount":2,"unit":"pezzi"}]',
        'note': 'Tagliare i calamari ad anelli, impanare, friggere',
        'immagine': 'https://images.unsplash.com/photo-1599487488170-d11ec9c172f0?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_9',
        'nome': 'Coniglio alla cacciatora',
        'ingredienti': '[{"name":"Coniglio","amount":1,"unit":"kg"},{"name":"Olive taggiasche","amount":100,"unit":"g"},{"name":"Pomodoro","amount":300,"unit":"g"},{"name":"Vino rosso","amount":150,"unit":"ml"},{"name":"Rosmarino","amount":2,"unit":"rametti"}]',
        'note': 'Saltare il coniglio, aggiungere olive, pomodoro e vino',
        'immagine': 'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_10',
        'nome': 'Salmone al forno',
        'ingredienti': '[{"name":"Salmone","amount":600,"unit":"g"},{"name":"Limone","amount":2,"unit":"pezzi"},{"name":"Erbe aromatiche","amount":20,"unit":"g"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Condire il salmone con limone e erbe, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_11',
        'nome': 'Involtini di vitello',
        'ingredienti': '[{"name":"Vitello","amount":400,"unit":"g"},{"name":"Prosciutto cotto","amount":100,"unit":"g"},{"name":"Formaggio","amount":100,"unit":"g"},{"name":"Pomodoro","amount":300,"unit":"g"},{"name":"Burro","amount":30,"unit":"g"}]',
        'note': 'Arrotolare la carne con prosciutto e formaggio, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_12',
        'nome': 'Frittura di paranza',
        'ingredienti': '[{"name":"Pesce misto","amount":600,"unit":"g"},{"name":"Farina","amount":150,"unit":"g"},{"name":"Uova","amount":2,"unit":"pezzi"},{"name":"Olio per friggere","amount":500,"unit":"ml"},{"name":"Limone","amount":2,"unit":"pezzi"}]',
        'note': 'Impanare il pesce, friggere, servire con limone',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_13',
        'nome': 'Spezzatino di manzo',
        'ingredienti': '[{"name":"Manzo","amount":600,"unit":"g"},{"name":"Carote","amount":2,"unit":"pezzi"},{"name":"Cipolla","amount":1,"unit":"pezzo"},{"name":"Vino rosso","amount":200,"unit":"ml"},{"name":"Brodo","amount":500,"unit":"ml"}]',
        'note': 'Saltare la carne con verdure, aggiungere vino e brodo, cuocere a lungo',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      {
        'id': 'secondi_14',
        'nome': 'Tonno alla griglia',
        'ingredienti': '[{"name":"Tonno","amount":500,"unit":"g"},{"name":"Limone","amount":2,"unit":"pezzi"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"},{"name":"Rosmarino","amount":2,"unit":"rametti"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Condire il tonno, grigliare, servire con limone',
        'immagine': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Pesce',
      },
      {
        'id': 'secondi_15',
        'nome': 'Fegato alla veneziana',
        'ingredienti': '[{"name":"Fegato di vitello","amount":500,"unit":"g"},{"name":"Cipolle","amount":300,"unit":"g"},{"name":"Burro","amount":50,"unit":"g"},{"name":"Vino bianco","amount":100,"unit":"ml"},{"name":"Prezzemolo","amount":1,"unit":"mazzetto"}]',
        'note': 'Saltare le cipolle, aggiungere il fegato, sfumare con vino',
        'immagine': 'https://images.unsplash.com/photo-1544025162-d76694265947?w=800',
        'categoria': 'Secondi',
        'sottocategoria': 'Carne',
      },
      // Contorni (10 ricette)
      {
        'id': 'contorni_1',
        'nome': 'Insalata verde',
        'ingredienti': '[{"name":"Lattuga","amount":200,"unit":"g"},{"name":"Rucola","amount":100,"unit":"g"},{"name":"Pomodorini","amount":10,"unit":"pezzi"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"},{"name":"Aceto","amount":1,"unit":"cucchiaio"}]',
        'note': 'Lavare le verdure, condire con olio e aceto',
        'immagine': 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Insalate',
      },
      {
        'id': 'contorni_2',
        'nome': 'Patate al forno',
        'ingredienti': '[{"name":"Patate","amount":800,"unit":"g"},{"name":"Rosmarino","amount":3,"unit":"rametti"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Tagliare le patate a spicchi, condire con olio e rosmarino, cuocere in forno',
        'immagine': 'https://images.unsplash.com/photo-1593560708920-61dd98c46a4e?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Patate',
      },
      {
        'id': 'contorni_3',
        'nome': 'Zucchine grigliate',
        'ingredienti': '[{"name":"Zucchine","amount":500,"unit":"g"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"},{"name":"Limone","amount":1,"unit":"succo"},{"name":"Menta","amount":5,"unit":"foglie"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Tagliare le zucchine a fette, grigliare, condire con limone e menta',
        'immagine': 'https://images.unsplash.com/photo-1604909052743-94e838986d24?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_4',
        'nome': 'Melanzane grigliate',
        'ingredienti': '[{"name":"Melanzane","amount":2,"unit":"pezzi"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"},{"name":"Aglio","amount":2,"unit":"spicchi"},{"name":"Prezzemolo","amount":1,"unit":"mazzetto"},{"name":"Aceto","amount":1,"unit":"cucchiaio"}]',
        'note': 'Tagliare le melanzane a fette, grigliare, condire',
        'immagine': 'https://images.unsplash.com/photo-1598511757337-4f45c8e6b6ed?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_5',
        'nome': 'Carciofi alla romana',
        'ingredienti': '[{"name":"Carciofi","amount":4,"unit":"pezzi"},{"name":"Menta","amount":5,"unit":"foglie"},{"name":"Aglio","amount":2,"unit":"spicchi"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"},{"name":"Prezzemolo","amount":1,"unit":"mazzetto"}]',
        'note': 'Pulire i carciofi, cuocere in padella con menta e aglio',
        'immagine': 'https://images.unsplash.com/photo-1594282486552-e05c4f996b2b?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_6',
        'nome': 'Fagioli all\'uccelletto',
        'ingredienti': '[{"name":"Fagioli cannellini","amount":400,"unit":"g"},{"name":"Pomodoro","amount":300,"unit":"g"},{"name":"Salvia","amount":4,"unit":"foglie"},{"name":"Aglio","amount":2,"unit":"spicchi"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"}]',
        'note': 'Cuocere i fagioli con pomodoro, salvia e aglio',
        'immagine': 'https://images.unsplash.com/photo-1585937421612-70a008356f36?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Legumi',
      },
      {
        'id': 'contorni_7',
        'nome': 'Cicoria ripassata',
        'ingredienti': '[{"name":"Cicoria","amount":500,"unit":"g"},{"name":"Aglio","amount":2,"unit":"spicchi"},{"name":"Peperoncino","amount":1,"unit":"pezzo"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"}]',
        'note': 'Lessare la cicoria, saltare con aglio e peperoncino',
        'immagine': 'https://images.unsplash.com/photo-1540420773420-3366772f4999?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_8',
        'nome': 'Peperoni arrostiti',
        'ingredienti': '[{"name":"Peperoni","amount":4,"unit":"pezzi"},{"name":"Aglio","amount":2,"unit":"spicchi"},{"name":"Olio extra vergine","amount":4,"unit":"cucchiai"},{"name":"Aceto","amount":1,"unit":"cucchiaio"},{"name":"Prezzemolo","amount":1,"unit":"mazzetto"}]',
        'note': 'Arrostire i peperoni, spellarli, condire',
        'immagine': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_9',
        'nome': 'Cavolfiore al vapore',
        'ingredienti': '[{"name":"Cavolfiore","amount":1,"unit":"pezzo"},{"name":"Limone","amount":1,"unit":"succo"},{"name":"Olio extra vergine","amount":3,"unit":"cucchiai"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Cuocere il cavolfiore al vapore, condire con limone e olio',
        'immagine': 'https://images.unsplash.com/photo-1567306226416-28f0efdc88ce?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Verdure',
      },
      {
        'id': 'contorni_10',
        'nome': 'Purè di patate',
        'ingredienti': '[{"name":"Patate","amount":800,"unit":"g"},{"name":"Latte","amount":200,"unit":"ml"},{"name":"Burro","amount":60,"unit":"g"},{"name":"Noce moscata","amount":1,"unit":"pizzico"},{"name":"Sale","amount":1,"unit":"pizzico"}]',
        'note': 'Cuocere le patate, schiacciare, aggiungere latte e burro',
        'immagine': 'https://images.unsplash.com/photo-1576107118395-697d9dc97f79?w=800',
        'categoria': 'Contorni',
        'sottocategoria': 'Patate',
      },
      // Dolci (10 ricette)
      {
        'id': 'dolci_1',
        'nome': 'Tiramisù',
        'ingredienti': '[{"name":"Savoiardi","amount":24,"unit":"pezzi"},{"name":"Mascarpone","amount":500,"unit":"g"},{"name":"Uova","amount":6,"unit":"pezzi"},{"name":"Zucchero","amount":150,"unit":"g"},{"name":"Caffè","amount":300,"unit":"ml"}]',
        'note': 'Montare mascarpone con uova e zucchero, inzuppare i savoiardi nel caffè',
        'immagine': 'https://images.unsplash.com/photo-1571877227200-a0d98ea607e9?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci al cucchiaio',
      },
      {
        'id': 'dolci_2',
        'nome': 'Panna cotta',
        'ingredienti': '[{"name":"Panna fresca","amount":500,"unit":"ml"},{"name":"Zucchero","amount":80,"unit":"g"},{"name":"Gelatina","amount":10,"unit":"g"},{"name":"Vaniglia","amount":1,"unit":"baccello"},{"name":"Frutti di bosco","amount":100,"unit":"g"}]',
        'note': 'Sciogliere la gelatina, unire alla panna, versare negli stampi',
        'immagine': 'https://images.unsplash.com/photo-1488477181946-6428a0291777?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci al cucchiaio',
      },
      {
        'id': 'dolci_3',
        'nome': 'Crostata di frutta',
        'ingredienti': '[{"name":"Farina","amount":300,"unit":"g"},{"name":"Burro","amount":150,"unit":"g"},{"name":"Zucchero","amount":100,"unit":"g"},{"name":"Uova","amount":2,"unit":"pezzi"},{"name":"Marmellata","amount":300,"unit":"g"}]',
        'note': 'Preparare la pasta frolla, stenderla, farcire con marmellata',
        'immagine': 'https://images.unsplash.com/photo-1565958011703-44f9829ba187?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Torte',
      },
      {
        'id': 'dolci_4',
        'nome': 'Torta caprese',
        'ingredienti': '[{"name":"Mandorle","amount":200,"unit":"g"},{"name":"Cioccolato","amount":200,"unit":"g"},{"name":"Zucchero","amount":200,"unit":"g"},{"name":"Uova","amount":5,"unit":"pezzi"},{"name":"Burro","amount":150,"unit":"g"}]',
        'note': 'Tritare mandorle e cioccolato, mescolare con uova e zucchero, cuocere',
        'immagine': 'https://images.unsplash.com/photo-1578985545062-6428a0291777?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Torte',
      },
      {
        'id': 'dolci_5',
        'nome': 'Zuppa inglese',
        'ingredienti': '[{"name":"Uova","amount":6,"unit":"pezzi"},{"name":"Zucchero","amount":200,"unit":"g"},{"name":"Latte","amount":500,"unit":"ml"},{"name":"Alchermes","amount":100,"unit":"ml"},{"name":"Pan di spagna","amount":1,"unit":"panetto"}]',
        'note': 'Preparare la crema, bagnare il pan di spagna con alchermes',
        'immagine': 'https://images.unsplash.com/photo-1578985545062-6428a0291777?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci al cucchiaio',
      },
      {
        'id': 'dolci_6',
        'nome': 'Cannoli siciliani',
        'ingredienti': '[{"name":"Ricotta","amount":500,"unit":"g"},{"name":"Zucchero","amount":100,"unit":"g"},{"name":"Cialde","amount":12,"unit":"pezzi"},{"name":"Cioccolato","amount":50,"unit":"g"},{"name":"Canditi","amount":50,"unit":"g"}]',
        'note': 'Mescolare la ricotta con zucchero, riempire le cialde',
        'immagine': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci fritti',
      },
      {
        'id': 'dolci_7',
        'nome': 'Babà',
        'ingredienti': '[{"name":"Farina","amount":300,"unit":"g"},{"name":"Uova","amount":5,"unit":"pezzi"},{"name":"Zucchero","amount":100,"unit":"g"},{"name":"Lievito","amount":10,"unit":"g"},{"name":"Rum","amount":100,"unit":"ml"}]',
        'note': 'Preparare l\'impasto, cuocere, bagnare con rum',
        'immagine': 'https://images.unsplash.com/photo-1578985545062-6428a0291777?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci lievitati',
      },
      {
        'id': 'dolci_8',
        'nome': 'Gelato al pistacchio',
        'ingredienti': '[{"name":"Panna fresca","amount":400,"unit":"ml"},{"name":"Latte","amount":300,"unit":"ml"},{"name":"Zucchero","amount":120,"unit":"g"},{"name":"Pasta di pistacchio","amount":80,"unit":"g"},{"name":"Tuorli","amount":4,"unit":"pezzi"}]',
        'note': 'Preparare la base, aggiungere pasta di pistacchio, mantecare',
        'immagine': 'https://images.unsplash.com/photo-1497034825429-c343d7c6a68f?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Gelati',
      },
      {
        'id': 'dolci_9',
        'nome': 'Sfogliatella',
        'ingredienti': '[{"name":"Semola","amount":200,"unit":"g"},{"name":"Ricotta","amount":300,"unit":"g"},{"name":"Zucchero","amount":80,"unit":"g"},{"name":"Canditi","amount":50,"unit":"g"},{"name":"Arancia candita","amount":30,"unit":"g"}]',
        'note': 'Preparare la sfoglia, farcire con ricotta e canditi',
        'immagine': 'https://images.unsplash.com/photo-1551024601-bec78aea704b?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci da forno',
      },
      {
        'id': 'dolci_10',
        'nome': 'Affogato al caffè',
        'ingredienti': '[{"name":"Gelato alla vaniglia","amount":2,"unit":"palline"},{"name":"Caffè espresso","amount":2,"unit":"tazze"},{"name":"Amaretti","amount":4,"unit":"pezzi"},{"name":"Cacao amaro","amount":1,"unit":"pizzico"}]',
        'note': 'Versare il caffè caldo sul gelato, spolverare cacao',
        'immagine': 'https://images.unsplash.com/photo-1579954115545-a95591f28bfc?w=800',
        'categoria': 'Dolci',
        'sottocategoria': 'Dolci al cucchiaio',
      },
    ];
  }

  // Salva dati profilo
  Future<void> saveProfile(int? eta, String? regione) async {
    final db = await database;
    await db.insert(
      'profilo',
      {
        'id': 1,
        'eta': eta,
        'regione': regione,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Parsing numerico tollerante (es. "75,5" → 75.5).
  static int? parseIntIt(String? text) {
    if (text == null) return null;
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized.split('.').first);
  }

  static double? parseDoubleIt(String? text) {
    if (text == null) return null;
    final normalized = text.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  // Carica dati profilo
  Future<Map<String, dynamic>?> getProfile() async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'profilo',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Salva preferenze utente
  static Future<void> saveUserPreferences({
    required double peso,
    required int altezza,
    required int eta,
    required String genere,
    required int obiettivoCalorico,
    String? livelloAttivita,
    String? obiettivo,
  }) async {
    final db = await instance.database;
    await db.insert(
      'user_preferences',
      {
        'id': 1,
        'peso': peso,
        'altezza': altezza,
        'eta': eta,
        'genere': genere,
        'livello_attivita': livelloAttivita,
        'obiettivo': obiettivo,
        'obiettivo_calorico': obiettivoCalorico,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Salva un singolo campo del profilo utente
  static Future<void> saveUserProfileField(String field, dynamic value) async {
    final db = await instance.database;
    final existingPrefs = await getUserPreferences();
    
    if (existingPrefs != null) {
      // Aggiorna il campo esistente
      await db.update(
        'user_preferences',
        {field: value},
        where: 'id = ?',
        whereArgs: [1],
      );
    } else {
      // Crea nuovo record con solo questo campo
      await db.insert(
        'user_preferences',
        {
          'id': 1,
          field: value,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }
  
  // Salva preferenze parziali (quando non tutti i campi sono presenti)
  static Future<void> savePartialUserPreferences({
    double? peso,
    int? altezza,
    int? eta,
    String? genere,
    int? obiettivoCalorico,
    String? livelloAttivita,
    String? obiettivo,
  }) async {
    final db = await instance.database;
    final existingPrefs = await getUserPreferences();
    
    final Map<String, dynamic> data = {'id': 1};
    
    if (peso != null) data['peso'] = peso;
    if (altezza != null) data['altezza'] = altezza;
    if (eta != null) data['eta'] = eta;
    if (genere != null) data['genere'] = genere;
    if (obiettivoCalorico != null) data['obiettivo_calorico'] = obiettivoCalorico;
    if (livelloAttivita != null) data['livello_attivita'] = livelloAttivita;
    if (obiettivo != null) data['obiettivo'] = obiettivo;
    
    if (existingPrefs != null) {
      // Aggiorna i campi esistenti
      await db.update(
        'user_preferences',
        data,
        where: 'id = ?',
        whereArgs: [1],
      );
    } else {
      // Crea nuovo record
      await db.insert(
        'user_preferences',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  // Recupera preferenze utente
  static Future<Map<String, dynamic>?> getUserPreferences() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> results = await db.query(
      'user_preferences',
      where: 'id = ?',
      whereArgs: [1],
    );
    if (results.isNotEmpty) {
      return results.first;
    }
    return null;
  }

  // Recupera ricette locali per il contesto Gemini
  static Future<List<Map<String, dynamic>>> getLocalRecipesForGemini() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> results = await db.query(
      'ricette',
      columns: ['id', 'nome', 'ingredienti'],
      limit: 20, // Limita a 20 ricette per non sovraccaricare il contesto
    );
    return results;
  }

  // Calcola BMR usando la formula di Mifflin-St Jeor
  static double calcolaBMR({
    required double peso,
    required int altezza,
    required int eta,
    required String genere,
  }) {
    if (genere.toLowerCase() == 'uomo' || genere.toLowerCase() == 'male') {
      return (10 * peso) + (6.25 * altezza) - (5 * eta) + 5;
    } else {
      return (10 * peso) + (6.25 * altezza) - (5 * eta) - 161;
    }
  }

  /// Fattore moltiplicativo TDEE (Mifflin-St Jeor × livello attività).
  static double fattoreAttivita(String livelloAttivita) {
    switch (livelloAttivita.toLowerCase()) {
      case 'sedentario':
        return 1.2;
      case 'leggermente attivo':
        return 1.375;
      case 'moderatamente attivo':
        return 1.55;
      case 'molto attivo':
        return 1.725;
      case 'atleta':
      case 'estremamente attivo':
        return 1.9;
      default:
        return 1.2;
    }
  }

  /// TDEE = BMR × fattore attività (consumo calorico totale giornaliero).
  static int calcolaTDEE({
    required double bmr,
    required String livelloAttivita,
  }) {
    return (bmr * fattoreAttivita(livelloAttivita)).round();
  }

  // Calcola obiettivo calorico basato sul BMR e sul livello di attività
  static int calcolaObiettivoCalorico({
    required double bmr,
    required String obiettivo,
    required String livelloAttivita,
  }) {
    double tdee = bmr * fattoreAttivita(livelloAttivita);

    // Aggiustamenti per obiettivo
    switch (obiettivo.toLowerCase()) {
      case 'perdere peso':
        tdee -= 500; // Deficit di 500 calorie
        break;
      case 'aumentare massa':
        tdee += 500; // Surplus di 500 calorie
        break;
      case 'mantenere':
        // Nessun aggiustamento
        break;
    }

    return tdee.round();
  }

  // Calcola calorie da ingredienti
  static int calcolaCalorieDaIngredienti(List<dynamic> ingredienti) {
    int totalCalories = 0;
    
    // Valori calorici medi per categoria (kcal per 100g)
    final Map<String, double> caloriePerCategoria = {
      'ortofrutta': 30, // ~30 kcal/100g
      'carne': 200, // ~200 kcal/100g
      'pesce': 150, // ~150 kcal/100g
      'latticini': 100, // ~100 kcal/100g
      'panetteria': 250, // ~250 kcal/100g
      'surgelati': 150, // ~150 kcal/100g
      'dispensa': 350, // ~350 kcal/100g (pasta, riso, ecc.)
      'bevande': 40, // ~40 kcal/100ml
    };
    
    for (final ingrediente in ingredienti) {
      if (ingrediente is Map<String, dynamic>) {
        final quantita = ingrediente['quantita'];
        final unita = ingrediente['unita']?.toString().toLowerCase() ?? '';
        final categoria = ingrediente['categoria']?.toString().toLowerCase() ?? 'altro';
        
        double quantitaInGrammi = 0;
        
        // Converti quantità in grammi
        if (quantita is num) {
          if (unita.contains('g') || unita.contains('grammi')) {
            quantitaInGrammi = quantita.toDouble();
          } else if (unita.contains('kg') || unita.contains('chilogrammi')) {
            quantitaInGrammi = quantita.toDouble() * 1000;
          } else if (unita.contains('ml') || unita.contains('millilitri')) {
            quantitaInGrammi = quantita.toDouble(); // 1ml ≈ 1g per liquidi
          } else if (unita.contains('l') || unita.contains('litri')) {
            quantitaInGrammi = quantita.toDouble() * 1000;
          } else if (unita.contains('cucchiaio')) {
            quantitaInGrammi = quantita.toDouble() * 15; // 1 cucchiaio ≈ 15g
          } else if (unita.contains('cucchiaino')) {
            quantitaInGrammi = quantita.toDouble() * 5; // 1 cucchiaino ≈ 5g
          } else {
            quantitaInGrammi = quantita.toDouble() * 100; // Default: assume 100g
          }
        }
        
        // Calcola calorie usando il valore per categoria
        final caloriePer100g = caloriePerCategoria[categoria] ?? 100;
        totalCalories += ((quantitaInGrammi / 100) * caloriePer100g).round();
      }
    }
    
    return totalCalories;
  }
  
  // Save profile photo path
  static Future<void> saveProfilePhoto(String photoPath) async {
    final db = await instance.database;
    await db.insert(
      'profilo',
      {'id': 1, 'foto_profilo': photoPath},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // Get profile photo path
  static Future<String?> getProfilePhoto() async {
    final db = await instance.database;
    final result = await db.query(
      'profilo',
      columns: ['foto_profilo'],
      where: 'id = ?',
      whereArgs: [1],
    );
    
    if (result.isNotEmpty && result.first['foto_profilo'] != null) {
      return result.first['foto_profilo'] as String?;
    }
    return null;
  }

  // Salva menu pianificato per una data specifica
  Future<void> saveMenuPianificato(String data, String ricettaId, String pasto) async {
    final db = await database;
    await db.insert(
      'menu_pianificato',
      {
        'data': data,
        'ricetta_id': ricettaId,
        'pasto': pasto,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Ottieni menu pianificato per una data specifica
  Future<List<Map<String, dynamic>>> getMenuByDate(String data) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'menu_pianificato',
      where: 'data = ?',
      whereArgs: [data],
    );
    return results;
  }

  // Ottieni menu pianificato per un intervallo di date
  Future<List<Map<String, dynamic>>> getMenuByDateRange(String startDate, String endDate) async {
    final db = await database;
    final List<Map<String, dynamic>> results = await db.query(
      'menu_pianificato',
      where: 'data BETWEEN ? AND ?',
      whereArgs: [startDate, endDate],
      orderBy: 'data ASC',
    );
    return results;
  }

  // Elimina menu pianificato per una data specifica
  Future<void> deleteMenuByDate(String data) async {
    final db = await database;
    await db.delete(
      'menu_pianificato',
      where: 'data = ?',
      whereArgs: [data],
    );
  }

  // Elimina singolo menu pianificato
  Future<void> deleteSingleMenu(int id) async {
    final db = await database;
    await db.delete(
      'menu_pianificato',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
