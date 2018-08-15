library data.vector.operators;

import 'builder.dart';
import 'vector.dart';

Vector<T> _targetOrBuilder<T>(int count, Vector<T> target, Builder<T> builder) {
  if (target != null) {
    if (count != target.count) {
      throw ArgumentError('Expected a vector of dimension $count, '
          'but got ${target.count}.');
    }
    return target;
  } else if (builder != null) {
    return builder(count);
  } else {
    throw ArgumentError('Expected either a "target" or a "builder".');
  }
}

/// Helper to add two numeric vectors [sourceA] and [sourceB].
Vector<T> add<T extends num>(Vector<T> sourceA, Vector<T> sourceB,
    {Vector<T> target, Builder<T> builder}) {
  if (sourceA.count != sourceB.count) {
    throw ArgumentError('Source vector dimensions do not match.');
  }
  final result = _targetOrBuilder(sourceA.count, target, builder);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, sourceA.getUnchecked(i) + sourceB.getUnchecked(i));
  }
  return result;
}

/// Helper to subtract two numeric vectors [sourceA] and [sourceB].
Vector<T> sub<T extends num>(Vector<T> sourceA, Vector<T> sourceB,
    {Vector<T> target, Builder<T> builder}) {
  if (sourceA.count != sourceB.count) {
    throw ArgumentError('Source vector dimensions do not match.');
  }
  final result = _targetOrBuilder(sourceA.count, target, builder);
  for (var i = 0; i < result.count; i++) {
    result.setUnchecked(i, sourceA.getUnchecked(i) - sourceB.getUnchecked(i));
  }
  return result;
}

/// Helper to compute the dot product of two vectors [sourceA] and [sourceB].
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
