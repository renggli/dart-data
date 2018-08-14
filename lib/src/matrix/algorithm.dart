library data.matrix.algorithm;

import 'builder.dart';
import 'matrix.dart';

/// Helper to copy a matrix from [source].
Matrix<T> copy<T>(Matrix<T> source, {Matrix<T> target, Builder<T> builder}) {
  if (target != null) {
    if (target.rowCount != source.rowCount ||
        target.colCount != source.colCount) {
      throw ArgumentError('Target matrix does not match in size.');
    }
  }
  final result = target ?? builder(source.rowCount, source.colCount);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(r, c, source.getUnchecked(r, c));
    }
  }
  return result;
}

/// Helper to add two numeric matrices [sourceA] and [sourceB].
Matrix<T> add<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
    {Matrix<T> target, Builder<T> builder}) {
  if (sourceA.rowCount != sourceB.rowCount ||
      sourceA.colCount != sourceB.colCount) {
    throw ArgumentError('Source matrices do not match in size.');
  }
  if (target != null) {
    if (target.rowCount != sourceA.rowCount ||
        target.colCount != sourceA.colCount) {
      throw ArgumentError('Target matrix does not match in size.');
    }
  }
  final result = target ?? builder(sourceA.rowCount, sourceA.colCount);
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
  if (target != null) {
    if (target.rowCount != sourceA.rowCount ||
        target.colCount != sourceA.colCount) {
      throw ArgumentError('Target matrix does not match in size.');
    }
  }
  final result = target ?? builder(sourceA.rowCount, sourceA.colCount);
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
  if (target != null) {
    if (target.rowCount != sourceA.rowCount ||
        target.colCount != sourceB.colCount) {
      throw ArgumentError('Target matrix does not match in size.');
    }
  }
  final result = target ?? builder(sourceA.rowCount, sourceB.colCount);
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
