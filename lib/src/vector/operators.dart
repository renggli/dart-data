library data.vector.operators;

import 'dart:math' as math;

import 'package:data/matrix.dart' show Matrix;
import 'package:data/src/vector/builder.dart';
import 'package:data/src/vector/vector.dart';
import 'package:data/type.dart';

Vector<T> _resultVector<T>(
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

void _unaryOperator<T>(
    Vector<T> result, Vector<T> source, T Function(T value) operator) {
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, operator(source.getUnchecked(i)));
  }
}

void _binaryOperator<T>(Vector<T> result, Vector<T> sourceA, Vector<T> sourceB,
    T Function(T a, T b) operator) {
  _checkMatchingDimensions(sourceA, sourceB);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(
        i, operator(sourceA.getUnchecked(i), sourceB.getUnchecked(i)));
  }
}

void _checkMatchingDimensions<T>(Vector<T> sourceA, Vector<T> sourceB) {
  if (sourceA.count != sourceB.count) {
    throw ArgumentError('Vector dimensions do not match: '
        '${sourceA.count} and ${sourceB.count}.');
  }
}

/// Generic unary operator on a vector.
Vector<T> unaryOperator<T>(Vector<T> source, T Function(T value) operator,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result =
      _resultVector(source.count, target, builder, dataType ?? source.dataType);
  _unaryOperator(result, source, operator);
  return result;
}

/// Generic binary operator on two equal sized vectors.
Vector<T> binaryOperator<T>(
    Vector<T> sourceA, Vector<T> sourceB, T Function(T a, T b) operator,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultVector(
      sourceA.count, target, builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, operator);
  return result;
}

/// Adds two vectors [sourceA] and [sourceB].
Vector<T> add<T>(Vector<T> sourceA, Vector<T> sourceB,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultVector(
      sourceA.count, target, builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, result.dataType.system.add);
  return result;
}

/// Subtracts two numeric vectors [sourceB] from [sourceA].
Vector<T> sub<T>(Vector<T> sourceA, Vector<T> sourceB,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultVector(
      sourceA.count, target, builder, dataType ?? sourceA.dataType);
  _binaryOperator(result, sourceA, sourceB, result.dataType.system.sub);
  return result;
}

/// Negates a numeric vector [source].
Vector<T> neg<T>(Vector<T> source,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result =
      _resultVector(source.count, target, builder, dataType ?? source.dataType);
  _unaryOperator(result, source, result.dataType.system.neg);
  return result;
}

/// Scales a numeric vector [source] with a [factor].
Vector<T> scale<T>(Vector<T> source, num factor,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result =
      _resultVector(source.count, target, builder, dataType ?? source.dataType);
  final scale = result.dataType.system.scale;
  _unaryOperator(result, source, (a) => scale(a, factor));
  return result;
}

/// Interpolates linearly between [sourceA] and [sourceA] with a factor [t].
Vector<T> lerp<T>(Vector<T> sourceA, Vector<T> sourceB, num t,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  final result = _resultVector(
      sourceA.count, target, builder, dataType ?? sourceA.dataType);
  final system = result.dataType.system;
  _binaryOperator(result, sourceA, sourceB,
      (a, b) => system.add(system.scale(a, 1.0 - t), system.scale(b, t)));
  return result;
}

/// Multiplies a numeric [matrix] and a [vector].
Vector<T> mul<T>(Matrix<T> matrix, Vector<T> vector,
    {Vector<T> target, Builder<T> builder, DataType<T> dataType}) {
  if (matrix.colCount != vector.count) {
    throw ArgumentError('Number of columns in matrix (${matrix.colCount}) '
        'do not match number of elements in vector (${vector.count}).');
  }
  final result = _resultVector(
      matrix.rowCount, target, builder, dataType ?? matrix.dataType);
  if (identical(result, target)) {
    final sourcesStorage = Set.identity()
      ..addAll(matrix.storage)
      ..addAll(vector.storage);
    if (result.storage.any(sourcesStorage.contains)) {
      throw ArgumentError('Vector multiplication cannot be done in-place.');
    }
  }
  final system = result.dataType.system;
  for (var r = 0; r < matrix.rowCount; r++) {
    var sum = system.additiveIdentity;
    for (var j = 0; j < matrix.colCount; j++) {
      sum = system.add(
        sum,
        system.mul(
          matrix.getUnchecked(r, j),
          vector.getUnchecked(j),
        ),
      );
    }
    result.setUnchecked(r, sum);
  }
  return result;
}

/// Computes the dot product of two vectors [sourceA] and [sourceB].
T dot<T>(Vector<T> sourceA, Vector<T> sourceB) {
  _checkMatchingDimensions(sourceA, sourceB);
  final system = sourceA.dataType.system;
  var result = system.additiveIdentity;
  for (var i = 0; i < sourceA.count; i++) {
    result = system.add(
      result,
      system.mul(
        sourceA.getUnchecked(i),
        sourceB.getUnchecked(i),
      ),
    );
  }
  return result;
}

/// Computes the sum of all elements in this vector.
T sum<T>(Vector<T> source) {
  final system = source.dataType.system;
  var result = system.additiveIdentity;
  for (var i = 0; i < source.count; i++) {
    result = system.add(result, source[i]);
  }
  return result;
}

/// Computes the length of a vector.
double length<T extends num>(Vector<T> source) => math.sqrt(length2(source));

/// Computes the squared length of a vector.
T length2<T extends num>(Vector<T> source) {
  final system = source.dataType.system;
  var result = system.additiveIdentity;
  for (var i = 0; i < source.count; i++) {
    final value = source.getUnchecked(i);
    result = system.add(result, system.mul(value, value));
  }
  return result;
}

/// Compares two vectors [sourceA] and [sourceB] with each other.
bool compare<T>(Vector<T> sourceA, Vector<T> sourceB,
    {bool Function(T a, T b) equals}) {
  if (equals == null && identical(sourceA, sourceB)) {
    return true;
  }
  if (sourceA.count != sourceB.count) {
    return false;
  }
  equals ??= sourceA.dataType.equality.isEqual;
  for (var i = 0; i < sourceA.count; i++) {
    if (!equals(sourceA.getUnchecked(i), sourceB.getUnchecked(i))) {
      return false;
    }
  }
  return true;
}
