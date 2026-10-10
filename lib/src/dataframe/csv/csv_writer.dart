import '../dataframe.dart';

/// CSV serialization for DataFrame.
class CsvWriter {
  /// Serializes DataFrame to a CSV formatted string.
  static String write(DataFrame df, {String separator = ','}) {
    final sb = StringBuffer();
    // Header
    sb.writeln(
      df.columnNames.map((name) => _escape(name, separator)).join(separator),
    );

    // Rows
    for (var rowIdx = 0; rowIdx < df.rowCount; rowIdx++) {
      final rowVals = [
        for (final col in df.columnNames)
          _formatVal(df.column(col)[rowIdx], separator),
      ];
      sb.writeln(rowVals.join(separator));
    }

    return sb.toString();
  }

  static String _formatVal(dynamic val, String separator) {
    if (val == null) return '';
    return _escape('$val', separator);
  }

  static String _escape(String field, String separator) {
    if (field.contains(separator) ||
        field.contains('"') ||
        field.contains('\n') ||
        field.contains('\r')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }
}
