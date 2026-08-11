enum TransactionType { expense, income, adjustment, transfer }

class Transaction {
  final String id;
  final double amount;
  final DateTime date;
  final String category;
  final String subcategory;
  final String note;
  final TransactionType type;
  final String account;
  final String? targetAccount;

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

  // Crea una copia della transazione modificando solo
  // i campi che vengono specificati.
  Transaction copyWith({
    String? id,
    double? amount,
    DateTime? date,
    String? category,
    String? subcategory,
    String? note,
    TransactionType? type,
    String? account,
    String? targetAccount,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      subcategory: subcategory ?? this.subcategory,
      note: note ?? this.note,
      type: type ?? this.type,
      account: account ?? this.account,
      targetAccount: targetAccount ?? this.targetAccount,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'amount': amount,
    'date': date.toIso8601String(),
    'category': category,
    'subcategory': subcategory,
    'note': note,
    'type': type.index,
    'account': account,
    'targetAccount': targetAccount,
  };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
    amount: (json['amount'] as num).toDouble(),
    date: DateTime.parse(json['date']),
    category: json['category'] ?? '',
    subcategory: json['subcategory'] ?? '',
    note: json['note'] ?? '',
    type: TransactionType.values[json['type'] ?? 0],
    account: json['account'] is String
        ? json['account']
        : 'Conto Principale',
    targetAccount: json['targetAccount'] is String
        ? json['targetAccount']
        : null,
  );
}