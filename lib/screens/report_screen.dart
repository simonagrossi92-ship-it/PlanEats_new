import 'package:flutter/material.dart';
import '../app_state.dart';
import '../models.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  DateTime? _archiveStartDate;
  DateTime? _archiveEndDate;

  @override
  void initState() {
    super.initState();
    _setArchiveDateDefaults();
    // Forza un aggiornamento iniziale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {});
    });
  }

  void _setArchiveDateDefaults() {
    final now = DateTime.now();
    _archiveStartDate = DateTime(now.year, now.month - 3, 1);
    _archiveEndDate = now;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final expenseRecords = widget.state.data.expenseRecords;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Report Spese'),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Riepilogo spese mensili
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF8BA888).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF8BA888),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Speso questo mese',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF8BA888),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '€${widget.state.getFoodExpensesForMonth(DateTime.now().year, DateTime.now().month).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.blue,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Numero spese',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${widget.state.getFoodExpenseCount(DateTime.now().year, DateTime.now().month)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Sezione Budget Mensile
                _buildBudgetSection(context),

                if (expenseRecords.isEmpty) ...[
                  const SizedBox(height: 32),
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nessuna spesa registrata',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Riepilogo totale
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8BA888),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Totale Spese',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '€ ${_calculateTotal(expenseRecords).toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${expenseRecords.length} spese registrate',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Lista spese raggruppate per mese (tutte le spese, non solo filtrate)
                  _buildExpensesByMonth(expenseRecords),
                  const SizedBox(height: 16),
                  // Sezione Analisi Archivio
                  _buildArchiveAnalysisSection(),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  double _calculateTotal(List<ExpenseRecord> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _deleteExpense(ExpenseRecord expense) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Spesa'),
        content: Text(
            'Vuoi eliminare la spesa di €${expense.amount.toStringAsFixed(2)} del ${expense.formattedDate}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.state.deleteExpense(expense);

              if (context.mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Spesa eliminata'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesByMonth(List<ExpenseRecord> expenses) {
    // Raggruppa le spese per mese
    final Map<String, List<ExpenseRecord>> groupedByMonth = {};

    for (final expense in expenses) {
      final monthKey =
          '${expense.dateTime.year}-${expense.dateTime.month.toString().padLeft(2, '0')}';
      if (!groupedByMonth.containsKey(monthKey)) {
        groupedByMonth[monthKey] = [];
      }
      groupedByMonth[monthKey]!.add(expense);
    }

    // Ordina le chiavi (mesi) dal più vecchio al più nuovo
    final sortedMonthKeys = groupedByMonth.keys.toList()..sort();

    final List<Widget> widgets = [];

    for (final monthKey in sortedMonthKeys) {
      final monthExpenses = groupedByMonth[monthKey]!;
      final parts = monthKey.split('-');
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);

      widgets.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del mese
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                '${_getMonthName(month)} $year',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8BA888),
                ),
              ),
            ),
            // Lista spese del mese
            ...monthExpenses.map((expense) => Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: ListTile(
                    title: Text(
                      expenseCategoryLabel(expense.category),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(expense.formattedDateTime),
                        if (expense.note != null && expense.note!.isNotEmpty)
                          Text(
                            expense.note!,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '€ ${expense.amount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF8BA888),
                          ),
                        ),
                        const SizedBox(width: 8),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.grey),
                            onPressed: () => _deleteExpense(expense),
                            hoverColor: Colors.red.withValues(alpha: 0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      );
    }

    return Column(children: widgets);
  }

  Widget _buildBudgetSection(BuildContext context) {
    final now = DateTime.now();
    final currentBudget = widget.state.getMonthlyBudget(now.year, now.month);
    final currentSpending =
        widget.state.getFoodExpensesForMonth(now.year, now.month);
    final status = widget.state.getBudgetStatus(now.year, now.month);
    final percentage =
        widget.state.getBudgetPercentageUsed(now.year, now.month);
    final remaining = widget.state.getBudgetRemaining(now.year, now.month);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: _getBudgetStatusColor(status),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Budget Mensile',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _getBudgetStatusColor(status),
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => _showQuickBudgetDialog(context),
                    icon: const Icon(Icons.edit),
                    tooltip: 'Modifica budget',
                  ),
                  if (currentBudget != null) ...[
                    IconButton(
                      onPressed: () =>
                          _showDeleteBudgetDialog(context, currentBudget),
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Elimina budget',
                      style: IconButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              if (currentBudget != null) ...[
                // Barra di progresso circolare
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: percentage,
                            backgroundColor: Colors.grey[300],
                            valueColor: AlwaysStoppedAnimation<Color>(
                                _getBudgetStatusColor(status)),
                            strokeWidth: 8,
                          ),
                          Text(
                            '${(percentage * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBudgetDetail(
                            'Speso',
                            '€${currentSpending.toStringAsFixed(2)}',
                            Colors.blue,
                          ),
                          const SizedBox(height: 8),
                          _buildBudgetDetail(
                            'Budget',
                            '€${currentBudget.amount.toStringAsFixed(2)}',
                            Colors.grey[700]!,
                          ),
                          const SizedBox(height: 8),
                          _buildBudgetDetail(
                            'Rimanente',
                            '€${remaining.toStringAsFixed(2)}',
                            remaining >= 0 ? Colors.green : Colors.red,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Nessun budget impostato
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nessun budget impostato',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Imposta un budget per monitorare le tue spese alimentari',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[500],
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _showQuickBudgetDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Imposta Budget'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF8BA888),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
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
      ),
    );
  }

  Widget _buildBudgetDetail(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getBudgetStatusColor(BudgetStatus status) {
    switch (status) {
      case BudgetStatus.verde:
        return Colors.green;
      case BudgetStatus.giallo:
        return Colors.orange;
      case BudgetStatus.rosso:
        return Colors.red;
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

  void _showDeleteBudgetDialog(BuildContext context, MonthlyBudget budget) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina Budget'),
        content: Text(
          'Sei sicuro di voler eliminare il budget di ${budget.monthLabel} ${budget.year}?\n\n'
          'Importo: €${budget.amount.toStringAsFixed(2)}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () async {
              await widget.state.deleteMonthlyBudget(budget.year, budget.month);

              if (context.mounted) {
                Navigator.pop(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Budget eliminato con successo'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _showQuickBudgetDialog(BuildContext context) {
    final now = DateTime.now();
    final amountController = TextEditingController();
    final currentBudget = widget.state.getMonthlyBudget(now.year, now.month);

    if (currentBudget != null) {
      amountController.text = currentBudget.amount.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(currentBudget != null
            ? 'Modifica Budget Mensile'
            : 'Imposta Budget Mensile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_getMonthName(now.month)} ${now.year}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountController,
              decoration: const InputDecoration(
                labelText: 'Importo Budget (€)',
                border: OutlineInputBorder(),
                prefixText: '€ ',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Inserisci un importo valido')),
                );
                return;
              }

              final budget = MonthlyBudget(
                year: now.year,
                month: now.month,
                amount: amount,
                yellowThreshold: 0.8,
                redThreshold: 0.95,
              );

              widget.state.setMonthlyBudget(budget);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Budget salvato con successo!'),
                  backgroundColor: Color(0xFF8BA888),
                ),
              );
            },
            child: const Text('Salva'),
          ),
        ],
      ),
    );
  }

  Widget _buildArchiveAnalysisSection() {
    final archivedItems = widget.state.getArchivedItemsByDateRange(
      _archiveStartDate ?? DateTime.now().subtract(const Duration(days: 90)),
      _archiveEndDate ?? DateTime.now(),
    );

    final categoryTotals =
        widget.state.getCategoryTotalsFromArchived(archivedItems);
    final totalAmount =
        categoryTotals.values.fold(0.0, (sum, value) => sum + value);

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Analisi Reparti Archivio',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8BA888),
                ),
              ),
              IconButton(
                onPressed: () => _showArchiveDateRangePicker(),
                icon: const Icon(Icons.date_range),
                tooltip: 'Seleziona periodo',
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date range display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  '${_formatDate(_archiveStartDate ?? DateTime.now().subtract(const Duration(days: 90)))} - ${_formatDate(_archiveEndDate ?? DateTime.now())}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (totalAmount > 0) ...[
            // Category percentages
            ...sortedCategories.map((entry) {
              final category = entry.key;
              final amount = entry.value;
              final percentage = (amount / totalAmount * 100);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          ingredientCategoryLabel(category),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF8BA888),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: percentage / 100,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF8BA888),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            const Text(
              'Nessun dato archiviato per questo periodo',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showArchiveDateRangePicker() async {
    final startDate = await showDatePicker(
      context: context,
      initialDate: _archiveStartDate ??
          DateTime.now().subtract(const Duration(days: 90)),
      firstDate: DateTime(2020),
      lastDate: _archiveEndDate ?? DateTime.now(),
    );

    if (startDate != null && context.mounted) {
      final ctx = context;
      final endDate = await showDatePicker(
        context: ctx,
        initialDate: _archiveEndDate ?? DateTime.now(),
        firstDate: startDate,
        lastDate: DateTime.now(),
      );

      if (endDate != null) {
        setState(() {
          _archiveStartDate = startDate;
          _archiveEndDate = endDate;
        });
      }
    }
  }
}
