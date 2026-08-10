import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:universal_html/html.dart' as html;

import '../models/transaction.dart';

class CsvExporter {
  static Future<void> exportTransactions(
      BuildContext context,
      List<Transaction> transactions,
      ) async {
    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun movimento presente da esportare.'),
        ),
      );
      return;
    }

    final dateFormat = DateFormat('dd/MM/yyyy');
    final csvBuffer = StringBuffer();

    // Header
    csvBuffer.write(
      'Id;Data;Conto;Tipo;Categoria;Sottocategoria;Importo;Nota;ContoDestinazione\r\n',
    );

    for (var tx in transactions) {
      final row = [
        tx.id,
        dateFormat.format(tx.date),
        tx.account, // Stringa diretta del conto
        tx.type.name,
        tx.category,
        tx.subcategory,
        tx.amount.toStringAsFixed(2).replaceAll('.', ','),
        tx.note,
        tx.targetAccount ?? '', // Stringa diretta del conto destinazione o vuota
      ];

      csvBuffer.write('${row.join(';')}\r\n');
    }

    final csvString = csvBuffer.toString();

    // UTF-8 BOM (come Excel)
    final csvBytes = Uint8List.fromList([
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(csvString),
    ]);

    try {
      if (kIsWeb) {
        final blob = html.Blob(
          [csvBytes],
          'text/csv;charset=utf-8',
        );

        final url = html.Url.createObjectUrlFromBlob(blob);

        html.AnchorElement(href: url)
          ..setAttribute('download', 'movimenti_patrimonio.csv')
          ..click();

        html.Url.revokeObjectUrl(url);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File CSV esportato con successo!'),
          ),
        );
      } else if (Platform.isAndroid || Platform.isIOS) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/movimenti_patrimonio.csv';

        final file = File(path);
        await file.writeAsBytes(csvBytes);

        await Share.shareXFiles(
          [XFile(path)],
          subject: 'Esportazione Movimenti',
          text: 'In allegato il file CSV esportato.',
        );
      } else {
        _showCsvTextDialog(context, csvString);
      }
    } catch (e) {
      _showCsvTextDialog(context, csvString);
    }
  }

  static void _showCsvTextDialog(
      BuildContext context,
      String csvContent,
      ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('CSV Esportato'),
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
              Clipboard.setData(
                ClipboardData(text: csvContent),
              );

              Navigator.of(ctx).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('CSV copiato negli appunti!'),
                ),
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
}