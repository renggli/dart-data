import 'dataframe.dart';
import 'series.dart';

/// Fast CSV parser with automatic column type inference.
class CsvReader {
  new _();

  /// Parses CSV string into a DataFrame.
  static DataFrame parse(
    String csv, {
    String separator = ',',
    bool header = true,
  }) {
    final parsedRows = _parseCsv(csv, separator);
    if (parsedRows.isEmpty) return DataFrame([]);

    List<String> colNames;
    List<List<String>> dataRows;

    if (header) {
      colNames = parsedRows.first;
      dataRows = parsedRows.sublist(1);
    } else {
      colNames = List.generate(parsedRows.first.length, (i) => 'col_$i');
      dataRows = parsedRows;
    }

    final colCount = colNames.length;
    final rowCount = dataRows.length;

    // Collect values column-wise and infer types
    final columns = <Series<dynamic>>[];
    for (var c = 0; c < colCount; c++) {
      final name = colNames[c];
      final rawVals = <String?>[];
      var canBeInt = true;
      var canBeDouble = true;
      var canBeBool = true;

      for (var r = 0; r < rowCount; r++) {
        final row = dataRows[r];
        final val = c < row.length ? row[c] : '';
        if (val.isEmpty || val == 'null' || val == 'NA') {
          rawVals.add(null);
        } else {
          rawVals.add(val);
          if (canBeInt && int.tryParse(val) == null) canBeInt = false;
          if (canBeDouble && double.tryParse(val) == null) canBeDouble = false;
          final lower = val.toLowerCase();
          if (canBeBool && lower != 'true' && lower != 'false') {
            canBeBool = false;
          }
        }
      }

      final nonNulls = rawVals.where((v) => v != null).toList();
      if (nonNulls.isEmpty) {
        columns.add(Series.fromList(name, rawVals));
      } else if (canBeInt) {
        final intVals = rawVals
            .map((v) => v != null ? int.parse(v) : null)
            .toList();
        columns.add(TypedSeries<int>.fromList(name, intVals));
      } else if (canBeDouble) {
        final doubleVals = rawVals
            .map((v) => v != null ? double.parse(v) : null)
            .toList();
        columns.add(TypedSeries<double>.fromList(name, doubleVals));
      } else if (canBeBool) {
        final boolVals = rawVals
            .map((v) => v != null ? v.toLowerCase() == 'true' : null)
            .toList();
        columns.add(BoolSeries.fromList(name, boolVals));
      } else {
        columns.add(StringSeries.fromList(name, rawVals));
      }
    }

    return DataFrame(columns);
  }

  static List<List<String>> _parseCsv(String csv, String separator) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;
    var fieldStarted = false;

    var i = 0;
    while (i < csv.length) {
      final ch = csv[i];
      if (inQuotes) {
        if (ch == '"') {
          if (i + 1 < csv.length && csv[i + 1] == '"') {
            sb.write('"');
            i += 2;
            continue;
          } else {
            inQuotes = false;
            i++;
            continue;
          }
        } else {
          sb.write(ch);
          i++;
        }
      } else {
        if (ch == '"') {
          inQuotes = true;
          fieldStarted = true;
          i++;
        } else if (csv.startsWith(separator, i)) {
          currentRow.add(sb.toString().trim());
          sb.clear();
          fieldStarted = false;
          i += separator.length;
        } else if (ch == '\r' || ch == '\n') {
          if (ch == '\r' && i + 1 < csv.length && csv[i + 1] == '\n') {
            i++;
          }
          i++;
          currentRow.add(sb.toString().trim());
          sb.clear();
          if (currentRow.any((s) => s.isNotEmpty)) {
            rows.add(currentRow);
          }
          currentRow = <String>[];
          fieldStarted = false;
        } else {
          sb.write(ch);
          fieldStarted = true;
          i++;
        }
      }
    }
    if (sb.isNotEmpty || fieldStarted || currentRow.isNotEmpty) {
      currentRow.add(sb.toString().trim());
      if (currentRow.any((s) => s.isNotEmpty)) {
        rows.add(currentRow);
      }
    }
    return rows;
  }
}

/// CSV serialization for DataFrame.
class CsvWriter {
  new _();

  /// Writes DataFrame into CSV string format.
  static String write(DataFrame df, {String separator = ','}) {
    final sb = StringBuffer();
    // Header
    sb.writeln(df.columnNames.map(_escape).join(separator));

    // Rows
    for (var r = 0; r < df.rowCount; r++) {
      final rowVals = [
        for (final col in df.columnNames) _formatVal(df.column(col)[r]),
      ];
      sb.writeln(rowVals.join(separator));
    }

    return sb.toString();
  }

  static String _formatVal(dynamic val) {
    if (val == null) return '';
    return _escape('$val');
  }

  static String _escape(String field) {
    if (field.contains(',') ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      final escaped = field.replaceAll('"', '""');
      return '"$escaped"';
    }
    return field;
  }
}
