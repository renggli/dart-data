import 'dart:collection';

import '../../type.dart';
import '../../vector.dart';
import 'column.dart';
import 'frame.dart';
import 'row.dart';

class Columns extends IterableBase<Column> {
  Columns(this._frame);

  final Frame _frame;
  final List<Column> _columns = [];

  @override
  Iterator<Column> get iterator => _columns.iterator;

  Column operator [](String name) =>
      _columns.firstWhere((column) => column.name == name);

  /// Adds a [list] to the columns of the data frame. Throws an [ArgumentError],
  /// if the number of elements does not match.
  Column<T> addList<T>(
    List<T> list, {
    String name = '',
    DataType<T>? dataType,
  }) =>
      addVector(
        Vector.fromList(
          dataType ?? DataType.fromType<T>(),
          list,
        ),
        name: name,
      );

  /// Adds a [vector] to the columns of the data frame. Throws an
  /// [ArgumentError], if the number of elements does not match.
  Column<T> addVector<T>(Vector<T> vector, {String name = ''}) {
    if (_columns.isNotEmpty && _frame.rows.length != vector.length) {
      throw ArgumentError('Expected a column of length '
          '${_frame.rows.length}, but got one with ${vector.length} '
          'elements.');
    }
    final column = Column<T>(name, vector);
    _columns.add(column);
    return column;
  }

  /// Adds a computed column to the data frame. The callback is evaluated with
  /// each [Row] of the data frame. If a [format] is provided, the resulting
  /// vector is mutable, otherwise the column is computed on demand only.
  Column<T> addComputed<T>(
    T Function(Row row) callback, {
    String name = '',
    DataType<T>? dataType,
    VectorFormat? format,
  }) =>
      addVector<T>(
        Vector<T>.generate(
          dataType ?? DataType.fromType<T>(),
          _frame.rows.length,
          (index) => callback(_frame.rows[index]),
          format: format,
        ),
        name: name,
      );
}
