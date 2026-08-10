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

  // Seleziona in automatico il mese corrente
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

  // Metodo per gestire l'importazione da CSV
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

  double _getAccountBalance(AccountType account) {
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

  // Aggiunto per calcolare le entrate del periodo
  double get _periodIncome {
    return _transactions.where((item) {
      return item.type == TransactionType.income && _isTxInSelectedRange(item);
    }).fold(0.0, (sum, item) => sum + item.amount);
  }

  String _getAccountName(AccountType account) {
    return account.defaultName;
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
        getAccountName: _getAccountName,
        getAccountBalance: _getAccountBalance,
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
        periodIncome: _periodIncome, // <-- Passato correttamente qui
        totalNetWorth: _totalNetWorth,
        selectedDateRange: _selectedDateRange,
        onPickDateRange: _pickDateRange,
        getAccountBalance: _getAccountBalance,
        getAccountName: _getAccountName,
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
        title: const Text('Spese'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.settings),
            tooltip: 'Impostazioni',
            onSelected: (value) {
              if (value == 'adjustment') {
                _openTransactionModal(type: TransactionType.adjustment);
              } else if (value == 'export_csv') {
                CsvExporter.exportTransactions(context, _transactions);
              } else if (value == 'import_csv') {
                _importCsvData();
              }
            },
            itemBuilder: (BuildContext context) => [
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