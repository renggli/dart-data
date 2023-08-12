import 'layout.dart';

/// Error indicating an unexpected [Layout] state.
class LayoutError extends ArgumentError {
  /// Asserts that the `layout` is not empty.
  static void checkNotEmpty(Layout layout, [String? name, String? message]) {
    if (layout.length == 0) {
      throw LayoutError.empty(layout, name);
    }
  }

  /// Asserts that the layouts `a` and `b` have the same length.
  static void checkEqualLength(Layout a, Layout b, [String? name]) {
    if (a.length != b.length) {
      throw LayoutError.length(a, b, name);
    }
  }

  /// Asserts that the layouts `a` and `b` share the same shape.
  static void checkEqualShape(Layout a, Layout b, [String? name]) {
    if (a.rank != b.rank) {
      throw LayoutError.rank(a, b, name);
    }
    for (var i = 0; i < a.rank; i++) {
      if (a.shape[i] != b.shape[i]) {
        throw LayoutError.shape(a, i, b, i, name);
      }
    }
  }

  /// Constructs an error indicating an empty [Layout].
  LayoutError.empty(Layout a, [String? name]) : super('$a is empty', name);

  /// Constructs an error indicating incompatible lengths.
  LayoutError.length(Layout a, Layout b, [String? name])
      : super('$a and $b have incompatible length: ${a.length} and ${b.length}',
            name);

  /// Constructs an error indicating incompatible ranks.
  LayoutError.rank(Layout a, Layout b, [String? name])
      : super(
            '$a and $b have incompatible rank: ${a.rank} and ${b.rank}', name);

  /// Constructs an error indicating incompatible shapes.
  LayoutError.shape(Layout a, int ai, Layout b, int bi, [String? name])
      : super('$a and $b have incompatible shape at $ai and $bi', name);
}
