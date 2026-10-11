import 'dart:math' as math;

import 'dataframe.dart';
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
  var_,

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
/// this induces a quotient partition $R / \sim$ over the relation based on
/// equivalence under the projection $\pi_{\text{byColumns}}(r)$.
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
  new(this.dataFrame, this.byColumns) {
    if (byColumns.isEmpty) {
      throw ArgumentError('byColumns cannot be empty');
    }
    _buildGroups();
  }

  /// The source [DataFrame] being partitioned.
  final DataFrame dataFrame;

  /// The column names whose values define group partitions.
  final List<String> byColumns;

  // Group key -> list of row indices
  final Map<Object?, List<int>> _groups = {};
  // Group key -> original key values
  final Map<Object?, List<dynamic>> _groupKeys = {};

  /// Evaluates aggregations across each group and produces a new [DataFrame].
  DataFrame aggregate(Map<String, List<Agg>> aggregations) {
    final resultCols = <String, List<dynamic>>{};
    // Initialize group key columns
    for (final col in byColumns) {
      resultCols[col] = [];
    }

    // Initialize aggregation output columns
    for (final entry in aggregations.entries) {
      final colName = entry.key;
      for (final agg in entry.value) {
        final outName = '${colName}_${agg.name}';
        resultCols[outName] = [];
      }
    }

    final medianScratch = <double>[];

    // Process each group
    for (final entry in _groups.entries) {
      final key = entry.key;
      final indices = entry.value;
      final keyVals = _groupKeys[key]!;

      // Append group key values
      for (var i = 0; i < byColumns.length; i++) {
        resultCols[byColumns[i]]!.add(keyVals[i]);
      }

      // Compute aggregations
      for (final aggEntry in aggregations.entries) {
        final colName = aggEntry.key;
        final col = dataFrame.column(colName);

        for (final agg in aggEntry.value) {
          final outName = '${colName}_${agg.name}';
          final aggResult = _computeAgg(col, indices, agg, medianScratch);
          resultCols[outName]!.add(aggResult);
        }
      }
    }

    for (final entry in resultCols.entries) {
      if (byColumns.contains(entry.key)) continue;
      final list = entry.value;
      if (list.any((v) => v is double)) {
        resultCols[entry.key] = [
          for (final v in list)
            if (v is num) v.toDouble() else v,
        ];
      }
    }

    final outputSeries = <Series<dynamic>>[];
    for (final col in byColumns) {
      final origCol = dataFrame.column(col);
      outputSeries.add(
        Series.fromList(col, resultCols[col]!, type: origCol.dataType),
      );
    }
    for (final entry in resultCols.entries) {
      if (byColumns.contains(entry.key)) continue;
      outputSeries.add(Series.fromList(entry.key, entry.value));
    }

    return DataFrame(outputSeries);
  }

  /// Computes mean of all numeric columns per group.
  DataFrame mean() {
    final numCols = dataFrame.columnNames
        .where(
          (col) =>
              !byColumns.contains(col) && dataFrame.column(col) is TypedSeries,
        )
        .toList();
    return aggregate({
      for (final col in numCols) col: [Agg.mean],
    });
  }

  /// Computes sum of all numeric columns per group.
  DataFrame sum() {
    final numCols = dataFrame.columnNames
        .where(
          (col) =>
              !byColumns.contains(col) && dataFrame.column(col) is TypedSeries,
        )
        .toList();
    return aggregate({
      for (final col in numCols) col: [Agg.sum],
    });
  }

  /// Computes count of entries per group.
  DataFrame count() {
    final targetCols = dataFrame.columnNames
        .where((col) => !byColumns.contains(col))
        .take(1)
        .toList();
    final col = targetCols.isNotEmpty ? targetCols.first : byColumns.first;
    return aggregate({
      col: [Agg.count],
    });
  }

  void _buildGroups() {
    final keyCols = byColumns.map(dataFrame.column).toList();
    final extractor = RowKeyExtractor(keyCols);
    for (var rowIdx = 0; rowIdx < dataFrame.rowCount; rowIdx++) {
      final key = extractor.extractKey(rowIdx);
      if (!_groups.containsKey(key)) {
        _groups[key] = [];
        _groupKeys[key] = [for (final col in keyCols) col[rowIdx]];
      }
      _groups[key]!.add(rowIdx);
    }
  }

  dynamic _computeAgg(
    Series<dynamic> col,
    List<int> indices,
    Agg agg,
    List<double> scratch,
  ) {
    switch (agg) {
      case Agg.count:
        var count = 0;
        for (var i = 0; i < indices.length; i++) {
          if (col[indices[i]] != null) count++;
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
        num total = 0;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is num) total += val;
        }
        return total;
      case Agg.mean:
        num total = 0;
        var count = 0;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is num) {
            total += val;
            count++;
          }
        }
        return count > 0 ? total.toDouble() / count : null;
      case Agg.min:
        Comparable<Object?>? minVal;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is Comparable<Object?>) {
            if (minVal == null || val.compareTo(minVal) < 0) {
              minVal = val;
            }
          }
        }
        return minVal;
      case Agg.max:
        Comparable<Object?>? maxVal;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is Comparable<Object?>) {
            if (maxVal == null || val.compareTo(maxVal) > 0) {
              maxVal = val;
            }
          }
        }
        return maxVal;
      case Agg.std:
        var count = 0;
        var mean = 0.0;
        var m2 = 0.0;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is num) {
            count++;
            final delta = val - mean;
            mean += delta / count;
            final delta2 = val - mean;
            m2 += delta * delta2;
          }
        }
        if (count <= 1) return 0.0;
        final variance = m2 / (count - 1);
        return math.sqrt(variance < 0.0 ? 0.0 : variance);
      case Agg.var_:
        var count = 0;
        var mean = 0.0;
        var m2 = 0.0;
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is num) {
            count++;
            final delta = val - mean;
            mean += delta / count;
            final delta2 = val - mean;
            m2 += delta * delta2;
          }
        }
        if (count < 2) return null;
        final variance = m2 / (count - 1);
        return variance < 0.0 ? 0.0 : variance;
      case Agg.median:
        scratch.clear();
        for (var i = 0; i < indices.length; i++) {
          final val = col[indices[i]];
          if (val is num) {
            scratch.add(val.toDouble());
          }
        }
        final n = scratch.length;
        if (n == 0) return null;
        for (var i = 0; i < n; i++) {
          if (scratch[i].isNaN) return double.nan;
        }
        final mid1 = (n - 1) ~/ 2;
        final mid2 = n ~/ 2;
        _quickselect(scratch, mid1);
        if (mid1 != mid2) {
          _quickselect(scratch, mid2, mid1 + 1, n - 1);
        }
        return (scratch[mid1] + scratch[mid2]) / 2.0;
    }
  }
}

void _quickselect(List<double> list, int k, [int left = 0, int? right]) {
  var l = left;
  var r = right ?? list.length - 1;
  while (l < r) {
    final mid = l + (r - l) ~/ 2;
    if (list[l] > list[mid]) _swap(list, l, mid);
    if (list[l] > list[r]) _swap(list, l, r);
    if (list[mid] > list[r]) _swap(list, mid, r);
    final pivot = list[mid];

    var i = l;
    var lt = l;
    var gt = r;
    while (i <= gt) {
      if (list[i] < pivot) {
        _swap(list, lt, i);
        lt++;
        i++;
      } else if (list[i] > pivot) {
        _swap(list, i, gt);
        gt--;
      } else {
        i++;
      }
    }

    if (k < lt) {
      r = lt - 1;
    } else if (k > gt) {
      l = gt + 1;
    } else {
      return;
    }
  }
}

void _swap(List<double> list, int i, int j) {
  final temp = list[i];
  list[i] = list[j];
  list[j] = temp;
}
