import 'dart:math' as math;

import '../type/data_type.dart';
import 'dataframe.dart';
import 'numeric_stats.dart';
import 'series.dart';
import 'tuple_key.dart';

/// Aggregation operations supported in [GroupBy].
enum Agg {
  /// Number of non-null values.
  count,

  /// Sum of numeric values.
  sum,

  /// Arithmetic mean of numeric values.
  mean,

  /// Minimum value.
  min,

  /// Maximum value.
  max,

  /// Sample standard deviation.
  std,

  /// Sample variance (Bessel's correction, n - 1).
  variance,

  /// Median value.
  median,

  /// First non-null value.
  first,

  /// Last non-null value.
  last,
}

/// Grouped [DataFrame] supporting hash-partitioned aggregations.
///
/// Conceptually, grouping organizes table rows into buckets based on shared
/// values (such as grouping records by department or category). Mathematically,
/// this induces a quotient partition `R / ~` over the relation based on
/// equivalence under the projection onto [byColumns].
///
/// ```dart
/// final df = DataFrame.fromColumns({
///   'dept': ['Sales', 'Sales', 'Eng'],
///   'salary': [50000, 60000, 80000],
/// });
/// final grouped = df.groupBy(['dept']);
/// final summary = grouped.mean();
/// ```
class GroupBy {
  /// Creates a grouped view of [dataFrame] partitioned by values in
  /// [byColumns].
  new(this.dataFrame, List<String> byColumns)
    : byColumns = List<String>.unmodifiable(byColumns) {
    if (this.byColumns.isEmpty) {
      throw ArgumentError('byColumns cannot be empty');
    }
    final seen = <String>{};
    for (final col in this.byColumns) {
      if (!seen.add(col)) {
        throw ArgumentError('Duplicate group-by column "$col".');
      }
    }
    _buildGroups();
  }

  /// The source [DataFrame] being partitioned.
  final DataFrame dataFrame;

  /// The unmodifiable column names whose values define group partitions.
  final List<String> byColumns;

  // Group key -> list of row indices
  final Map<Object?, List<int>> _groups = {};
  // Group key -> original key values
  final Map<Object?, List<Object?>> _groupKeys = {};

  /// Returns the number of distinct groups.
  int get groupCount => _groups.length;

  /// Evaluates aggregations across each group and produces a new [DataFrame].
  DataFrame aggregate(Map<String, List<Agg>> aggregations) {
    final resultCols = <String, List<Object?>>{};
    final outTypes = <String, DataType<Object?>>{};
    final usedNames = <String>{};
    // Initialize group key columns
    for (final col in byColumns) {
      resultCols[col] = [];
      outTypes[col] = dataFrame.column(col).dataType;
      usedNames.add(col);
    }

    // Initialize aggregation output columns
    final specs = <({Series<Object?> col, Agg agg, String outName})>[];
    for (final entry in aggregations.entries) {
      final colName = entry.key;
      final srcCol = dataFrame.column(colName);
      for (final agg in entry.value) {
        var outName = '${colName}_${agg.name}';
        var counter = 1;
        while (!usedNames.add(outName)) {
          outName = '${colName}_${agg.name}_$counter';
          counter++;
        }
        specs.add((col: srcCol, agg: agg, outName: outName));
        resultCols[outName] = [];
        outTypes[outName] = switch (agg) {
          Agg.count => DataType.int32,
          Agg.mean || Agg.std || Agg.variance || Agg.median => DataType.float64,
          Agg.sum =>
            srcCol.dataType is DataType<double> ||
                    srcCol.dataType == DataType.numeric
                ? DataType.float64
                : DataType.int64,
          Agg.min || Agg.max || Agg.first || Agg.last => srcCol.dataType,
        };
      }
    }

    final medianScratch = <double>[];

    // Process each group
    for (final entry in _groups.entries) {
      final key = entry.key;
      final indices = entry.value;
      final keyVals = _groupKeys[key];
      if (keyVals == null) continue;

      // Append group key values
      for (var i = 0; i < byColumns.length; i++) {
        final colList = resultCols[byColumns[i]];
        if (colList != null) colList.add(keyVals[i]);
      }

      // Compute aggregations
      for (final spec in specs) {
        final aggResult = _computeAgg(
          spec.col,
          indices,
          spec.agg,
          medianScratch,
        );
        final outList = resultCols[spec.outName];
        if (outList != null) outList.add(aggResult);
      }
    }

    for (final entry in resultCols.entries) {
      if (byColumns.contains(entry.key)) continue;
      final list = entry.value;
      if (outTypes[entry.key] == DataType.float64 ||
          list.any((v) => v is num && (!v.isFinite || v is! int))) {
        outTypes[entry.key] = DataType.float64;
        resultCols[entry.key] = [
          for (final v in list)
            if (v is num) v.toDouble() else v,
        ];
      }
    }

    final outputSeries = <Series<Object?>>[];
    for (final col in byColumns) {
      final origCol = dataFrame.column(col);
      final colVals = resultCols[col] ?? const <Object?>[];
      outputSeries.add(Series.fromList(col, colVals, type: origCol.dataType));
    }
    for (final entry in resultCols.entries) {
      if (byColumns.contains(entry.key)) continue;
      outputSeries.add(
        Series.fromList(entry.key, entry.value, type: outTypes[entry.key]),
      );
    }

    return DataFrame(outputSeries);
  }

  /// Computes mean of all numeric columns per group.
  DataFrame mean() => _aggregateCols(_numericTargetColumns(), Agg.mean);

  /// Computes sum of all numeric columns per group.
  DataFrame sum() => _aggregateCols(_numericTargetColumns(), Agg.sum);

  /// Computes minimum of all non-key columns per group.
  DataFrame min() => _aggregateCols(_nonKeyColumns(), Agg.min);

  /// Computes maximum of all non-key columns per group.
  DataFrame max() => _aggregateCols(_nonKeyColumns(), Agg.max);

  /// Computes sample standard deviation of all numeric columns per group.
  DataFrame std() => _aggregateCols(_numericTargetColumns(), Agg.std);

  /// Computes sample variance of all numeric columns per group.
  DataFrame variance() => _aggregateCols(_numericTargetColumns(), Agg.variance);

  /// Computes median of all numeric columns per group.
  DataFrame median() => _aggregateCols(_numericTargetColumns(), Agg.median);

  /// Computes count of entries per group.
  DataFrame count() {
    final targetCols = _nonKeyColumns();
    final cols = targetCols.isNotEmpty ? targetCols : [byColumns.first];
    return _aggregateCols(cols, Agg.count);
  }

  List<String> _nonKeyColumns() =>
      dataFrame.columnNames.where((col) => !byColumns.contains(col)).toList();

  List<String> _numericTargetColumns() => dataFrame.columnNames.where((name) {
    if (byColumns.contains(name)) return false;
    final col = dataFrame.column(name);
    return col.dataType.isNumeric || col is Series<num>;
  }).toList();

  DataFrame _aggregateCols(List<String> cols, Agg agg) => aggregate({
    for (final col in cols) col: [agg],
  });

  void _buildGroups() {
    final keyCols = byColumns.map(dataFrame.column).toList();
    final extractor = RowKeyExtractor(keyCols);
    for (var rowIdx = 0; rowIdx < dataFrame.rowCount; rowIdx++) {
      final key = extractor.extractKey(rowIdx);
      final groupRows = _groups.putIfAbsent(key, () {
        _groupKeys[key] = [for (final col in keyCols) col[rowIdx]];
        return [];
      });
      groupRows.add(rowIdx);
    }
  }

  Object? _computeAgg(
    Series<Object?> col,
    List<int> indices,
    Agg agg,
    List<double> scratch,
  ) {
    switch (agg) {
      case Agg.count:
        var count = 0;
        for (var i = 0; i < indices.length; i++) {
          if (!col.isNull(indices[i])) count++;
        }
        return count;
      case Agg.first:
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val != null) return val;
        }
        return null;
      case Agg.last:
        for (var i = indices.length - 1; i >= 0; i--) {
          final val = col[indices[i]];
          if (val != null) return val;
        }
        return null;
      case Agg.sum:
        var total =
            col.dataType is DataType<double> || col.dataType == DataType.numeric
            ? 0.0
            : 0;
        var hasValid = false;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is num) {
            total += val;
            hasValid = true;
          }
        }
        return hasValid ? total : null;
      case Agg.mean:
        return computeNumericMean(indices.length, (i) {
          final val = col[indices[i]];
          return val is num ? val.toDouble() : null;
        });
      case Agg.min:
        Object? minVal;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val == null) continue;
          if (val is num && val.isNaN) return double.nan;
          if (minVal == null) {
            minVal = val;
          } else if (compareDynamicValues(val, minVal) < 0) {
            minVal = val;
          }
        }
        return minVal;
      case Agg.max:
        Object? maxVal;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val == null) continue;
          if (val is num && val.isNaN) return double.nan;
          if (maxVal == null) {
            maxVal = val;
          } else if (compareDynamicValues(val, maxVal) > 0) {
            maxVal = val;
          }
        }
        return maxVal;
      case Agg.std:
        final variance = computeNumericVariance(indices.length, (i) {
          final val = col[indices[i]];
          return val is num ? val.toDouble() : null;
        }, population: false);
        return variance != null ? math.sqrt(variance) : null;
      case Agg.variance:
        return computeNumericVariance(indices.length, (i) {
          final val = col[indices[i]];
          return val is num ? val.toDouble() : null;
        }, population: false);
      case Agg.median:
        scratch.clear();
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is num) {
            scratch.add(val.toDouble());
          }
        }
        return computeQuantileInPlace(scratch, 0.5);
    }
  }
}
