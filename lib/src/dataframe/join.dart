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
  /// Hash join utilizing an in-memory hash table of keys (`O(M)` auxiliary
  /// memory).
  hash,

  /// Sort-merge join traversing ordered key streams with dual cursors
  /// (`O(M + N)` time, `O(1)` auxiliary memory when pre-sorted).
  sortMerge,
}

/// Extension providing relational join functionality on [DataFrame].
extension JoinDataFrameExtension on DataFrame {
  /// Performs a relational join between this [DataFrame] and [other].
  ///
  /// Conceptually, a join merges two tables together by matching up common
  /// identifiers (such as matching records across tables by an ID column).
  /// Mathematically, this calculates the relational equi-join based on key
  /// equality.
  ///
  /// Supports [JoinMethod.hash] (default) and [JoinMethod.sortMerge]. When
  /// [isSorted] is `true` with [JoinMethod.sortMerge], executes in `O(M + N)`
  /// time and `O(1)` auxiliary memory.
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

    if (effectiveLeftOn.isEmpty) {
      throw ArgumentError('Join key columns cannot be empty.');
    }
    if (effectiveOn != null) {
      final seen = <String>{};
      for (final col in effectiveOn) {
        if (!seen.add(col)) {
          throw ArgumentError('Duplicate join column "$col" in on.');
        }
      }
    }

    for (final col in effectiveLeftOn) {
      if (!containsColumn(col)) {
        throw ArgumentError('Join column "$col" missing in left DataFrame');
      }
    }
    for (final col in effectiveRightOn) {
      if (!other.containsColumn(col)) {
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
          } else {
            final v = rightCol[rightIdx!];
            vals.add(v == null ? null : combinedType.cast(v));
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
      final cmp = compareDynamicValues(valA, valB);
      if (cmp != 0) return cmp;
    }
    return 0;
  }

  final leftCount = left.rowCount;
  final rightCount = right.rowCount;
  final List<int>? leftOrder;
  final List<int>? rightOrder;

  if (isSorted) {
    for (var i = 1; i < leftCount; i++) {
      if (compareRows(leftCols, i - 1, leftCols, i) > 0) {
        throw ArgumentError(
          'Left DataFrame is not sorted by join keys ($leftOn) at row $i',
        );
      }
    }
    for (var i = 1; i < rightCount; i++) {
      if (compareRows(rightCols, i - 1, rightCols, i) > 0) {
        throw ArgumentError(
          'Right DataFrame is not sorted by join keys ($rightOn) at row $i',
        );
      }
    }
    leftOrder = null;
    rightOrder = null;
  } else {
    leftOrder = List<int>.generate(leftCount, (i) => i)
      ..sort((a, b) => compareRows(leftCols, a, leftCols, b));
    rightOrder = List<int>.generate(rightCount, (i) => i)
      ..sort((a, b) => compareRows(rightCols, a, rightCols, b));
  }

  int leftRowAt(int idx) => leftOrder != null ? leftOrder[idx] : idx;
  int rightRowAt(int idx) => rightOrder != null ? rightOrder[idx] : idx;

  final matchedPairs = <(int?, int?)>[];
  var p = 0;
  var q = 0;

  while (p < leftCount && q < rightCount) {
    final leftRow = leftRowAt(p);
    final rightRow = rightRowAt(q);

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
      while (pEnd < leftCount &&
          !leftExtractor.hasNullOrNan(leftRowAt(pEnd)) &&
          compareRows(leftCols, leftRow, leftCols, leftRowAt(pEnd)) == 0) {
        pEnd++;
      }

      var qEnd = q + 1;
      while (qEnd < rightCount &&
          !rightExtractor.hasNullOrNan(rightRowAt(qEnd)) &&
          compareRows(rightCols, rightRow, rightCols, rightRowAt(qEnd)) == 0) {
        qEnd++;
      }

      // Cartesian product of the duplicate runs
      for (var i = p; i < pEnd; i++) {
        final li = leftRowAt(i);
        for (var j = q; j < qEnd; j++) {
          matchedPairs.add((li, rightRowAt(j)));
        }
      }

      p = pEnd;
      q = qEnd;
    }
  }

  // Remaining left rows
  if (type == JoinType.left || type == JoinType.outer) {
    while (p < leftCount) {
      matchedPairs.add((leftRowAt(p), null));
      p++;
    }
  }

  // Remaining right rows
  if (type == JoinType.right || type == JoinType.outer) {
    while (q < rightCount) {
      matchedPairs.add((null, rightRowAt(q)));
      q++;
    }
  }

  return matchedPairs;
}
