import 'dart:math' as math;
import 'dart:typed_data';

import '../linear/matrix.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';
import 'arrow/arrow_c_data.dart';
import 'arrow/arrow_ipc.dart';
import 'csv/csv_reader.dart';
import 'csv/csv_writer.dart';
import 'groupby.dart';
import 'json/json_decoder.dart';
import 'json/json_encoder.dart';
import 'json/json_orient.dart';
import 'series.dart';

/// 2-dimensional heterogeneous tabular data structure.
///
/// Conceptually, a [DataFrame] is organized like a spreadsheet table with named
/// columns (such as 'Name', 'Age', 'Score') where each column has the same
/// number of rows. Mathematically, it represents a finite relation
/// $R \subseteq T_1 \times T_2 \times \dots \times T_k$ over typed attributes,
/// isomorphic to a columnar database table supporting relational algebra.
///
/// ```dart
/// final df = DataFrame.fromColumns({
///   'name': ['Alice', 'Bob'],
///   'score': [95.0, 88.5],
/// });
/// ```
class DataFrame {
  /// Creates a [DataFrame] from an ordered collection of [columns].
  ///
  /// Every column must have the same length [rowCount].
  ///
  /// ```dart
  /// final s1 = Series<int>.fromList('a', [1, 2]);
  /// final s2 = Series<String>.fromList('b', ['x', 'y']);
  /// final df = DataFrame([s1, s2]);
  /// ```
  new(Iterable<Series<Object?>> columns)
    : this._(columns.toList(growable: false));

  new _(List<Series<Object?>> list)
    : _columns = list,
      rowCount = list.isEmpty ? 0 : list[0].length,
      _columnIndex = {for (var i = 0; i < list.length; i++) list[i].name: i} {
    for (var i = 0; i < list.length; i++) {
      final col = list[i];
      if (col.length != rowCount) {
        throw ArgumentError(
          'All columns must have identical length ($rowCount), but column "${col.name}" has ${col.length}',
        );
      }
    }
  }

  /// Constructs a [DataFrame] from an ordered mapping of column names to row
  /// values.
  factory fromColumns(Map<String, List<Object?>> data) {
    final cols = <Series<Object?>>[];
    for (final entry in data.entries) {
      cols.add(Series.fromList(entry.key, entry.value));
    }
    return DataFrame(cols);
  }

  /// Constructs a [DataFrame] from a list of row maps.
  factory fromRows(List<Map<String, Object?>> rows) {
    if (rows.isEmpty) return DataFrame([]);
    final colNames = rows.first.keys.toList();
    final colData = <String, List<Object?>>{
      for (final name in colNames) name: [],
    };
    for (final row in rows) {
      for (final name in colNames) {
        colData[name]!.add(row[name]);
      }
    }
    return DataFrame.fromColumns(colData);
  }

  /// Parses a CSV string into a [DataFrame].
  factory fromCsv(String csv, {String separator = ',', bool header = true}) =>
      CsvReader.parse(csv, separator: separator, header: header);

  /// Parses a JSON string into a [DataFrame].
  factory fromJson(
    String source, {
    JsonOrient? orient,
    Map<String, DataType<dynamic>>? columnTypes,
  }) => DataFrameJsonDecoder.decode(
    source,
    orient: orient,
    columnTypes: columnTypes,
  );

  /// Constructs a [DataFrame] from an iterable of record maps.
  factory fromRecords(
    Iterable<Map<String, dynamic>> records, {
    Map<String, DataType<dynamic>>? columnTypes,
  }) => DataFrameJsonDecoder.fromRecords(records, columnTypes: columnTypes);

  /// Constructs a [DataFrame] by decoding an Apache Arrow IPC stream byte
  /// buffer.
  factory fromArrowIpc(Uint8List bytes) => ArrowIpc.decode(bytes);

  /// Number of rows.
  final int rowCount;
  final List<Series<Object?>> _columns;
  final Map<String, int> _columnIndex;

  /// Number of columns.
  int get columnCount => _columns.length;

  /// Ordered list of all column [Series] in this DataFrame.
  List<Series<Object?>> get columns => _columns;

  /// List of column names in schema order.
  List<String> get columnNames =>
      _columns.map((column) => column.name).toList(growable: false);

  /// Accesses a column by [name].
  Series<Object?> column(String name) {
    final idx = _columnIndex[name];
    if (idx == null) {
      throw ArgumentError('Column "$name" not found in DataFrame');
    }
    return _columns[idx];
  }

  /// Accesses a typed column by [name].
  Series<T> typedColumn<T>(String name) => column(name) as Series<T>;

  /// Accesses a column by [name].
  Series<Object?> operator [](String name) => column(name);

  /// Returns the row map at [index].
  Map<String, Object?> getRow(int index) {
    if (index < 0 || index >= rowCount) {
      throw RangeError.index(index, this, 'index', null, rowCount);
    }
    return {for (final col in _columns) col.name: col[index]};
  }

  /// Returns an iterable over all rows as maps.
  Iterable<Map<String, Object?>> get rows sync* {
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
    final remaining = _columns
        .where((col) => !dropSet.contains(col.name))
        .toList();
    return DataFrame(remaining);
  }

  /// Adds or replaces [series] in this [DataFrame].
  DataFrame withColumn(Series<Object?> series) {
    final newCols = <Series<Object?>>[];
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

  /// Renames columns according to [mapping].
  DataFrame rename(Map<String, String> mapping) {
    for (final oldName in mapping.keys) {
      if (!_columnIndex.containsKey(oldName)) {
        throw ArgumentError('Column "$oldName" does not exist in DataFrame.');
      }
    }
    final newCols = <Series<Object?>>[];
    for (final col in _columns) {
      final newName = mapping[col.name];
      newCols.add(newName != null ? col.rename(newName) : col);
    }
    return DataFrame(newCols);
  }

  /// Concatenates this [DataFrame] vertically with [other].
  DataFrame concat(DataFrame other) {
    if (columnCount != other.columnCount) {
      throw ArgumentError(
        'Cannot concatenate DataFrames with different column counts ($columnCount vs ${other.columnCount}).',
      );
    }
    for (final col in _columns) {
      if (!other._columnIndex.containsKey(col.name)) {
        throw ArgumentError(
          'Cannot concatenate DataFrames: column "${col.name}" missing in other DataFrame.',
        );
      }
    }
    final newCols = <Series<Object?>>[];
    for (final col in _columns) {
      final otherCol = other.column(col.name);
      final combinedType = col.dataType == otherCol.dataType
          ? col.dataType
          : col.dataType.promoteWith(otherCol.dataType);
      final List<Object?> combinedVals;
      if (combinedType == col.dataType && combinedType == otherCol.dataType) {
        combinedVals = <Object?>[...col.values, ...otherCol.values];
      } else {
        combinedVals = <Object?>[
          for (final v in col.values)
            if (v == null) null else combinedType.cast(v),
          for (final v in otherCol.values)
            if (v == null) null else combinedType.cast(v),
        ];
      }
      newCols.add(Series.fromList(col.name, combinedVals, type: combinedType));
    }
    return DataFrame(newCols);
  }

  /// Drops rows containing null values in any column (or any column in [subset]).
  DataFrame dropNulls({List<String>? subset}) {
    final targetCols = subset != null ? subset.map(column).toList() : _columns;
    final mask = <bool>[];
    for (var r = 0; r < rowCount; r++) {
      var keep = true;
      for (var c = 0; c < targetCols.length; c++) {
        if (targetCols[c].isNull(r)) {
          keep = false;
          break;
        }
      }
      mask.add(keep);
    }
    return filter(mask);
  }

  /// Returns a new [DataFrame] with null values replaced by [value] in all columns.
  DataFrame fillNull(Object value) {
    final newCols = <Series<Object?>>[];
    for (final col in _columns) {
      if (col.hasNulls) {
        newCols.add(col.fillNull(value));
      } else {
        newCols.add(col);
      }
    }
    return DataFrame(newCols);
  }

  /// Generates descriptive summary statistics for numeric columns.
  DataFrame describe() {
    final numericCols = _columns
        .where((col) => col.dataType.isNumeric || col is Series<num>)
        .toList();
    final stats = <String, List<Object?>>{
      'statistic': ['count', 'mean', 'std', 'min', '25%', '50%', '75%', 'max'],
    };

    for (final col in numericCols) {
      final nonNulls = <double>[];
      for (var i = 0; i < rowCount; i++) {
        final val = col[i];
        if (val != null) {
          nonNulls.add((val as num).toDouble());
        }
      }
      nonNulls.sort();
      final n = nonNulls.length;
      if (n == 0) {
        stats[col.name] = [
          0.0,
          double.nan,
          double.nan,
          double.nan,
          double.nan,
          double.nan,
          double.nan,
          double.nan,
        ];
      } else {
        var sum = 0.0;
        for (var i = 0; i < n; i++) {
          sum += nonNulls[i];
        }
        final mean = sum / n;
        var varSum = 0.0;
        for (var i = 0; i < n; i++) {
          final diff = nonNulls[i] - mean;
          varSum += diff * diff;
        }
        final std = n > 1 ? math.sqrt(varSum / (n - 1)) : 0.0;
        final min = nonNulls.first;
        final max = nonNulls.last;

        double quantile(double p) {
          final idx = p * (n - 1);
          final low = idx.floor();
          final frac = idx - low;
          if (low >= n - 1) return nonNulls.last;
          return nonNulls[low] + frac * (nonNulls[low + 1] - nonNulls[low]);
        }

        stats[col.name] = [
          n.toDouble(),
          mean,
          std,
          min,
          quantile(0.25),
          quantile(0.50),
          quantile(0.75),
          max,
        ];
      }
    }

    return DataFrame.fromColumns(stats);
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
  DataFrame filterBy(bool Function(Map<String, Object?> row) predicate) {
    final mask = <bool>[];
    for (var i = 0; i < rowCount; i++) {
      mask.add(predicate(getRow(i)));
    }
    return filter(mask);
  }

  /// Slices rows from [start] to [end].
  DataFrame slice(int start, int end) {
    final startIndex = math.max(0, start);
    final endIndex = math.min(rowCount, end);
    return DataFrame(_columns.map((col) => col.slice(startIndex, endIndex)));
  }

  /// Returns the first [count] rows.
  DataFrame head([int count = 5]) => slice(0, count);

  /// Returns the last [count] rows.
  DataFrame tail([int count = 5]) =>
      slice(math.max(0, rowCount - count), rowCount);

  /// Sorts rows by the values in [by] (column name or list of column names).
  ///
  /// The [ascending] parameter can be a single `bool` or a `List<bool>` for each
  /// column. The [nullsLast] parameter can be a `bool` or a `List<bool>`.
  DataFrame sortBy(
    Object by, {
    Object ascending = true,
    Object nullsLast = true,
  }) {
    final List<String> sortCols;
    if (by is String) {
      sortCols = [by];
    } else if (by is List<String>) {
      sortCols = by;
    } else {
      throw ArgumentError.value(by, 'by', 'Must be a String or List<String>');
    }

    final ascList = ascending is List<bool>
        ? ascending
        : List<bool>.filled(sortCols.length, ascending as bool);
    if (ascList.length != sortCols.length) {
      throw ArgumentError(
        'ascending list length (${ascList.length}) must match columns length (${sortCols.length}).',
      );
    }
    final nullsList = nullsLast is List<bool>
        ? nullsLast
        : List<bool>.filled(sortCols.length, nullsLast as bool);
    if (nullsList.length != sortCols.length) {
      throw ArgumentError(
        'nullsLast list length (${nullsList.length}) must match columns length (${sortCols.length}).',
      );
    }

    final cols = sortCols.map(column).toList(growable: false);
    final indices = List<int>.generate(rowCount, (i) => i);
    indices.sort((a, b) {
      for (var c = 0; c < sortCols.length; c++) {
        final col = cols[c];
        final valA = col[a];
        final valB = col[b];
        if (valA == null && valB == null) continue;
        final nLast = nullsList[c];
        if (valA == null) return nLast ? 1 : -1;
        if (valB == null) return nLast ? -1 : 1;
        final int cmp;
        if (valA is bool && valB is bool) {
          cmp = (valA ? 1 : 0).compareTo(valB ? 1 : 0);
        } else if (valA is Comparable) {
          cmp = valA.compareTo(valB);
        } else {
          cmp = '$valA'.compareTo('$valB');
        }
        if (cmp != 0) {
          return ascList[c] ? cmp : -cmp;
        }
      }
      return 0;
    });

    final sortedCols = <Series<Object?>>[];
    for (final col in _columns) {
      final sortedVals = [for (final idx in indices) col[idx]];
      sortedCols.add(Series.fromList(col.name, sortedVals, type: col.dataType));
    }
    return DataFrame(sortedCols);
  }

  /// Converts selected numeric columns into a 2D [Matrix].
  ///
  /// Throws [UnsupportedError] if any selected column is non-numeric.
  /// Missing values are mapped to [nullValue] (defaults to [double.nan]).
  Matrix<double> toMatrix({
    List<String>? columns,
    DataType<double>? type,
    double nullValue = double.nan,
  }) {
    final tensor = toTensor(columns: columns, type: type, nullValue: nullValue);
    return Matrix(tensor);
  }

  /// Converts selected numeric columns into a rank-2 [Tensor].
  ///
  /// Throws [UnsupportedError] if any selected column is non-numeric.
  /// Missing values are mapped to [nullValue] (defaults to [double.nan]).
  Tensor<double> toTensor({
    List<String>? columns,
    DataType<double>? type,
    double nullValue = double.nan,
  }) {
    final targetCols = columns != null
        ? columns.map(column).toList()
        : _columns;
    for (final col in targetCols) {
      if (!col.dataType.isNumeric && col is! Series<num>) {
        throw UnsupportedError(
          'Cannot convert non-numeric column "${col.name}" of type '
          '${col.dataType} to numeric tensor.',
        );
      }
    }
    final effType = type ?? DataType.float64;
    final rows = rowCount;
    final cols = targetCols.length;
    final tensor = Tensor<double>.filled(
      effType.defaultValue,
      shape: [rows, cols],
      type: effType,
    );

    if (rows == 0 || cols == 0) return tensor;

    final tensorData = tensor.data;
    final offset = tensor.layout.offset;
    final rowStride = tensor.layout.strides[0];
    final colStride = cols > 1 ? tensor.layout.strides[1] : 1;

    final allDoubleNonNull = targetCols.every(
      (col) => col is TypedSeries<double> && !col.hasNulls,
    );

    if (allDoubleNonNull) {
      if (cols == 1) {
        final colData = (targetCols.first as TypedSeries<double>).data;
        tensorData.setRange(offset, offset + rows, colData);
      } else {
        final colBuffers = [
          for (final col in targetCols) (col as TypedSeries<double>).data,
        ];
        var tensorIdx = offset;
        for (var i = 0; i < rows; i++) {
          for (var j = 0; j < cols; j++) {
            tensorData[tensorIdx++] = colBuffers[j][i];
          }
        }
      }
      return tensor;
    }

    for (var j = 0; j < cols; j++) {
      final col = targetCols[j];
      final colOffset = offset + j * colStride;
      if (col is TypedSeries<num> && !col.hasNulls) {
        final colData = col.data;
        for (var i = 0; i < rows; i++) {
          tensorData[colOffset + i * rowStride] = colData[i].toDouble();
        }
      } else if (col is TypedSeries<num>) {
        final colData = col.data;
        for (var i = 0; i < rows; i++) {
          tensorData[colOffset + i * rowStride] = col.isNull(i)
              ? nullValue
              : colData[i].toDouble();
        }
      } else {
        for (var i = 0; i < rows; i++) {
          final val = col[i];
          if (val == null) {
            tensorData[colOffset + i * rowStride] = nullValue;
          } else if (val is num) {
            tensorData[colOffset + i * rowStride] = val.toDouble();
          } else {
            throw UnsupportedError(
              'Cannot convert non-numeric value "$val" in column "${col.name}" to double.',
            );
          }
        }
      }
    }
    return tensor;
  }

  /// Groups by [byColumns] for partitioned aggregation.
  GroupBy groupBy(List<String> byColumns) => GroupBy(this, byColumns);

  /// Serializes this [DataFrame] to CSV format.
  String toCsv({String separator = ','}) =>
      CsvWriter.write(this, separator: separator);

  /// Serializes this [DataFrame] to JSON format.
  String toJson({JsonOrient orient = JsonOrient.records}) =>
      DataFrameJsonEncoder.encode(this, orient: orient);

  /// Converts this [DataFrame] rows to a list of record maps.
  List<Map<String, dynamic>> toRecords() =>
      DataFrameJsonEncoder.toRecords(this);

  /// Serializes this [DataFrame] to Apache Arrow IPC stream byte format.
  Uint8List toArrowIpc() => ArrowIpc.encode(this);

  /// Exports this [DataFrame] to Apache Arrow C Data structures.
  ///
  /// Populates [outSchema] (`Pointer<ArrowSchema>`) and [outArray]
  /// (`Pointer<ArrowArray>`). Requires `dart:ffi`.
  void exportTo({required Object outSchema, required Object outArray}) =>
      exportDataFrameToArrowC(
        dataFrame: this,
        outSchema: outSchema,
        outArray: outArray,
      );

  /// Imports a [DataFrame] from Apache Arrow C Data structures.
  ///
  /// Consumes [schema] (`Pointer<ArrowSchema>`) and [array]
  /// (`Pointer<ArrowArray>`). If [release] is true (default), the producer's
  /// release callbacks are invoked upon import completion.
  static DataFrame importFrom({
    required Object schema,
    required Object array,
    bool release = true,
  }) =>
      importDataFrameFromArrowC(schema: schema, array: array, release: release);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! DataFrame) return false;
    if (rowCount != other.rowCount || columnCount != other.columnCount) {
      return false;
    }
    for (var i = 0; i < columnCount; i++) {
      if (_columns[i] != other._columns[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    var hash = Object.hash(rowCount, columnCount);
    for (var i = 0; i < columnCount; i++) {
      hash = Object.hash(hash, _columns[i]);
    }
    return hash;
  }

  @override
  String toString() {
    final buffer = StringBuffer(
      'DataFrame($rowCount rows x $columnCount columns)\n',
    );
    final displayCols = _columns.take(6).toList();
    buffer.writeln(displayCols.map((col) => col.name.padRight(12)).join(' | '));
    buffer.writeln('-' * (displayCols.length * 15));
    for (var row = 0; row < math.min(rowCount, 5); row++) {
      buffer.writeln(
        displayCols.map((col) => '${col[row]}'.padRight(12)).join(' | '),
      );
    }
    if (rowCount > 5) buffer.writeln('... and ${rowCount - 5} more rows');
    return buffer.toString();
  }
}
