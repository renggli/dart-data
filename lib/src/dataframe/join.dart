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
  /// Hash join utilizing an in-memory hash table of keys ($\mathcal{O}(M)$
  /// auxiliary memory).
  hash,

  /// Sort-merge join traversing ordered key streams with dual cursors
  /// ($\mathcal{O}(M + N)$ time, $\mathcal{O}(1)$ auxiliary memory when
  /// sorted).
  sortMerge,
}

/// Extension providing relational join functionality on [DataFrame].
extension JoinDataFrameExtension on DataFrame {
  /// Performs a relational join between this [DataFrame] and [other].
  ///
  /// Conceptually, a join merges two tables together by matching up common
  /// identifiers (such as matching records across tables by an ID column).
  /// Mathematically, this calculates the relational algebra join
  /// $R \bowtie_{p} S$ based on key equality.
  ///
  /// Supports [JoinMethod.hash] (default) and [JoinMethod.sortMerge]. When
  /// [isSorted] is `true` with [JoinMethod.sortMerge], executes in
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
    List<String>? on,
    List<String>? leftOn,
    List<String>? rightOn,
    JoinType type = JoinType.inner,
    JoinMethod method = JoinMethod.hash,
    String suffix = '_other',
    bool isSorted = false,
  }) {
    final List<String> effectiveLeftOn;
    final List<String> effectiveRightOn;
    final List<String>? effectiveOn;
    if (on != null) {
      effectiveLeftOn = on;
      effectiveRightOn = on;
      effectiveOn = on;
    } else if (leftOn != null && rightOn != null) {
      if (leftOn.length != rightOn.length) {
        throw ArgumentError(
          'leftOn length (${leftOn.length}) must match rightOn length (${rightOn.length}).',
        );
      }
      effectiveLeftOn = leftOn;
      effectiveRightOn = rightOn;
      var areKeysIdentical = true;
      for (var i = 0; i < leftOn.length; i++) {
        if (leftOn[i] != rightOn[i]) {
          areKeysIdentical = false;
          break;
        }
      }
      effectiveOn = areKeysIdentical ? leftOn : null;
    } else {
      throw ArgumentError(
        'Must specify either "on" or both "leftOn" and "rightOn".',
      );
    }

    for (final col in effectiveLeftOn) {
      if (!columnNames.contains(col)) {
        throw ArgumentError('Join column "$col" missing in left DataFrame');
      }
    }
    for (final col in effectiveRightOn) {
      if (!other.columnNames.contains(col)) {
        throw ArgumentError('Join column "$col" missing in right DataFrame');
      }
    }

    final matchedPairs = switch (method) {
      JoinMethod.hash => _hashJoinPairs(
        this,
        other,
        effectiveLeftOn,
        effectiveRightOn,
        type,
      ),
      JoinMethod.sortMerge => _sortMergeJoinPairs(
        this,
        other,
        effectiveLeftOn,
        effectiveRightOn,
        type,
        isSorted,
      ),
    };

    // Build output columns preserving column DataType
    final outputColumns = <Series<Object?>>[];
    final usedNames = <String>{};
    final onSet = effectiveOn != null ? effectiveOn.toSet() : const <String>{};

    String disambiguate(String baseName) {
      if (!usedNames.contains(baseName)) return baseName;
      final effectiveSuffix = suffix.isNotEmpty ? suffix : '_other';
      var candidate = '$baseName$effectiveSuffix';
      var counter = 2;
      while (usedNames.contains(candidate)) {
        candidate = '$baseName$effectiveSuffix$counter';
        counter++;
      }
      return candidate;
    }

    if (effectiveOn != null) {
      // Key columns
      for (final keyCol in effectiveOn) {
        final leftCol = column(keyCol);
        final rightCol = other.column(keyCol);
        final combinedType = leftCol.dataType == rightCol.dataType
            ? leftCol.dataType
            : leftCol.dataType.promoteWith(rightCol.dataType);
        final vals = <Object?>[];
        for (final (leftIdx, rightIdx) in matchedPairs) {
          if (leftIdx != null) {
            final v = leftCol[leftIdx];
            vals.add(v == null ? null : combinedType.cast(v));
          } else if (rightIdx != null) {
            final v = rightCol[rightIdx];
            vals.add(v == null ? null : combinedType.cast(v));
          } else {
            vals.add(null);
          }
        }
        final outName = disambiguate(keyCol);
        usedNames.add(outName);
        outputColumns.add(Series.fromList(outName, vals, type: combinedType));
      }
    }

    // Non-key columns from left (or all left columns if on == null)
    for (final col in columnNames) {
      if (onSet.contains(col)) continue;
      final leftCol = column(col);
      final vals = <Object?>[
        for (final (leftIdx, _) in matchedPairs)
          if (leftIdx != null) leftCol[leftIdx] else null,
      ];
      final outName = disambiguate(col);
      usedNames.add(outName);
      outputColumns.add(Series.fromList(outName, vals, type: leftCol.dataType));
    }

    // Non-key columns from right (or all right columns if on == null)
    for (final col in other.columnNames) {
      if (onSet.contains(col)) continue;
      final outName = disambiguate(col);
      final rightCol = other.column(col);
      final vals = <Object?>[
        for (final (_, rightIdx) in matchedPairs)
          if (rightIdx != null) rightCol[rightIdx] else null,
      ];
      usedNames.add(outName);
      outputColumns.add(
        Series.fromList(outName, vals, type: rightCol.dataType),
      );
    }

    return DataFrame(outputColumns);
  }
}

List<(int?, int?)> _hashJoinPairs(
  DataFrame left,
  DataFrame right,
  List<String> leftOn,
  List<String> rightOn,
  JoinType type,
) {
  // Build hash index on right DataFrame
  final rightExtractor = RowKeyExtractor(rightOn.map(right.column).toList());
  final rightIndex = <Object?, List<int>>{};
  for (var rightRow = 0; rightRow < right.rowCount; rightRow++) {
    final key = rightExtractor.extractJoinKeyOrNull(rightRow);
    if (key == null) continue;
    rightIndex.putIfAbsent(key, () => []).add(rightRow);
  }

  final matchedPairs = <(int?, int?)>[];
  final matchedRightIndices = <int>{};

  // Scan left DataFrame
  final leftExtractor = RowKeyExtractor(leftOn.map(left.column).toList());
  for (var leftRow = 0; leftRow < left.rowCount; leftRow++) {
    final key = leftExtractor.extractJoinKeyOrNull(leftRow);
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
  List<String> leftOn,
  List<String> rightOn,
  JoinType type,
  bool isSorted,
) {
  final leftCols = [for (final c in leftOn) left.column(c)];
  final rightCols = [for (final c in rightOn) right.column(c)];
  final leftExtractor = RowKeyExtractor(leftCols);
  final rightExtractor = RowKeyExtractor(rightCols);

  int compareRows(
    List<Series<Object?>> colsA,
    int rowA,
    List<Series<Object?>> colsB,
    int rowB,
  ) {
    for (var i = 0; i < colsA.length; i++) {
      final valA = colsA[i][rowA];
      final valB = colsB[i][rowB];
      if (valA == null && valB == null) continue;
      if (valA == null) return 1;
      if (valB == null) return -1;
      final isNanA = valA is num && valA.isNaN;
      final isNanB = valB is num && valB.isNaN;
      if (isNanA && isNanB) continue;
      if (isNanA) return 1;
      if (isNanB) return -1;
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
          'Left DataFrame is not sorted by join keys ($leftOn) at row $i',
        );
      }
    }
    for (var i = 1; i < right.rowCount; i++) {
      if (compareRows(rightCols, i - 1, rightCols, i) > 0) {
        throw ArgumentError(
          'Right DataFrame is not sorted by join keys ($rightOn) at row $i',
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

    if (leftExtractor.hasNullOrNan(leftRow)) {
      if (type == JoinType.left || type == JoinType.outer) {
        matchedPairs.add((leftRow, null));
      }
      p++;
      continue;
    }

    if (rightExtractor.hasNullOrNan(rightRow)) {
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
          !leftExtractor.hasNullOrNan(leftOrder[pEnd]) &&
          compareRows(leftCols, leftOrder[p], leftCols, leftOrder[pEnd]) == 0) {
        pEnd++;
      }

      var qEnd = q + 1;
      while (qEnd < rightOrder.length &&
          !rightExtractor.hasNullOrNan(rightOrder[qEnd]) &&
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
