import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';

class TransactionForm extends StatefulWidget {
  final TransactionType type;
  final Map<String, List<String>> expenseCategories;
  final Map<String, List<String>> incomeCategories;
  final String Function(AccountType) getAccountName;
  final double Function(AccountType)? getAccountBalance; // <-- NUOVO: per ottenere il saldo attuale
  final Function(Transaction) onSubmit;
  final Transaction? existingTransaction;

  const TransactionForm({
    super.key,
    required this.type,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.getAccountName,
    this.getAccountBalance,
    required this.onSubmit,
    this.existingTransaction,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  // 1. RIMOSSO 'late' E IMPOSTATI VALORI DI DEFAULT SICURI
  Map<String, List<String>> _activeCategories = {};
  String _selectedCategory = '';
  String _selectedSubcategory = '';

  DateTime _selectedDate = DateTime.now();
  AccountType _selectedAccount = AccountType.bank1;
  AccountType _selectedTargetAccount = AccountType.etf;

  @override
  void initState() {
    super.initState();

    // 2. Inizializzazione categorie in base al tipo
    if (widget.type == TransactionType.income) {
      _activeCategories = widget.incomeCategories;
    } else if (widget.type == TransactionType.transfer) {
      _activeCategories = {'Giroconto': ['Trasferimento Interno']};
    } else if (widget.type == TransactionType.adjustment) {
      _activeCategories = {'Sistema': ['Rettifica Saldo']};
    } else {
      _activeCategories = widget.expenseCategories;
    }

    // Fallignment di sicurezza se la mappa è vuota
    if (_activeCategories.isEmpty) {
      _activeCategories = {
        'Altro': ['Varie']
      };
    }

    if (widget.existingTransaction != null) {
      final tx = widget.existingTransaction!;
      _amountController.text = tx.amount.toString();
      _noteController.text = tx.note;
      _selectedCategory = _activeCategories.containsKey(tx.category)
          ? tx.category
          : _activeCategories.keys.first;

      final subList = _activeCategories[_selectedCategory];
      _selectedSubcategory = (subList != null && subList.contains(tx.subcategory))
          ? tx.subcategory
          : (subList?.isNotEmpty == true ? subList!.first : 'Varie');

      _selectedDate = tx.date;
      _selectedAccount = tx.account;
      if (tx.targetAccount != null) {
        _selectedTargetAccount = tx.targetAccount!;
      }
    } else {
      _selectedCategory = _activeCategories.keys.first;
      _selectedSubcategory = _activeCategories[_selectedCategory]!.first;
    }

    _amountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submitData() {
    final enteredValue = double.tryParse(_amountController.text.replaceAll(',', '.'));

    if (enteredValue == null) {
      return;
    }

    double finalAmount = enteredValue;

    if (widget.type == TransactionType.adjustment) {
      final currentBalance = widget.getAccountBalance?.call(_selectedAccount) ?? 0.0;
      finalAmount = enteredValue - currentBalance;

      if (finalAmount == 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Il saldo inserito è già identico a quello attuale.')),
        );
        return;
      }
    } else {
      if (enteredValue <= 0) return;
    }

    if (widget.type == TransactionType.transfer && _selectedAccount == _selectedTargetAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona due conti diversi per il trasferimento')),
      );
      return;
    }

    final newTx = Transaction(
      id: widget.existingTransaction?.id ?? DateTime.now().toIso8601String(),
      amount: finalAmount,
      date: _selectedDate,
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      note: _noteController.text.isEmpty && widget.type == TransactionType.adjustment
          ? 'Rettifica a €${enteredValue.toStringAsFixed(2)}'
          : _noteController.text,
      type: widget.type,
      account: _selectedAccount,
      targetAccount: widget.type == TransactionType.transfer ? _selectedTargetAccount : null,
    );

    widget.onSubmit(newTx);
    Navigator.of(context).pop();
  }

  String _getTitleText() {
    if (widget.existingTransaction != null) return 'Modifica Movimento';
    switch (widget.type) {
      case TransactionType.expense:
        return 'Nuova Spesa';
      case TransactionType.income:
        return 'Nuova Entrata';
      case TransactionType.transfer:
        return 'Trasferimento tra Conti';
      case TransactionType.adjustment:
        return 'Rettifica Saldo / ETF';
    }
  }

  Color _getTitleColor() {
    switch (widget.type) {
      case TransactionType.expense:
        return Colors.red;
      case TransactionType.income:
        return Colors.green;
      case TransactionType.transfer:
        return Colors.blue.shade700;
      case TransactionType.adjustment:
        return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = widget.type == TransactionType.transfer;
    final isAdjustment = widget.type == TransactionType.adjustment;
    final mediaQuery = MediaQuery.of(context);

    final currentAccountBalance = isAdjustment && widget.getAccountBalance != null
        ? widget.getAccountBalance!(_selectedAccount)
        : 0.0;

    final targetBalanceInput = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? currentAccountBalance;
    final calculatedAdjustment = targetBalanceInput - currentAccountBalance;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: mediaQuery.viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _getTitleText(),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _getTitleColor(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<AccountType>(
              value: _selectedAccount,
              decoration: InputDecoration(
                labelText: isTransfer ? 'Da (Conto Origine)' : 'Seleziona Conto',
                border: const OutlineInputBorder(),
              ),
              items: AccountType.values.map((acc) {
                return DropdownMenuItem(
                  value: acc,
                  child: Text(widget.getAccountName(acc)),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedAccount = val);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: isAdjustment ? 'Nuovo Saldo Totale (€)' : 'Importo (€)',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.euro),
                helperText: isAdjustment ? 'Inserisci il saldo finale che vuoi ottenere' : null,
              ),
            ),
            if (isAdjustment) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Saldo Attuale: € ${currentAccountBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verrà registrato uno scostamento di: ${calculatedAdjustment >= 0 ? '+' : ''}${calculatedAdjustment.toStringAsFixed(2)} €',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: calculatedAdjustment >= 0 ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            if (isTransfer) ...[
              DropdownButtonFormField<AccountType>(
                value: _selectedTargetAccount,
                decoration: const InputDecoration(
                  labelText: 'A (Conto Destinazione)',
                  border: OutlineInputBorder(),
                ),
                items: AccountType.values.map((acc) {
                  return DropdownMenuItem(
                    value: acc,
                    child: Text(widget.getAccountName(acc)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTargetAccount = val);
                },
              ),
              const SizedBox(height: 12),
            ],
            if (widget.type == TransactionType.expense || widget.type == TransactionType.income) ...[
              DropdownButtonFormField<String>(
                value: _activeCategories.containsKey(_selectedCategory) ? _selectedCategory : null,
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                items: _activeCategories.keys.map((cat) {
                  return DropdownMenuItem(value: cat, child: Text(cat));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedCategory = val;
                      _selectedSubcategory = _activeCategories[val]!.first;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: (_activeCategories[_selectedCategory]?.contains(_selectedSubcategory) ?? false)
                    ? _selectedSubcategory
                    : null,
                decoration: const InputDecoration(labelText: 'Sottocategoria', border: OutlineInputBorder()),
                items: (_activeCategories[_selectedCategory] ?? []).map((sub) {
                  return DropdownMenuItem(value: sub, child: Text(sub));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedSubcategory = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: Text('Data: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}'),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Scegli Data'),
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                )
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Nota (opzionale)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _getTitleColor(),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _submitData,
              child: Text(widget.existingTransaction != null ? 'Aggiorna Movimento' : 'Salva Movimento'),
            )
          ],
        ),
      ),
    );
  }
}