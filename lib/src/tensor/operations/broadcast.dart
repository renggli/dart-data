import 'dart:math';

import '../errors.dart';
import '../layout.dart';
import '../utils/layout.dart';

extension BroadcastLayoutExtension on Layout {
  /// Returns a tuple with updated layouts for broadcasting. Throws an
  /// [LayoutError] if the shapes are not compatible.
  (Layout, Layout) broadcast(Layout other) => _broadcast(this, other);
}

(Layout, Layout) _broadcast(Layout a, Layout b) {
  // If the shape of `a` and `b` are the same, we are good to go.
  if (indicesEquality.equals(a.shape, b.shape)) {
    return (a, b);
  }
  // If one of the shapes is empty, that is a no go.
  LayoutError.checkNotEmpty(a);
  LayoutError.checkNotEmpty(b);
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
      throw LayoutError.shape(a, ai, b, bi);
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
