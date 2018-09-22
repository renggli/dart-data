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
  }
  throw ArgumentError('Expected either a "target" or a "builder".');
}

/// Generic unary operator on a matrix.
Matrix<T> unaryOperator<T>(Matrix<T> source, T callback(T a),
    {Matrix<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _targetOrBuilder(source.rowCount, source.colCount, target,
      builder, dataType ?? source.dataType);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(r, c, callback(source.getUnchecked(r, c)));
    }
  }
  return result;
}

/// Generic binary operator on two equal sized matrices.
Matrix<T> binaryOperator<T>(
    Matrix<T> sourceA, Matrix<T> sourceB, T callback(T a, T b),
    {Matrix<T> target, Builder<T> builder, DataType<T> dataType}) {
  if (sourceA.rowCount != sourceB.rowCount ||
      sourceA.colCount != sourceB.colCount) {
    throw ArgumentError('Source matrices do not match in size.');
  }
  final result = _targetOrBuilder(sourceA.rowCount, sourceA.colCount, target,
      builder, dataType ?? sourceA.dataType);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(r, c,
          callback(sourceA.getUnchecked(r, c), sourceB.getUnchecked(r, c)));
    }
  }
  return result;
}

/// Adds two numeric matrices [sourceA] and [sourceB].
Matrix<T> add<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
        {Matrix<T> target, Builder<T> builder, DataType<T> dataType}) =>
    binaryOperator(sourceA, sourceB, (a, b) => a + b,
        target: target, builder: builder, dataType: dataType);

/// Subtracts two numeric matrices [sourceB] from [sourceA].
Matrix<T> sub<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
        {Matrix<T> target, Builder<T> builder, DataType<T> dataType}) =>
    binaryOperator(sourceA, sourceB, (a, b) => a - b,
        target: target, builder: builder, dataType: dataType);

/// Negates a numeric matrix [source].
Matrix<T> neg<T extends num>(Matrix<T> source,
        {Matrix<T> target, Builder<T> builder, DataType<T> dataType}) =>
    unaryOperator(source, (a) => -a,
        target: target, builder: builder, dataType: dataType);

/// Scales a numeric matrix [source] with a [factor].
Matrix<T> scale<T extends num>(T factor, Matrix<T> source,
        {Matrix<T> target, Builder<T> builder, DataType<T> dataType}) =>
    unaryOperator(source, (a) => factor * a,
        target: target, builder: builder, dataType: dataType);

/// Compares two matrices [sourceA] and [sourceB] with each other.
bool compare<A, B>(Matrix<A> sourceA, Matrix<B> sourceB,
    {bool equals(A a, B b)}) {
  if (sourceA.rowCount != sourceB.rowCount ||
      sourceA.colCount != sourceB.colCount) {
    return false;
  }
  equals ??= (a, b) => a == b;
  for (var r = 0; r < sourceA.rowCount; r++) {
    for (var c = 0; c < sourceA.colCount; c++) {
      if (!equals(sourceA.getUnchecked(r, c), sourceB.getUnchecked(r, c))) {
        return false;
      }
    }
  }
  return true;
}

/// Interpolates linearly between [m0] and [m1] with a factor [t].
Matrix<double> lerp<T extends num>(Matrix<T> m0, Matrix<T> m1, double t,
    {Matrix<double> target, Builder<double> builder, DataType<T> dataType}) {
  if (m0.rowCount != m1.rowCount || m0.colCount != m1.colCount) {
    throw ArgumentError('Source matrices do not match in size.');
  }
  final t1 = 1.0 - t;
  final result = _targetOrBuilder(
      m0.rowCount, m0.colCount, target, builder, dataType ?? DataType.float64);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(
          r, c, t1 * m0.getUnchecked(r, c) + t * m1.getUnchecked(r, c));
    }
  }
  return result;
}

/// Multiplies two numeric matrices [sourceA] and [sourceB].
Matrix<T> mul<T extends num>(Matrix<T> sourceA, Matrix<T> sourceB,
    {Matrix<T> target, Builder<T> builder, DataType<T> dataType}) {
  if (sourceA.colCount != sourceB.rowCount) {
    throw ArgumentError('Inner dimensions of source matrices do not match.');
  }
  final result = _targetOrBuilder(sourceA.rowCount, sourceB.colCount, target,
      builder, dataType ?? sourceA.dataType);
  if (identical(result, sourceA) || identical(result, sourceB)) {
    throw ArgumentError('Matrix multiplication cannot be done in-place.');
  }
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      var sum = result.dataType.nullValue;
      for (var i = 0; i < sourceA.colCount; i++) {
        sum += sourceA.getUnchecked(r, i) * sourceB.getUnchecked(i, c);
      }
      result.setUnchecked(r, c, sum);
    }
  }
  return result;
}
