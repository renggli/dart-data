import 'dataframe.dart';
import 'series.dart';
import 'tuple_key.dart';

/// Supported relational database join types.
enum JoinType {
  /// Inner join: retains rows with matching keys in both [DataFrame] instances.
  inner,

  /// Left outer join: retains all rows from the left [DataFrame].
  left,

  /// Right outer join: retains all rows from the right [DataFrame].
  right,

  /// Full outer join: retains all rows from both [DataFrame] instances.
  outer,
}

/// Supported relational database join methods.
enum JoinMethod {
  /// Hash join utilizing an in-memory hash table of keys ($\mathcal{O}(M)$ auxiliary memory).
  hash,

  /// Sort-merge join traversing ordered key streams with dual cursors ($\mathcal{O}(M + N)$ time, $\mathcal{O}(1)$ auxiliary memory when sorted).
  sortMerge,
}

/// Extension providing relational join functionality on [DataFrame].
extension JoinDataFrameExtension on DataFrame {
  /// Performs a relational join between this [DataFrame] and [other].
  ///
  /// Conceptually, a join merges two tables together by matching up
  /// common identifiers (such as matching records across tables by an ID column).
  /// Mathematically, this calculates the relational algebra join
  /// $R \bowtie_{p} S$ based on key equality.
  ///
  /// Supports [JoinMethod.hash] (default) and [JoinMethod.sortMerge].
  /// When [isSorted] is `true` with [JoinMethod.sortMerge], executes in
  /// $\mathcal{O}(M + N)$ time and $\mathcal{O}(1)$ auxiliary memory.
  ///
  /// ```dart
  /// final left = DataFrame.fromColumns({
  ///   'id': [1, 2],
  ///   'name': ['Alice', 'Bob'],
  /// });
  /// final right = DataFrame.fromColumns({
  ///   'id': [1, 2],
  ///   'age': [20, 25],
  /// });
  /// final merged = left.join(right, on: ['id']);
  /// ```
  DataFrame join(
    DataFrame other, {
    required List<String> on,
    JoinType type = JoinType.inner,
    JoinMethod method = JoinMethod.hash,
    String suffix = '_other',
    bool isSorted = false,
  }) {
    for (final col in on) {
      if (!columnNames.contains(col)) {
        throw ArgumentError('Join column "$col" missing in left DataFrame');
      }
      if (!other.columnNames.contains(col)) {
        throw ArgumentError('Join column "$col" missing in right DataFrame');
      }
    }

    final matchedPairs = switch (method) {
      JoinMethod.hash => _hashJoinPairs(this, other, on, type),
      JoinMethod.sortMerge => _sortMergeJoinPairs(
        this,
        other,
        on,
        type,
        isSorted,
      ),
    };

    // Build output columns
    final resultCols = <String, List<dynamic>>{};
    final onSet = on.toSet();

    // Key columns
    for (final keyCol in on) {
      final leftCol = column(keyCol);
      final rightCol = other.column(keyCol);
      final vals = <dynamic>[];
      for (final (leftIdx, rightIdx) in matchedPairs) {
        if (leftIdx != null) {
          vals.add(leftCol[leftIdx]);
        } else if (rightIdx != null) {
          vals.add(rightCol[rightIdx]);
        } else {
          vals.add(null); // coverage:ignore-line
        }
      }
      resultCols[keyCol] = vals;
    }

    // Non-key columns from left
    for (final col in columnNames) {
      if (onSet.contains(col)) continue;
      final leftCol = column(col);
      resultCols[col] = [
        for (final (leftIdx, _) in matchedPairs)
          if (leftIdx != null) leftCol[leftIdx] else null,
      ];
    }

    // Non-key columns from right
    for (final col in other.columnNames) {
      if (onSet.contains(col)) continue;
      final outName = resultCols.containsKey(col) ? '$col$suffix' : col;
      final rightCol = other.column(col);
      resultCols[outName] = [
        for (final (_, rightIdx) in matchedPairs)
          if (rightIdx != null) rightCol[rightIdx] else null,
      ];
    }

    return DataFrame.fromColumns(resultCols);
  }

  /// Performs a sort-merge relational join between this [DataFrame] and [other].
  ///
  /// Convenience canonical method equivalent to calling [join] with
  /// `method: JoinMethod.sortMerge`. If [isSorted] is `true`, both DataFrames
  /// must already be sorted in ascending order by the join key columns in [on],
  /// running in $\mathcal{O}(M + N)$ time and $\mathcal{O}(1)$ auxiliary memory.
  DataFrame sortMergeJoin(
    DataFrame other, {
    required List<String> on,
    JoinType type = JoinType.inner,
    String suffix = '_other',
    bool isSorted = false,
  }) => join(
    other,
    on: on,
    type: type,
    method: JoinMethod.sortMerge,
    suffix: suffix,
    isSorted: isSorted,
  );
}

List<(int?, int?)> _hashJoinPairs(
  DataFrame left,
  DataFrame right,
  List<String> on,
  JoinType type,
) {
  // Build hash index on right DataFrame
  final rightExtractor = RowKeyExtractor(on.map(right.column).toList());
  final rightIndex = <Object?, List<int>>{};
  for (var rightRow = 0; rightRow < right.rowCount; rightRow++) {
    final key = rightExtractor.extractKeyOrNull(rightRow);
    if (key == null) continue;
    rightIndex.putIfAbsent(key, () => []).add(rightRow);
  }

  final matchedPairs = <(int?, int?)>[];
  final matchedRightIndices = <int>{};

  // Scan left DataFrame
  final leftExtractor = RowKeyExtractor(on.map(left.column).toList());
  for (var leftRow = 0; leftRow < left.rowCount; leftRow++) {
    final key = leftExtractor.extractKeyOrNull(leftRow);
    if (key == null) {
      if (type == JoinType.left || type == JoinType.outer) {
        matchedPairs.add((leftRow, null));
      }
      continue;
    }
    final matchingRight = rightIndex[key];

    if (matchingRight != null && matchingRight.isNotEmpty) {
      for (final rightRow in matchingRight) {
        matchedPairs.add((leftRow, rightRow));
        matchedRightIndices.add(rightRow);
      }
    } else {
      if (type == JoinType.left || type == JoinType.outer) {
        matchedPairs.add((leftRow, null));
      }
    }
  }

  // Include unmatched right rows for right/outer joins
  if (type == JoinType.right || type == JoinType.outer) {
    for (var rightRow = 0; rightRow < right.rowCount; rightRow++) {
      if (!matchedRightIndices.contains(rightRow)) {
        matchedPairs.add((null, rightRow));
      }
    }
  }

  return matchedPairs;
}

List<(int?, int?)> _sortMergeJoinPairs(
  DataFrame left,
  DataFrame right,
  List<String> on,
  JoinType type,
  bool isSorted,
) {
  final leftCols = [for (final c in on) left.column(c)];
  final rightCols = [for (final c in on) right.column(c)];

  bool hasNullInKey(List<Series<dynamic>> cols, int row) {
    for (var i = 0; i < cols.length; i++) {
      if (cols[i].isNull(row)) return true;
    }
    return false;
  }

  int compareRows(
    List<Series<dynamic>> colsA,
    int rowA,
    List<Series<dynamic>> colsB,
    int rowB,
  ) {
    for (var i = 0; i < colsA.length; i++) {
      final valA = colsA[i][rowA];
      final valB = colsB[i][rowB];
      if (valA == null && valB == null) continue;
      if (valA == null) return 1;
      if (valB == null) return -1;
      if (valA is num && valB is num) {
        final diff = valA.compareTo(valB);
        if (diff != 0) return diff;
      } else if (valA is Comparable && valB is Comparable) {
        final diff = valA.compareTo(valB);
        if (diff != 0) return diff;
      } else {
        final diff = valA.toString().compareTo(valB.toString());
        if (diff != 0) return diff;
      }
    }
    return 0;
  }

  List<int> leftOrder;
  List<int> rightOrder;

  if (isSorted) {
    for (var i = 1; i < left.rowCount; i++) {
      if (compareRows(leftCols, i - 1, leftCols, i) > 0) {
        throw ArgumentError(
          'Left DataFrame is not sorted by join keys ($on) at row $i',
        );
      }
    }
    for (var i = 1; i < right.rowCount; i++) {
      if (compareRows(rightCols, i - 1, rightCols, i) > 0) {
        throw ArgumentError(
          'Right DataFrame is not sorted by join keys ($on) at row $i',
        );
      }
    }
    leftOrder = List<int>.generate(left.rowCount, (i) => i);
    rightOrder = List<int>.generate(right.rowCount, (i) => i);
  } else {
    leftOrder = List<int>.generate(left.rowCount, (i) => i)
      ..sort((a, b) => compareRows(leftCols, a, leftCols, b));
    rightOrder = List<int>.generate(right.rowCount, (i) => i)
      ..sort((a, b) => compareRows(rightCols, a, rightCols, b));
  }

  final matchedPairs = <(int?, int?)>[];
  var p = 0;
  var q = 0;

  while (p < leftOrder.length && q < rightOrder.length) {
    final leftRow = leftOrder[p];
    final rightRow = rightOrder[q];

    if (hasNullInKey(leftCols, leftRow)) {
      if (type == JoinType.left || type == JoinType.outer) {
        matchedPairs.add((leftRow, null));
      }
      p++;
      continue;
    }

    if (hasNullInKey(rightCols, rightRow)) {
      if (type == JoinType.right || type == JoinType.outer) {
        matchedPairs.add((null, rightRow));
      }
      q++;
      continue;
    }

    final cmp = compareRows(leftCols, leftRow, rightCols, rightRow);
    if (cmp < 0) {
      if (type == JoinType.left || type == JoinType.outer) {
        matchedPairs.add((leftRow, null));
      }
      p++;
    } else if (cmp > 0) {
      if (type == JoinType.right || type == JoinType.outer) {
        matchedPairs.add((null, rightRow));
      }
      q++;
    } else {
      // Find runs of duplicate keys
      var pEnd = p + 1;
      while (pEnd < leftOrder.length &&
          !hasNullInKey(leftCols, leftOrder[pEnd]) &&
          compareRows(leftCols, leftOrder[p], leftCols, leftOrder[pEnd]) == 0) {
        pEnd++;
      }

      var qEnd = q + 1;
      while (qEnd < rightOrder.length &&
          !hasNullInKey(rightCols, rightOrder[qEnd]) &&
          compareRows(rightCols, rightOrder[q], rightCols, rightOrder[qEnd]) ==
              0) {
        qEnd++;
      }

      // Cartesian product of the duplicate runs
      for (var i = p; i < pEnd; i++) {
        for (var j = q; j < qEnd; j++) {
          matchedPairs.add((leftOrder[i], rightOrder[j]));
        }
      }

      p = pEnd;
      q = qEnd;
    }
  }

  // Remaining left rows
  if (type == JoinType.left || type == JoinType.outer) {
    while (p < leftOrder.length) {
      matchedPairs.add((leftOrder[p], null));
      p++;
    }
  }

  // Remaining right rows
  if (type == JoinType.right || type == JoinType.outer) {
    while (q < rightOrder.length) {
      matchedPairs.add((null, rightOrder[q]));
      q++;
    }
  }

  return matchedPairs;
}
