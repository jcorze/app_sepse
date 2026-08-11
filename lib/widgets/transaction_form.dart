import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionForm extends StatefulWidget {
  final TransactionType type;
  final Map<String, List<String>> expenseCategories;
  final Map<String, List<String>> incomeCategories;
  final List<String> accounts; // Lista dei conti dinamica
  final double Function(String)? getAccountBalance; // <-- Aggiunto per ottenere il saldo del conto
  final Function(Transaction) onSubmit;
  final Transaction? existingTransaction;

  const TransactionForm({
    super.key,
    required this.type,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accounts,
    this.getAccountBalance,
    required this.onSubmit,
    this.existingTransaction,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController; // Convertito a controller per la reattività del saldo
  late DateTime _date;
  late String _category;
  late String _subcategory;
  late String _note;
  late String _selectedAccount;
  String? _selectedTargetAccount;

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTransaction;

    _amountController = TextEditingController(
      text: tx != null ? tx.amount.toString() : '',
    );
    _date = tx?.date ?? DateTime.now();

    // Gestione categorie
    if (widget.type == TransactionType.expense) {
      _category = tx?.category ?? widget.expenseCategories.keys.first;
      final subList = widget.expenseCategories[_category] ?? ['Generale'];
      _subcategory = tx?.subcategory ?? subList.first;
    } else if (widget.type == TransactionType.income) {
      _category = tx?.category ?? widget.incomeCategories.keys.first;
      final subList = widget.incomeCategories[_category] ?? ['Generale'];
      _subcategory = tx?.subcategory ?? subList.first;
    } else {
      _category = tx?.category ?? 'Rettifica';
      _subcategory = tx?.subcategory ?? '';
    }

    _note = tx?.note ?? '';

    // Gestione conti dinamici
    _selectedAccount = tx?.account ?? widget.accounts.first;
    _selectedTargetAccount = tx?.targetAccount ?? (widget.accounts.length > 1 ? widget.accounts[1] : widget.accounts.first);

    // Listener per aggiornare la UI in tempo reale durante la scrittura dell'importo/saldo
    _amountController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      final enteredValue = double.tryParse(_amountController.text.replaceAll(',', '.'));
      if (enteredValue == null) return;

      if (widget.type == TransactionType.transfer && _selectedAccount == _selectedTargetAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Il conto di origine e di destinazione non possono essere uguali.')),
        );
        return;
      }

      double finalAmount = enteredValue;

      // Gestione del calcolo per la rettifica del saldo
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

      final finalNote = _note.isEmpty && widget.type == TransactionType.adjustment
          ? 'Rettifica a €${enteredValue.toStringAsFixed(2)}'
          : _note;

      final newTx = Transaction(
        id: widget.existingTransaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        amount: finalAmount,
        date: _date,
        category: widget.type == TransactionType.transfer ? 'Trasferimento' : (widget.type == TransactionType.adjustment ? 'Rettifica' : _category),
        subcategory: widget.type == TransactionType.transfer || widget.type == TransactionType.adjustment ? '' : _subcategory,
        note: finalNote,
        type: widget.type,
        account: _selectedAccount,
        targetAccount: widget.type == TransactionType.transfer ? _selectedTargetAccount : null,
      );

      widget.onSubmit(newTx);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransfer = widget.type == TransactionType.transfer;
    final isAdjustment = widget.type == TransactionType.adjustment;

    // Calcoli per la preview della rettifica
    final currentAccountBalance = isAdjustment && widget.getAccountBalance != null
        ? widget.getAccountBalance!(_selectedAccount)
        : 0.0;

    final targetBalanceInput = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? currentAccountBalance;
    final calculatedAdjustment = targetBalanceInput - currentAccountBalance;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.existingTransaction == null ? 'Nuovo Movimento' : 'Modifica Movimento',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Importo / Nuovo Saldo
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: isAdjustment ? 'Nuovo Saldo Totale (€)' : 'Importo (€)',
                  border: const OutlineInputBorder(),
                  prefixIcon: isAdjustment ? const Icon(Icons.euro) : null,
                  helperText: isAdjustment ? 'Inserisci il saldo finale che vuoi ottenere' : null,
                ),
                validator: (value) {
                  if (value == null || double.tryParse(value.replaceAll(',', '.')) == null) {
                    return 'Inserisci un importo valido';
                  }
                  if (!isAdjustment && double.parse(value.replaceAll(',', '.')) <= 0) {
                    return 'L\'importo deve essere maggiore di zero';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Box Informativo per la Rettifica Saldo (come nel primo codice)
              if (isAdjustment) ...[
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
                const SizedBox(height: 12),
              ],

              // Categorie (se non trasferimento o rettifica)
              if (!isTransfer && !isAdjustment) ...[
                DropdownButtonFormField<String>(
                  value: _category,
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                  items: (widget.type == TransactionType.expense ? widget.expenseCategories : widget.incomeCategories)
                      .keys
                      .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _category = val!;
                      final subList = (widget.type == TransactionType.expense ? widget.expenseCategories : widget.incomeCategories)[_category] ?? [];
                      _subcategory = subList.isNotEmpty ? subList.first : '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _subcategory,
                  decoration: const InputDecoration(labelText: 'Sottocategoria', border: OutlineInputBorder()),
                  items: ((widget.type == TransactionType.expense ? widget.expenseCategories : widget.incomeCategories)[_category] ?? [])
                      .map((sub) => DropdownMenuItem(value: sub, child: Text(sub)))
                      .toList(),
                  onChanged: (val) => setState(() => _subcategory = val!),
                ),
                const SizedBox(height: 12),
              ],

              // Selezione Conto
              DropdownButtonFormField<String>(
                value: _selectedAccount,
                decoration: InputDecoration(
                  labelText: isTransfer ? 'Conto Origine' : 'Conto',
                  border: const OutlineInputBorder(),
                ),
                items: widget.accounts.map((acc) {
                  return DropdownMenuItem(value: acc, child: Text(acc));
                }).toList(),
                onChanged: (val) => setState(() => _selectedAccount = val!),
              ),
              const SizedBox(height: 12),

              // Conto di destinazione (solo per trasferimenti)
              if (isTransfer) ...[
                DropdownButtonFormField<String>(
                  value: _selectedTargetAccount,
                  decoration: const InputDecoration(labelText: 'Conto Destinazione', border: OutlineInputBorder()),
                  items: widget.accounts.map((acc) {
                    return DropdownMenuItem(value: acc, child: Text(acc));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTargetAccount = val!),
                ),
                const SizedBox(height: 12),
              ],

              // Nota
              TextFormField(
                initialValue: _note,
                decoration: const InputDecoration(labelText: 'Nota (opzionale)', border: OutlineInputBorder()),
                onChanged: (value) => _note = value,
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: _submitData,
                child: const Text('Salva', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}