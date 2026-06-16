import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';

class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  @override
  Widget build(BuildContext context) {
    final archivedItems = widget.state.getArchivedItems();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archivio Prodotti'),
        actions: [
          if (archivedItems.isNotEmpty) ...[
            IconButton(
              tooltip: 'Svuota archivio',
              onPressed: () => _showClearAllDialog(context),
              icon: const Icon(Icons.delete_sweep),
            ),
          ],
        ],
      ),
      body: archivedItems.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.archive_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Archivio vuoto',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'I prodotti spuntati nella lista della spesa appariranno qui',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: archivedItems.length,
              itemBuilder: (context, index) {
                final item = archivedItems[index];
                return _ArchivedItemTile(
                  item: item,
                  onDelete: () => _deleteItem(item.id),
                );
              },
            ),
    );
  }

  void _deleteItem(String id) async {
    await widget.state.deleteArchivedItem(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prodotto rimosso dall\'archivio'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _showClearAllDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Svuota Archivio'),
        content: const Text(
          'Sei sicuro di voler rimuovere tutti i prodotti dall\'archivio? Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await widget.state.clearAllArchivedItems();
              if (mounted) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Archivio svuotato'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Svuota'),
          ),
        ],
      ),
    );
  }
}

class _ArchivedItemTile extends StatelessWidget {
  const _ArchivedItemTile({
    required this.item,
    required this.onDelete,
  });

  final ArchivedItem item;
  final VoidCallback onDelete;

  Color _getCategoryColor() {
    switch (item.category) {
      case IngredientCategory.ortofrutta:
        return Colors.green.shade100;
      case IngredientCategory.carne:
        return Colors.red.shade100;
      case IngredientCategory.pesce:
        return Colors.blue.shade100;
      case IngredientCategory.latticini:
        return Colors.orange.shade100;
      case IngredientCategory.panetteria:
        return Colors.brown.shade100;
      case IngredientCategory.surgelati:
        return Colors.cyan.shade100;
      case IngredientCategory.dispensa:
        return Colors.amber.shade100;
      case IngredientCategory.bevande:
        return Colors.purple.shade100;
      case IngredientCategory.prodottiAnimali:
        return Colors.teal.shade100;
      case IngredientCategory.curaCasa:
        return Colors.lime.shade100;
      case IngredientCategory.igienePersonale:
        return Colors.pink.shade100;
      case IngredientCategory.altro:
        return Colors.grey.shade200;
    }
  }

  String _displayQuantity() {
    if (item.quantity == null) return '';
    final q = item.quantity!;
    final unit = item.unit?.isEmpty == true ? '' : ' ${item.unit}';

    // Formatta la quantità
    String formattedQty;
    if ((q - q.roundToDouble()).abs() < 0.00001) {
      formattedQty = q.toInt().toString();
    } else {
      formattedQty = q.toStringAsFixed(1).replaceAll('.0', '');
    }

    return '$formattedQty$unit';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Categoria
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    ingredientCategoryLabel(item.category),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                // Data archiviazione
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.formattedDate,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      item.formattedTime,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Nome prodotto
            Text(
              item.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Quantità e prezzo
            if (item.quantity != null || item.estimatedPrice != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  if (item.quantity != null) ...[
                    Text(
                      _displayQuantity(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                    if (item.estimatedPrice != null) const SizedBox(width: 16),
                  ],
                  if (item.estimatedPrice != null)
                    Text(
                      '€ ${item.estimatedPrice!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8BA888),
                      ),
                    ),
                ],
              ),
            ],
            // Note
            if (item.note != null && item.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.note!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Pulsante elimina
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, size: 18),
                  label: const Text('Rimuovi'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
