library data.vector.operators;

import 'dart:math' as math;

import 'package:data/type.dart';

import 'builder.dart';
import 'vector.dart';

Vector<T> _targetOrBuilder<T>(
    int count, Vector<T> target, Builder<T> builder, DataType<T> type) {
  if (target != null) {
    if (count != target.count) {
      throw ArgumentError('Expected a vector of dimension $count, '
          'but got ${target.count}.');
    }
    return target;
  } else if (builder != null) {
    return builder(count);
  } else if (type != null) {
    return Vector.builder.withType(type)(count);
  } else {
    throw ArgumentError('Expected either a "target" or a "builder".');
  }
}

/// Add two numeric vectors [sourceA] and [sourceB].
Vector<T> add<T extends num>(Vector<T> sourceA, Vector<T> sourceB,
    {Vector<T> target, Builder<T> builder}) {
  if (sourceA.count != sourceB.count) {
    throw ArgumentError('Source vector dimensions do not match.');
  }
  final result =
      _targetOrBuilder(sourceA.count, target, builder, sourceA.dataType);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, sourceA.getUnchecked(i) + sourceB.getUnchecked(i));
  }
  return result;
}

/// Subtract two numeric vectors [sourceA] and [sourceB].
Vector<T> sub<T extends num>(Vector<T> sourceA, Vector<T> sourceB,
    {Vector<T> target, Builder<T> builder}) {
  if (sourceA.count != sourceB.count) {
    throw ArgumentError('Source vector dimensions do not match.');
  }
  final result =
      _targetOrBuilder(sourceA.count, target, builder, sourceA.dataType);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, sourceA.getUnchecked(i) - sourceB.getUnchecked(i));
  }
  return result;
}

/// Scales a vector [source] with a [factor].
Vector<T> mul<T extends num>(T factor, Vector<T> source,
    {Vector<T> target, Builder<T> builder}) {
  final result =
      _targetOrBuilder(source.count, target, builder, source.dataType);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, factor * source.getUnchecked(i));
  }
  return result;
}

/// Interpolates linearly between [v0] and [v0] with a factor [t].
Vector<double> lerp<T extends num>(Vector<T> v0, Vector<T> v1, double t,
    {Vector<double> target, Builder<double> builder}) {
  if (v0.count != v1.count) {
    throw ArgumentError('Source vector dimensions do not match.');
  }
  final t1 = 1.0 - t;
  final result = _targetOrBuilder(v1.count, target, builder, DataType.float64);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, t1 * v0.getUnchecked(i) + t * v1.getUnchecked(i));
  }
  return result;
}

/// Computes the dot product of two vectors [sourceA] and [sourceB].
T dot<T extends num>(Vector<T> sourceA, Vector<T> sourceB) {
  if (sourceA.count != sourceB.count) {
    throw ArgumentError('Source vector dimensions do not match.');
  }
  var result = 0 as T;
  for (var i = 0; i < sourceA.count; i++) {
    result += sourceA.getUnchecked(i) * sourceB.getUnchecked(i);
  }
  return result;
}

/// Computes the length of a vector.
double length<T extends num>(Vector<T> source) => math.sqrt(length2(source));

/// Computes the squared length of a vector.
T length2<T extends num>(Vector<T> source) {
  var result = 0 as T;
  for (var i = 0; i < source.count; i++) {
    final value = source.getUnchecked(i);
    result += value * value;
  }
  return result;
}
