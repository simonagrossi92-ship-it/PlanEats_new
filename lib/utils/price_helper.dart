import '../models.dart';

class PriceEstimate {
  final double amount;
  final bool isReliable;

  PriceEstimate(this.amount, {this.isReliable = true});
}

PriceEstimate estimatePrice(String name, double? quantity, String? unit, {Map<String, CustomProduct>? customProducts}) {
  final n = name.toLowerCase().trim();
  final u = (unit ?? '').toLowerCase().trim();
  final q = quantity ?? 1.0;

  // Prima controlla nei prodotti personalizzati
  if (customProducts != null && customProducts.isNotEmpty) {
    final product = customProducts[n];
    if (product != null) {
      double factor = q;
      if (product.isWeight) {
        // Conversioni unità di peso
        if (u == 'g' || u == 'gr' || u == 'grammi') {
          factor = q / 1000.0;
        } else if (u == 'hg' || u == 'etti') {
          factor = q / 10.0;
        } else if (u == 'ml') {
          factor = q / 1000.0;
        } else if (u == 'cl') {
          factor = q / 100.0;
        } else if (u == 'dl') {
          factor = q / 10.0;
        }
        // Se l'unità è kg o l, factor rimane q
      }
      return PriceEstimate(product.price * factor, isReliable: true);
    }
  }

  // Prezzi medi indicativi (in Euro)
  // soldByWeight: prezzo per KG
  // soldByPiece: prezzo per PEZZO
  final Map<String, _PriceInfo> catalog = {
    // Ortofrutta
    'mela': _PriceInfo(2.2, isWeight: true),
    'pera': 2.5.w,
    'banana': 1.8.w,
    'pomodor': 2.8.w,
    'patat': 1.4.w,
    'insalata': 2.0.w,
    'cipolla': 1.2.w,
    'aglio': 0.6.p,
    'carota': 1.5.w,
    'zucchina': 2.0.w,
    'limone': 0.5.p,
    'arancia': 2.0.w,

    // Carne/Pesce
    'pollo': 9.5.w,
    'manzo': 18.0.w,
    'maiale': 9.0.w,
    'macinato': 11.0.w,
    'tonno': 15.0.w,
    'salmone': 24.0.w,
    'merluzzo': 16.0.w,
    'prosciutto': 28.0.w,
    'salsiccia': 12.0.w,

    // Latticini/Uova
    'latte': 1.6.w, // litro
    'uova': 0.35.p,
    'uovo': 0.35.p,
    'burro': 12.0.w,
    'yogurt': 1.0.p,
    'mozzarella': 14.0.w,
    'parmigiano': 22.0.w,
    'ricotta': 10.0.w,
    'pecorino': 20.0.w,

    // Panetteria
    'pane': 4.0.w,
    'focaccia': 14.0.w,
    'pizza': 12.0.w,
    'biscott': 5.0.p, // per pacco

    // Dispensa
    'pasta': 1.8.w,
    'riso': 2.8.w,
    'farina': 1.2.w,
    'zucchero': 1.4.w,
    'olio': 9.0.w, // litro
    'passata': 1.5.p,
    'caffè': 7.0.p,
  };

  double price = 0.0;
  bool found = false;

  for (final entry in catalog.entries) {
    if (n.contains(entry.key)) {
      final info = entry.value;
      double factor = q;

      if (info.isWeight) {
        // Normalizzazione verso il KG/Litro
        if (u == 'g' || u == 'gr' || u == 'grammi') {
          factor = q / 1000.0;
        } else if (u == 'hg' || u == 'etti') {
          factor = q / 10.0;
        } else if (u == 'ml') {
          factor = q / 1000.0;
        } else if (u == 'cl') {
          factor = q / 100.0;
        } else if (u == 'dl') {
          factor = q / 10.0;
        }
        // Se l'unità è kg o l, factor rimane q
      } else {
        // Se è a pezzo, l'unità non cambia il moltiplicatore (di solito)
        // ma potremmo aggiungere logica se servisse (es. confezioni da 6)
      }

      price = info.unitPrice * factor;
      found = true;
      break;
    }
  }

  if (!found) return PriceEstimate(0.0, isReliable: false);
  return PriceEstimate(price);
}

class _PriceInfo {
  final double unitPrice;
  final bool isWeight;
  _PriceInfo(this.unitPrice, {required this.isWeight});
}

extension _PriceHelpers on double {
  _PriceInfo get w => _PriceInfo(this, isWeight: true);
  _PriceInfo get p => _PriceInfo(this, isWeight: false);
}
