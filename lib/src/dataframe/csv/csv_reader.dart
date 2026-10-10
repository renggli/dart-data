import 'package:petitparser/petitparser.dart';

import '../dataframe.dart';
import '../series.dart';
import 'parser.dart';

/// Fast CSV parser with automatic column type inference.
class CsvReader {
  /// Parses CSV string into a DataFrame.
  static DataFrame parse(
    String csv, {
    String separator = ',',
    bool header = true,
  }) => _parse(
    csv,
    parser: TabularDefinition.csv(delimiter: separator.toParser()).build(),
    header: header,
  );

  /// Parses TSV string into a DataFrame.
  static DataFrame parseTsv(String tsv, {bool header = true}) =>
      _parse(tsv, parser: TabularDefinition.tsv().build(), header: header);

  static DataFrame _parse(
    String text, {
    required Parser<List<List<String>>> parser,
    required bool header,
  }) {
    if (text.trim().isEmpty) return DataFrame([]);

    final result = parser.parse(text);
    if (result is! Success<List<List<String>>>) {
      throw FormatException(result.message, text, result.position);
    }
    final parsedRows = result.value;
    if (parsedRows.isEmpty) return DataFrame([]);

    List<String> colNames;
    List<List<String>> dataRows;

    if (header) {
      colNames = parsedRows.first;
      dataRows = parsedRows.sublist(1);
    } else {
      final colCount = parsedRows.first.length;
      colNames = List.generate(colCount, (i) => 'col_$i');
      dataRows = parsedRows;
    }

    final rowCount = dataRows.length;
    final columns = <Series<dynamic>>[];

    for (var colIdx = 0; colIdx < colNames.length; colIdx++) {
      final name = colNames[colIdx];
      var canBeInt = true;
      var canBeDouble = true;
      var canBeBool = true;
      final rawVals = <String?>[];

      for (var rowIdx = 0; rowIdx < rowCount; rowIdx++) {
        final row = dataRows[rowIdx];
        final val = colIdx < row.length ? row[colIdx] : '';
        final trimmed = val.trim();
        if (trimmed.isEmpty || trimmed == 'null' || trimmed == 'NA') {
          rawVals.add(null);
        } else {
          rawVals.add(val);
          if (canBeInt && int.tryParse(trimmed) == null) canBeInt = false;
          if (canBeDouble && double.tryParse(trimmed) == null) {
            canBeDouble = false;
          }
          final lower = trimmed.toLowerCase();
          if (canBeBool && lower != 'true' && lower != 'false') {
            canBeBool = false;
          }
        }
      }

      final nonNullCount = rawVals.where((v) => v != null).length;
      if (nonNullCount == 0) {
        columns.add(Series.fromList(name, rawVals));
      } else if (canBeInt) {
        final intVals = rawVals
            .map((value) => value != null ? int.parse(value.trim()) : null)
            .toList();
        columns.add(TypedSeries<int>.fromList(name, intVals));
      } else if (canBeDouble) {
        final doubleVals = rawVals
            .map((value) => value != null ? double.parse(value.trim()) : null)
            .toList();
        columns.add(TypedSeries<double>.fromList(name, doubleVals));
      } else if (canBeBool) {
        final boolVals = rawVals
            .map(
              (value) =>
                  value != null ? value.trim().toLowerCase() == 'true' : null,
            )
            .toList();
        columns.add(BoolSeries.fromList(name, boolVals));
      } else {
        columns.add(Series.fromList(name, rawVals));
      }
    }

    return DataFrame(columns);
  }
}
