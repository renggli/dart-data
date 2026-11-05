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
import 'tuple_key.dart';

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
    final colNames = <String>{};
    for (final row in rows) {
      colNames.addAll(row.keys);
    }
    final colData = <String, List<Object?>>{
      for (final name in colNames) name: [],
    };
    for (final row in rows) {
      for (final name in colNames) {
        final colList = colData[name];
        if (colList != null) colList.add(row[name]);
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
    Map<String, DataType<Object?>>? columnTypes,
  }) => DataFrameJsonDecoder.decode(
    source,
    orient: orient,
    columnTypes: columnTypes,
  );

  /// Constructs a [DataFrame] from an iterable of record maps.
  factory fromRecords(
    Iterable<Map<String, Object?>> records, {
    Map<String, DataType<Object?>>? columnTypes,
  }) => DataFrameJsonDecoder.fromRecords(records, columnTypes: columnTypes);

  /// Constructs a [DataFrame] from a 2-dimensional [matrix].
  ///
  /// Column names default to `'col_0'`, `'col_1'`, etc., unless [columnNames]
  /// is specified.
  factory fromMatrix(Matrix<Object?> matrix, {List<String>? columnNames}) {
    final cols = matrix.colCount;
    final rows = matrix.rowCount;
    if (columnNames != null && columnNames.length != cols) {
      throw ArgumentError(
        'Length of columnNames (${columnNames.length}) must match matrix column count ($cols).',
      );
    }
    final seriesList = <Series<Object?>>[];
    for (var c = 0; c < cols; c++) {
      final name = columnNames != null ? columnNames[c] : 'col_$c';
      final values = List<Object?>.generate(rows, (r) => matrix.get(r, c));
      seriesList.add(Series.fromList(name, values, type: matrix.type));
    }
    return DataFrame(seriesList);
  }

  /// Constructs a [DataFrame] from a rank-2 [tensor].
  ///
  /// Column names default to `'col_0'`, `'col_1'`, etc., unless [columnNames]
  /// is specified. Throws [ArgumentError] if [tensor] is not rank-2.
  factory fromTensor(Tensor<Object?> tensor, {List<String>? columnNames}) {
    if (tensor.rank != 2) {
      throw ArgumentError(
        'Tensor must have rank 2 to convert to DataFrame, but got rank ${tensor.rank}.',
      );
    }
    final rows = tensor.shape[0];
    final cols = tensor.shape[1];
    if (columnNames != null && columnNames.length != cols) {
      throw ArgumentError(
        'Length of columnNames (${columnNames.length}) must match tensor column count ($cols).',
      );
    }
    final seriesList = <Series<Object?>>[];
    for (var c = 0; c < cols; c++) {
      final name = columnNames != null ? columnNames[c] : 'col_$c';
      final values = List<Object?>.generate(rows, (r) => tensor.get2D(r, c));
      seriesList.add(Series.fromList(name, values, type: tensor.type));
    }
    return DataFrame(seriesList);
  }

  /// Constructs a [DataFrame] by decoding an Apache Arrow IPC stream byte
  /// buffer.
  factory fromArrowIpc(Uint8List bytes) => ArrowIpc.decode(bytes);

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
      newCols.add(col.concat(otherCol));
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

  /// Returns a new [DataFrame] with duplicate rows removed.
  ///
  /// If [subset] is provided, only the specified columns are considered when
  /// identifying duplicates. Otherwise, all columns are compared.
  /// If [keepFirst] is `true` (default), the first occurrence is kept;
  /// otherwise, the last occurrence is kept.
  DataFrame dropDuplicates({List<String>? subset, bool keepFirst = true}) {
    if (rowCount == 0) return this;
    final targetCols = subset != null ? subset.map(column).toList() : _columns;
    final extractor = RowKeyExtractor(targetCols);
    final seen = <Object?>{};
    final mask = List<bool>.filled(rowCount, false);

    if (keepFirst) {
      for (var r = 0; r < rowCount; r++) {
        final key = extractor.extractKey(r);
        if (seen.add(key)) {
          mask[r] = true;
        }
      }
    } else {
      for (var r = rowCount - 1; r >= 0; r--) {
        final key = extractor.extractKey(r);
        if (seen.add(key)) {
          mask[r] = true;
        }
      }
    }
    return filter(mask);
  }

  /// Unpivots this [DataFrame] from wide to long format.
  ///
  /// [idVars] specifies columns to use as identifier variables.
  /// [valueVars] specifies columns to unpivot. If omitted, all columns not in
  /// [idVars] are used.
  /// [varName] is the name of the column storing the unpivoted variable names (default: `'variable'`).
  /// [valueName] is the name of the column storing the values (default: `'value'`).
  DataFrame melt({
    required List<String> idVars,
    List<String>? valueVars,
    String varName = 'variable',
    String valueName = 'value',
  }) {
    for (final id in idVars) {
      if (!_columnIndex.containsKey(id)) {
        throw ArgumentError('Identifier column "$id" not found in DataFrame.');
      }
    }
    final effectiveValueVars =
        valueVars ??
        _columns
            .map((c) => c.name)
            .where((name) => !idVars.contains(name))
            .toList();

    for (final val in effectiveValueVars) {
      if (!_columnIndex.containsKey(val)) {
        throw ArgumentError('Value column "$val" not found in DataFrame.');
      }
    }

    final idCols = idVars.map(column).toList();
    final valCols = effectiveValueVars.map(column).toList();
    final numValCols = valCols.length;
    final totalRows = rowCount * numValCols;

    if (totalRows == 0) {
      final newCols = <Series<Object?>>[
        for (final idCol in idCols)
          Series.fromList(idCol.name, const [], type: idCol.dataType),
        Series<String>.fromList(varName, const []),
        Series.fromList(valueName, const []),
      ];
      return DataFrame(newCols);
    }

    final newIdData = <String, List<Object?>>{
      for (final id in idVars) id: List<Object?>.filled(totalRows, null),
    };
    final newVarData = List<String>.filled(totalRows, '');
    final newValData = List<Object?>.filled(totalRows, null);

    var writeIdx = 0;
    for (final valCol in valCols) {
      for (var r = 0; r < rowCount; r++) {
        for (final idCol in idCols) {
          newIdData[idCol.name]![writeIdx] = idCol[r];
        }
        newVarData[writeIdx] = valCol.name;
        newValData[writeIdx] = valCol[r];
        writeIdx++;
      }
    }

    DataType<Object?>? valueDataType;
    if (valCols.isNotEmpty) {
      final firstType = valCols.first.dataType;
      if (valCols.every((c) => c.dataType == firstType)) {
        valueDataType = firstType;
      }
    }

    final newCols = <Series<Object?>>[
      for (final idCol in idCols)
        Series.fromList(
          idCol.name,
          newIdData[idCol.name]!,
          type: idCol.dataType,
        ),
      Series<String>.fromList(varName, newVarData),
      Series.fromList(valueName, newValData, type: valueDataType),
    ];
    return DataFrame(newCols);
  }

  /// Reshapes this [DataFrame] from long to wide format.
  ///
  /// [index] specifies the column to use as row identifiers.
  /// [columns] specifies the column whose unique values become the new column names.
  /// [values] specifies the column providing values for the new cells.
  /// If multiple rows have the same [index] and [columns] combination, [aggregate]
  /// must be provided to reduce the list of values to a single value; otherwise,
  /// an [ArgumentError] is thrown.
  DataFrame pivot({
    required String index,
    required String columns,
    required String values,
    Object? Function(List<Object?> values)? aggregate,
  }) {
    final indexCol = column(index);
    final colCol = column(columns);
    final valCol = column(values);

    final orderedIndexValues = <Object?>[];
    final seenIndices = <Object?>{};
    final orderedColValues = <Object?>[];
    final seenCols = <Object?>{};

    final table = <Object?, Map<Object?, List<Object?>>>{};

    for (var r = 0; r < rowCount; r++) {
      final idxVal = indexCol[r];
      final colVal = colCol[r];
      final val = valCol[r];

      if (seenIndices.add(idxVal)) {
        orderedIndexValues.add(idxVal);
      }
      if (seenCols.add(colVal)) {
        orderedColValues.add(colVal);
      }

      table
          .putIfAbsent(idxVal, () => {})
          .putIfAbsent(colVal, () => [])
          .add(val);
    }

    if (aggregate == null) {
      for (final entry in table.entries) {
        for (final colEntry in entry.value.entries) {
          if (colEntry.value.length > 1) {
            throw ArgumentError(
              'Duplicate entries for index "${entry.key}" and column "${colEntry.key}" '
              'without aggregate function.',
            );
          }
        }
      }
    }

    final newCols = <Series<Object?>>[];
    newCols.add(
      Series.fromList(index, orderedIndexValues, type: indexCol.dataType),
    );

    for (final colVal in orderedColValues) {
      final colName = colVal?.toString() ?? 'null';
      final cellValues = <Object?>[];
      for (final idxVal in orderedIndexValues) {
        final list = table[idxVal]?[colVal];
        if (list == null || list.isEmpty) {
          cellValues.add(null);
        } else if (aggregate != null) {
          cellValues.add(aggregate(list));
        } else {
          cellValues.add(list.first);
        }
      }
      newCols.add(Series.fromList(colName, cellValues));
    }

    return DataFrame(newCols);
  }

  /// Returns a new [DataFrame] with null values replaced by [value] in specified [columns] (or all columns).
  ///
  /// [value] can be a single replacement value, or a [Map<String, Object?>] mapping column names
  /// to their respective replacement values. If a single [value] is not compatible with a column's
  /// data type, that column is left unmodified instead of throwing a type error.
  DataFrame fillNull(Object value, {List<String>? columns}) {
    final colSet = columns?.toSet();
    final newCols = <Series<Object?>>[];
    for (final col in _columns) {
      if (colSet != null && !colSet.contains(col.name)) {
        newCols.add(col);
        continue;
      }
      if (!col.hasNulls) {
        newCols.add(col);
        continue;
      }
      final Object? replacement;
      if (value is Map<String, Object?>) {
        if (!value.containsKey(col.name)) {
          newCols.add(col);
          continue;
        }
        replacement = value[col.name];
      } else {
        replacement = value;
      }
      if (replacement == null) {
        newCols.add(col);
        continue;
      }
      final Object? castValue;
      if (col.dataType.isNumeric && replacement is num) {
        castValue = col.dataType.cast(replacement);
      } else {
        castValue = replacement;
      }
      if (castValue == null) {
        newCols.add(col);
        continue;
      }
      try {
        newCols.add(col.fillNull(castValue));
      } on TypeError {
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
      var hasNaN = false;
      for (var i = 0; i < rowCount; i++) {
        final val = col[i];
        if (val != null) {
          final d = (val as num).toDouble();
          if (d.isNaN) hasNaN = true;
          nonNulls.add(d);
        }
      }
      final n = nonNulls.length;
      if (n == 0 || hasNaN) {
        stats[col.name] = [
          n.toDouble(),
          double.nan,
          double.nan,
          double.nan,
          double.nan,
          double.nan,
          double.nan,
          double.nan,
        ];
      } else {
        nonNulls.sort();
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
        } else if (valA is num && valB is num) {
          final isNanA = valA.isNaN;
          final isNanB = valB.isNaN;
          if (isNanA && isNanB) {
            cmp = 0;
          } else if (isNanA) {
            cmp = 1;
          } else if (isNanB) {
            cmp = -1;
          } else {
            cmp = valA.compareTo(valB);
          }
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
      sortedCols.add(col.permute(indices));
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
  List<Map<String, Object?>> toRecords() =>
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

  new _(List<Series<Object?>> list)
    : _columns = list,
      rowCount = list.isEmpty ? 0 : list[0].length,
      _columnIndex = {} {
    for (var i = 0; i < list.length; i++) {
      final col = list[i];
      if (_columnIndex.containsKey(col.name)) {
        throw ArgumentError('Duplicate column name "${col.name}" in DataFrame');
      }
      _columnIndex[col.name] = i;
      if (col.length != rowCount) {
        throw ArgumentError(
          'All columns must have identical length ($rowCount), but column "${col.name}" has ${col.length}',
        );
      }
    }
  }
}
