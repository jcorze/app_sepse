enum TransactionType { expense, income, adjustment, transfer }

enum AccountType { bank1, bank2, cash, etf }

extension AccountTypeExtension on AccountType {
  /// Nome di default se l'utente non ha impostato un nome personalizzato
  String get defaultName {
    switch (this) {
      case AccountType.bank1:
        return 'Banco BPM';
      case AccountType.bank2:
        return 'Fineco';
      case AccountType.cash:
        return 'Contanti';
      case AccountType.etf:
        return 'Portafoglio ETF';
    }
  }
}

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