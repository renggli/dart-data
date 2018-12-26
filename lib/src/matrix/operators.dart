library data.matrix.operators;

import 'package:data/type.dart';

import 'builder.dart';
import 'matrix.dart';

Matrix<T> _targetOrBuilderOrDataType<T>(int rowCount, int colCount,
    Matrix<T> target, Builder<T> builder, DataType<T> dataType) {
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
  throw ArgumentError(
      'Expected either a "target", a "builder", or a "dataType".');
}

void _checkMatchingDimensions<T>(Matrix<T> sourceA, Matrix<T> sourceB) {
  if (sourceA.rowCount != sourceB.rowCount ||
      sourceA.colCount != sourceB.colCount) {
    throw ArgumentError('Matrix dimensions do not match: '
        '${sourceA.rowCount} * ${sourceA.colCount} and '
        '${sourceB.rowCount} * ${sourceB.colCount}.');
  }
}

/// Generic unary operator on a matrix.
Matrix<T> unaryOperator<T>(Matrix<T> source, T callback(T a),
    {Matrix<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _targetOrBuilderOrDataType(source.rowCount, source.colCount,
      target, builder, dataType ?? source.dataType);
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
  _checkMatchingDimensions(sourceA, sourceB);
  final result = _targetOrBuilderOrDataType(sourceA.rowCount, sourceA.colCount,
      target, builder, dataType ?? sourceA.dataType);
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
  if (identical(sourceA, sourceB)) {
    return true;
  }
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

/// Interpolates linearly between [sourceA] and [sourceB] with a factor [t].
Matrix<double> lerp<T extends num>(
    Matrix<T> sourceA, Matrix<T> sourceB, double t,
    {Matrix<double> target, Builder<double> builder, DataType<T> dataType}) {
  _checkMatchingDimensions(sourceA, sourceB);
  final t1 = 1.0 - t;
  final result = _targetOrBuilderOrDataType(sourceA.rowCount, sourceA.colCount,
      target, builder, dataType ?? DataType.float64);
  for (var r = 0; r < result.rowCount; r++) {
    for (var c = 0; c < result.colCount; c++) {
      result.setUnchecked(r, c,
          t1 * sourceA.getUnchecked(r, c) + t * sourceB.getUnchecked(r, c));
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
  final result = _targetOrBuilderOrDataType(sourceA.rowCount, sourceB.colCount,
      target, builder, dataType ?? sourceA.dataType);
  final sourcesStorage = Set.identity()
    ..addAll(sourceA.storage)
    ..addAll(sourceB.storage);
  if (result.storage.any(sourcesStorage.contains)) {
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
