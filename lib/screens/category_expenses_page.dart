import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class CategoryExpensesPage extends StatelessWidget {
  final List<Transaction> transactions;
  final DateTimeRange selectedDateRange;
  final VoidCallback onPickDateRange;
  final bool Function(Transaction) isTxInSelectedRange;

  const CategoryExpensesPage({
    super.key,
    required this.transactions,
    required this.selectedDateRange,
    required this.onPickDateRange,
    required this.isTxInSelectedRange,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final periodExpensesList = transactions.where((tx) {
      return tx.type == TransactionType.expense && isTxInSelectedRange(tx);
    }).toList();

    final Map<String, Map<String, double>> categoryBreakdown = {};
    final Map<String, double> categoryTotals = {};

    double totalSpent = 0.0;
    for (var tx in periodExpensesList) {
      totalSpent += tx.amount;
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;

      if (!categoryBreakdown.containsKey(tx.category)) {
        categoryBreakdown[tx.category] = {};
      }
      final subMap = categoryBreakdown[tx.category]!;
      subMap[tx.subcategory] = (subMap[tx.subcategory] ?? 0) + tx.amount;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Analisi Spese',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.date_range, size: 14),
                label: Text(
                  '${dateFormat.format(selectedDateRange.start)} - ${dateFormat.format(selectedDateRange.end)}',
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: onPickDateRange,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Totale Uscite:', style: TextStyle(fontWeight: FontWeight.bold)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      currencyFormat.format(totalSpent),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: categoryTotals.isEmpty
                ? const Center(child: Text('Nessuna spesa nel periodo selezionato'))
                : ListView.builder(
              itemCount: categoryTotals.keys.length,
              itemBuilder: (ctx, index) {
                final category = categoryTotals.keys.elementAt(index);
                final catTotal = categoryTotals[category]!;
                final subMap = categoryBreakdown[category] ?? {};
                final percentage = totalSpent > 0 ? (catTotal / totalSpent) * 100 : 0.0;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: FittedBox(
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        currencyFormat.format(catTotal),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.red,
                        ),
                      ),
                    ),
                    children: subMap.entries.map((subEntry) {
                      return ListTile(
                        contentPadding: const EdgeInsets.only(left: 32, right: 16),
                        title: Text(subEntry.key.isEmpty ? 'Generale' : subEntry.key),
                        trailing: Text(currencyFormat.format(subEntry.value)),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}