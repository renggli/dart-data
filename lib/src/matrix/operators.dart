library data.matrix.operators;

import 'builder.dart';
import 'matrix.dart';

Matrix<T> _targetOrBuilder<T>(
    int rowCount, int colCount, Matrix<T> target, Builder<T> builder) {
  if (target == null) {
    return builder(rowCount, colCount);
  } else {
    if (target.rowCount != rowCount || target.colCount != colCount) {
      throw ArgumentError('Expected a matrix with $rowCount * $colCount, '
          'but got ${target.rowCount} * ${target.colCount}.');
    }
    return target;
  }
}

/// Helper to add two numeric matrices [sourceA] and [sourceB].
Matrix<T> add<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
    {Matrix<T> target, Builder<T> builder}) {
  if (sourceA.rowCount != sourceB.rowCount ||
      sourceA.colCount != sourceB.colCount) {
    throw ArgumentError('Source matrices do not match in size.');
  }
  final result =
      _targetOrBuilder(sourceA.rowCount, sourceA.colCount, target, builder);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(
          r, c, sourceA.getUnchecked(r, c) + sourceB.getUnchecked(r, c));
    }
  }
  return result;
}

/// Helper to subtract two numeric matrices [sourceA] and [sourceB].
Matrix<T> sub<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
    {Matrix<T> target, Builder<T> builder}) {
  if (sourceA.rowCount != sourceB.rowCount ||
      sourceA.colCount != sourceB.colCount) {
    throw ArgumentError('Source matrices do not match in size.');
  }
  final result =
      _targetOrBuilder(sourceA.rowCount, sourceA.colCount, target, builder);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(
          r, c, sourceA.getUnchecked(r, c) - sourceB.getUnchecked(r, c));
    }
  }
  return result;
}

/// Helper to multiply two numeric matrices [sourceA] and [sourceB].
Matrix<T> mul<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
    {Matrix<T> target, Builder<T> builder}) {
  if (sourceA.colCount != sourceB.rowCount) {
    throw ArgumentError('Inner dimensions of source matrices do not match.');
  }
  final result =
      _targetOrBuilder(sourceA.rowCount, sourceB.colCount, target, builder);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      var sum = result.dataType.nullValue;
      for (var j = 0; j < sourceA.colCount; j++) {
        sum += sourceA.getUnchecked(r, j) * sourceB.getUnchecked(j, c);
      }
      result.setUnchecked(r, c, sum);
    }
  }
  return result;
}
