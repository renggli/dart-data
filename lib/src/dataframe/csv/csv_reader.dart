import 'package:petitparser/petitparser.dart';

import '../../type/data_type.dart';
import '../dataframe.dart';
import 'csv_stream.dart';
import 'parser.dart';

/// Fast CSV parser with automatic column type inference.
class CsvReader {
  /// Parses CSV string into a [DataFrame].
  static DataFrame parse(
    String csv, {
    String separator = ',',
    bool header = true,
    Map<String, DataType<Object?>>? columnTypes,
  }) => _parse(
    csv,
    parser: TabularDefinition.csv(delimiter: separator.toParser()).build(),
    header: header,
    columnTypes: columnTypes,
  );

  /// Parses TSV string into a [DataFrame].
  static DataFrame parseTsv(
    String tsv, {
    bool header = true,
    Map<String, DataType<Object?>>? columnTypes,
  }) => _parse(
    tsv,
    parser: TabularDefinition.tsv().build(),
    header: header,
    columnTypes: columnTypes,
  );

  static DataFrame _parse(
    String text, {
    required Parser<List<List<String>>> parser,
    required bool header,
    Map<String, DataType<Object?>>? columnTypes,
  }) {
    if (text.trim().isEmpty) return DataFrame([]);

    final result = parser.parse(text);
    if (result is! Success<List<List<String>>>) {
      throw FormatException(result.message, text, result.position);
    }
    final parsedRows = result.value;
    if (parsedRows.isEmpty) return DataFrame([]);

    final List<String> colNames;
    final List<List<String>> dataRows;

    if (header) {
      colNames = parsedRows.first;
      dataRows = parsedRows.sublist(1);
    } else {
      final colCount = parsedRows.first.length;
      colNames = List.generate(colCount, (i) => 'col_$i');
      dataRows = parsedRows;
    }

    return CsvStream.buildDataFrame(
      colNames,
      dataRows,
      explicitTypes: columnTypes,
    );
  }
}
