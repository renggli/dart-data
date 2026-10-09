import 'dataframe.dart';

/// Supported relational database join types.
enum JoinType { inner, left, right, outer }

/// Extension providing relational join functionality on [DataFrame].
extension JoinDataFrameExtension on DataFrame {
  /// Performs a relational hash join between this DataFrame and [other].
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
    final rightKeyCols = on.map(other.column).toList();
    final rightIndex = <String, List<int>>{};
    for (var r = 0; r < other.rowCount; r++) {
      final keyVals = [for (final c in rightKeyCols) c[r]];
      if (keyVals.any((v) => v == null)) continue;
      final key = keyVals.map((v) => '$v').join('__#_#__');
      rightIndex.putIfAbsent(key, () => []).add(r);
    }

    final matchedPairs = <(int?, int?)>[];
    final matchedRightIndices = <int>{};

    // Scan left DataFrame
    final leftKeyCols = on.map(column).toList();
    for (var l = 0; l < rowCount; l++) {
      final keyVals = [for (final c in leftKeyCols) c[l]];
      if (keyVals.any((v) => v == null)) {
        if (type == JoinType.left || type == JoinType.outer) {
          matchedPairs.add((l, null));
        }
        continue;
      }
      final key = keyVals.map((v) => '$v').join('__#_#__');
      final matchingRight = rightIndex[key];

      if (matchingRight != null && matchingRight.isNotEmpty) {
        for (final r in matchingRight) {
          matchedPairs.add((l, r));
          matchedRightIndices.add(r);
        }
      } else {
        if (type == JoinType.left || type == JoinType.outer) {
          matchedPairs.add((l, null));
        }
      }
    }

    // Include unmatched right rows for right/outer joins
    if (type == JoinType.right || type == JoinType.outer) {
      for (var r = 0; r < other.rowCount; r++) {
        if (!matchedRightIndices.contains(r)) {
          matchedPairs.add((null, r));
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
      for (final (l, r) in matchedPairs) {
        if (l != null) {
          vals.add(leftCol[l]);
        } else if (r != null) {
          vals.add(rightCol[r]);
        } else {
          vals.add(null);
        }
      }
      resultCols[keyCol] = vals;
    }

    // Non-key columns from left
    for (final col in columnNames) {
      if (onSet.contains(col)) continue;
      final leftCol = column(col);
      resultCols[col] = [
        for (final (l, _) in matchedPairs)
          if (l != null) leftCol[l] else null,
      ];
    }

    // Non-key columns from right
    for (final col in other.columnNames) {
      if (onSet.contains(col)) continue;
      final outName = resultCols.containsKey(col) ? '$col$suffix' : col;
      final rightCol = other.column(col);
      resultCols[outName] = [
        for (final (_, r) in matchedPairs)
          if (r != null) rightCol[r] else null,
      ];
    }

    return DataFrame.fromColumns(resultCols);
  }
}
