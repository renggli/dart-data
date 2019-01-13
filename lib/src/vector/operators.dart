library data.vector.operators;

import 'dart:math' as math;

import 'package:data/matrix.dart' show Matrix;
import 'package:data/type.dart';

import 'builder.dart';
import 'vector.dart';

Vector<T> _targetOrBuilderOrDataType<T>(
    int count, Vector<T> target, Builder<T> builder, DataType<T> dataType) {
  if (target != null) {
    if (count != target.count) {
      throw ArgumentError('Expected a vector of dimension $count, '
          'but got ${target.count}.');
    }
    return target;
  } else if (builder != null) {
    return builder(count);
  } else if (dataType != null) {
    return Vector.builder.withType(dataType)(count);
  }
  throw ArgumentError(
      'Expected either a "target", a "builder", or a "dataType".');
}

void _checkMatchingDimensions<T>(Vector<T> sourceA, Vector<T> sourceB) {
  if (sourceA.count != sourceB.count) {
    throw ArgumentError('Vector dimensions do not match: '
        '${sourceA.count} and ${sourceB.count}.');
  }
}

/// Generic unary operator on a vector.
Vector<T> unaryOperator<T>(Vector<T> source, T Function(T value) callback,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _targetOrBuilderOrDataType(
      source.count, target, builder, dataType ?? source.dataType);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, callback(source.getUnchecked(i)));
  }
  return result;
}

/// Generic binary operator on two equal sized vectors.
Vector<T> binaryOperator<T>(
    Vector<T> sourceA, Vector<T> sourceB, T Function(T a, T b) callback,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  _checkMatchingDimensions(sourceA, sourceB);
  final result = _targetOrBuilderOrDataType(
      sourceA.count, target, builder, sourceA.dataType);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(
        i, callback(sourceA.getUnchecked(i), sourceB.getUnchecked(i)));
  }
  return result;
}

/// Adds two numeric vectors [sourceA] and [sourceB].
Vector<T> add<T extends num>(Vector<T> sourceA, Vector<T> sourceB,
        {Vector<T> target, Builder<T> builder, DataType<T> dataType}) =>
    binaryOperator(sourceA, sourceB, (a, b) => a + b,
        target: target, builder: builder, dataType: dataType);

/// Subtracts two numeric vectors [sourceB] from [sourceA].
Vector<T> sub<T extends num>(Vector<T> sourceA, Vector<T> sourceB,
        {Vector<T> target, Builder<T> builder, DataType<T> dataType}) =>
    binaryOperator(sourceA, sourceB, (a, b) => a - b,
        target: target, builder: builder, dataType: dataType);

/// Negates a numeric vector [source].
Vector<T> neg<T extends num>(Vector<T> source,
        {Vector<T> target, Builder<T> builder, DataType<T> dataType}) =>
    unaryOperator(source, (a) => -a,
        target: target, builder: builder, dataType: dataType);

/// Scales a numeric vector [source] with a [factor].
Vector<T> scale<T extends num>(T factor, Vector<T> source,
        {Vector<T> target, Builder<T> builder, DataType<T> dataType}) =>
    unaryOperator(source, (a) => factor * a,
        target: target, builder: builder, dataType: dataType);

/// Compares two vectors [sourceA] and [sourceB] with each other.
bool compare<A, B>(Vector<A> sourceA, Vector<B> sourceB,
    {bool Function(A a, B b) equals}) {
  if (equals == null && identical(sourceA, sourceB)) {
    return true;
  }
  if (sourceA.count != sourceB.count) {
    return false;
  }
  equals ??= (a, b) => a == b;
  for (var i = 0; i < sourceA.count; i++) {
    if (!equals(sourceA.getUnchecked(i), sourceB.getUnchecked(i))) {
      return false;
    }
  }
  return true;
}

/// Interpolates linearly between [v0] and [v0] with a factor [t].
Vector<double> lerp<T extends num>(Vector<T> v0, Vector<T> v1, double t,
    {Vector<double> target, Builder<double> builder, DataType<T> dataType}) {
  _checkMatchingDimensions(v0, v1);
  final t1 = 1.0 - t;
  final result = _targetOrBuilderOrDataType(
      v0.count, target, builder, dataType ?? DataType.float64);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, t1 * v0.getUnchecked(i) + t * v1.getUnchecked(i));
  }
  return result;
}

/// Multiplies a numeric [matrix] and a [vector].
Vector<T> mul<T extends num>(Matrix<T> matrix, Vector<T> vector,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  if (matrix.colCount != vector.count) {
    throw ArgumentError('Number of columns in matrix (${matrix.colCount}) '
        'do not match number of elements in vector (${vector.count}).');
  }
  final result = _targetOrBuilderOrDataType(
      matrix.rowCount, target, builder, dataType ?? matrix.dataType);
  if (identical(result, target)) {
    final sourcesStorage = Set.identity()
      ..addAll(matrix.storage)
      ..addAll(vector.storage);
    if (result.storage.any(sourcesStorage.contains)) {
      throw ArgumentError('Vector multiplication cannot be done in-place.');
    }
  }
  for (var r = 0; r < matrix.rowCount; r++) {
    var sum = result.dataType.nullValue;
    for (var j = 0; j < matrix.colCount; j++) {
      sum += matrix.getUnchecked(r, j) * vector.getUnchecked(j);
    }
    result.setUnchecked(r, sum);
  }
  return result;
}

/// Computes the dot product of two vectors [sourceA] and [sourceB].
T dot<T extends num>(Vector<T> sourceA, Vector<T> sourceB) {
  _checkMatchingDimensions(sourceA, sourceB);
  var result = sourceA.dataType.nullValue;
  for (var i = 0; i < sourceA.count; i++) {
    result += sourceA.getUnchecked(i) * sourceB.getUnchecked(i);
  }
  return result;
}

/// Computes the sum of all elements in this vector.
T sum<T extends num>(Vector<T> source) {
  var result = source.dataType.nullValue;
  for (var i = 0; i < source.count; i++) {
    result += source[i];
  }
  return result;
}

/// Computes the length of a vector.
double length<T extends num>(Vector<T> source) => math.sqrt(length2(source));

/// Computes the squared length of a vector.
T length2<T extends num>(Vector<T> source) {
  var result = source.dataType.nullValue;
  for (var i = 0; i < source.count; i++) {
    final value = source.getUnchecked(i);
    result += value * value;
  }
  return result;
}
