import 'dart:math' as math;

import 'dataframe.dart';
import 'series.dart';
import 'tuple_key.dart';

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

  // Group key -> list of row indices
  final Map<Object?, List<int>> _groups = {};
  // Group key -> original key values
  final Map<Object?, List<dynamic>> _groupKeys = {};

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
        final groupVals = [for (final idx in indices) col[idx]];

        for (final agg in aggEntry.value) {
          final outName = '${colName}_${agg.name}';
          final aggResult = _computeAgg(groupVals, agg);
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
