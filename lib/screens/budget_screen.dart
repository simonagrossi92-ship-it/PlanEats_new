import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../models.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key, required this.state});
  final AppState state;

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Budget Spesa Mensile',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8BA888),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Budget corrente in evidenza
          _CurrentBudgetCard(state: widget.state),
          const SizedBox(height: 16),
          // Statistiche aggiuntive
          _StatisticsCards(state: widget.state),
          const SizedBox(height: 16),
          // Lista di tutti i budget
          Expanded(
            child: _BudgetsList(state: widget.state),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBudgetDialog(context),
        backgroundColor: const Color(0xFF8BA888),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final now = DateTime.now();
    int selectedYear = now.year;
    int selectedMonth = now.month;
    final amountController = TextEditingController();
    final yellowThresholdController = TextEditingController(text: '0.8');
    final redThresholdController = TextEditingController(text: '0.95');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Nuovo Budget Mensile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selettore anno
                DropdownButtonFormField<int>(
                  initialValue: selectedYear,
                  decoration: const InputDecoration(
                    labelText: 'Anno',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(5, (index) => now.year + index)
                      .map((year) => DropdownMenuItem(
                            value: year,
                            child: Text(year.toString()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedYear = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Selettore mese
                DropdownButtonFormField<int>(
                  initialValue: selectedMonth,
                  decoration: const InputDecoration(
                    labelText: 'Mese',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(12, (index) => index + 1)
                      .map((month) => DropdownMenuItem(
                            value: month,
                            child: Text(_getMonthName(month)),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedMonth = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                // Importo budget
                TextFormField(
                  controller: amountController,
                  decoration: const InputDecoration(
                    labelText: 'Importo Budget (€)',
                    border: OutlineInputBorder(),
                    prefixText: '€ ',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 16),
                // Soglia gialla
                TextFormField(
                  controller: yellowThresholdController,
                  decoration: const InputDecoration(
                    labelText: 'Soglia Gialla (0.0 - 1.0)',
                    border: OutlineInputBorder(),
                    helperText:
                        'Percentuale per passare a giallo (es. 0.8 = 80%)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[0-1]?\.?\d+')),
                  ],
                ),
                const SizedBox(height: 16),
                // Soglia rossa
                TextFormField(
                  controller: redThresholdController,
                  decoration: const InputDecoration(
                    labelText: 'Soglia Rossa (0.0 - 1.0)',
                    border: OutlineInputBorder(),
                    helperText:
                        'Percentuale per passare a rosso (es. 0.95 = 95%)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^[0-1]?\.?\d+')),
                  ],
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
                final amount = double.tryParse(amountController.text);
                final yellowThreshold =
                    double.tryParse(yellowThresholdController.text) ?? 0.8;
                final redThreshold =
                    double.tryParse(redThresholdController.text) ?? 0.95;

                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Inserisci un importo valido')),
                  );
                  return;
                }

                if (yellowThreshold >= redThreshold) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'La soglia gialla deve essere inferiore a quella rossa')),
                  );
                  return;
                }

                final budget = MonthlyBudget(
                  year: selectedYear,
                  month: selectedMonth,
                  amount: amount,
                  yellowThreshold: yellowThreshold,
                  redThreshold: redThreshold,
                );

                widget.state.setMonthlyBudget(budget).then((_) {
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Budget salvato con successo!'),
                        backgroundColor: Color(0xFF8BA888),
                      ),
                    );
                  }
                }).catchError((error) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Errore durante il salvataggio: $error'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                });
              },
              child: const Text('Salva'),
            ),
          ],
        ),
      ),
    );
  }

  String _getMonthName(int month) {
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
}

class _CurrentBudgetCard extends StatelessWidget {
  const _CurrentBudgetCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final currentBudget = state.getMonthlyBudget(now.year, now.month);
    final currentSpending = state.getFoodExpensesForMonth(now.year, now.month);
    final status = state.getBudgetStatus(now.year, now.month);
    final percentage = state.getBudgetPercentageUsed(now.year, now.month);
    final remaining = state.getBudgetRemaining(now.year, now.month);

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: _getStatusColor(status).withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.account_balance_wallet_outlined,
                  color: _getStatusColor(status),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Budget ${_getMonthName(now.month)} ${now.year}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(status),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (currentBudget != null) ...[
              // Budget Ring - Grafico circolare
              Center(
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Cerchio di sfondo
                      SizedBox(
                        height: 150,
                        width: 150,
                        child: CircularProgressIndicator(
                          value: 1.0,
                          strokeWidth: 12,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.grey[300]!,
                          ),
                        ),
                      ),
                      // Cerchio di progresso
                      SizedBox(
                        height: 150,
                        width: 150,
                        child: CircularProgressIndicator(
                          value: percentage.clamp(0.0, 1.0),
                          strokeWidth: 12,
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _getStatusColor(status),
                          ),
                        ),
                      ),
                      // Testo centrale
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}%',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: _getStatusColor(status),
                                ),
                          ),
                          Text(
                            'utilizzato',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Card di stato dinamico
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getStatusColor(status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getStatusText(status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getStatusDescription(status, percentage),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Dettagli numerici
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Speso',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '€${currentSpending.toStringAsFixed(2)}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Budget',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '€${currentBudget.amount.toStringAsFixed(2)}',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Rimanente',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      Text(
                        '€${remaining.toStringAsFixed(2)}',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: remaining > 0 ? Colors.green : Colors.red,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              // Nessun budget impostato
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Nessun budget impostato per questo mese. Tocca + per aggiungerne uno.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.verde:
        return Colors.green;
      case BudgetStatus.giallo:
        return Colors.orange;
      case BudgetStatus.rosso:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.verde:
        return Icons.check_circle;
      case BudgetStatus.giallo:
        return Icons.warning;
      case BudgetStatus.rosso:
        return Icons.error;
    }
  }

  String _getStatusText(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.verde:
        return 'SOTTO CONTROLLO';
      case BudgetStatus.giallo:
        return 'ATTENZIONE';
      case BudgetStatus.rosso:
        return 'SUPERATO';
    }
  }

  String _getStatusDescription(BudgetStatus status, double percentage) {
    switch (status) {
      case BudgetStatus.verde:
        return 'Sei ampiamente dentro il budget';
      case BudgetStatus.giallo:
        return 'Ti stai avvicinando alla soglia limite';
      case BudgetStatus.rosso:
        return 'Hai superato il budget prefissato';
    }
  }

  String _getMonthName(int month) {
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
}

class _StatisticsCards extends StatelessWidget {
  const _StatisticsCards({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final averageReceipt = state.getAverageReceiptAmount(now.year, now.month);
    final expenseCount = state.getFoodExpenseCount(now.year, now.month);
    final mostPurchased = state.getMostPurchasedProducts(limit: 5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Scontrino Medio
          Expanded(
            child: _AverageReceiptCard(
              averageReceipt: averageReceipt,
              expenseCount: expenseCount,
            ),
          ),
          const SizedBox(width: 12),
          // Prodotti più acquistati
          Expanded(
            child: _MostPurchasedCard(mostPurchased: mostPurchased),
          ),
        ],
      ),
    );
  }
}

class _AverageReceiptCard extends StatelessWidget {
  const _AverageReceiptCard({
    required this.averageReceipt,
    required this.expenseCount,
  });

  final double averageReceipt;
  final int expenseCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF8BA888),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Scontrino Medio',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8BA888),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (expenseCount > 0) ...[
              Text(
                '€${averageReceipt.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'In media a scontrino',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Basato su $expenseCount spese',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
              ),
            ] else ...[
              Text(
                'Nessuna spesa',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'questo mese',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MostPurchasedCard extends StatelessWidget {
  const _MostPurchasedCard({required this.mostPurchased});

  final List<MapEntry<String, int>> mostPurchased;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shopping_basket,
                  color: Color(0xFF8BA888),
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Più Acquistati',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF8BA888),
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (mostPurchased.isNotEmpty) ...[
              ...mostPurchased.take(3).toList().asMap().entries.map((entry) {
                final index = entry.key;
                final product = entry.value;
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < 2 ? 8 : 0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _getRankColor(index),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '${index + 1}°',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _capitalizeFirst(product.key),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${product.value}x',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                );
              }),
            ] else ...[
              Text(
                'Nessun dato',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Archivia prodotti per vedere statistiche',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int index) {
    switch (index) {
      case 0:
        return Colors.amber;
      case 1:
        return Colors.grey;
      case 2:
        return Colors.brown;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _BudgetsList extends StatelessWidget {
  const _BudgetsList({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final budgets = state.getAllBudgets();

    if (budgets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun budget impostato',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tocca il pulsante + per creare il tuo primo budget',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[500],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: budgets.length,
      itemBuilder: (context, index) {
        final budget = budgets[index];
        final currentSpending =
            state.getFoodExpensesForMonth(budget.year, budget.month);
        final status = budget.getStatus(currentSpending);
        final percentage = budget.getPercentageUsed(currentSpending);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${budget.monthLabel} ${budget.year}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _showDeleteConfirmation(context, budget);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Elimina'),
                            ],
                          ),
                        ),
                      ],
                      child: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey[300],
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_getStatusColor(status)),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(3),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Speso: €${currentSpending.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Text(
                      'Budget: €${budget.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _getStatusColor(status), width: 1),
                      ),
                      child: Text(
                        _getStatusText(status),
                        style: TextStyle(
                          color: _getStatusColor(status),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.verde:
        return Colors.green;
      case BudgetStatus.giallo:
        return Colors.orange;
      case BudgetStatus.rosso:
        return Colors.red;
    }
  }

  String _getStatusText(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.verde:
        return 'OK';
      case BudgetStatus.giallo:
        return 'ATT';
      case BudgetStatus.rosso:
        return 'SUP';
    }
  }

  void _showDeleteConfirmation(BuildContext context, MonthlyBudget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Budget'),
        content: Text(
          'Sei sicuro di voler eliminare il budget di ${budget.monthLabel} ${budget.year}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              state.deleteMonthlyBudget(budget.year, budget.month);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}
