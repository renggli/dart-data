import '../dataframe.dart';

/// CSV serialization for [DataFrame].
class CsvWriter {
  /// Serializes [DataFrame] to a CSV formatted string.
  static String write(DataFrame df, {String separator = ','}) {
    final sb = StringBuffer();
    final columns = df.columns;
    final numCols = columns.length;

    // Header
    for (var i = 0; i < numCols; i++) {
      if (i > 0) sb.write(separator);
      sb.write(_escape(columns[i].name, separator));
    }
    sb.writeln();

    // Rows
    for (var rowIdx = 0; rowIdx < df.rowCount; rowIdx++) {
      for (var colIdx = 0; colIdx < numCols; colIdx++) {
        if (colIdx > 0) sb.write(separator);
        final val = columns[colIdx][rowIdx];
        if (val != null) {
          sb.write(_escape('$val', separator));
        }
      }
      sb.writeln();
    }

    return sb.toString();
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
