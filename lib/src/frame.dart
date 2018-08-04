library pandas.core.frame;

class Frame<V> {
  final List<Row<V>> _rowIndex;

  final List<Column<V>> _columnIndex;

  Frame._(this._rowIndex, this._columnIndex);

  // Row Accessors
  // // // // // // // // // // // // // // // // // // // // // // // //

  /// Returns the number of rows in this frame.
  int get rowCount => _rowIndex.length;

  /// Returns an iterator over all rows in this frame.
  Iterable<Row<V>> get rows => null;

  /// Returns the row at the specified `key`.
  Row<V> getRow(Object key) => null;

  /// Returns the row at the specified `index`.
  Row<V> getRowIndex(int index) => null;

  // Column Accessors
  // // // // // // // // // // // // // // // // // // // // // // // //

  /// Returns the number of columns in this frame.
  int get columnCount => _columnIndex.length;

  /// Returns an iterator over all columns in this frame.
  Iterable<Column<V>> get columns => null;

  /// Returns the column with the specified `name`.
  Column<V> getColumn(String name) => null;

  /// Returns the column at the specified `index`.
  Column<V> getColumnIndex(int index) => null;

  // Transformations
  // // // // // // // // // // // // // // // // // // // // // // // //

  /// Returns a new frame with the columns satisfying the provided `predicate`.
  Frame<V> filterColumns(bool predicate(Column<V> column)) => Frame._(
        _rowIndex,
        List.from(_columnIndex.where(predicate)),
      );

  /// Returns a new frame with the rows satisfying the provided `predicate`.
  Frame<V> filterRows(bool predicate(Row<V> row)) => Frame._(
        List.from(_rowIndex.where(predicate)),
        _columnIndex,
      );

  Frame<V> group(Object grouper(Row<V> row)) => null;
}

/// Abstract view onto a row of elements.
abstract class Row<V> {
  Iterable<Column<V>> get columns;

  Iterable<V> get values;

  int get length;
}

/// Abstract view onto a column of elements
abstract class Column<V> {
  String name;

  Iterable<Row<V>> get rows;

  Iterable<V> get values;

  int get length;
}
