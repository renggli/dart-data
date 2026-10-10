import 'dart:math' as math;

import 'dataframe.dart';
import 'series.dart';

/// Aggregation operations supported in GroupBy.
enum Agg { count, sum, mean, min, max, std, first, last }

/// Grouped DataFrame supporting hash-partitioned aggregations.
class GroupBy {
  new(this.dataFrame, this.byColumns) {
    if (byColumns.isEmpty) {
      throw ArgumentError('byColumns cannot be empty');
    }
    _buildGroups();
  }

  final DataFrame dataFrame;
  final List<String> byColumns;

  // Group key string -> list of row indices
  final Map<String, List<int>> _groups = {};
  // Group key string -> original key values
  final Map<String, List<dynamic>> _groupKeys = {};

  /// Evaluates aggregations across each group and produces a new DataFrame.
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

    // Process each group
    for (final entry in _groups.entries) {
      final keyStr = entry.key;
      final indices = entry.value;
      final keyVals = _groupKeys[keyStr]!;

      // Append group key values
      for (var i = 0; i < byColumns.length; i++) {
        resultCols[byColumns[i]]!.add(keyVals[i]);
      }

      // Compute aggregations
      for (final aggEntry in aggregations.entries) {
        final colName = aggEntry.key;
        final col = dataFrame.column(colName);
        final groupVals = [for (final idx in indices) col[idx]];

        for (final agg in aggEntry.value) {
          final outName = '${colName}_${agg.name}';
          final aggResult = _computeAgg(groupVals, agg);
          resultCols[outName]!.add(aggResult);
        }
      }
    }

    return DataFrame.fromColumns(resultCols);
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
    for (var rowIdx = 0; rowIdx < dataFrame.rowCount; rowIdx++) {
      final keyVals = [for (final col in keyCols) col[rowIdx]];
      final keyStr = keyVals.map((val) => '$val').join('__#_#__');
      if (!_groups.containsKey(keyStr)) {
        _groups[keyStr] = [];
        _groupKeys[keyStr] = keyVals;
      }
      _groups[keyStr]!.add(rowIdx);
    }
  }

  dynamic _computeAgg(List<dynamic> values, Agg agg) {
    final nonNulls = values.where((val) => val != null).toList();
    switch (agg) {
      case Agg.count:
        return nonNulls.length;
      case Agg.first:
        return nonNulls.isNotEmpty ? nonNulls.first : null;
      case Agg.last:
        return nonNulls.isNotEmpty ? nonNulls.last : null;
      case Agg.sum:
        num total = 0;
        for (final val in nonNulls) {
          if (val is num) total += val;
        }
        return total;
      case Agg.mean:
        if (nonNulls.isEmpty) return null;
        num total = 0;
        var count = 0;
        for (final val in nonNulls) {
          if (val is num) {
            total += val;
            count++;
          }
        }
        return count > 0 ? total.toDouble() / count : null;
      case Agg.min:
        if (nonNulls.isEmpty) return null;
        var minVal = nonNulls.first as Comparable;
        for (final val in nonNulls.skip(1)) {
          if ((val as Comparable).compareTo(minVal) < 0) minVal = val;
        }
        return minVal;
      case Agg.max:
        if (nonNulls.isEmpty) return null;
        var maxVal = nonNulls.first as Comparable;
        for (final val in nonNulls.skip(1)) {
          if ((val as Comparable).compareTo(maxVal) > 0) maxVal = val;
        }
        return maxVal;
      case Agg.std:
        if (nonNulls.length <= 1) return 0.0;
        final nums = nonNulls
            .whereType<num>()
            .map((element) => element.toDouble())
            .toList();
        if (nums.length <= 1) return 0.0;
        final mean = nums.reduce((a, b) => a + b) / nums.length;
        final sumSq = nums
            .map((x) => (x - mean) * (x - mean))
            .reduce((a, b) => a + b);
        return math.sqrt(sumSq / (nums.length - 1));
    }
  }
}
