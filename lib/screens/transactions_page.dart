import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionsPage extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(String) onDeleteTransaction;
  final Function(TransactionType, Transaction) onEditTransaction;
  final VoidCallback onExportCsv;
  final String Function(String) getAccountName;

  const TransactionsPage({
    super.key,
    required this.transactions,
    required this.onDeleteTransaction,
    required this.onEditTransaction,
    required this.onExportCsv,
    required this.getAccountName,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Storico Movimenti',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Tocca per modificare, scorri a sinistra per eliminare',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.file_download, color: Colors.teal),
                tooltip: 'Esporta CSV',
                onPressed: onExportCsv,
              )
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: transactions.isEmpty
                ? const Center(child: Text('Nessun movimento registrato'))
                : ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (ctx, index) {
                final item = transactions.reversed.toList()[index];

                Color itemColor = Colors.green;
                IconData itemIcon = Icons.arrow_upward;
                String subtitleText = '${dateFormat.format(item.date)} - ${getAccountName(item.account)}';

                if (item.type == TransactionType.expense) {
                  itemColor = Colors.red;
                  itemIcon = Icons.arrow_downward;
                } else if (item.type == TransactionType.adjustment) {
                  itemColor = Colors.orange;
                  itemIcon = Icons.tune;
                } else if (item.type == TransactionType.transfer) {
                  itemColor = Colors.blue;
                  itemIcon = Icons.swap_horiz;
                  final targetName = item.targetAccount != null ? getAccountName(item.targetAccount!) : 'Destinazione';
                  subtitleText = '${dateFormat.format(item.date)} - Da ${getAccountName(item.account)} a $targetName';
                }

                if (item.note.isNotEmpty) {
                  subtitleText += '\n${item.note}';
                }

                return Dismissible(
                  key: Key(item.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) => onDeleteTransaction(item.id),
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      onTap: () => onEditTransaction(item.type, item),
                      leading: CircleAvatar(
                        backgroundColor: itemColor.withOpacity(0.15),
                        child: Icon(itemIcon, color: itemColor),
                      ),
                      title: Text(
                        '${item.category} ${item.subcategory.isNotEmpty ? "(${item.subcategory})" : ""}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(subtitleText),
                      trailing: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${item.type == TransactionType.expense ? "-" : (item.type == TransactionType.transfer ? "" : "+")}${currencyFormat.format(item.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: itemColor,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
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