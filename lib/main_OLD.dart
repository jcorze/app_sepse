import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const FinanceApp());
}

class FinanceApp extends StatelessWidget {
  const FinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Patrimonio & Spese',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// --- STRUTTURE DATI ---

enum TransactionType { expense, income, adjustment, transfer }
enum AccountType { bank1, bank2, cash, etf }

class Transaction {
  final String id;
  final double amount;
  final DateTime date;
  final String category;
  final String subcategory;
  final String note;
  final TransactionType type;
  final AccountType account;
  final AccountType? targetAccount;

  Transaction({
    required this.id,
    required this.amount,
    required this.date,
    required this.category,
    required this.subcategory,
    required this.note,
    required this.type,
    required this.account,
    this.targetAccount,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category,
    'subcategory': subcategory,
    'note': note,
    'type': type.index,
    'account': account.index,
    'targetAccount': targetAccount?.index,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'],
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date']),
    category: json['category'],
    subcategory: json['subcategory'],
    note: json['note'],
    type: TransactionType.values[json['type']],
    account: AccountType.values[json['account']],
    targetAccount: json['targetAccount'] != null
        ? AccountType.values[json['targetAccount']]
        : null,
  );
}

// --- CONTROLLORE DI NAVIGAZIONE ---

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final List<Transaction> _transactions = [];

  double _initialBank1 = 0.0;
  double _initialBank2 = 0.0;
  double _initialCash = 0.0;
  double _initialEtf = 0.0;

  final Map<String, List<String>> _expenseCategories = {
    'Cibo & Spesa': ['Supermercato', 'Ristoranti', 'Bar'],
    'Trasporti': ['Carburante', 'Mezzi Pubblici', 'Manutenzione Auto'],
    'Casa': ['Affitto', 'Bollette', 'Arredamento'],
    'Svago': ['Cinema', 'Hobby', 'Viaggi'],
    'Altro': ['Varie'],
  };

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
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _initialBank1 = prefs.getDouble('initial_bank1') ?? 0.0;
      _initialBank2 = prefs.getDouble('initial_bank2') ?? 0.0;
      _initialCash = prefs.getDouble('initial_cash') ?? 0.0;
      _initialEtf = prefs.getDouble('initial_etf') ?? 0.0;
    });

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

  Future<void> _saveInitialBalances(double b1, double b2, double cash, double etf) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('initial_bank1', b1);
    await prefs.setDouble('initial_bank2', b2);
    await prefs.setDouble('initial_cash', cash);
    await prefs.setDouble('initial_etf', etf);

    setState(() {
      _initialBank1 = b1;
      _initialBank2 = b2;
      _initialCash = cash;
      _initialEtf = etf;
    });
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

  double _getAccountBalance(AccountType account) {
    double initial = 0.0;
    if (account == AccountType.bank1) initial = _initialBank1;
    if (account == AccountType.bank2) initial = _initialBank2;
    if (account == AccountType.cash) initial = _initialCash;
    if (account == AccountType.etf) initial = _initialEtf;

    return initial +
        _transactions.fold(0.0, (sum, item) {
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
      _getAccountBalance(AccountType.bank1) +
          _getAccountBalance(AccountType.bank2) +
          _getAccountBalance(AccountType.cash) +
          _getAccountBalance(AccountType.etf);

  bool _isTxInSelectedRange(Transaction tx) {
    return tx.date.isAfter(_selectedDateRange.start.subtract(const Duration(days: 1))) &&
        tx.date.isBefore(_selectedDateRange.end.add(const Duration(days: 1)));
  }

  double get _periodExpenses {
    return _transactions.where((item) {
      return item.type == TransactionType.expense && _isTxInSelectedRange(item);
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  String _getAccountName(AccountType account) {
    switch (account) {
      case AccountType.bank1:
        return 'Conto 1';
      case AccountType.bank2:
        return 'Conto 2';
      case AccountType.cash:
        return 'Contanti';
      case AccountType.etf:
        return 'ETF / PAC';
    }
  }

  // --- FUNZIONE DI ESPORTAZIONE IN CSV ---
  Future<void> _exportToCsv() async {
    if (_transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nessun movimento presente da esportare.')),
      );
      return;
    }

    final dateFormat = DateFormat('dd/MM/yyyy');

    // Generazione della matrice di dati CSV
    List<List<dynamic>> csvData = [
      ['Data', 'Categoria', 'Sottocategoria', 'Importo', 'Nota'],
    ];

    for (var tx in _transactions) {
      double signedAmount = tx.amount;
      if (tx.type == TransactionType.expense) {
        signedAmount = -tx.amount;
      }

      csvData.add([
        dateFormat.format(tx.date),
        tx.category,
        tx.subcategory,
        signedAmount.toStringAsFixed(2),
        tx.note,
      ]);
    }

    String csvString = const ListToCsvConverter().convert(csvData);

    try {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/movimenti_patrimonio.csv';
        final file = File(path);
        await file.writeAsString(csvString);

        await Share.shareXFiles(
          [XFile(path)],
          text: 'Esportazione Movimenti Patrimonio',
        );
      } else {
        _showCsvTextDialog(csvString);
      }
    } catch (e) {
      _showCsvTextDialog(csvString);
    }
  }

  void _showCsvTextDialog(String csvContent) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CSV Generato'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(csvContent),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Copia'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: csvContent));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copiato negli appunti!')),
              );
            },
          ),
          ElevatedButton(
            child: const Text('Chiudi'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
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

  void _openInitialBalanceDialog() {
    final b1Controller = TextEditingController(text: _initialBank1.toString());
    final b2Controller = TextEditingController(text: _initialBank2.toString());
    final cashController = TextEditingController(text: _initialCash.toString());
    final etfController = TextEditingController(text: _initialEtf.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Saldi Iniziali di Partenza'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: b1Controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Saldo Iniziale Conto 1 (€)'),
              ),
              TextField(
                controller: b2Controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Saldo Iniziale Conto 2 (€)'),
              ),
              TextField(
                controller: cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Saldo Iniziale Contanti (€)'),
              ),
              TextField(
                controller: etfController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Valore Iniziale ETF / PAC (€)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Annulla'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            child: const Text('Salva'),
            onPressed: () {
              final b1 = double.tryParse(b1Controller.text.replaceAll(',', '.')) ?? 0.0;
              final b2 = double.tryParse(b2Controller.text.replaceAll(',', '.')) ?? 0.0;
              final cash = double.tryParse(cashController.text.replaceAll(',', '.')) ?? 0.0;
              final etf = double.tryParse(etfController.text.replaceAll(',', '.')) ?? 0.0;

              _saveInitialBalances(b1, b2, cash, etf);
              Navigator.of(ctx).pop();
            },
          )
        ],
      ),
    );
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
        onSubmit: _saveOrUpdateTransaction,
        existingTransaction: existingTransaction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomePage(),
      _buildTransactionsPage(),
      _buildCategoryExpensesPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Patrimonio'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Impostazioni',
            onSelected: (value) {
              if (value == 'balances') {
                _openInitialBalanceDialog();
              } else if (value == 'adjustment') {
                _openTransactionModal(type: TransactionType.adjustment);
              } else if (value == 'export_csv') {
                _exportToCsv();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem(
                value: 'balances',
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet, color: Colors.teal),
                    SizedBox(width: 8),
                    Text('Imposta Saldi Iniziali'),
                  ],
                ),
              ),
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

  // --- PAGINA 1: HOME PAGE ---
  Widget _buildHomePage() {
    final currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final dateFormat = DateFormat('dd/MM/yyyy');

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
                              '${dateFormat.format(_selectedDateRange.start)} - ${dateFormat.format(_selectedDateRange.end)}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onPressed: _pickDateRange,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currencyFormat.format(_periodExpenses),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Card(
                color: Colors.teal.shade50,
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text(
                        'Patrimonio Totale',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.teal),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          currencyFormat.format(_totalNetWorth),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.teal),
                        ),
                      ),
                      const Divider(height: 20),
                      Row(
                        children: [
                          Expanded(child: _buildBalanceColumn('Conto 1', _getAccountBalance(AccountType.bank1), Icons.account_balance, currencyFormat)),
                          Container(height: 30, width: 1, color: Colors.teal.shade200),
                          Expanded(child: _buildBalanceColumn('Conto 2', _getAccountBalance(AccountType.bank2), Icons.account_balance_wallet, currencyFormat)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _buildBalanceColumn('Contanti', _getAccountBalance(AccountType.cash), Icons.payments, currencyFormat)),
                          Container(height: 30, width: 1, color: Colors.teal.shade200),
                          Expanded(child: _buildBalanceColumn('ETF / PAC', _getAccountBalance(AccountType.etf), Icons.show_chart, currencyFormat)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

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
      onPressed: () => _openTransactionModal(type: type),
    );
  }

  // --- PAGINA 2: LISTA TRANSAZIONI ---
  Widget _buildTransactionsPage() {
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
                onPressed: _exportToCsv,
              )
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _transactions.isEmpty
                ? const Center(child: Text('Nessun movimento registrato'))
                : ListView.builder(
              itemCount: _transactions.length,
              itemBuilder: (ctx, index) {
                final item = _transactions.reversed.toList()[index];

                Color itemColor = Colors.green;
                IconData itemIcon = Icons.arrow_upward;
                String subtitleText = '${dateFormat.format(item.date)} - ${_getAccountName(item.account)}';

                if (item.type == TransactionType.expense) {
                  itemColor = Colors.red;
                  itemIcon = Icons.arrow_downward;
                } else if (item.type == TransactionType.adjustment) {
                  itemColor = Colors.orange;
                  itemIcon = Icons.tune;
                } else if (item.type == TransactionType.transfer) {
                  itemColor = Colors.blue;
                  itemIcon = Icons.swap_horiz;
                  final targetName = item.targetAccount != null ? _getAccountName(item.targetAccount!) : 'Destinazione';
                  subtitleText = '${dateFormat.format(item.date)} - Da ${_getAccountName(item.account)} a $targetName';
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
                  onDismissed: (direction) {
                    _deleteTransaction(item.id);
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ListTile(
                      onTap: () {
                        _openTransactionModal(
                          type: item.type,
                          existingTransaction: item,
                        );
                      },
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

  // --- PAGINA 3: DETTAGLIO SPESE ---
  Widget _buildCategoryExpensesPage() {
    final currencyFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');
    final dateFormat = DateFormat('dd/MM/yyyy');

    final periodExpensesList = _transactions.where((tx) {
      return tx.type == TransactionType.expense && _isTxInSelectedRange(tx);
    }).toList();

    final Map<String, Map<String, double>> categoryBreakdown = {};
    final Map<String, double> categoryTotals = {};

    for (var tx in periodExpensesList) {
      categoryTotals[tx.category] = (categoryTotals[tx.category] ?? 0) + tx.amount;

      if (!categoryBreakdown.containsKey(tx.category)) {
        categoryBreakdown[tx.category] = {};
      }
      final subMap = categoryBreakdown[tx.category]!;
      subMap[tx.subcategory] = (subMap[tx.subcategory] ?? 0) + tx.amount;
    }

    final totalSpent = _periodExpenses;

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
                  '${dateFormat.format(_selectedDateRange.start)} - ${dateFormat.format(_selectedDateRange.end)}',
                  style: const TextStyle(fontSize: 11),
                ),
                onPressed: _pickDateRange,
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
            formatter.format(value),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

// --- FORM MODALE ---

class TransactionForm extends StatefulWidget {
  final TransactionType type;
  final Map<String, List<String>> expenseCategories;
  final Map<String, List<String>> incomeCategories;
  final Function(Transaction) onSubmit;
  final Transaction? existingTransaction;

  const TransactionForm({
    super.key,
    required this.type,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.onSubmit,
    this.existingTransaction,
  });

  @override
  State<TransactionForm> createState() => _TransactionFormState();
}

class _TransactionFormState extends State<TransactionForm> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late Map<String, List<String>> _activeCategories;
  late String _selectedCategory;
  late String _selectedSubcategory;
  DateTime _selectedDate = DateTime.now();

  AccountType _selectedAccount = AccountType.bank1;
  AccountType _selectedTargetAccount = AccountType.etf;

  @override
  void initState() {
    super.initState();

    if (widget.type == TransactionType.income) {
      _activeCategories = widget.incomeCategories;
    } else if (widget.type == TransactionType.transfer) {
      _activeCategories = {'Giroconto': ['Trasferimento Interno']};
    } else if (widget.type == TransactionType.adjustment) {
      _activeCategories = {'Sistema': ['Rettifica Saldo']};
    } else {
      _activeCategories = widget.expenseCategories;
    }

    if (widget.existingTransaction != null) {
      final tx = widget.existingTransaction!;
      _amountController.text = tx.amount.toString();
      _noteController.text = tx.note;
      _selectedCategory = _activeCategories.containsKey(tx.category) ? tx.category : _activeCategories.keys.first;
      _selectedSubcategory = tx.subcategory;
      _selectedDate = tx.date;
      _selectedAccount = tx.account;
      if (tx.targetAccount != null) {
        _selectedTargetAccount = tx.targetAccount!;
      }
    } else {
      _selectedCategory = _activeCategories.keys.first;
      _selectedSubcategory = _activeCategories[_selectedCategory]!.first;
    }
  }

  void _submitData() {
    final enteredAmount = double.tryParse(_amountController.text.replaceAll(',', '.'));

    if (enteredAmount == null || enteredAmount <= 0) {
      return;
    }

    if (widget.type == TransactionType.transfer && _selectedAccount == _selectedTargetAccount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona due conti diversi per il trasferimento')),
      );
      return;
    }

    final newTx = Transaction(
      id: widget.existingTransaction?.id ?? DateTime.now().toIso8601String(),
      amount: enteredAmount,
      date: _selectedDate,
      category: _selectedCategory,
      subcategory: _selectedSubcategory,
      note: _noteController.text,
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
    final mediaQuery = MediaQuery.of(context);

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

            // IMPORTO
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Importo (€)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro),
              ),
            ),
            const SizedBox(height: 12),

            // SELEZIONE CONTO ORIGINE
            DropdownButtonFormField<AccountType>(
              value: _selectedAccount,
              decoration: InputDecoration(
                labelText: isTransfer ? 'Da (Conto Origine)' : 'Seleziona Conto',
                border: const OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: AccountType.bank1, child: Text('Conto 1')),
                DropdownMenuItem(value: AccountType.bank2, child: Text('Conto 2')),
                DropdownMenuItem(value: AccountType.cash, child: Text('Contanti')),
                DropdownMenuItem(value: AccountType.etf, child: Text('ETF / PAC')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedAccount = val);
              },
            ),
            const SizedBox(height: 12),

            // CONTO DESTINAZIONE (SOLO TRASFERIMENTO)
            if (isTransfer) ...[
              DropdownButtonFormField<AccountType>(
                value: _selectedTargetAccount,
                decoration: const InputDecoration(
                  labelText: 'A (Conto Destinazione)',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: AccountType.bank1, child: Text('Conto 1')),
                  DropdownMenuItem(value: AccountType.bank2, child: Text('Conto 2')),
                  DropdownMenuItem(value: AccountType.cash, child: Text('Contanti')),
                  DropdownMenuItem(value: AccountType.etf, child: Text('ETF / PAC')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedTargetAccount = val);
                },
              ),
              const SizedBox(height: 12),
            ],

            // CATEGORIE
            if (widget.type == TransactionType.expense || widget.type == TransactionType.income) ...[
              DropdownButtonFormField<String>(
                value: _selectedCategory,
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
                value: _selectedSubcategory,
                decoration: const InputDecoration(labelText: 'Sottocategoria', border: OutlineInputBorder()),
                items: (_activeCategories[_selectedCategory] ?? [_selectedSubcategory]).map((sub) {
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

            // DATA
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

            // NOTA
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Nota (opzionale)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // BOTTONE SALVA
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