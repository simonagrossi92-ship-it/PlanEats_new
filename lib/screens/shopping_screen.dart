import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/gemini_service.dart';
import '../utils/dates.dart';
import '../utils/category_helper.dart';

class ShoppingScreen extends StatefulWidget {
  const ShoppingScreen({super.key, required this.state});
  final AppState state;

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  String? _geminiEstimatedPrice;
  bool _isEstimatingPrice = false;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadEstimatedPrice();
  }

  void _loadEstimatedPrice() {
    final now = DateTime.now();
    final days = weekDays(now);
    final start = days.first;
    final weekKey = isoDate(weekStartMonday(start));
    final savedPrice = widget.state.getEstimatedPrice(weekKey);
    if (savedPrice != null) {
      setState(() {
        _geminiEstimatedPrice = savedPrice;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      locale: const Locale('it', 'IT'),
    );

    if (startDate != null && mounted) {
      final endDate = await showDatePicker(
        context: context,
        initialDate: startDate.add(const Duration(days: 7)),
        firstDate: startDate,
        lastDate: startDate.add(const Duration(days: 365)),
        locale: const Locale('it', 'IT'),
      );

      if (endDate != null) {
        setState(() {
          _startDate = startDate;
          _endDate = endDate;
        });
      }
    }
  }

  List<DateTime> _getDateRange() {
    if (_startDate != null && _endDate != null) {
      final days = <DateTime>[];
      var current = _startDate!;
      while (current.isBefore(_endDate!) || current.isAtSameMomentAs(_endDate!)) {
        days.add(current);
        current = current.add(const Duration(days: 1));
      }
      return days;
    }
    return weekDays(DateTime.now());
  }

  // Reset della lista spesa e del saldo dopo archiviazione
  Future<void> _resetSpesa(DateTime now) async {
    // Resetta la lista della spesa per la settimana corrente
    await widget.state.resetShoppingChecks(now);

    // Resetta il saldo stimato
    final days = weekDays(now);
    final start = days.first;
    final weekKey = isoDate(weekStartMonday(start));
    await widget.state.saveEstimatedPrice(weekKey, null);

    // Aggiorna lo stato locale
    setState(() {
      _geminiEstimatedPrice = null;
    });
  }

  Future<void> _estimatePriceWithGemini() async {
    final now = DateTime.now();
    final days = weekDays(now);
    final items = _buildShoppingItems(state: widget.state, days: days);
    // Include quantities and units for accurate price calculation
    final shoppingList = items.map((item) => 
      item.displayQuantity.isEmpty ? item.name : '${item.displayQuantity} ${item.name}'
    ).toList();

    if (shoppingList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La lista della spesa è vuota'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isEstimatingPrice = true;
    });

    try {
      final geminiService = GeminiService();
      final estimate = await geminiService.stimaPrezzoSpesa(shoppingList);

      // Salva il prezzo stimato
      final start = days.first;
      final weekKey = isoDate(weekStartMonday(start));
      await widget.state.saveEstimatedPrice(weekKey, estimate);

      setState(() {
        _geminiEstimatedPrice = estimate;
        _isEstimatingPrice = false;
      });
    } catch (e) {
      setState(() {
        _isEstimatingPrice = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final days = _getDateRange();
    final start = days.first;
    final end = days.last;

    final items = _buildShoppingItems(state: widget.state, days: days);
    final grouped = <IngredientCategory, List<_ShoppingItem>>{};

    for (final it in items) {
      grouped.putIfAbsent(it.category, () => []).add(it);
    }

    return Scaffold(
      appBar: AppBar(
        title: _startDate != null && _endDate != null
            ? Text('Spesa • ${_startDate!.day}/${_startDate!.month} - ${_endDate!.day}/${_endDate!.month}')
            : Text('Spesa • ${weekdayShortLabel(start)}-${weekdayShortLabel(end)}'),
        actions: [
          IconButton(
            tooltip: 'Seleziona intervallo date',
            onPressed: _selectDateRange,
            icon: const Icon(Icons.calendar_month),
          ),
          IconButton(
            tooltip: 'Archivia spuntati',
            onPressed: () async {
              final now = DateTime.now();
              final days = weekDays(now);

              // Controlla se ci sono prodotti spuntati
              bool hasCheckedItems = false;
              for (final day in days) {
                final weekKey = isoDate(weekStartMonday(day));
                final checks = widget.state.data.shoppingChecks[weekKey] ?? {};
                for (final entry in checks.entries) {
                  if (entry.value == true) {
                    hasCheckedItems = true;
                    break;
                  }
                }
                if (hasCheckedItems) break;
              }

              if (!hasCheckedItems) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nessun prodotto spuntato da archiviare'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              // Mostra dialogo di conferma
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Archivia Prodotti Spuntati'),
                      content: const Text(
                        'Vuoi archiviare tutti i prodotti spuntati e rimuoverli dalla lista corrente?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Annulla'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Archivia'),
                        ),
                      ],
                    ),
                  ) ??
                  false;

              if (confirmed) {
                // Prima ottieni gli ingredienti spuntati
                final checkedIngredients = <Ingredient>[];
                for (final day in days) {
                  final weekKey = isoDate(weekStartMonday(day));
                  final checks =
                      widget.state.data.shoppingChecks[weekKey] ?? {};

                  // Ottieni ingredienti dalla lista generata
                  final generatedList =
                      widget.state.data.generatedShoppingList[weekKey] ?? [];
                  for (final ingredient in generatedList) {
                    final norm = ingredient.name.toLowerCase();
                    final unit = (ingredient.unit ?? '').trim().toLowerCase();
                    final key = '${ingredient.category.name}|$norm|$unit';
                    if (checks[key] == true) {
                      checkedIngredients.add(ingredient);
                    }
                  }

                  // Ottieni ingredienti extra
                  final extraList =
                      widget.state.data.extraShoppingItems[weekKey] ?? [];
                  for (final ingredient in extraList) {
                    final norm = ingredient.name.toLowerCase();
                    final unit = (ingredient.unit ?? '').trim().toLowerCase();
                    final key = '${ingredient.category.name}|$norm|$unit';
                    if (checks[key] == true) {
                      checkedIngredients.add(ingredient);
                    }
                  }
                }

                // Mostra dialog per inserire importo scontrino
                final ctx = context;
                final receiptAmount = await showDialog<double>(
                  context: ctx,
                  builder: (context) {
                    final controller = TextEditingController();

                    return AlertDialog(
                      title: const Text('Importo Scontrino'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Inserisci l\'importo totale dello scontrino',
                            style: TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: controller,
                            decoration: const InputDecoration(
                              labelText: 'Importo (€)',
                              prefixText: '€ ',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            autofocus: true,
                            onFieldSubmitted: (value) {
                              Navigator.pop(
                                  context, double.tryParse(value) ?? 0.0);
                            },
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, null),
                          child: const Text('Annulla'),
                        ),
                        FilledButton(
                          onPressed: () {
                            final value =
                                double.tryParse(controller.text) ?? 0.0;
                            Navigator.pop(context, value);
                          },
                          child: const Text('Conferma'),
                        ),
                      ],
                    );
                  },
                );

                if (receiptAmount == null || receiptAmount <= 0) {
                  // Se l'utente annulla o inserisce un valore non valido,
                  // procedi con l'archiviazione normale
                  debugPrint(
                      'Importo scontrino non valido o annullato: $receiptAmount');
                  await widget.state.archiveCheckedItems(now);
                  if (checkedIngredients.isNotEmpty) {
                    await widget.state
                        .convertArchivedShoppingToExpenses(checkedIngredients);
                  }

                  // Reset della lista spesa e del saldo dopo archiviazione riuscita
                  await _resetSpesa(now);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Prodotti archiviati'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                  return;
                }

                debugPrint(
                    'Importo scontrino valido: €${receiptAmount.toStringAsFixed(2)}');

                // Calcola la distribuzione per reparto
                final categoryCounts = <IngredientCategory, int>{};
                for (final ingredient in checkedIngredients) {
                  categoryCounts[ingredient.category] =
                      (categoryCounts[ingredient.category] ?? 0) + 1;
                }

                final totalCount = checkedIngredients.length;
                debugPrint('Totale ingredienti spuntati: $totalCount');
                debugPrint('Distribuzione per reparto: $categoryCounts');

                final categoryAmounts = <IngredientCategory, double>{};

                for (final entry in categoryCounts.entries) {
                  final percentage = entry.value / totalCount;
                  categoryAmounts[entry.key] = receiptAmount * percentage;
                }

                debugPrint('Importi per reparto calcolati: $categoryAmounts');

                // Archivia gli elementi spuntati
                await widget.state.archiveCheckedItems(now);

                // Converti gli importi calcolati in spese
                debugPrint(
                    'Chiamata convertCategoryAmountsToExpenses con $categoryAmounts');
                await widget.state
                    .convertCategoryAmountsToExpenses(categoryAmounts);
                debugPrint(
                    'Dopo convertCategoryAmountsToExpenses, spese totali: ${widget.state.data.expenseRecords.length}');

                // Reset della lista spesa e del saldo dopo archiviazione riuscita
                await _resetSpesa(now);

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Scontrino registrato e spese aggiornate!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.inventory_2),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_shopping_cart),
            tooltip: 'Aggiungi',
            onSelected: (value) {
              if (value == 'extra') {
                _showAddItemDialog(context, now);
              } else if (value == 'new_product') {
                _showAddNewProductDialog(context);
              } else if (value == 'edit_product') {
                _showEditProductDialog(context);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'extra',
                child: Row(
                  children: [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('Aggiungi spesa extra'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'new_product',
                child: Row(
                  children: [
                    Icon(Icons.add_circle_outline),
                    SizedBox(width: 8),
                    Text('Aggiungi nuovo prodotto'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'edit_product',
                child: Row(
                  children: [
                    Icon(Icons.edit),
                    SizedBox(width: 8),
                    Text('Modifica prodotto esistente'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Reset spunte',
            onPressed: () async {
              final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Reset spunte'),
                      content: const Text(
                          'Vuoi azzerare tutte le spunte e gli extra di questa settimana?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Annulla')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Reset')),
                      ],
                    ),
                  ) ??
                  false;
              if (!ok) return;
              await widget.state.resetShoppingChecks(now);
            },
            icon: const Icon(Icons.restart_alt),
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Lista vuota.'),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _showAddItemDialog(context, now),
                    icon: const Icon(Icons.add),
                    label: const Text('Aggiungi spesa extra'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _showAddNewProductDialog(context),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Aggiungi nuovo prodotto'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8BA888),
                    ),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      ...IngredientCategory.values
                          .where(grouped.containsKey)
                          .map((cat) {
                        final catItems = grouped[cat]!
                          ..sort((a, b) => a.name.compareTo(b.name));
                        return _CategorySection(
                          state: widget.state,
                          weekRef: now,
                          category: cat,
                          items: catItems,
                          onEditExtra: (index, item) => _showAddItemDialog(
                              context, now,
                              editIndex: index, initialItem: item),
                        );
                      }),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_geminiEstimatedPrice == null)
                        FilledButton.icon(
                          onPressed: _isEstimatingPrice
                              ? null
                              : _estimatePriceWithGemini,
                          icon: _isEstimatingPrice
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text('Genera prezzo medio'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF8BA888),
                          ),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'PREZZO AI',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey),
                            ),
                            Text(
                              _geminiEstimatedPrice!,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8BA888)),
                            ),
                            TextButton(
                              onPressed: _estimatePriceWithGemini,
                              child: const Text('Ricalcola'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showAddItemDialog(BuildContext context, DateTime weekRef,
      {int? editIndex, Ingredient? initialItem}) {
    String name = initialItem?.name ?? '';
    IngredientCategory category =
        initialItem?.category ?? IngredientCategory.altro;
    String? quantityStr = initialItem?.quantity?.toString();
    String? unit = initialItem?.unit;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(editIndex == null ? 'Aggiungi alla spesa' : 'Modifica voce'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: name,
                  decoration:
                      const InputDecoration(labelText: 'Nome ingrediente'),
                  onChanged: (v) {
                    name = v;
                    if (editIndex == null) {
                      _updateSuggestions(
                        v,
                        setDialogState,
                        (newCategory) =>
                            setDialogState(() => category = newCategory),
                        (newUnit) => setDialogState(() => unit = newUnit),
                      );
                    }
                  },
                  autofocus: editIndex == null,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<IngredientCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Reparto'),
                  items: IngredientCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(ingredientCategoryLabel(c))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: quantityStr,
                        decoration: const InputDecoration(labelText: 'Qtà'),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => quantityStr = v,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: unit,
                        decoration: const InputDecoration(labelText: 'Unità'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Nessuna')),
                          DropdownMenuItem(value: 'pz', child: Text('pezzi')),
                          DropdownMenuItem(value: 'g', child: Text('grammi')),
                          DropdownMenuItem(
                              value: 'kg', child: Text('chilogrammi')),
                          DropdownMenuItem(value: 'hg', child: Text('etti')),
                          DropdownMenuItem(value: 'l', child: Text('litri')),
                          DropdownMenuItem(
                              value: 'ml', child: Text('millilitri')),
                          DropdownMenuItem(
                              value: 'cl', child: Text('centilitri')),
                          DropdownMenuItem(
                              value: 'dl', child: Text('decilitri')),
                          DropdownMenuItem(
                              value: 'cucchiaino', child: Text('cucchiaini')),
                          DropdownMenuItem(
                              value: 'cucchiaio', child: Text('cucchiai')),
                          DropdownMenuItem(
                              value: 'tazza', child: Text('tazze')),
                          DropdownMenuItem(
                              value: 'bicchiere', child: Text('bicchieri')),
                          DropdownMenuItem(
                              value: 'confezione', child: Text('confezioni')),
                          DropdownMenuItem(
                              value: 'pacco', child: Text('pacchi')),
                          DropdownMenuItem(
                              value: 'barattolo', child: Text('barattoli')),
                          DropdownMenuItem(
                              value: 'vasetto', child: Text('vasetti')),
                          DropdownMenuItem(
                              value: 'busta', child: Text('buste')),
                          DropdownMenuItem(
                              value: 'scatola', child: Text('scatole')),
                          DropdownMenuItem(
                              value: 'flacone', child: Text('flaconi')),
                          DropdownMenuItem(
                              value: 'bottiglia', child: Text('bottiglie')),
                          DropdownMenuItem(
                              value: 'lattina', child: Text('lattine')),
                        ],
                        onChanged: (v) => setDialogState(() => unit = v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Annulla')),
            FilledButton(
              onPressed: () {
                if (name.trim().isEmpty) return;
                final qty = double.tryParse(quantityStr ?? '');
                final newItem = Ingredient(
                  name: name.trim(),
                  category: category,
                  quantity: qty,
                  unit: unit?.trim(),
                );

                if (editIndex == null) {
                  widget.state.addExtraShoppingItem(weekRef, newItem);
                } else {
                  widget.state
                      .updateExtraShoppingItem(weekRef, editIndex, newItem);
                }
                Navigator.pop(context);
              },
              child: Text(editIndex == null ? 'Aggiungi' : 'Salva'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddNewProductDialog(BuildContext context) {
    String name = '';
    IngredientCategory category = IngredientCategory.altro;
    double? price;
    String? priceUnit;
    String? note;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Aggiungi nuovo prodotto'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Nome prodotto'),
                  onChanged: (v) => name = v,
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<IngredientCategory>(
                  initialValue: category,
                  decoration: const InputDecoration(labelText: 'Reparto'),
                  items: IngredientCategory.values
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(ingredientCategoryLabel(c))))
                      .toList(),
                  onChanged: (v) => setDialogState(() => category = v!),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Prezzo unitario',
                    prefixText: '€ ',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => price = double.tryParse(v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: priceUnit,
                  decoration:
                      const InputDecoration(labelText: 'Unità del prezzo'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Automatico')),
                    DropdownMenuItem(value: 'kg', child: Text('Al kg')),
                    DropdownMenuItem(value: 'pz', child: Text('Al pezzo')),
                    DropdownMenuItem(value: 'l', child: Text('Al litro')),
                    DropdownMenuItem(value: 'g', child: Text('Al 100g')),
                    DropdownMenuItem(
                        value: 'hg', child: Text('All\'etto (100g)')),
                    DropdownMenuItem(value: 'ml', child: Text('Ai 100ml')),
                    DropdownMenuItem(
                        value: 'confezione', child: Text('Alla confezione')),
                  ],
                  onChanged: (v) => setDialogState(() => priceUnit = v),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Note (opzionale)'),
                  onChanged: (v) => note = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                if (name.trim().isEmpty || price == null) return;

                final isWeight = priceUnit != 'pz';
                final customProduct = CustomProduct(
                  name: name.trim(),
                  category: category,
                  price: price!,
                  isWeight: isWeight,
                  priceUnit: priceUnit,
                  note: note?.trim(),
                );

                widget.state.saveCustomProduct(customProduct);
                Navigator.pop(context);

                // Mostra messaggio di successo
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Prodotto "${name.trim()}" salvato con successo!'),
                    backgroundColor: const Color(0xFF8BA888),
                  ),
                );
              },
              child: const Text('Salva prodotto'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateSuggestions(
      String query,
      StateSetter setDialogState,
      ValueSetter<IngredientCategory> onCategoryChanged,
      ValueSetter<String> onUnitChanged) async {
    if (query.trim().isEmpty) return;

    try {
      final product = await widget.state.findProductAnywhere(query);
      if (product != null) {
        setDialogState(() {
          onCategoryChanged(product.category);
          // Suggerisci unità base in base al tipo di prezzo
          if (product.priceUnit != null) {
            onUnitChanged(product.priceUnit == 'pz' ? 'pz' : 'g');
          }
        });
      } else {
        // Fallback alle categorie standard
        final suggestedCat = suggestCategory(query);
        if (suggestedCat != IngredientCategory.altro) {
          setDialogState(() {
            onCategoryChanged(suggestedCat);
          });
        }
        final suggestedUnit = suggestUnit(query);
        if (suggestedUnit != null) {
          setDialogState(() {
            onUnitChanged(suggestedUnit);
          });
        }
      }
    } catch (e) {
      // Silenzioso su errori
    }
  }

  void _showEditProductDialog(BuildContext context) {
    final customProducts = widget.state.getAllCustomProducts();

    if (customProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun prodotto personalizzato da modificare'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    CustomProduct? selectedProduct;
    String searchQuery = '';
    List<CustomProduct> filteredProducts = customProducts;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Modifica prodotto esistente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Campo di testo per ricerca/scrittura
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Cerca o scrivi nome prodotto',
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Digita per cercare o seleziona dalla lista',
                  ),
                  onChanged: (value) {
                    setDialogState(() {
                      searchQuery = value.toLowerCase().trim();
                      if (searchQuery.isEmpty) {
                        filteredProducts = customProducts;
                      } else {
                        filteredProducts = customProducts
                            .where((product) => product.name
                                .toLowerCase()
                                .contains(searchQuery))
                            .toList();
                      }

                      // Se c'è una corrispondenza esatta, selezionala automaticamente
                      final exactMatch = filteredProducts
                          .where((product) =>
                              product.name.toLowerCase() == searchQuery)
                          .firstOrNull;
                      if (exactMatch != null) {
                        selectedProduct = exactMatch;
                      }
                    });
                  },
                ),

                const SizedBox(height: 8),

                // Dropdown con prodotti filtrati
                DropdownButtonFormField<CustomProduct>(
                  initialValue: selectedProduct,
                  decoration: InputDecoration(
                    labelText: 'Seleziona prodotto',
                    helperText: filteredProducts.length < customProducts.length
                        ? '${filteredProducts.length} prodotti trovati'
                        : 'Tutti i prodotti',
                  ),
                  items: filteredProducts
                      .map((product) => DropdownMenuItem(
                            value: product,
                            child: Text(
                                '${product.name} (${ingredientCategoryLabel(product.category)})'),
                          ))
                      .toList(),
                  onChanged: (product) {
                    setDialogState(() {
                      selectedProduct = product;
                      searchQuery = product!.name;
                    });
                  },
                ),

                if (selectedProduct != null) ...[
                  const SizedBox(height: 16),

                  // Campi modificabili
                  TextFormField(
                    initialValue: selectedProduct!.name,
                    decoration:
                        const InputDecoration(labelText: 'Nome prodotto'),
                    onChanged: (v) => setDialogState(() {
                      selectedProduct = CustomProduct(
                        name: v.trim(),
                        category: selectedProduct!.category,
                        price: selectedProduct!.price,
                        isWeight: selectedProduct!.isWeight,
                        unit: selectedProduct!.unit,
                        priceUnit: selectedProduct!.priceUnit,
                        note: selectedProduct!.note,
                      );
                    }),
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<IngredientCategory>(
                    initialValue: selectedProduct!.category,
                    decoration: const InputDecoration(labelText: 'Reparto'),
                    items: IngredientCategory.values
                        .map((c) => DropdownMenuItem(
                            value: c, child: Text(ingredientCategoryLabel(c))))
                        .toList(),
                    onChanged: (v) => setDialogState(() {
                      selectedProduct = CustomProduct(
                        name: selectedProduct!.name,
                        category: v!,
                        price: selectedProduct!.price,
                        isWeight: selectedProduct!.isWeight,
                        unit: selectedProduct!.unit,
                        priceUnit: selectedProduct!.priceUnit,
                        note: selectedProduct!.note,
                      );
                    }),
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    initialValue: selectedProduct!.price.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Prezzo unitario',
                      prefixText: '€ ',
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => setDialogState(() {
                      final newPrice = double.tryParse(v);
                      if (newPrice != null) {
                        selectedProduct = CustomProduct(
                          name: selectedProduct!.name,
                          category: selectedProduct!.category,
                          price: newPrice,
                          isWeight: selectedProduct!.isWeight,
                          unit: selectedProduct!.unit,
                          priceUnit: selectedProduct!.priceUnit,
                          note: selectedProduct!.note,
                        );
                      }
                    }),
                  ),

                  const SizedBox(height: 8),

                  DropdownButtonFormField<String?>(
                    initialValue: selectedProduct!.priceUnit,
                    decoration:
                        const InputDecoration(labelText: 'Unità del prezzo'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Automatico')),
                      DropdownMenuItem(value: 'kg', child: Text('Al kg')),
                      DropdownMenuItem(value: 'pz', child: Text('Al pezzo')),
                      DropdownMenuItem(value: 'l', child: Text('Al litro')),
                      DropdownMenuItem(value: 'g', child: Text('Al 100g')),
                      DropdownMenuItem(
                          value: 'hg', child: Text('All\'etto (100g)')),
                      DropdownMenuItem(value: 'ml', child: Text('Ai 100ml')),
                      DropdownMenuItem(
                          value: 'confezione', child: Text('Alla confezione')),
                    ],
                    onChanged: (v) => setDialogState(() {
                      selectedProduct = CustomProduct(
                        name: selectedProduct!.name,
                        category: selectedProduct!.category,
                        price: selectedProduct!.price,
                        isWeight: v != 'pz',
                        unit: selectedProduct!.unit,
                        priceUnit: v,
                        note: selectedProduct!.note,
                      );
                    }),
                  ),

                  const SizedBox(height: 8),

                  TextFormField(
                    initialValue: selectedProduct!.note,
                    decoration:
                        const InputDecoration(labelText: 'Note (opzionale)'),
                    onChanged: (v) => setDialogState(() {
                      selectedProduct = CustomProduct(
                        name: selectedProduct!.name,
                        category: selectedProduct!.category,
                        price: selectedProduct!.price,
                        isWeight: selectedProduct!.isWeight,
                        unit: selectedProduct!.unit,
                        priceUnit: selectedProduct!.priceUnit,
                        note: v.trim().isEmpty ? null : v.trim(),
                      );
                    }),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                if (selectedProduct == null ||
                    selectedProduct!.name.trim().isEmpty) {
                  return;
                }

                await widget.state.saveCustomProduct(selectedProduct!);

                if (context.mounted) {
                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Prodotto "${selectedProduct!.name.trim()}" aggiornato con successo!'),
                      backgroundColor: const Color(0xFF8BA888),
                    ),
                  );
                }
              },
              child: const Text('Salva modifiche'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.state,
    required this.weekRef,
    required this.category,
    required this.items,
    required this.onEditExtra,
  });

  final AppState state;
  final DateTime weekRef;
  final IngredientCategory category;
  final List<_ShoppingItem> items;
  final Function(int index, Ingredient item) onEditExtra;

  Color _getCategoryColor() {
    switch (category) {
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _getCategoryColor(),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            ingredientCategoryLabel(category).toUpperCase(),
            style: const TextStyle(
                fontWeight: FontWeight.bold, letterSpacing: 1.1),
          ),
        ),
        ...items.map((it) {
          final checked =
              state.isShoppingChecked(anyDayInWeek: weekRef, itemKey: it.key);
          final qtySubtitle =
              it.displayQuantity.isEmpty ? null : it.displayQuantity;
          final priceSubtitle = it.estimatedPrice > 0
              ? '€ ${it.estimatedPrice.toStringAsFixed(2)}'
              : null;

          return CheckboxListTile(
            value: checked,
            onChanged: (v) => state.setShoppingChecked(
                anyDayInWeek: weekRef, itemKey: it.key, checked: v ?? false),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        it.name,
                        style: TextStyle(
                          decoration:
                              checked ? TextDecoration.lineThrough : null,
                          color: checked ? Colors.grey : null,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (qtySubtitle != null)
                        Text(
                          qtySubtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: checked ? Colors.grey : Colors.black54,
                          ),
                        ),
                    ],
                  ),
                ),
                if (priceSubtitle != null)
                  Text(
                    priceSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: checked ? Colors.grey : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (it.extraIndices.isNotEmpty)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, size: 20),
                    onSelected: (val) {
                      if (val == 'edit') {
                        // Per semplicità editiamo il primo extra se ce ne sono più di uno con lo stesso nome
                        final idx = it.extraIndices.first;
                        final extras = state.data.extraShoppingItems[
                                isoDate(weekStartMonday(weekRef))] ??
                            [];
                        onEditExtra(idx, extras[idx]);
                      } else if (val == 'delete') {
                        for (final idx in it.extraIndices.reversed) {
                          state.removeExtraShoppingItem(weekRef, idx);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'edit', child: Text('Modifica')),
                      const PopupMenuItem(
                          value: 'delete', child: Text('Elimina')),
                    ],
                  ),
              ],
            ),
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
      ],
    );
  }
}

class _ShoppingItem {
  _ShoppingItem({
    required this.key,
    required this.name,
    required this.category,
    required this.displayQuantity,
    required this.estimatedPrice,
    required this.isPriceReliable,
    this.extraIndices = const [],
  });

  final String key;
  final String name;
  final IngredientCategory category;
  final String displayQuantity;
  final double estimatedPrice;
  final bool isPriceReliable;
  final List<int> extraIndices;
}

List<_ShoppingItem> _buildShoppingItems({
  required AppState state,
  required List<DateTime> days,
}) {
  final agg = <String, _Agg>{};

  // 1. Dalla lista generata manualmente
  final startOfWeek = weekStartMonday(days.first);
  final weekKey = isoDate(startOfWeek);
  final generatedItems = state.data.generatedShoppingList[weekKey] ?? [];

  for (final ingredient in generatedItems) {
    _aggregate(agg, ingredient);
  }

  // 2. Dagli extra aggiunti manualmente per questa settimana
  final extras = state.data.extraShoppingItems[weekKey] ?? [];
  for (int i = 0; i < extras.length; i++) {
    _aggregate(agg, extras[i], extraIndex: i);
  }

  String fmtQty(double v) {
    if ((v - v.roundToDouble()).abs() < 0.00001) return v.toInt().toString();
    return v.toStringAsFixed(1).replaceAll('.0', '');
  }

  final out = <_ShoppingItem>[];
  for (final entry in agg.entries) {
    final a = entry.value;
    final unit = a.unit.isEmpty ? '' : a.unit;
    String q = '';
    if (a.hasQty) {
      q = '${fmtQty(a.totalQty)}${unit.isEmpty ? '' : ' $unit'}';
      if (a.missingQty) q = '$q (alcune senza quantità)';
    }

    // Prezzo disabilitato - uso solo prezzi Gemini
    out.add(_ShoppingItem(
      key: entry.key,
      name: a.name,
      category: a.category,
      displayQuantity: q,
      estimatedPrice: 0.0, // Disabilitato - uso solo prezzi Gemini
      isPriceReliable: false,
      extraIndices: a.extraIndices,
    ));
  }
  return out;
}

void _aggregate(Map<String, _Agg> agg, Ingredient ing, {int? extraIndex}) {
  final name = ing.name.trim();
  if (name.isEmpty) return;
  final norm = name.toLowerCase();
  final unit = (ing.unit ?? '').trim().toLowerCase();
  final key = '${ing.category.name}|$norm|$unit';
  final a = agg.putIfAbsent(
    key,
    () => _Agg(name: name, category: ing.category, unit: unit),
  );
  if (ing.quantity != null) {
    a.hasQty = true;
    a.totalQty += ing.quantity!;
  } else {
    a.missingQty = true;
  }
  if (extraIndex != null) {
    a.extraIndices.add(extraIndex);
  }
}

class _Agg {
  _Agg({required this.name, required this.category, required this.unit});
  final String name;
  final IngredientCategory category;
  final String unit;
  double totalQty = 0;
  bool hasQty = false;
  bool missingQty = false;
  final List<int> extraIndices = [];
}
