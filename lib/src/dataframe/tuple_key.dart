import 'package:collection/collection.dart';

import 'series.dart';

/// A composite key representing a sequence of column values.
///
/// Uses deep collection equality and cached hash code for efficient hash map
/// lookups when joining or grouping across more than three columns.
final class TupleKey {
  /// Creates a [TupleKey] wrapping [values].
  new(this.values) : _hashCode = const DeepCollectionEquality().hash(values);

  /// The values comprising this composite key.
  final List<Object?> values;
  final int _hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TupleKey &&
          _hashCode == other._hashCode &&
          const DeepCollectionEquality().equals(values, other.values));

  @override
  int get hashCode => _hashCode;

  @override
  String toString() => 'TupleKey($values)';
}

/// Extracts a composite key from a list of [values].
///
/// Returns:
/// - The direct value if [values] has length 1.
/// - A 2-record `(values[0], values[1])` if [values] has length 2.
/// - A 3-record `(values[0], values[1], values[2])` if [values] has length 3.
/// - A [TupleKey] wrapping [values] otherwise.
Object? extractKey(List<Object?> values) => switch (values.length) {
  1 => values[0],
  2 => (values[0], values[1]),
  3 => (values[0], values[1], values[2]),
  _ => TupleKey(values),
};

/// Optimized extractor for row keys across columnar series.
///
/// Provides specialized zero-allocation record-based key extraction for 1, 2,
/// and 3 columns, falling back to [TupleKey] for 4 or more columns.
abstract interface class RowKeyExtractor {
  /// Creates an optimized key extractor for the given [columns].
  factory(List<Series<dynamic>> columns) => switch (columns.length) {
    1 => _SingleKeyExtractor(columns[0]),
    2 => _PairKeyExtractor(columns[0], columns[1]),
    3 => _TripleKeyExtractor(columns[0], columns[1], columns[2]),
    _ => _MultiKeyExtractor(List.of(columns)),
  };

  /// Extracts the composite key for the row at [rowIndex].
  Object? extractKey(int rowIndex);

  /// Extracts the composite key for the row at [rowIndex], or returns `null`
  /// if any key column at [rowIndex] is null.
  Object? extractKeyOrNull(int rowIndex);

  /// Returns `true` if any key column at [rowIndex] is null.
  bool hasNull(int rowIndex);
}

final class _SingleKeyExtractor implements RowKeyExtractor {
  const new(this._col);

  final Series<dynamic> _col;

  @override
  Object? extractKey(int rowIndex) => _col[rowIndex];

  @override
  Object? extractKeyOrNull(int rowIndex) => _col[rowIndex];

  @override
  bool hasNull(int rowIndex) => _col[rowIndex] == null;
}

final class _PairKeyExtractor implements RowKeyExtractor {
  const new(this._col0, this._col1);

  final Series<dynamic> _col0;
  final Series<dynamic> _col1;

  @override
  Object? extractKey(int rowIndex) => (_col0[rowIndex], _col1[rowIndex]);

  @override
  Object? extractKeyOrNull(int rowIndex) {
    final v0 = _col0[rowIndex];
    if (v0 == null) return null;
    final v1 = _col1[rowIndex];
    if (v1 == null) return null;
    return (v0, v1);
  }

  @override
  bool hasNull(int rowIndex) =>
      _col0[rowIndex] == null || _col1[rowIndex] == null;
}

final class _TripleKeyExtractor implements RowKeyExtractor {
  const new(this._col0, this._col1, this._col2);

  final Series<dynamic> _col0;
  final Series<dynamic> _col1;
  final Series<dynamic> _col2;

  @override
  Object? extractKey(int rowIndex) =>
      (_col0[rowIndex], _col1[rowIndex], _col2[rowIndex]);

  @override
  Object? extractKeyOrNull(int rowIndex) {
    final v0 = _col0[rowIndex];
    if (v0 == null) return null;
    final v1 = _col1[rowIndex];
    if (v1 == null) return null;
    final v2 = _col2[rowIndex];
    if (v2 == null) return null;
    return (v0, v1, v2);
  }

  @override
  bool hasNull(int rowIndex) =>
      _col0[rowIndex] == null ||
      _col1[rowIndex] == null ||
      _col2[rowIndex] == null;
}

final class _MultiKeyExtractor implements RowKeyExtractor {
  const new(this._columns);

  final List<Series<dynamic>> _columns;

  @override
  Object? extractKey(int rowIndex) =>
      TupleKey([for (final col in _columns) col[rowIndex]]);

  @override
  Object? extractKeyOrNull(int rowIndex) {
    final values = List<Object?>.filled(_columns.length, null);
    for (var i = 0; i < _columns.length; i++) {
      final val = _columns[i][rowIndex];
      if (val == null) return null;
      values[i] = val;
    }
    return TupleKey(values);
  }

  @override
  bool hasNull(int rowIndex) {
    for (var i = 0; i < _columns.length; i++) {
      if (_columns[i][rowIndex] == null) return true;
    }
    return false;
  }
}
