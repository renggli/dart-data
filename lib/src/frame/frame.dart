library data.frame.frame;

import '../shared/storage.dart';
import '../type/type.dart';
import '../vector/vector.dart';
import 'index.dart';

class Frame<R, C> implements Storage {
  final Index<R> rowIndex;
  final Index<C> columnIndex;
  final List<Vector> columns;

  Frame(this.rowIndex, this.columnIndex, this.columns);

  @override
  Frame<R, C> copy() => Frame<R, C>(
      rowIndex, columnIndex, columns.map((column) => column.copy()));

  @override
  List<int> get shape => throw UnimplementedError();

  @override
  Set<Storage> get storage =>
      columns.expand((column) => column.storage).toSet();

  /// Returns a human readable representation of the frame.
  String format({
    String columnIndexSeparator = ' |',
    String horizontalSeparator = ' ',
    String verticalSeparator = '\n',
  }) {
    final buffer = StringBuffer();
    final columnKeyPrinter = columnIndex.dataType.printer;
    buffer.write(columnIndexSeparator);
    for (final columnKey in columnIndex.keys) {
      buffer.write(horizontalSeparator);
      buffer.write(columnKeyPrinter(columnKey));
    }
    buffer.write(verticalSeparator);
    final rowLabelPrinter = rowIndex.dataType.printer;
    final valuePrinter = DataType.object.printer;
    for (final rowKey in rowIndex.keys) {
      buffer.write(rowLabelPrinter(rowKey));
      buffer.write(columnIndexSeparator);
      for (final columnIndex in columnIndex.values) {
        final column = columns[columnIndex];
        buffer.write(horizontalSeparator);
        buffer.write(valuePrinter(column[rowIndex[rowKey]]));
      }
      buffer.write(verticalSeparator);
    }
    return buffer.toString();
  }

  /// Returns the string representation of this matrix.
  @override
  String toString() => '$runtimeType:\n'
      '${format()}';
}
