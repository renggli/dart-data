import 'dataframe.dart';
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

/// Extension providing relational join functionality on [DataFrame].
extension JoinDataFrameExtension on DataFrame {
  /// Performs a relational hash join between this [DataFrame] and [other].
  ///
  /// Conceptually, a join merges two tables together by matching up
  /// common identifiers (such as matching records across tables by an ID column).
  /// Mathematically, this calculates the relational algebra join
  /// $R \bowtie_{p} S$ based on key equality.
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
    String suffix = '_other',
  }) {
    for (final col in on) {
      if (!columnNames.contains(col)) {
        throw ArgumentError('Join column "$col" missing in left DataFrame');
      }
      if (!other.columnNames.contains(col)) {
        throw ArgumentError('Join column "$col" missing in right DataFrame');
      }
    }

    // Build hash index on right DataFrame
    final rightExtractor = RowKeyExtractor(on.map(other.column).toList());
    final rightIndex = <Object?, List<int>>{};
    for (var rightRow = 0; rightRow < other.rowCount; rightRow++) {
      final key = rightExtractor.extractKeyOrNull(rightRow);
      if (key == null) continue;
      rightIndex.putIfAbsent(key, () => []).add(rightRow);
    }

    final matchedPairs = <(int?, int?)>[];
    final matchedRightIndices = <int>{};

    // Scan left DataFrame
    final leftExtractor = RowKeyExtractor(on.map(column).toList());
    for (var leftRow = 0; leftRow < rowCount; leftRow++) {
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
      for (var rightRow = 0; rightRow < other.rowCount; rightRow++) {
        if (!matchedRightIndices.contains(rightRow)) {
          matchedPairs.add((null, rightRow));
        }
      }
    }

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
}
