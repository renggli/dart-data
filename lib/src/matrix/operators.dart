library data.matrix.operators;

import 'package:data/type.dart';

import 'builder.dart';
import 'matrix.dart';

Matrix<T> _targetOrBuilder<T>(int rowCount, int colCount, Matrix<T> target,
    Builder<T> builder, DataType<T> dataType) {
  if (target != null) {
    if (target.rowCount != rowCount || target.colCount != colCount) {
      throw ArgumentError('Expected a matrix with $rowCount * $colCount, '
          'but got ${target.rowCount} * ${target.colCount}.');
    }
    return target;
  } else if (builder != null) {
    return builder(rowCount, colCount);
  } else if (dataType != null) {
    return Matrix.builder.withType(dataType)(rowCount, colCount);
  } else {
    throw ArgumentError('Expected either a "target" or a "builder".');
  }
}

/// Helper to add two numeric matrices [sourceA] and [sourceB].
Matrix<T> add<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
    {Matrix<T> target, Builder<T> builder}) {
  if (sourceA.rowCount != sourceB.rowCount ||
      sourceA.colCount != sourceB.colCount) {
    throw ArgumentError('Source matrices do not match in size.');
  }
  final result = _targetOrBuilder(
      sourceA.rowCount, sourceA.colCount, target, builder, sourceA.dataType);
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
  final result = _targetOrBuilder(
      sourceA.rowCount, sourceA.colCount, target, builder, sourceA.dataType);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(
          r, c, sourceA.getUnchecked(r, c) - sourceB.getUnchecked(r, c));
    }
  }
  return result;
}

/// Helper to scale a matrix [source] with a [factor].
Matrix<T> scale<T extends num>(T factor, Matrix<T> source,
    {Matrix<T> target, Builder<T> builder}) {
  final result = _targetOrBuilder(
      source.rowCount, source.colCount, target, builder, source.dataType);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(r, c, factor * source.getUnchecked(r, c));
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
  final result = _targetOrBuilder(
      sourceA.rowCount, sourceB.colCount, target, builder, sourceA.dataType);
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
