import 'dart:math' show max;

import 'package:collection/collection.dart';

import 'layout.dart';

const _listEquality = ListEquality<int>();

/// Returns a tuple of the updated broadcast layouts of `a` and `b`. Throws an
/// [ArgumentError] if the shapes are not compatible.
(Layout, Layout) broadcast(Layout a, Layout b) {
  // If the shape of `a` and `b` are the same, we are good to go.
  if (_listEquality.equals(a.shape, b.shape)) return (a, b);
  // If one of the shapes is empty, that is a no go.
  ShapeError.checkNotEmpty(a);
  ShapeError.checkNotEmpty(b);
  // Updates shape and strides for `a` and `b` (in reverse order).
  final shape = <int>[];
  final aStrides = <int>[];
  final bStrides = <int>[];
  // Iterate over the shape from the back.
  for (var ai = a.rank - 1, bi = b.rank - 1; ai >= 0 || bi >= 0; ai--, bi--) {
    // Get the current shape `as` and `bs`.
    final as = ai >= 0 ? a.shape[ai] : 1;
    final bs = bi >= 0 ? b.shape[bi] : 1;
    // Verify the compatibility of the shape.
    if (as != bs && as != 1 && bs != 1) {
      throw ShapeError.incompatible(a, ai, b, bi);
    }
    final rs = max(as, bs);
    aStrides.add(as == rs && ai >= 0 ? a.strides[ai] : 0);
    bStrides.add(bs == rs && bi >= 0 ? b.strides[bi] : 0);
    shape.add(rs);
  }
  return (
    Layout(shape: shape.reversed, strides: aStrides.reversed, offset: a.offset),
    Layout(shape: shape.reversed, strides: bStrides.reversed, offset: b.offset),
  );
}

class ShapeError extends ArgumentError {
  static void checkNotEmpty(Layout layout, [String? name]) {
    if (layout.length == 0) {
      throw ShapeError(layout, name, 'empty layout');
    }
  }

  ShapeError.incompatible(Layout a, int ai, Layout b, int bi)
      : super('Shape ${a.shape} at $ai and ${b.shape} at $bi are incompatible');

  ShapeError.assignment(Layout a, Layout b)
      : super(
            'Shape ${a.shape} cannot be assigned to ${b.shape} is not assignable to ${a.shape}');

  ShapeError(super.value, [super.name, String? super.message]) : super.value();
}
