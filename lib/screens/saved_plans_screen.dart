import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../utils/dates.dart';

class SavedPlansScreen extends StatelessWidget {
  const SavedPlansScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    // Recupera tutte le settimane con piani salvati
    final weekKeys = state.data.weekPlans.keys.toList();

    // Ordina per data (dalla più recente alla più vecchia)
    weekKeys.sort((a, b) => b.compareTo(a));

    if (weekKeys.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('I miei piani salvati'),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.calendar_month, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'Nessun piano salvato',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              SizedBox(height: 8),
              Text(
                'Crea il tuo primo menu settimanale!',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei piani salvati'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: weekKeys.length,
        itemBuilder: (context, index) {
          final weekKey = weekKeys[index];
          final weekDate = DateTime.parse(weekKey);
          final weekStart = weekDate;
          final weekEnd = weekDate.add(const Duration(days: 6));

          final meals = state.data.weekPlans[weekKey] ?? {};
          final totalMeals = meals.values
              .map((entry) => entry.items.length)
              .fold(0, (sum, count) => sum + count);

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFF8BA888),
                child: Text(
                  '${weekDate.day}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                _formatDateRange(weekStart, weekEnd),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              subtitle: Text('$totalMeals piatti pianificati'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => _WeekPlanDetailScreen(
                      state: state,
                      weekKey: weekKey,
                      weekStart: weekStart,
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatDateRange(DateTime start, DateTime end) {
    final months = [
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic'
    ];

    if (start.month == end.month) {
      return '${start.day} - ${end.day} ${months[start.month - 1]} ${start.year}';
    } else {
      return '${start.day} ${months[start.month - 1]} - ${end.day} ${months[end.month - 1]} ${start.year}';
    }
  }
}

class _WeekPlanDetailScreen extends StatelessWidget {
  const _WeekPlanDetailScreen({
    required this.state,
    required this.weekKey,
    required this.weekStart,
  });

  final AppState state;
  final String weekKey;
  final DateTime weekStart;

  @override
  Widget build(BuildContext context) {
    final meals = state.data.weekPlans[weekKey] ?? {};
    final days = weekDays(weekStart);

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatWeekTitle(weekStart)),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final dayMeals = <MealType, List<MealItem>>{};

          for (final mealType in MealType.values) {
            final entry = meals[mealType.name];
            if (entry != null && entry.items.isNotEmpty) {
              // Filtra gli item per questo giorno specifico
              final dayItems = entry.items.where((item) {
                // Qui dovremmo avere una logica per associare item a giorni specifici
                // Per ora mostriamo tutti gli item
                return true;
              }).toList();

              if (dayItems.isNotEmpty) {
                dayMeals[mealType] = dayItems;
              }
            }
          }

          if (dayMeals.isEmpty) {
            return const SizedBox.shrink();
          }

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    weekdayShortLabel(day),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF8BA888),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...dayMeals.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mealTypeLabel(entry.key),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...entry.value.map((item) {
                            final recipe = state.data.recipes
                                .where((r) => r.id == item.recipeId)
                                .firstOrNull;

                            return Padding(
                              padding: const EdgeInsets.only(left: 8, top: 2),
                              child: Text(
                                recipe?.title ??
                                    item.customTitle ??
                                    'Piatto personalizzato',
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatWeekTitle(DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    final months = [
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

    if (weekStart.month == weekEnd.month) {
      return '${weekStart.day} - ${weekEnd.day} ${months[weekStart.month - 1]} ${weekStart.year}';
    } else {
      return '${weekStart.day} ${months[weekStart.month - 1]} - ${weekEnd.day} ${months[weekEnd.month - 1]} ${weekStart.year}';
    }
  }
}
