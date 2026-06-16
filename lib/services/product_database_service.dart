import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models.dart';

class ProductDatabaseService {
  static ProductDatabaseService? _instance;
  static ProductDatabaseService get instance => _instance ??= ProductDatabaseService._();
  
  ProductDatabaseService._();

  late Directory _databaseDir;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _databaseDir = Directory('${appDir.path}/PlanEats/Products');
      
      // Crea la cartella se non esiste
      if (!await _databaseDir.exists()) {
        await _databaseDir.create(recursive: true);
      }
      
      _initialized = true;
    } catch (e) {
      throw Exception('Impossibile inizializzare il database prodotti: $e');
    }
  }

  Future<void> saveProduct(CustomProduct product) async {
    await initialize();
    
    try {
      final fileName = '${product.name.toLowerCase().trim().replaceAll(' ', '_')}.json';
      final file = File('${_databaseDir.path}/$fileName');
      
      await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(product.toJson()),
      );
    } catch (e) {
      throw Exception('Impossibile salvare il prodotto: $e');
    }
  }

  Future<List<CustomProduct>> loadAllProducts() async {
    await initialize();
    
    try {
      final files = await _databaseDir.list().toList();
      final products = <CustomProduct>[];
      
      for (final file in files) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final json = jsonDecode(content) as Map<String, dynamic>;
            final product = CustomProduct.fromJson(json);
            products.add(product);
          } catch (e) {
            // Ignora file corrotti
            continue;
          }
        }
      }
      
      return products;
    } catch (e) {
      throw Exception('Impossibile caricare i prodotti: $e');
    }
  }

  Future<CustomProduct?> findProduct(String name) async {
    await initialize();
    
    try {
      final fileName = '${name.toLowerCase().trim().replaceAll(' ', '_')}.json';
      final file = File('${_databaseDir.path}/$fileName');
      
      if (!await file.exists()) return null;
      
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      return CustomProduct.fromJson(json);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteProduct(String name) async {
    await initialize();
    
    try {
      final fileName = '${name.toLowerCase().trim().replaceAll(' ', '_')}.json';
      final file = File('${_databaseDir.path}/$fileName');
      
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Impossibile eliminare il prodotto: $e');
    }
  }

  Future<void> exportDatabase() async {
    await initialize();
    
    try {
      final products = await loadAllProducts();
      final exportFile = File('${_databaseDir.path}/database_export.json');
      
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'total_products': products.length,
        'products': products.map((p) => p.toJson()).toList(),
      };
      
      await exportFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(exportData),
      );
    } catch (e) {
      throw Exception('Impossibile esportare il database: $e');
    }
  }

  Future<String> getDatabasePath() async {
    await initialize();
    return _databaseDir.path;
  }

  Future<int> getProductsCount() async {
    await initialize();
    
    try {
      final files = await _databaseDir.list().toList();
      return files.where((f) => f is File && f.path.endsWith('.json')).length;
    } catch (e) {
      return 0;
    }
  }
}
