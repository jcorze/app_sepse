import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class HomePage extends StatefulWidget {
  final double periodExpenses;
  final double periodIncome;
  final double totalNetWorth;
  final DateTimeRange selectedDateRange;
  final List<String> accounts;
  final VoidCallback onPickDateRange;
  final Function(String) getAccountBalance;
  final Function(TransactionType) onOpenTransactionModal;

  const HomePage({
    super.key,
    required this.periodExpenses,
    required this.periodIncome,
    required this.totalNetWorth,
    required this.selectedDateRange,
    required this.accounts,
    required this.onPickDateRange,
    required this.getAccountBalance,
    required this.onOpenTransactionModal,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isNetWorthVisible = false;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final dateFormat = DateFormat('dd/MM/yyyy');
    final double periodSavings = widget.periodIncome - widget.periodExpenses;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideScreen = constraints.maxWidth > 600;

        return SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: constraints.maxWidth * 0.04,
            vertical: 12.0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card Spese
              Card(
                color: Colors.red.shade50,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Spese del Periodo',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                          TextButton.icon(
                            icon: const Icon(Icons.date_range, size: 16),
                            label: Text(
                              '${dateFormat.format(widget.selectedDateRange.start)} - ${dateFormat.format(widget.selectedDateRange.end)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: widget.onPickDateRange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currencyFormat.format(widget.periodExpenses),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Card Risparmi
              Card(
                color: periodSavings >= 0 ? Colors.blue.shade50 : Colors.orange.shade50,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Risparmi del Periodo',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currencyFormat.format(periodSavings),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: periodSavings >= 0 ? Colors.blue.shade700 : Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Card Patrimonio Totale con conti dinamici
              Card(
                color: Colors.teal.shade50,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SizedBox(width: 40),
                          const Text(
                            'Patrimonio Totale',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                          ),
                          IconButton(
                            icon: Icon(
                              _isNetWorthVisible ? Icons.visibility : Icons.visibility_off,
                              size: 20,
                              color: Colors.teal.shade700,
                            ),
                            onPressed: () {
                              setState(() {
                                _isNetWorthVisible = !_isNetWorthVisible;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isNetWorthVisible
                              ? currencyFormat.format(widget.totalNetWorth)
                              : '€ ••••••••',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                      const Divider(height: 20),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: widget.accounts.map((accountName) {
                          return SizedBox(
                            width: (constraints.maxWidth * 0.85) / (constraints.maxWidth > 600 ? 3 : 2),
                            child: _buildBalanceColumn(
                              accountName,
                              widget.getAccountBalance(accountName),
                              Icons.account_balance_wallet,
                              currencyFormat,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Pulsanti Azione
              if (isWideScreen)
                Row(
                  children: [
                    Expanded(child: _buildActionButton('Spesa', Colors.red.shade400, Icons.remove_circle_outline, TransactionType.expense)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildActionButton('Entrata', Colors.green.shade600, Icons.add_circle_outline, TransactionType.income)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildActionButton('Trasferimento', Colors.blue.shade600, Icons.swap_horiz, TransactionType.transfer)),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildActionButton('Spesa', Colors.red.shade400, Icons.remove_circle_outline, TransactionType.expense),
                    const SizedBox(height: 10),
                    _buildActionButton('Entrata', Colors.green.shade600, Icons.add_circle_outline, TransactionType.income),
                    const SizedBox(height: 10),
                    _buildActionButton('Trasferimento', Colors.blue.shade600, Icons.swap_horiz, TransactionType.transfer),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(String label, Color color, IconData icon, TransactionType type) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      icon: Icon(icon, size: 22),
      label: Text(label),
      onPressed: () => widget.onOpenTransactionModal(type),
    );
  }

  Widget _buildBalanceColumn(String label, double value, IconData icon, NumberFormat formatter) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.teal.shade700),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            _isNetWorthVisible ? formatter.format(value) : '€ •••••',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}