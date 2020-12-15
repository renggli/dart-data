import 'package:collection/collection.dart';

/// Integration warnings that can be triggered for badly behaving functions or
/// ill defined parameters.
enum IntegrateWarning {
  doesNotConverge,
  depthTooShallow,
}

/// Returns the numerical integration of the provided function [f] from [a] to
/// [b].
///
/// [epsilon] is the maximum error tolerance. [depth] is the maximum
/// calculation depth. If set, [onWarning] is triggered with problematic
/// parts (do not ignore those).
double integrate(double Function(double) f, double a, double b,
    {int depth = 6,
    double epsilon = 1e-6,
    void Function(IntegrateWarning)? onWarning}) {
  onWarning ??= (type) {};
  // https://en.wikipedia.org/wiki/Numerical_integration#Integrals_over_infinite_intervals
  if (a.isNaN) {
    throw ArgumentError.value(a, 'a', 'Invalid lower bound');
  } else if (b.isNaN) {
    throw ArgumentError.value(b, 'b', 'Invalid upper bound');
  } else if (a > b) {
    return -integrate(f, b, a,
        depth: depth, epsilon: epsilon, onWarning: onWarning);
  } else if (a == b) {
    return 0.0;
  } else if (a == double.negativeInfinity && b == double.infinity) {
    return integrate(f, a, 0,
            depth: depth, epsilon: epsilon, onWarning: onWarning) +
        integrate(f, 0, b,
            depth: depth, epsilon: epsilon, onWarning: onWarning);
  } else if (a == double.negativeInfinity) {
    return integrate((t) {
      final omt = 1.0 - t, t2 = t * t;
      return f(b - omt / t) / t2;
    }, epsilon, 1, depth: depth, epsilon: epsilon, onWarning: onWarning);
  } else if (b == double.infinity) {
    return integrate((t) {
      final omt = 1.0 - t, t2 = t * t;
      return f(a + omt / t) / t2;
    }, epsilon, 1, depth: depth, epsilon: epsilon, onWarning: onWarning);
  }
  // https://en.wikipedia.org/wiki/Adaptive_quadrature
  var result = 0.0;
  final queue = QueueList.from(
      [_Quadrature.simpson(f, depth, epsilon, a, f(a), b, f(b))]);
  while (queue.isNotEmpty) {
    final full = queue.removeLast();
    final left = _Quadrature.simpson(f, full.depth - 1, full.epsilon / 2.0,
        full.a, full.fa, full.m, full.fm);
    final right = _Quadrature.simpson(
        f, left.depth, left.epsilon, full.m, full.fm, full.b, full.fb);
    if (left.epsilon == full.epsilon || left.a == left.m) {
      onWarning(IntegrateWarning.doesNotConverge);
      result += full.w;
      continue;
    }
    if (full.depth <= 0) {
      onWarning(IntegrateWarning.depthTooShallow);
    }
    final delta = left.w + right.w - full.w;
    if (full.depth <= 0 || delta.abs() <= 15 * full.epsilon) {
      result += left.w + right.w + delta / 15;
    } else {
      queue.addLast(right);
      queue.addLast(left);
    }
  }
  return result;
}

class _Quadrature {
  final int depth;
  final double epsilon;
  final double a, fa;
  final double m, fm;
  final double b, fb;
  final double w;

  factory _Quadrature.simpson(double Function(double) f, int depth,
      double epsilon, double a, double fa, double b, double fb) {
    final m = 0.5 * (a + b), fm = f(m);
    return _Quadrature(depth, epsilon, a, fa, m, fm, b, fb,
        (b - a) / 6.0 * (fa + 4 * fm + fb));
  }

  _Quadrature(this.depth, this.epsilon, this.a, this.fa, this.m, this.fm,
      this.b, this.fb, this.w);

  @override
  String toString() => 'Quadrature{a: $a -> $fa, m: $m -> $fm, '
      'b: $b -> $fb, w: $w, epsilon: $epsilon}';
}
