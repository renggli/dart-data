library pandas.core.frame;

import 'index.dart';

class Frame<V> {
  Index<Row<V>> rowIndex_;

  Index<Column<V>> columnIndex_;

  Frame._(this.rowIndex_, this.columnIndex_);

  // Row Accessors
  // // // // // // // // // // // // // // // // // // // // // // // //

  /// Returns the number of rows in this frame.
  int get rowCount => rowIndex_.length;

  /// Returns an iterator over all rows in this frame.
  Iterable<Row<V>> get rows => null;

  /// Returns the row at the specified `key`.
  Row<V> getRow(Object key) => null;

  /// Returns the row at the specified `index`.
  Row<V> getRowIndex(int index) => null;

  // Column Accessors
  // // // // // // // // // // // // // // // // // // // // // // // //

  /// Returns the number of columns in this frame.
  int get columnCount => columnIndex_.length;

  /// Returns an iterator over all columns in this frame.
  Iterable<Column<V>> get columns => null;

  /// Returns the column with the specified `name`.
  Column<V> getColumn(String name) => null;

  /// Returns the column at the specified `index`.
  Column<V> getColumnIndex(int index) => null;

  // Transformations
  // // // // // // // // // // // // // // // // // // // // // // // //

  /// Returns a new frame with the columns satisfying the provided `predicate`.
  Frame<V> filterColumns(bool predicate(Column<V> column)) {
    return new Frame._(rowIndex_,
        new Map.fromIterable(
            columns.where(predicate),
            key: (Column<V> column) => column.name));
  }

  /// Returns a new frame with the rows satisfying the provided `predicate`.
  Frame<V> filterRows(bool predicate(Row<V> row)) {
    return new Frame._(
        new Map.fromIterable(
          rows.where(predicate),
        ),
        columnIndex_);
  }

  Frame<V> group(Object grouper(Row<V> row));
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
