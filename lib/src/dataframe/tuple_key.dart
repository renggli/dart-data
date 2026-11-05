import 'package:collection/collection.dart';

import 'series.dart';

/// Internal canonical key value for NaN so that NaN == NaN and hashCode is stable.
final class NaNKey {
  const new();

  @override
  bool operator ==(Object other) => other is NaNKey;

  @override
  int get hashCode => 0x7fc00000;

  @override
  String toString() => 'NaN';
}

/// Constant instance of [NaNKey].
const nanKey = NaNKey();

/// Canonicalizes [value] for consistent key-based grouping, uniqueness, and hashing.
///
/// Maps any [num] where `isNaN` is true to [nanKey], and normalizes `-0.0` to `0.0`.
Object? canonicalizeKey(Object? value) {
  if (value is num) {
    if (value.isNaN) return nanKey;
    if (value is double && value == 0.0) return 0.0;
  }
  return value;
}

/// A composite key representing a sequence of column values.
///
/// Uses deep collection equality and cached hash code for efficient hash map
/// lookups when joining or grouping across more than three columns.
final class TupleKey {
  /// Creates a [TupleKey] wrapping [values].
  new(Iterable<Object?> values)
    : this._(values.map(canonicalizeKey).toList(growable: false));

  new _(this.values)
    : _hashCode = const DeepCollectionEquality().hash(values);

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

/// Optimized extractor for row keys across columnar series.
///
/// Provides specialized zero-allocation record-based key extraction for 1, 2,
/// and 3 columns, falling back to [TupleKey] for 4 or more columns.
abstract interface class RowKeyExtractor {
  /// Creates an optimized key extractor for the given [columns].
  factory(List<Series<Object?>> columns) => switch (columns.length) {
    1 => _SingleKeyExtractor(columns[0]),
    2 => _PairKeyExtractor(columns[0], columns[1]),
    3 => _TripleKeyExtractor(columns[0], columns[1], columns[2]),
    _ => _MultiKeyExtractor(List.of(columns)),
  };

  /// Extracts the composite key for the row at [rowIndex].
  Object? extractKey(int rowIndex);

  /// Extracts the composite key for the row at [rowIndex], or returns `null` if
  /// any key column at [rowIndex] is null.
  Object? extractKeyOrNull(int rowIndex);

  /// Extracts the composite join key for the row at [rowIndex], or returns
  /// `null` if any key column at [rowIndex] is null or [double.nan].
  Object? extractJoinKeyOrNull(int rowIndex);

  /// Returns `true` if any key column at [rowIndex] is null.
  bool hasNull(int rowIndex);

  /// Returns `true` if any key column at [rowIndex] is null or [double.nan].
  bool hasNullOrNan(int rowIndex);
}

final class _SingleKeyExtractor implements RowKeyExtractor {
  const new(this._col);

  final Series<Object?> _col;

  @override
  Object? extractKey(int rowIndex) => canonicalizeKey(_col[rowIndex]);

  @override
  Object? extractKeyOrNull(int rowIndex) {
    final v = _col[rowIndex];
    return v == null ? null : canonicalizeKey(v);
  }

  @override
  Object? extractJoinKeyOrNull(int rowIndex) {
    final v = _col[rowIndex];
    return _isMissingOrNan(v) ? null : canonicalizeKey(v);
  }

  @override
  bool hasNull(int rowIndex) => _col[rowIndex] == null;

  @override
  bool hasNullOrNan(int rowIndex) => _isMissingOrNan(_col[rowIndex]);
}

final class _PairKeyExtractor implements RowKeyExtractor {
  const new(this._col0, this._col1);

  final Series<Object?> _col0;
  final Series<Object?> _col1;

  @override
  Object? extractKey(int rowIndex) =>
      (canonicalizeKey(_col0[rowIndex]), canonicalizeKey(_col1[rowIndex]));

  @override
  Object? extractKeyOrNull(int rowIndex) {
    final v0 = _col0[rowIndex];
    if (v0 == null) return null;
    final v1 = _col1[rowIndex];
    if (v1 == null) return null;
    return (canonicalizeKey(v0), canonicalizeKey(v1));
  }

  @override
  Object? extractJoinKeyOrNull(int rowIndex) {
    final v0 = _col0[rowIndex];
    if (_isMissingOrNan(v0)) return null;
    final v1 = _col1[rowIndex];
    if (_isMissingOrNan(v1)) return null;
    return (canonicalizeKey(v0), canonicalizeKey(v1));
  }

  @override
  bool hasNull(int rowIndex) =>
      _col0[rowIndex] == null || _col1[rowIndex] == null;

  @override
  bool hasNullOrNan(int rowIndex) =>
      _isMissingOrNan(_col0[rowIndex]) || _isMissingOrNan(_col1[rowIndex]);
}

final class _TripleKeyExtractor implements RowKeyExtractor {
  const new(this._col0, this._col1, this._col2);

  final Series<Object?> _col0;
  final Series<Object?> _col1;
  final Series<Object?> _col2;

  @override
  Object? extractKey(int rowIndex) => (
    canonicalizeKey(_col0[rowIndex]),
    canonicalizeKey(_col1[rowIndex]),
    canonicalizeKey(_col2[rowIndex]),
  );

  @override
  Object? extractKeyOrNull(int rowIndex) {
    final v0 = _col0[rowIndex];
    if (v0 == null) return null;
    final v1 = _col1[rowIndex];
    if (v1 == null) return null;
    final v2 = _col2[rowIndex];
    if (v2 == null) return null;
    return (canonicalizeKey(v0), canonicalizeKey(v1), canonicalizeKey(v2));
  }

  @override
  Object? extractJoinKeyOrNull(int rowIndex) {
    final v0 = _col0[rowIndex];
    if (_isMissingOrNan(v0)) return null;
    final v1 = _col1[rowIndex];
    if (_isMissingOrNan(v1)) return null;
    final v2 = _col2[rowIndex];
    if (_isMissingOrNan(v2)) return null;
    return (canonicalizeKey(v0), canonicalizeKey(v1), canonicalizeKey(v2));
  }

  @override
  bool hasNull(int rowIndex) =>
      _col0[rowIndex] == null ||
      _col1[rowIndex] == null ||
      _col2[rowIndex] == null;

  @override
  bool hasNullOrNan(int rowIndex) =>
      _isMissingOrNan(_col0[rowIndex]) ||
      _isMissingOrNan(_col1[rowIndex]) ||
      _isMissingOrNan(_col2[rowIndex]);
}

final class _MultiKeyExtractor implements RowKeyExtractor {
  const new(this._columns);

  final List<Series<Object?>> _columns;

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
  Object? extractJoinKeyOrNull(int rowIndex) {
    final values = List<Object?>.filled(_columns.length, null);
    for (var i = 0; i < _columns.length; i++) {
      final val = _columns[i][rowIndex];
      if (_isMissingOrNan(val)) return null;
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

  @override
  bool hasNullOrNan(int rowIndex) {
    for (var i = 0; i < _columns.length; i++) {
      if (_isMissingOrNan(_columns[i][rowIndex])) return true;
    }
    return false;
  }
}

bool _isMissingOrNan(Object? val) =>
    val == null || (val is num && val.isNaN) || val is NaNKey;
