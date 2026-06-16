import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../app_state.dart';
import '../models.dart';

class ArchiveReportScreen extends StatefulWidget {
  const ArchiveReportScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ArchiveReportScreen> createState() => _ArchiveReportScreenState();
}

class _ArchiveReportScreenState extends State<ArchiveReportScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  IngredientCategory? _selectedCategory;
  List<ArchivedItem> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _setDefaults();
    _updateFilteredItems();
  }

  void _setDefaults() {
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month - 1, 1);
    _endDate = now;
  }

  void _updateFilteredItems() {
    final allItems = widget.state.getArchivedItems();

    _filteredItems = allItems.where((item) {
      // Filtro per data di inizio
      if (_startDate != null && item.archivedDate.isBefore(_startDate!)) {
        return false;
      }

      // Filtro per data di fine
      if (_endDate != null && item.archivedDate.isAfter(_endDate!)) {
        return false;
      }

      // Filtro per categoria
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }

      return true;
    }).toList();
  }

  Map<IngredientCategory, double> _getCategoryTotals() {
    final totals = <IngredientCategory, double>{};

    for (final item in _filteredItems) {
      final price = item.estimatedPrice ?? 0.0;
      totals[item.category] = (totals[item.category] ?? 0.0) + price;
    }

    return totals;
  }

  double _getTotalSpent() {
    return _filteredItems.fold(
        0.0, (sum, item) => sum + (item.estimatedPrice ?? 0.0));
  }

  @override
  Widget build(BuildContext context) {
    final categoryTotals = _getCategoryTotals();
    final totalSpent = _getTotalSpent();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Archivio'),
        backgroundColor: const Color(0xFF8BA888),
      ),
      body: Column(
        children: [
          // Filtri
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtri',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Periodo date
                Row(
                  children: [
                    Expanded(
                      child: ListTile(
                        title: const Text('Data inizio'),
                        subtitle: Text(_startDate != null
                            ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}'
                            : 'Seleziona data'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _selectStartDate,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    Expanded(
                      child: ListTile(
                        title: const Text('Data fine'),
                        subtitle: Text(_endDate != null
                            ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}'
                            : 'Seleziona data'),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _selectEndDate,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Filtro categoria
                ListTile(
                  title: const Text('Reparto'),
                  subtitle: Text(_selectedCategory != null
                      ? ingredientCategoryLabel(_selectedCategory!)
                      : 'Tutti i reparti'),
                  trailing: const Icon(Icons.category),
                  onTap: _selectCategory,
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 8),

                // Pulsanti reset
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset filtri'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _setLastMonth,
                      icon: const Icon(Icons.date_range),
                      label: const Text('Mese scorso'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Statistiche
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Prodotti archiviati',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            '${_filteredItems.length}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8BA888),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Importo totale',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                          Text(
                            '€ ${totalSpent.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8BA888),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Grafico
          if (categoryTotals.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Spesa per Reparto',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildChart(categoryTotals),
              ),
            ),
          ],

          // Lista prodotti
          if (_filteredItems.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Prodotti nel periodo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _filteredItems.length,
                itemBuilder: (context, index) {
                  final item = _filteredItems[index];
                  return _ReportItemTile(
                    item: item,
                    onDelete: () => _deleteItem(item),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChart(Map<IngredientCategory, double> categoryTotals) {
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: sortedCategories.isNotEmpty
                      ? (sortedCategories.first.value * 1.2).ceilToDouble()
                      : 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => Colors.white,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (group.x.toInt() >= sortedCategories.length) {
                          return null;
                        }
                        final category = sortedCategories[group.x.toInt()].key;
                        final value = sortedCategories[group.x.toInt()].value;
                        return BarTooltipItem(
                          '${ingredientCategoryLabel(category)}\n€ ${value.toStringAsFixed(2)}',
                          const TextStyle(color: Colors.black),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '€ ${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= sortedCategories.length) {
                            return const Text('');
                          }
                          final category = sortedCategories[value.toInt()].key;
                          final label = ingredientCategoryLabel(category);
                          return SizedBox(
                            width: 60,
                            child: Text(
                              label.length > 8
                                  ? '${label.substring(0, 6)}...'
                                  : label,
                              style: const TextStyle(fontSize: 9),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: sortedCategories.asMap().entries.map((entry) {
                    final index = entry.key;
                    final categoryData = entry.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: categoryData.value,
                          color: _getCategoryColor(categoryData.key),
                          width: 20,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(IngredientCategory category) {
    switch (category) {
      case IngredientCategory.ortofrutta:
        return Colors.green;
      case IngredientCategory.carne:
        return Colors.red;
      case IngredientCategory.pesce:
        return Colors.blue;
      case IngredientCategory.latticini:
        return Colors.orange;
      case IngredientCategory.panetteria:
        return Colors.brown;
      case IngredientCategory.surgelati:
        return Colors.cyan;
      case IngredientCategory.dispensa:
        return Colors.amber;
      case IngredientCategory.bevande:
        return Colors.purple;
      case IngredientCategory.prodottiAnimali:
        return Colors.teal;
      case IngredientCategory.curaCasa:
        return Colors.lime;
      case IngredientCategory.igienePersonale:
        return Colors.pink;
      case IngredientCategory.altro:
        return Colors.grey;
    }
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: _endDate ?? DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        _updateFilteredItems();
      });
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() {
        _endDate = date;
        _updateFilteredItems();
      });
    }
  }

  Future<void> _selectCategory() async {
    final category = await showDialog<IngredientCategory?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleziona Reparto'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                title: const Text('Tutti i reparti'),
                onTap: () => Navigator.pop(context, null),
              ),
              ...IngredientCategory.values.map((cat) => ListTile(
                    title: Text(ingredientCategoryLabel(cat)),
                    onTap: () => Navigator.pop(context, cat),
                  )),
            ],
          ),
        ),
      ),
    );

    if (category != null) {
      setState(() {
        _selectedCategory = category;
        _updateFilteredItems();
      });
    }
  }

  void _resetFilters() {
    setState(() {
      _setDefaults();
      _selectedCategory = null;
      _updateFilteredItems();
    });
  }

  void _setLastMonth() {
    final now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month - 1, 1);
      _endDate = DateTime(
          now.year, now.month - 1, DateTime(now.year, now.month, 0).day);
      _selectedCategory = null;
      _updateFilteredItems();
    });
  }

  void _deleteItem(ArchivedItem item) async {
    await widget.state.deleteArchivedItem(item.id);
    setState(() {
      _updateFilteredItems();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prodotto rimosso dall\'archivio'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}

class _ReportItemTile extends StatelessWidget {
  const _ReportItemTile({
    required this.item,
    required this.onDelete,
  });
  final ArchivedItem item;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(item.category),
          child: Text(
            ingredientCategoryLabel(item.category)
                .substring(0, 2)
                .toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(item.name),
        subtitle: Text(
          '${item.formattedDate} • ${ingredientCategoryLabel(item.category)}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '€ ${(item.estimatedPrice ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8BA888),
                  ),
                ),
                if (item.quantity != null)
                  Text(
                    '${item.quantity!.toStringAsFixed(1).replaceAll('.0', '')} ${item.unit ?? ''}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: onDelete,
              tooltip: 'Rimuovi',
              color: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(IngredientCategory category) {
    switch (category) {
      case IngredientCategory.ortofrutta:
        return Colors.green;
      case IngredientCategory.carne:
        return Colors.red;
      case IngredientCategory.pesce:
        return Colors.blue;
      case IngredientCategory.latticini:
        return Colors.orange;
      case IngredientCategory.panetteria:
        return Colors.brown;
      case IngredientCategory.surgelati:
        return Colors.cyan;
      case IngredientCategory.dispensa:
        return Colors.amber;
      case IngredientCategory.bevande:
        return Colors.purple;
      case IngredientCategory.prodottiAnimali:
        return Colors.teal;
      case IngredientCategory.curaCasa:
        return Colors.lime;
      case IngredientCategory.igienePersonale:
        return Colors.pink;
      case IngredientCategory.altro:
        return Colors.grey;
    }
  }
}
