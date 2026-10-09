import 'dart:math' as math;

import '../linear/matrix.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';
import 'csv.dart';
import 'groupby.dart';
import 'series.dart';

/// 2-dimensional heterogeneous tabular data structure.
class DataFrame {
  new(Iterable<Series<dynamic>> columns)
    : _columns = columns.toList(growable: false),
      _columnIndex = {
        for (var i = 0; i < columns.length; i++) columns.elementAt(i).name: i,
      },
      rowCount = columns.isEmpty ? 0 : columns.first.length {
    for (final col in _columns) {
      if (col.length != rowCount) {
        throw ArgumentError(
          'All columns must have identical length ($rowCount), but column "${col.name}" has ${col.length}',
        );
      }
    }
  }

  /// Constructs a DataFrame from an ordered mapping of column names to row values.
  factory fromColumns(Map<String, List<dynamic>> data) {
    final cols = <Series<dynamic>>[];
    for (final entry in data.entries) {
      cols.add(Series.fromList(entry.key, entry.value));
    }
    return DataFrame(cols);
  }

  /// Constructs a DataFrame from a list of row maps.
  factory fromRows(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return DataFrame([]);
    final colNames = rows.first.keys.toList();
    final colData = <String, List<dynamic>>{
      for (final name in colNames) name: [],
    };
    for (final row in rows) {
      for (final name in colNames) {
        colData[name]!.add(row[name]);
      }
    }
    return DataFrame.fromColumns(colData);
  }

  /// Parses a CSV string into a DataFrame.
  factory fromCsv(String csv, {String separator = ',', bool header = true}) =>
      CsvReader.parse(csv, separator: separator, header: header);

  /// Number of rows.
  final int rowCount;
  final List<Series<dynamic>> _columns;
  final Map<String, int> _columnIndex;

  /// Number of columns.
  int get columnCount => _columns.length;

  /// List of column names in schema order.
  List<String> get columnNames =>
      _columns.map((c) => c.name).toList(growable: false);

  /// Accesses a column by [name].
  Series<dynamic> column(String name) {
    final idx = _columnIndex[name];
    if (idx == null) {
      throw ArgumentError('Column "$name" not found in DataFrame');
    }
    return _columns[idx];
  }

  /// Accesses a typed column by [name].
  Series<T> typedColumn<T>(String name) => column(name) as Series<T>;

  /// Accesses a column by [name].
  Series<dynamic> operator [](String name) => column(name);

  /// Returns the row map at [index].
  Map<String, dynamic> getRow(int index) {
    if (index < 0 || index >= rowCount) {
      throw RangeError.index(index, this, 'index', null, rowCount);
    }
    return {for (final col in _columns) col.name: col[index]};
  }

  /// Returns an iterable over all rows as maps.
  Iterable<Map<String, dynamic>> get rows sync* {
    for (var i = 0; i < rowCount; i++) {
      yield getRow(i);
    }
  }

  /// Selects a subset of columns.
  DataFrame select(List<String> names) {
    final selected = names.map(column).toList();
    return DataFrame(selected);
  }

  /// Drops the specified columns.
  DataFrame drop(List<String> names) {
    final dropSet = names.toSet();
    final remaining = _columns.where((c) => !dropSet.contains(c.name)).toList();
    return DataFrame(remaining);
  }

  /// Adds or replaces [series] in this DataFrame.
  DataFrame withColumn(Series<dynamic> series) {
    final newCols = <Series<dynamic>>[];
    var replaced = false;
    for (final col in _columns) {
      if (col.name == series.name) {
        newCols.add(series);
        replaced = true;
      } else {
        newCols.add(col);
      }
    }
    if (!replaced) newCols.add(series);
    return DataFrame(newCols);
  }

  /// Filters rows using a boolean mask.
  DataFrame filter(List<bool> condition) {
    if (condition.length != rowCount) {
      throw ArgumentError(
        'Condition length (${condition.length}) must match rowCount ($rowCount)',
      );
    }
    return DataFrame(_columns.map((col) => col.filter(condition)));
  }

  /// Filters rows using a row predicate.
  DataFrame filterBy(bool Function(Map<String, dynamic> row) predicate) {
    final mask = <bool>[];
    for (var i = 0; i < rowCount; i++) {
      mask.add(predicate(getRow(i)));
    }
    return filter(mask);
  }

  /// Slices rows from [start] to [end].
  DataFrame slice(int start, int end) {
    final s = math.max(0, start);
    final e = math.min(rowCount, end);
    return DataFrame(_columns.map((col) => col.slice(s, e)));
  }

  /// Returns the first [n] rows.
  DataFrame head([int n = 5]) => slice(0, n);

  /// Returns the last [n] rows.
  DataFrame tail([int n = 5]) => slice(math.max(0, rowCount - n), rowCount);

  /// Sorts rows by the values in [columnName].
  DataFrame sortBy(String columnName, {bool ascending = true}) {
    final col = column(columnName);
    final indices = List<int>.generate(rowCount, (i) => i);
    indices.sort((a, b) {
      final valA = col[a];
      final valB = col[b];
      if (valA == null && valB == null) return 0;
      if (valA == null) return 1;
      final int cmp;
      if (valA is bool && valB is bool) {
        cmp = (valA ? 1 : 0).compareTo(valB ? 1 : 0);
      } else if (valA is Comparable) {
        cmp = valA.compareTo(valB);
      } else {
        cmp = '$valA'.compareTo('$valB');
      }
      return ascending ? cmp : -cmp;
    });

    final sortedCols = <Series<dynamic>>[];
    for (final c in _columns) {
      final sortedVals = [for (final idx in indices) c[idx]];
      sortedCols.add(Series.fromList(c.name, sortedVals, type: c.dataType));
    }
    return DataFrame(sortedCols);
  }

  /// Converts selected numeric columns into a 2D [Matrix].
  Matrix<double> toMatrix({List<String>? columns, DataType<double>? type}) {
    final tensor = toTensor(columns: columns, type: type);
    return Matrix(tensor);
  }

  /// Converts selected numeric columns into a rank-2 [Tensor].
  Tensor<double> toTensor({List<String>? columns, DataType<double>? type}) {
    final targetCols = columns != null
        ? columns.map(column).toList()
        : _columns;
    final effType = type ?? DataType.float64;
    final r = rowCount;
    final c = targetCols.length;
    final tensor = Tensor<double>.filled(
      effType.defaultValue,
      shape: [r, c],
      type: effType,
    );

    for (var j = 0; j < c; j++) {
      final col = targetCols[j];
      for (var i = 0; i < r; i++) {
        final val = col[i];
        final numVal = val is num ? val.toDouble() : 0.0;
        tensor.setValue([i, j], numVal);
      }
    }
    return tensor;
  }

  /// Groups by [byColumns] for partitioned aggregation.
  GroupBy groupBy(List<String> byColumns) => GroupBy(this, byColumns);

  /// Serializes DataFrame to CSV format.
  String toCsv({String separator = ','}) =>
      CsvWriter.write(this, separator: separator);

  @override
  String toString() {
    final buffer = StringBuffer(
      'DataFrame($rowCount rows x $columnCount columns)\n',
    );
    final displayCols = _columns.take(6).toList();
    buffer.writeln(displayCols.map((c) => c.name.padRight(12)).join(' | '));
    buffer.writeln('-' * (displayCols.length * 15));
    for (var r = 0; r < math.min(rowCount, 5); r++) {
      buffer.writeln(
        displayCols.map((c) => '${c[r]}'.padRight(12)).join(' | '),
      );
    }
    if (rowCount > 5) buffer.writeln('... and ${rowCount - 5} more rows');
    return buffer.toString();
  }
}
