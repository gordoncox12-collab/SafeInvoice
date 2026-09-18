import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:spreadsheet_decoder/spreadsheet_decoder.dart';

import '../domain/money.dart';

class SheetPreview {
  const SheetPreview({
    required this.fileName,
    required this.sheetName,
    required this.headers,
    required this.rows,
  });

  final String fileName;
  final String sheetName;
  final List<String> headers;
  final List<List<String>> rows;
}

class ExcelService {
  SheetPreview preview(Uint8List bytes, String displayName, {int maxRows = 25}) {
    final all = readAll(bytes, displayName);
    return SheetPreview(
      fileName: displayName,
      sheetName: all.$1,
      headers: all.$2,
      rows: all.$3.take(maxRows).toList(),
    );
  }

  (String sheetName, List<String> headers, List<List<String>> rows) readAll(
    Uint8List bytes,
    String displayName,
  ) {
    final name = displayName.toLowerCase();
    if (name.endsWith('.csv') || _looksLikeCsv(bytes)) {
      final parsed = _readCsv(utf8.decode(bytes, allowMalformed: true));
      return ('CSV', parsed.$1, parsed.$2);
    }
    try {
      final decoder = SpreadsheetDecoder.decodeBytes(bytes, update: false);
      final table = decoder.tables.values.first;
      final raw = table.rows
          .map((r) => r.map((c) => _cellString(c)).toList())
          .where((r) => r.any((c) => c.trim().isNotEmpty))
          .toList();
      if (raw.isEmpty) return (table.name, <String>[], <List<String>>[]);
      final headers = raw.first;
      final width = headers.length;
      final rows = raw.skip(1).map((r) {
        final copy = List<String>.from(r);
        while (copy.length < width) {
          copy.add('');
        }
        return copy.take(width).toList();
      }).toList();
      return (table.name, headers, rows);
    } catch (_) {
      final parsed = _readCsv(utf8.decode(bytes, allowMalformed: true));
      return ('CSV', parsed.$1, parsed.$2);
    }
  }

  File writeWorkbook(
    File dest,
    Map<String, (List<String>, List<List<String>>)> sheets,
  ) {
    dest.parent.createSync(recursive: true);
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet();
    var first = true;
    sheets.forEach((name, content) {
      final sheetName = name.length > 31 ? name.substring(0, 31) : name;
      final sheet = excel[sheetName];
      for (var c = 0; c < content.$1.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).value =
            TextCellValue(content.$1[c]);
      }
      for (var r = 0; r < content.$2.length; r++) {
        for (var c = 0; c < content.$2[r].length; c++) {
          sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
              .value = TextCellValue(content.$2[r][c]);
        }
      }
      if (first && defaultSheet != null && defaultSheet != name) {
        excel.delete(defaultSheet);
        first = false;
      } else {
        first = false;
      }
    });
    dest.writeAsBytesSync(excel.encode() ?? <int>[]);
    return dest;
  }

  File writeCsv(File dest, List<String> headers, List<List<String>> rows) {
    dest.parent.createSync(recursive: true);
    final buf = StringBuffer();
    buf.writeln(headers.map(_csvEscape).join(','));
    for (final row in rows) {
      buf.writeln(row.map(_csvEscape).join(','));
    }
    dest.writeAsStringSync(buf.toString());
    return dest;
  }

  String cell(List<String> row, Map<String, int> mapping, String key) {
    final idx = mapping[key];
    if (idx == null || idx < 0 || idx >= row.length) return '';
    return row[idx].trim();
  }

  double parseAmount(String raw) {
    final cleaned = raw
        .replaceAll(RegExp(r'R', caseSensitive: false), '')
        .replaceAll(RegExp(r'ZAR', caseSensitive: false), '')
        .replaceAll(',', '')
        .replaceAll(RegExp(r'\s'), '')
        .trim();
    return Money.round(double.tryParse(cleaned) ?? 0);
  }

  bool _looksLikeCsv(Uint8List bytes) {
    final probe = utf8.decode(bytes.take(200).toList(), allowMalformed: true);
    return probe.contains(',') && !probe.contains('\u0000');
  }

  (List<String>, List<List<String>>) _readCsv(String text) {
    final lines = const LineSplitter().convert(text).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return (<String>[], <List<String>>[]);
    final headers = _splitCsv(lines.first);
    final rows = lines.skip(1).map((l) => _splitCsv(l, headers.length)).toList();
    return (headers, rows);
  }

  List<String> _splitCsv(String line, [int minSize = 0]) {
    final out = <String>[];
    final cur = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"' && inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        cur.write('"');
        i++;
      } else if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        out.add(cur.toString());
        cur.clear();
      } else {
        cur.write(c);
      }
    }
    out.add(cur.toString());
    while (out.length < minSize) {
      out.add('');
    }
    return out;
  }

  String _csvEscape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  String _cellString(Object? cell) {
    if (cell == null) return '';
    if (cell is DateTime) {
      return '${cell.year.toString().padLeft(4, '0')}-'
          '${cell.month.toString().padLeft(2, '0')}-'
          '${cell.day.toString().padLeft(2, '0')}';
    }
    if (cell is num) {
      if (cell % 1 == 0) return cell.toInt().toString();
      return cell.toString();
    }
    return cell.toString();
  }
}

Map<String, int> guessMapping(List<String> headers, List<(String, String)> fields) {
  final normalized = headers
      .map((h) => h.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
      .toList();
  const extraAliases = {
    'quantity': ['qty', 'qnty', 'amountqty'],
    'unitPrice': ['price', 'rate', 'unitcost'],
    'customerName': ['client', 'clientname', 'customer'],
    'vatNumber': ['vat', 'taxnumber', 'vatno'],
    'postalCode': ['postcode', 'zip', 'zipcode'],
    'contactName': ['contact', 'attn', 'attention'],
    'addressLine1': ['address', 'street'],
    'name': ['customername', 'client', 'company'],
  };
  return {
    for (final field in fields)
      field.$1: () {
        final aliases = [field.$1, field.$2, ...?extraAliases[field.$1]]
            .map((a) => a.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), ''))
            .toList();
        return normalized.indexWhere(
          (h) =>
              h.isNotEmpty &&
              aliases.any((a) => a.isNotEmpty && (h == a || h.contains(a) || a.contains(h))),
        );
      }(),
  };
}
