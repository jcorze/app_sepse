import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionForm extends StatefulWidget {
  final TransactionType type;
  final Map<String, List<String>> expenseCategories;
  final Map<String, List<String>> incomeCategories;
  final List<String> accounts; // Lista dei conti dinamica
  final Function(Transaction) onSubmit;
  final Transaction? existingTransaction;

  const TransactionForm({
    super.key,
    required this.type,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accounts,
    required this.onSubmit,
    this.existingTransaction,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _formKey = GlobalKey<FormState>();
  late double _amount;
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
    _amount = tx?.amount ?? 0.0;
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
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (widget.type == TransactionType.transfer && _selectedAccount == _selectedTargetAccount) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Il conto di origine e di destinazione non possono essere uguali.')),
        );
        return;
      }

      final newTx = Transaction(
        id: widget.existingTransaction?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        amount: _amount,
        date: _date,
        category: widget.type == TransactionType.transfer ? 'Trasferimento' : (widget.type == TransactionType.adjustment ? 'Rettifica' : _category),
        subcategory: widget.type == TransactionType.transfer || widget.type == TransactionType.adjustment ? '' : _subcategory,
        note: _note,
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
              // Importo
              TextFormField(
                initialValue: _amount == 0.0 ? '' : _amount.toString(),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Importo (€)', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || double.tryParse(value) == null || double.parse(value) <= 0) {
                    return 'Inserisci un importo valido';
                  }
                  return null;
                },
                onSaved: (value) => _amount = double.parse(value!),
              ),
              const SizedBox(height: 12),

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
                onSaved: (value) => _note = value ?? '',
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