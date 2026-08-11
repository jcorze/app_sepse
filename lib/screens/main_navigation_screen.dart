import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/transaction.dart';
import '../utils/csv_exporter.dart';
import '../utils/csv_importer.dart';
import '../widgets/transaction_form.dart';
import 'home_page.dart';
import 'transactions_page.dart';
import 'category_expenses_page.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Transaction> _transactions = [];

  // Lista dinamica dei conti (salvata su SharedPreferences)
  List<String> _accounts = ['Conto Principale', 'Conto Secondario', 'Contanti', 'ETF'];

  // Categorie delle spese
  final Map<String, List<String>> _expenseCategories = {
    'Macchina': ['Benzina', 'Meccanico', 'Parcheggio', 'Assicurazione', 'Pulizia'],
    'Casa': ['Affitto', 'Bollette'],
    'Spesa': ['Supermercato', 'Spaccio Unilever', 'Macchinette Lavoro', 'Fruttivendolo', 'Panettiere', 'Macellaio', 'Negozio'],
    'Ristoranti':['Colazione', 'Pranzo', 'Merenda', 'Aperitivo', 'Cena'],
    'Acquisti': ['Vestiti', 'Oggetti', 'Regali', 'Oggetti Casa', 'Abbonamenti'],
    'Viaggi': ['Trasporti', 'Alloggio', 'Mangiare', 'Acquisti', 'Svago', 'Totale'],
    'Trasporti': ['Metro', 'Treno', 'Nave'],
    'Salute': ['Medicinali', 'Visita', 'Certificato'],
    'Svago': ['Palestra', 'Attività', 'Post Cena', 'Oggetti per Svago']
  };

  // Categorie delle entrate
  final Map<String, List<String>> _incomeCategories = {
    'Entrate': ['Stipendio', 'Altro'],
  };

  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    _loadData();
  }

  // --- GESTIONE CONTI DINAMICI ---
  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final savedAccounts = prefs.getStringList('saved_accounts');
    if (savedAccounts != null && savedAccounts.isNotEmpty) {
      setState(() {
        _accounts = savedAccounts;
      });
    }
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('saved_accounts', _accounts);
  }

  void _addAccount(String name) {
    if (name.trim().isNotEmpty && !_accounts.contains(name.trim())) {
      setState(() {
        _accounts.add(name.trim());
      });
      _saveAccounts();
    }
  }

  void _deleteAccount(String name) {
    if (_accounts.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Devi mantenere almeno un conto attivo.')),
      );
      return;
    }
    setState(() {
      _accounts.remove(name);
    });
    _saveAccounts();
  }

  void _renameAccount(int index, String newName) {
    if (newName.trim().isNotEmpty) {
      setState(() {
        _accounts[index] = newName.trim();
      });
      _saveAccounts();
    }
  }

  String _getAccountName(String account) {
    return account;
  }

  void _renameAccountEverywhere(String oldName, String newName) {
    if (oldName == newName) return;

    for (int i = 0; i < _transactions.length; i++) {
      if (_transactions[i].account == oldName) {
        _transactions[i] = _transactions[i].copyWith(
          account: newName,
        );
      }

      if (_transactions[i].targetAccount == oldName) {
        _transactions[i] = _transactions[i].copyWith(
          targetAccount: newName,
        );
      }
    }
  }

  void _openManageAccountsDialog() {
    final TextEditingController newAccountController = TextEditingController();

    // Copia temporanea dei conti
    List<String> tempAccounts = List.from(_accounts);

    List<TextEditingController> controllers = tempAccounts
        .map((account) => TextEditingController(text: account))
        .toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text(
            'Gestione Conti',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              children: [
                Expanded(
                  child: ReorderableListView.builder(
                    buildDefaultDragHandles: false,
                    itemCount: tempAccounts.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;

                      setDialogState(() {
                        final account = tempAccounts.removeAt(oldIndex);
                        tempAccounts.insert(newIndex, account);

                        final controller = controllers.removeAt(oldIndex);
                        controllers.insert(newIndex, controller);
                      });
                    },
                    itemBuilder: (context, index) {
                      return Card(
                        key: ValueKey(tempAccounts[index]),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: ReorderableDragStartListener(
                            index: index,
                            child: const Icon(Icons.drag_handle),
                          ),
                          title: TextField(
                            controller: controllers[index],
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.red,
                            ),
                            onPressed: () {
                              if (tempAccounts.length <= 1) return;

                              setDialogState(() {
                                controllers[index].dispose();
                                controllers.removeAt(index);
                                tempAccounts.removeAt(index);
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(height: 20),

                TextField(
                  controller: newAccountController,
                  decoration: const InputDecoration(
                    labelText: 'Nuovo Conto',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.add),
                  ),
                ),

                const SizedBox(height: 10),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Aggiungi Conto'),
                  onPressed: () {
                    final newName = newAccountController.text.trim();

                    if (newName.isEmpty) return;

                    if (tempAccounts.contains(newName)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Esiste già un conto con questo nome'),
                        ),
                      );
                      return;
                    }

                    setDialogState(() {
                      tempAccounts.add(newName);
                      controllers.add(
                        TextEditingController(text: newName),
                      );
                      newAccountController.clear();
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                for (final controller in controllers) {
                  controller.dispose();
                }
                Navigator.pop(context);
              },
              child: const Text('Annulla'),
            ),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.save),
              label: const Text('Salva'),
              onPressed: () async {
                final updatedAccounts = controllers
                    .map((c) => c.text.trim())
                    .where((name) => name.isNotEmpty)
                    .toList();

                final uniqueAccounts = updatedAccounts.toSet().toList();

                if (uniqueAccounts.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deve esistere almeno un conto'),
                    ),
                  );
                  return;
                }

                setState(() {
                  final oldAccounts = List<String>.from(_accounts);

                  for (int i = 0; i < oldAccounts.length; i++) {
                    if (i < uniqueAccounts.length &&
                        oldAccounts[i] != uniqueAccounts[i]) {
                      _renameAccountEverywhere(
                        oldAccounts[i],
                        uniqueAccounts[i],
                      );
                    }
                  }

                  _accounts = uniqueAccounts;
                });

                await _saveAccounts();
                await _saveTransactions();

                for (final controller in controllers) {
                  controller.dispose();
                }

                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- GESTIONE DATI TRANSAZIONI ---
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final String? txData = prefs.getString('saved_transactions');
    if (txData != null) {
      final List<dynamic> decodedList = jsonDecode(txData);
      setState(() {
        _transactions.clear();
        _transactions.addAll(
          decodedList.map((item) => Transaction.fromJson(item)).toList(),
        );
      });
    }
  }

  Future<void> _saveTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      _transactions.map((tx) => tx.toJson()).toList(),
    );
    await prefs.setString('saved_transactions', encodedData);
  }

  void _saveOrUpdateTransaction(Transaction tx) {
    setState(() {
      final index = _transactions.indexWhere((item) => item.id == tx.id);
      if (index >= 0) {
        _transactions[index] = tx;
      } else {
        _transactions.add(tx);
      }
    });
    _saveTransactions();
  }

  void _deleteTransaction(String id) {
    setState(() {
      _transactions.removeWhere((tx) => tx.id == id);
    });
    _saveTransactions();
  }

  Future<void> _importCsvData() async {
    final importedTransactions = await CsvImporter.importTransactions(context);
    if (importedTransactions != null && importedTransactions.isNotEmpty) {
      setState(() {
        for (var newTx in importedTransactions) {
          final index = _transactions.indexWhere((item) => item.id == newTx.id);
          if (index >= 0) {
            _transactions[index] = newTx;
          } else {
            _transactions.add(newTx);
          }
        }
      });
      _saveTransactions();
    }
  }

  // --- CALCOLI FINANZIARI ---
  double _getAccountBalance(String account) {
    return _transactions.fold(0.0, (sum, item) {
      if (item.type == TransactionType.transfer) {
        if (item.account == account) return sum - item.amount;
        if (item.targetAccount == account) return sum + item.amount;
        return sum;
      }

      if (item.account == account) {
        if (item.type == TransactionType.income || item.type == TransactionType.adjustment) {
          return sum + item.amount;
        } else if (item.type == TransactionType.expense) {
          return sum - item.amount;
        }
      }
      return sum;
    });
  }

  double get _totalNetWorth =>
      _accounts.fold(0.0, (sum, account) => sum + _getAccountBalance(account));

  bool _isTxInSelectedRange(Transaction tx) {
    return tx.date.isAfter(_selectedDateRange.start.subtract(const Duration(days: 1))) &&
        tx.date.isBefore(_selectedDateRange.end.add(const Duration(days: 1)));
  }

  double get _periodExpenses {
    return _transactions.where((item) {
      return item.type == TransactionType.expense && _isTxInSelectedRange(item);
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  double get _periodIncome {
    return _transactions.where((item) {
      return item.type == TransactionType.income && _isTxInSelectedRange(item);
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  void _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: _selectedDateRange,
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  void _openTransactionModal({
    required TransactionType type,
    Transaction? existingTransaction,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => TransactionForm(
        type: type,
        expenseCategories: _expenseCategories,
        incomeCategories: _incomeCategories,
        accounts: _accounts,
        getAccountBalance: _getAccountBalance, // <-- Lascia solo questo
        onSubmit: _saveOrUpdateTransaction,
        existingTransaction: existingTransaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      HomePage(
        periodExpenses: _periodExpenses,
        periodIncome: _periodIncome,
        totalNetWorth: _totalNetWorth,
        selectedDateRange: _selectedDateRange,
        accounts: _accounts,
        onPickDateRange: _pickDateRange,
        getAccountBalance: _getAccountBalance,
        onOpenTransactionModal: (type) => _openTransactionModal(type: type),
      ),
      TransactionsPage(
        transactions: _transactions,
        onDeleteTransaction: _deleteTransaction,
        onEditTransaction: (type, tx) => _openTransactionModal(type: type, existingTransaction: tx),
        onExportCsv: () => CsvExporter.exportTransactions(context, _transactions),
        getAccountName: _getAccountName,
      ),
      CategoryExpensesPage(
        transactions: _transactions,
        selectedDateRange: _selectedDateRange,
        onPickDateRange: _pickDateRange,
        isTxInSelectedRange: _isTxInSelectedRange,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spese v2'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Impostazioni',
            onSelected: (value) {
              if (value == 'manage_accounts') {
                _openManageAccountsDialog();
              } else if (value == 'adjustment') {
                _openTransactionModal(type: TransactionType.adjustment);
              } else if (value == 'export_csv') {
                CsvExporter.exportTransactions(context, _transactions);
              } else if (value == 'import_csv') {
                _importCsvData();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'manage_accounts',
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Gestisci Conti'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'adjustment',
                child: Row(
                  children: [
                    Icon(Icons.tune, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Rettifica Saldo / ETF'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export_csv',
                child: Row(
                  children: [
                    Icon(Icons.ios_share, color: Colors.green),
                    SizedBox(width: 8),
                    Text('Esporta in CSV'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'import_csv',
                child: Row(
                  children: [
                    Icon(Icons.file_upload, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Importa da CSV'),
                  ],
                ),
              ),
            ],
          )
        ],
      ),
      body: SafeArea(child: pages[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'Movimenti'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Analisi Spese'),
        ],
      ),
    );
  }
}