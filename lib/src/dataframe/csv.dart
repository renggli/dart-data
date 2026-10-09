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
    final lines = csv
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return DataFrame([]);

    final parsedRows = <List<String>>[];
    for (final line in lines) {
      parsedRows.add(_parseLine(line, separator));
    }

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

  static List<String> _parseLine(String line, String separator) {
    final fields = <String>[];
    final sb = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++; // Skip escaped quote
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == separator && !inQuotes) {
        fields.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    fields.add(sb.toString().trim());
    return fields;
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
