import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart' as numeric;
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('linearSpaced', () {
    test('default configuration (count = 50, endpoint = true)', () {
      final v = linearSpaced(0.0, 1.0);
      check(v.length).equals(50);
      check(v[0]).equals(0.0);
      check(v[49]).equals(1.0);
      for (var i = 0; i < 49; i++) {
        check(v[i + 1] - v[i]).isCloseTo(1.0 / 49.0, 1e-12);
      }
    });

    test('endpoint = true with custom count', () {
      final v = linearSpaced(2.0, 3.0, count: 5);
      check(v.length).equals(5);
      check(v[0]).equals(2.0);
      check(v[1]).isCloseTo(2.25, 1e-12);
      check(v[2]).isCloseTo(2.50, 1e-12);
      check(v[3]).isCloseTo(2.75, 1e-12);
      check(v[4]).equals(3.0);
    });

    test('endpoint = false with custom count', () {
      final v = linearSpaced(2.0, 3.0, count: 5, endpoint: false);
      check(v.length).equals(5);
      check(v[0]).equals(2.0);
      check(v[1]).isCloseTo(2.2, 1e-12);
      check(v[2]).isCloseTo(2.4, 1e-12);
      check(v[3]).isCloseTo(2.6, 1e-12);
      check(v[4]).isCloseTo(2.8, 1e-12);
    });

    test('descending interval', () {
      final v = linearSpaced(10.0, 0.0, count: 5);
      check(v.length).equals(5);
      check(v[0]).equals(10.0);
      check(v[1]).isCloseTo(7.5, 1e-12);
      check(v[2]).isCloseTo(5.0, 1e-12);
      check(v[3]).isCloseTo(2.5, 1e-12);
      check(v[4]).equals(0.0);
    });

    test('negative coordinates', () {
      final v = linearSpaced(-10.0, 10.0, count: 5);
      check(v.length).equals(5);
      check(v[0]).equals(-10.0);
      check(v[1]).isCloseTo(-5.0, 1e-12);
      check(v[2]).isCloseTo(0.0, 1e-12);
      check(v[3]).isCloseTo(5.0, 1e-12);
      check(v[4]).equals(10.0);
    });

    test('count = 0 produces empty vector', () {
      final v = linearSpaced(0.0, 10.0, count: 0);
      check(v.length).equals(0);
    });

    test('count = 1 returns start', () {
      final v1 = linearSpaced(5.0, 10.0, count: 1, endpoint: true);
      check(v1.length).equals(1);
      check(v1[0]).equals(5.0);

      final v2 = linearSpaced(5.0, 10.0, count: 1, endpoint: false);
      check(v2.length).equals(1);
      check(v2[0]).equals(5.0);
    });

    test('count < 0 throws ArgumentError', () {
      check(() => linearSpaced(0.0, 1.0, count: -1)).throws<ArgumentError>();
    });

    test('custom DataType and native buffer', () {
      final v = linearSpaced(0.0, 1.0, count: 5, type: DataType.float32);
      check(v.type).equals(DataType.float32);
      check(v.length).equals(5);
      check(v[0]).equals(0.0);
      check(v[4]).equals(1.0);
    });

    test('Vector.linspace parity', () {
      final v1 = Vector<double>.linspace(0.0, 4.0, count: 5);
      final v2 = linearSpaced(0.0, 4.0, count: 5);
      check(v1.length).equals(v2.length);
      for (var i = 0; i < v1.length; i++) {
        check(v1[i]).equals(v2[i]);
      }
    });

    test('Float64Vector.linspace parity', () {
      final fv = Float64Vector.linspace(0.0, 4.0, count: 5);
      check(fv.length).equals(5);
      check(fv[0]).equals(0.0);
      check(fv[2]).equals(2.0);
      check(fv[4]).equals(4.0);
    });
  });

  group('logarithmicSpaced', () {
    test('base 10 powers (count = 4, start = 0, stop = 3)', () {
      final v = logarithmicSpaced(0.0, 3.0, count: 4);
      check(v.length).equals(4);
      check(v[0]).isCloseTo(1.0, 1e-12);
      check(v[1]).isCloseTo(10.0, 1e-12);
      check(v[2]).isCloseTo(100.0, 1e-12);
      check(v[3]).isCloseTo(1000.0, 1e-12);
    });

    test('base 10 with endpoint = false', () {
      final v = logarithmicSpaced(0.0, 3.0, count: 3, endpoint: false);
      check(v.length).equals(3);
      check(v[0]).isCloseTo(1.0, 1e-12);
      check(v[1]).isCloseTo(10.0, 1e-12);
      check(v[2]).isCloseTo(100.0, 1e-12);
    });

    test('base 2 powers', () {
      final v = logarithmicSpaced(0.0, 8.0, count: 9, base: 2.0);
      check(v.length).equals(9);
      check(v[0]).isCloseTo(1.0, 1e-12);
      check(v[1]).isCloseTo(2.0, 1e-12);
      check(v[2]).isCloseTo(4.0, 1e-12);
      check(v[3]).isCloseTo(8.0, 1e-12);
      check(v[4]).isCloseTo(16.0, 1e-12);
      check(v[8]).isCloseTo(256.0, 1e-12);
    });

    test('negative exponents', () {
      final v = logarithmicSpaced(-3.0, 0.0, count: 4);
      check(v.length).equals(4);
      check(v[0]).isCloseTo(0.001, 1e-12);
      check(v[1]).isCloseTo(0.01, 1e-12);
      check(v[2]).isCloseTo(0.1, 1e-12);
      check(v[3]).isCloseTo(1.0, 1e-12);
    });

    test('count = 0 produces empty vector', () {
      final v = logarithmicSpaced(0.0, 3.0, count: 0);
      check(v.length).equals(0);
    });

    test('count = 1 returns base^start', () {
      final v = logarithmicSpaced(2.0, 5.0, count: 1, base: 10.0);
      check(v.length).equals(1);
      check(v[0]).isCloseTo(100.0, 1e-12);
    });

    test('count < 0 throws ArgumentError', () {
      check(() => logarithmicSpaced(0.0, 3.0, count: -1))
          .throws<ArgumentError>();
    });

    test('base <= 0 throws ArgumentError', () {
      check(() => logarithmicSpaced(0.0, 3.0, base: 0.0))
          .throws<ArgumentError>();
      check(() => logarithmicSpaced(0.0, 3.0, base: -2.0))
          .throws<ArgumentError>();
    });

    test('Vector.logspace parity', () {
      final v1 = Vector<double>.logspace(0.0, 3.0, count: 4);
      final v2 = logarithmicSpaced(0.0, 3.0, count: 4);
      check(v1.length).equals(v2.length);
      for (var i = 0; i < v1.length; i++) {
        check(v1[i]).isCloseTo(v2[i], 1e-12);
      }
    });

    test('Float64Vector.logspace parity', () {
      final fv = Float64Vector.logspace(0.0, 3.0, count: 4);
      check(fv.length).equals(4);
      check(fv[0]).isCloseTo(1.0, 1e-12);
      check(fv[3]).isCloseTo(1000.0, 1e-12);
    });
  });

  group('geometricSpaced', () {
    test('positive interval decade progression (1 to 1000)', () {
      final v = geometricSpaced(1.0, 1000.0, count: 4);
      check(v.length).equals(4);
      check(v[0]).isCloseTo(1.0, 1e-12);
      check(v[1]).isCloseTo(10.0, 1e-12);
      check(v[2]).isCloseTo(100.0, 1e-12);
      check(v[3]).isCloseTo(1000.0, 1e-12);
    });

    test('geometric ratio step consistency', () {
      final v = geometricSpaced(2.0, 32.0, count: 5);
      check(v.length).equals(5);
      check(v[0]).isCloseTo(2.0, 1e-12);
      check(v[1]).isCloseTo(4.0, 1e-12);
      check(v[2]).isCloseTo(8.0, 1e-12);
      check(v[3]).isCloseTo(16.0, 1e-12);
      check(v[4]).isCloseTo(32.0, 1e-12);

      // Verify constant geometric ratio r = 2.0
      for (var i = 0; i < 4; i++) {
        check(v[i + 1] / v[i]).isCloseTo(2.0, 1e-12);
      }
    });

    test('endpoint = false excludes stop', () {
      final v = geometricSpaced(1.0, 1000.0, count: 3, endpoint: false);
      check(v.length).equals(3);
      check(v[0]).isCloseTo(1.0, 1e-12);
      check(v[1]).isCloseTo(10.0, 1e-12);
      check(v[2]).isCloseTo(100.0, 1e-12);
    });

    test('negative interval preserves signs', () {
      final v = geometricSpaced(-1.0, -1000.0, count: 4);
      check(v.length).equals(4);
      check(v[0]).isCloseTo(-1.0, 1e-12);
      check(v[1]).isCloseTo(-10.0, 1e-12);
      check(v[2]).isCloseTo(-100.0, 1e-12);
      check(v[3]).isCloseTo(-1000.0, 1e-12);
    });

    test('descending interval', () {
      final v = geometricSpaced(1000.0, 1.0, count: 4);
      check(v.length).equals(4);
      check(v[0]).isCloseTo(1000.0, 1e-12);
      check(v[1]).isCloseTo(100.0, 1e-12);
      check(v[2]).isCloseTo(10.0, 1e-12);
      check(v[3]).isCloseTo(1.0, 1e-12);
    });

    test('count = 0 produces empty vector', () {
      final v = geometricSpaced(1.0, 10.0, count: 0);
      check(v.length).equals(0);
    });

    test('count = 1 returns start', () {
      final v1 = geometricSpaced(5.0, 100.0, count: 1, endpoint: true);
      check(v1.length).equals(1);
      check(v1[0]).isCloseTo(5.0, 1e-12);

      final v2 = geometricSpaced(5.0, 100.0, count: 1, endpoint: false);
      check(v2.length).equals(1);
      check(v2[0]).isCloseTo(5.0, 1e-12);
    });

    test('count < 0 throws ArgumentError', () {
      check(() => geometricSpaced(1.0, 10.0, count: -1))
          .throws<ArgumentError>();
    });

    test('start or stop zero throws ArgumentError', () {
      check(() => geometricSpaced(0.0, 10.0)).throws<ArgumentError>();
      check(() => geometricSpaced(1.0, 0.0)).throws<ArgumentError>();
    });

    test('mismatched signs throws ArgumentError', () {
      check(() => geometricSpaced(-1.0, 10.0)).throws<ArgumentError>();
      check(() => geometricSpaced(1.0, -10.0)).throws<ArgumentError>();
    });

    test('Vector.geomspace parity', () {
      final v1 = Vector<double>.geomspace(1.0, 1000.0, count: 4);
      final v2 = geometricSpaced(1.0, 1000.0, count: 4);
      check(v1.length).equals(v2.length);
      for (var i = 0; i < v1.length; i++) {
        check(v1[i]).isCloseTo(v2[i], 1e-12);
      }
    });

    test('Float64Vector.geomspace parity', () {
      final fv = Float64Vector.geomspace(1.0, 1000.0, count: 4);
      check(fv.length).equals(4);
      check(fv[0]).isCloseTo(1.0, 1e-12);
      check(fv[3]).isCloseTo(1000.0, 1e-12);
    });
  });

  group('sampleCurve', () {
    test('samples smooth continuous curves into a single segment', () {
      final sample = numeric.sampleCurve((x) => x * x, -2.0, 2.0);
      check(sample.segments.length).equals(1);
      check(sample.pointCount).isGreaterOrEqual(65);
      final seg = sample.segments.first;
      check(seg.x[0]).equals(-2.0);
      check(seg.x[seg.x.length - 1]).equals(2.0);
      check(sample.yMin).isCloseTo(0.0, 1e-3);
      check(sample.yMax).isCloseTo(4.0, 1e-3);
    });

    test('splits vertical asymptotes and poles into separate segments', () {
      // 1 / x on [-1, 1] has a pole at x = 0 -> 2 segments
      final invSample = numeric.sampleCurve((x) => 1.0 / x, -1.0, 1.0);
      check(invSample.segments.length).equals(2);
      final seg0 = invSample.segments[0];
      final seg1 = invSample.segments[1];
      check(seg0.x[seg0.x.length - 1]).isLessThan(0.0);
      check(seg1.x[0]).isGreaterThan(0.0);

      // tan(x) on [-3, 3] has poles at -pi/2 and +pi/2 -> 3 segments
      final tanSample = numeric.sampleCurve(_tan, -3.0, 3.0);
      check(tanSample.segments.length).equals(3);
    });

    test('splits step discontinuities and handles out-of-domain intervals', () {
      // Sign / step function on [-1, 1] -> 2 segments
      final stepSample = numeric.sampleCurve(
        (x) => x < 0.0 ? -1.0 : 1.0,
        -1.0,
        1.0,
      );
      check(stepSample.segments.length).equals(2);

      // Out-of-domain NaN on [-1, 0) for sqrt(x) on [-1, 1] -> 1 segment on [0, 1]
      final sqrtSample = numeric.sampleCurve(_sqrt, -1.0, 1.0);
      check(sqrtSample.segments.length).equals(1);
      final seg = sqrtSample.segments.first;
      check(seg.x[0]).isGreaterOrEqual(0.0);
      check(seg.x[seg.x.length - 1]).equals(1.0);
    });

    test('validates arguments and respects maxPoints budget', () {
      final bounded = numeric.sampleCurve(
        _sin10,
        0.0,
        1.0,
        initialPoints: 10,
        maxPoints: 25,
      );
      check(bounded.pointCount).isLessOrEqual(25);

      check(() => numeric.sampleCurve((x) => x, 2.0, 1.0))
          .throws<ArgumentError>();
      check(() => numeric.sampleCurve((x) => x, 0.0, 1.0, initialPoints: 2))
          .throws<ArgumentError>();
      check(
        () => numeric.sampleCurve(
          (x) => x,
          0.0,
          1.0,
          initialPoints: 20,
          maxPoints: 10,
        ),
      ).throws<ArgumentError>();
      check(() => numeric.sampleCurve((x) => x, 0.0, 1.0, tolerance: 0.0))
          .throws<ArgumentError>();
    });
  });

  group('package:data/numeric.dart exports', () {
    test('provides linearSpaced, logarithmicSpaced, geometricSpaced', () {
      final v1 = numeric.linearSpaced(0.0, 1.0, count: 5);
      check(v1.length).equals(5);
      final v2 = numeric.logarithmicSpaced(0.0, 3.0, count: 4);
      check(v2.length).equals(4);
      final v3 = numeric.geometricSpaced(1.0, 100.0, count: 3);
      check(v3.length).equals(3);
    });
  });
}

double _tan(double x) => _sin(x) / _cos(x);

double _sin(double x) {
  // Reduce x mod 2*pi
  const twoPi = 6.283185307179586;
  var u = x % twoPi;
  if (u > 3.141592653589793) u -= twoPi;
  if (u < -3.141592653589793) u += twoPi;
  var term = u;
  var sum = u;
  for (var i = 1; i <= 10; i++) {
    term *= -u * u / ((2 * i) * (2 * i + 1));
    sum += term;
  }
  return sum;
}

double _cos(double x) => _sin(x + 1.5707963267948966);

double _sin10(double x) => _sin(10.0 * x);

double _sqrt(double x) {
  if (x < 0.0) return double.nan;
  if (x == 0.0) return 0.0;
  var g = x;
  for (var i = 0; i < 12; i++) {
    g = 0.5 * (g + x / g);
  }
  return g;
}
