import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/transaction.dart';

class CsvImporter {
static Future<List<Transaction>?> importTransactions(
BuildContext context,
) async {
try {
// ==========================================================
// SELEZIONE FILE
// ==========================================================

final result = await FilePicker.platform.pickFiles(
type: FileType.custom,
allowedExtensions: ['csv', 'txt'],
withData: true,
allowMultiple: false,
);

if (result == null || result.files.isEmpty) {
return null;
}

final pickedFile = result.files.single;

// ==========================================================
// LETTURA FILE
//
// Usiamo SEMPRE bytes.
// Questo funziona su:
// - Windows
// - Android
// - iOS
// - Web / GitHub Pages
//
// Non utilizziamo dart:io.
// ==========================================================

final bytes = pickedFile.bytes;

if (bytes == null || bytes.isEmpty) {
_showSnackBar(
context,
'Impossibile leggere il file selezionato.',
);
return null;
}

String csvString;

// ==========================================================
// UTF-8
// ==========================================================

try {
csvString = utf8.decode(
bytes,
allowMalformed: true,
);
} catch (e) {
_showSnackBar(
context,
'Il file non è in un formato supportato.',
);
return null;
}

// Rimuove BOM UTF-8
csvString = csvString.replaceFirst('\uFEFF', '');

// Rimuove eventuale BOM Unicode
csvString = csvString.trim();

if (csvString.isEmpty) {
_showSnackBar(
context,
'Il file CSV è vuoto.',
);
return null;
}

// ==========================================================
// RILEVAMENTO SEPARATORE
// ==========================================================

final lines = csvString.split(RegExp(r'\r?\n'));

String firstLine = '';

for (final line in lines) {
if (line.trim().isNotEmpty) {
firstLine = line;
break;
}
}

if (firstLine.isEmpty) {
_showSnackBar(
context,
'Il file CSV è vuoto.',
);
return null;
}

final semicolonCount =
';'.allMatches(firstLine).length;

final commaCount =
','.allMatches(firstLine).length;

final fieldDelimiter =
semicolonCount > commaCount ? ';' : ',';

if (kDebugMode) {
debugPrint(
'CSV delimiter: "$fieldDelimiter"',
);
}

// ==========================================================
// PARSER CSV
// ==========================================================

final rows = CsvToListConverter(
fieldDelimiter: fieldDelimiter,
shouldParseNumbers: false,
eol: '\n',
).convert(csvString);

if (rows.isEmpty) {
_showSnackBar(
context,
'Il file CSV non contiene dati.',
);
return null;
}

// ==========================================================
// HEADER
// ==========================================================

int startIndex = 0;

if (rows[0].isNotEmpty) {
final headerCheck = rows[0]
    .map((e) => e.toString().trim().toLowerCase())
    .join(' ');

if (headerCheck.contains('data') ||
headerCheck.contains('date') ||
headerCheck.contains('id') ||
headerCheck.contains('categoria') ||
headerCheck.contains('category') ||
headerCheck.contains('importo') ||
headerCheck.contains('amount')) {
startIndex = 1;
}
}

if (rows.length <= startIndex) {
_showSnackBar(
context,
'Il file CSV non contiene dati.',
);
return null;
}

// ==========================================================
// FORMATO DATE
// ==========================================================

final dateFormats = <DateFormat>[
DateFormat('dd/MM/yyyy'),
DateFormat('d/M/yyyy'),
DateFormat('yyyy-MM-dd'),
DateFormat('dd-MM-yyyy'),
DateFormat('d-M-yyyy'),
];

// ==========================================================
// IMPORTAZIONE
// ==========================================================

final List<Transaction> importedTransactions = [];

int errorCount = 0;

for (int i = startIndex; i < rows.length; i++) {
final row = rows[i];

// Salta righe completamente vuote
if (row.isEmpty ||
row.every(
(element) =>
element == null ||
element.toString().trim().isEmpty,
)) {
continue;
}

try {
// ======================================================
// VALORI DEFAULT
// ======================================================

String id = '';
DateTime date;

AccountType account = AccountType.bank1;

TransactionType type =
TransactionType.expense;

String category = 'Altro';
String subcategory = 'Varie';

double amount = 0.0;

String note = '';

AccountType? targetAccount;

// ======================================================
// FORMATO COMPLETO
//
// 0 id
// 1 data
// 2 account
// 3 type
// 4 category
// 5 subcategory
// 6 amount
// 7 note
// 8 targetAccount
// ======================================================

if (row.length >= 9) {
// ID
final rawId =
row[0].toString().trim();

id = rawId.isNotEmpty
? rawId
    : _generateId(i);

// DATA
date = _parseDate(
row[1].toString().trim(),
dateFormats,
);

// ACCOUNT
account = _parseAccount(
row[2].toString(),
);

// TYPE
type = _parseTransactionType(
row[3].toString(),
);

// CATEGORY
category =
row[4].toString().trim();

if (category.isEmpty) {
category = 'Altro';
}

// SUBCATEGORY
subcategory =
row[5].toString().trim();

if (subcategory.isEmpty) {
subcategory = 'Varie';
}

// AMOUNT
amount = _parseAmount(
row[6].toString(),
);

// NOTE
note =
row[7].toString().trim();

// TARGET ACCOUNT
final rawTarget =
row[8].toString().trim();

if (rawTarget.isNotEmpty) {
targetAccount =
_parseNullableAccount(
rawTarget,
);
}
}

// ======================================================
// FORMATO RIDOTTO
//
// 0 data
// 1 category
// 2 subcategory
// 3 amount
// 4 note
// ======================================================

else {
id = _generateId(i);

// DATA
date = _parseDate(
row[0].toString().trim(),
dateFormats,
);

// CATEGORY
if (row.length > 1) {
category =
row[1].toString().trim();

if (category.isEmpty) {
category = 'Altro';
}
}

// SUBCATEGORY
if (row.length > 2) {
subcategory =
row[2].toString().trim();

if (subcategory.isEmpty) {
subcategory = 'Varie';
}
}

// IMPORTO
if (row.length > 3) {
final rawAmount =
_parseSignedAmount(
row[3].toString(),
);

type = rawAmount < 0
? TransactionType.expense
    : TransactionType.income;

amount = rawAmount.abs();
} else {
throw const FormatException(
'Importo mancante',
);
}

// NOTE
if (row.length > 4) {
note =
row[4].toString().trim();
}
}

// ======================================================
// CONTROLLO IMPORTO
// ======================================================

if (!amount.isFinite) {
throw const FormatException(
'Importo non valido',
);
}

// ======================================================
// CREA TRANSAZIONE
// ======================================================

final tx = Transaction(
id: id,
amount: amount,
date: date,
category: category,
subcategory: subcategory,
note: note,
type: type,
account: account,
targetAccount: targetAccount,
);

importedTransactions.add(tx);
} catch (e, stackTrace) {
errorCount++;

if (kDebugMode) {
debugPrint(
'========================================',
);
debugPrint(
'Errore importazione riga $i',
);
debugPrint(
'Riga: $row',
);
debugPrint(
'Errore: $e',
);
debugPrint(
'$stackTrace',
);
debugPrint(
'========================================',
);
}
}
}

// ==========================================================
// NESSUNA TRANSAZIONE
// ==========================================================

if (importedTransactions.isEmpty) {
_showSnackBar(
context,
'Nessuna transazione valida trovata.',
);
return null;
}

// ==========================================================
// RISULTATO
// ==========================================================

String message =
'Importate con successo '
'${importedTransactions.length} transazioni';

if (errorCount > 0) {
message +=
' ($errorCount righe ignorate)';
}

message += '!';

_showSnackBar(
context,
message,
);

return importedTransactions;
} catch (e, stackTrace) {
if (kDebugMode) {
debugPrint(
'========================================',
);
debugPrint(
'ERRORE IMPORTAZIONE CSV',
);
debugPrint(
'Errore: $e',
);
debugPrint(
'$stackTrace',
);
debugPrint(
'========================================',
);
}

_showSnackBar(
context,
'Errore durante l\'importazione: $e',
);

return null;
}
}

// ============================================================
// DATE
// ============================================================

static DateTime _parseDate(
String value,
List<DateFormat> formats,
) {
final cleaned = value.trim();

if (cleaned.isEmpty) {
throw const FormatException(
'Data mancante',
);
}

for (final format in formats) {
try {
return format.parseStrict(cleaned);
} catch (_) {
// Prova formato successivo
}
}

// Prova anche ISO 8601
try {
return DateTime.parse(cleaned);
} catch (_) {
throw FormatException(
'Data non valida: $value',
);
}
}

// ============================================================
// ACCOUNT
// ============================================================

static AccountType _parseAccount(
String value,
) {
final normalized =
value.trim().toLowerCase();

if (normalized.isEmpty) {
return AccountType.bank1;
}

// Nome enum
for (final account in AccountType.values) {
if (account.name.toLowerCase() ==
normalized) {
return account;
}
}

// Nomi leggibili
switch (normalized) {
case 'banco bpm':
case 'bancobpm':
case 'bpm':
return AccountType.bank1;

case 'fineco':
return AccountType.bank2;

case 'contanti':
case 'cash':
return AccountType.cash;

case 'portafoglio etf':
case 'etf':
return AccountType.etf;
}

return AccountType.bank1;
}

static AccountType? _parseNullableAccount(
String value,
) {
final normalized =
value.trim().toLowerCase();

if (normalized.isEmpty) {
return null;
}

return _parseAccount(normalized);
}

// ============================================================
// TRANSACTION TYPE
// ============================================================

static TransactionType _parseTransactionType(
String value,
) {
final normalized =
value.trim().toLowerCase();

// Nome enum
for (final type in TransactionType.values) {
if (type.name.toLowerCase() ==
normalized) {
return type;
}
}

// Nomi leggibili
switch (normalized) {
case 'uscita':
case 'spesa':
case 'expense':
return TransactionType.expense;

case 'entrata':
case 'incasso':
case 'income':
return TransactionType.income;

case 'rettifica':
case 'adjustment':
return TransactionType.adjustment;

case 'trasferimento':
case 'transfer':
return TransactionType.transfer;
}

return TransactionType.expense;
}

// ============================================================
// IMPORTO
// ============================================================

static double _parseAmount(
String value,
) {
var v = value
    .trim()
    .replaceAll('€', '')
    .replaceAll('EUR', '')
    .replaceAll('eur', '')
    .replaceAll(' ', '')
    .trim();

if (v.isEmpty) {
throw const FormatException(
'Importo mancante',
);
}

// Gestione valori tra parentesi:
// (123,45) = -123,45
bool negative = false;

if (v.startsWith('(') &&
v.endsWith(')')) {
negative = true;
v = v.substring(1, v.length - 1);
}

// Gestione segno
if (v.startsWith('-')) {
negative = true;
v = v.substring(1);
}

if (v.startsWith('+')) {
v = v.substring(1);
}

// 1.234,56
if (v.contains('.') &&
v.contains(',')) {
v = v.replaceAll('.', '');
v = v.replaceAll(',', '.');
}

// 1234,56
else if (v.contains(',')) {
v = v.replaceAll(',', '.');
}

final amount = double.parse(v);

return negative ? -amount : amount;
}

// ============================================================
// IMPORTO CON SEGNO
// ============================================================

static double _parseSignedAmount(
String value,
) {
return _parseAmount(value);
}

// ============================================================
// ID
// ============================================================

static String _generateId(
int index,
) {
return '${DateTime.now().microsecondsSinceEpoch}_$index';
}

// ============================================================
// SNACKBAR
// ============================================================

static void _showSnackBar(
BuildContext context,
String message,
) {
if (!context.mounted) {
return;
}

ScaffoldMessenger.of(context)
..hideCurrentSnackBar()
..showSnackBar(
SnackBar(
content: Text(message),
),
);
}
}

