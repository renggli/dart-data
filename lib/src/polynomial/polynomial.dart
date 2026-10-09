import 'dart:math' as math;

import '../../linear.dart';
import '../../type.dart';

/// 1-dimensional algebraic polynomial with coefficients in [T].
///
/// Coefficients are ordered in ascending power of $x$:
/// $P(x) = c_0 + c_1 x + c_2 x^2 + \dots + c_n x^n$.
class Polynomial<T> {
  /// Constructs a polynomial from [coefficients] where index $i$ corresponds
  /// to $x^i$.
  new fromCoefficients(Iterable<T> coefficients, {DataType<T>? type})
    : type = type ?? DataType.fromIterable(coefficients),
      _coefficients = coefficients.toList(growable: false);

  /// Constructs a polynomial using [generator] for each exponent from 0 to [degree].
  factory generate(
    int degree,
    T Function(int exponent) generator, {
    DataType<T>? type,
  }) {
    final effectiveType = type ?? DataType.fromType<T>();
    final coeffs = List<T>.generate(
      degree < 0 ? 0 : degree + 1,
      generator,
      growable: false,
    );
    return Polynomial.fromCoefficients(coeffs, type: effectiveType);
  }

  /// Constructs a zero polynomial with degree -1.
  factory zero({DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    return Polynomial.fromCoefficients(const [], type: effectiveType);
  }

  /// Constructs a monic polynomial from its real [roots]:
  /// $P(x) = (x - r_1)(x - r_2)\dots(x - r_k)$.
  factory fromRoots(Iterable<num> roots, {DataType<T>? type}) {
    final effectiveType = (type ?? DataType.float64) as DataType<T>;
    final f = effectiveType.field;
    var result = Polynomial<T>.fromCoefficients([
      f.multiplicativeIdentity,
    ], type: effectiveType);
    for (final r in roots) {
      final rootVal = effectiveType.cast(r);
      final factor = Polynomial<T>.fromCoefficients([
        f.neg(rootVal),
        f.multiplicativeIdentity,
      ], type: effectiveType);
      result = result * factor;
    }
    return result;
  }

  /// The data type of the coefficients.
  final DataType<T> type;

  final List<T> _coefficients;

  /// The list of coefficients from exponent 0 to [degree].
  List<T> get coefficients => _coefficients;

  /// The degree of this polynomial (the highest power with a non-zero coefficient),
  /// or -1 if the polynomial is zero.
  int get degree {
    final f = type.field;
    final zero = f.additiveIdentity;
    for (var i = _coefficients.length - 1; i >= 0; i--) {
      if (_coefficients[i] != zero) return i;
    }
    return -1;
  }

  /// Returns the coefficient for $x^{exponent}$, or zero if beyond the stored degree.
  T operator [](int exponent) {
    if (exponent < 0 || exponent >= _coefficients.length) {
      return type.field.additiveIdentity;
    }
    return _coefficients[exponent];
  }

  /// The leading coefficient of the polynomial (coefficient of $x^{\deg(P)}$),
  /// or zero if the polynomial is empty.
  T get leadingCoefficient {
    final deg = degree;
    return deg < 0 ? type.field.additiveIdentity : _coefficients[deg];
  }

  /// Evaluates $P(x)$ at [x] using Horner's method.
  T evaluate(T x) {
    final deg = degree;
    if (deg < 0) return type.field.additiveIdentity;
    final f = type.field;
    var acc = _coefficients[deg];
    for (var i = deg - 1; i >= 0; i--) {
      acc = f.add(f.mul(acc, x), _coefficients[i]);
    }
    return acc;
  }

  /// Evaluates $P(x)$ for a numeric value [x] as a double.
  double evaluateDouble(num x) {
    final deg = degree;
    if (deg < 0) return 0.0;
    final xd = x.toDouble();
    var acc = (this[deg] as num).toDouble();
    for (var i = deg - 1; i >= 0; i--) {
      acc = acc * xd + (this[i] as num).toDouble();
    }
    return acc;
  }

  /// Evaluates $P(x)$ for a complex value [x].
  Complex evaluateComplex(Complex x) {
    final deg = degree;
    if (deg < 0) return Complex.zero;
    var acc = Complex((this[deg] as num).toDouble());
    for (var i = deg - 1; i >= 0; i--) {
      acc = acc * x + Complex((this[i] as num).toDouble());
    }
    return acc;
  }

  /// Polynomial addition $P(x) + Q(x)$.
  Polynomial<T> operator +(Polynomial<T> other) {
    final f = type.field;
    final maxLen = math.max(_coefficients.length, other._coefficients.length);
    final newCoeffs = List<T>.generate(
      maxLen,
      (i) => f.add(this[i], other[i]),
      growable: false,
    );
    return Polynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  /// Polynomial subtraction $P(x) - Q(x)$.
  Polynomial<T> operator -(Polynomial<T> other) {
    final f = type.field;
    final maxLen = math.max(_coefficients.length, other._coefficients.length);
    final newCoeffs = List<T>.generate(
      maxLen,
      (i) => f.sub(this[i], other[i]),
      growable: false,
    );
    return Polynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  /// Unary polynomial negation $-P(x)$.
  Polynomial<T> operator -() {
    final f = type.field;
    final newCoeffs = List<T>.generate(
      _coefficients.length,
      (i) => f.neg(_coefficients[i]),
      growable: false,
    );
    return Polynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  /// Multiplies every coefficient by [scalar].
  Polynomial<T> scale(T scalar) {
    final f = type.field;
    final newCoeffs = List<T>.generate(
      _coefficients.length,
      (i) => f.mul(_coefficients[i], scalar),
      growable: false,
    );
    return Polynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  /// Polynomial multiplication $P(x) \cdot Q(x)$.
  Polynomial<T> operator *(Polynomial<T> other) {
    final deg1 = degree;
    final deg2 = other.degree;
    if (deg1 < 0 || deg2 < 0) return Polynomial<T>.zero(type: type);

    final f = type.field;
    final outDegree = deg1 + deg2;
    final resultCoeffs = List<T>.filled(
      outDegree + 1,
      f.additiveIdentity,
      growable: false,
    );

    for (var i = 0; i <= deg1; i++) {
      final ci = this[i];
      if (ci == f.additiveIdentity) continue;
      for (var j = 0; j <= deg2; j++) {
        final cj = other[j];
        if (cj == f.additiveIdentity) continue;
        resultCoeffs[i + j] = f.add(resultCoeffs[i + j], f.mul(ci, cj));
      }
    }

    return Polynomial<T>.fromCoefficients(resultCoeffs, type: type);
  }

  /// Polynomial division with remainder: $A(x) = Q(x) \cdot B(x) + R(x)$.
  ({Polynomial<T> quotient, Polynomial<T> remainder}) divide(
    Polynomial<T> divisor,
  ) {
    final degB = divisor.degree;
    if (degB < 0) {
      throw UnsupportedError('Division by zero polynomial.');
    }
    final degA = degree;
    if (degA < degB) {
      return (quotient: Polynomial<T>.zero(type: type), remainder: this);
    }

    final f = type.field;
    final leadB = divisor.leadingCoefficient;
    final qCoeffs = List<T>.filled(
      degA - degB + 1,
      f.additiveIdentity,
      growable: false,
    );
    final rCoeffs = List<T>.generate(degA + 1, (i) => this[i]);

    for (var i = degA; i >= degB; i--) {
      final curCoeff = rCoeffs[i];
      if (curCoeff != f.additiveIdentity) {
        final factor = f.div(curCoeff, leadB);
        final qIdx = i - degB;
        qCoeffs[qIdx] = factor;
        for (var j = 0; j <= degB; j++) {
          final term = f.mul(factor, divisor[j]);
          rCoeffs[qIdx + j] = f.sub(rCoeffs[qIdx + j], term);
        }
      }
    }

    return (
      quotient: Polynomial<T>.fromCoefficients(qCoeffs, type: type),
      remainder: Polynomial<T>.fromCoefficients(rCoeffs, type: type),
    );
  }

  /// Returns the quotient polynomial $A(x) / B(x)$.
  Polynomial<T> operator /(Polynomial<T> divisor) => divide(divisor).quotient;

  /// Returns the remainder polynomial $A(x) \pmod{B(x)}$.
  Polynomial<T> operator %(Polynomial<T> divisor) => divide(divisor).remainder;

  /// Computes the monic greatest common divisor (GCD) using Euclid's algorithm.
  Polynomial<T> gcd(Polynomial<T> other) {
    var a = this;
    var b = other;
    while (b.degree >= 0) {
      final r = a % b;
      a = b;
      b = r;
    }
    if (a.degree <= 0) {
      return Polynomial<T>.fromCoefficients([
        type.field.multiplicativeIdentity,
      ], type: type);
    }
    // Make monic
    final lead = a.leadingCoefficient;
    final invLead = type.field.div(type.field.multiplicativeIdentity, lead);
    return a.scale(invLead);
  }

  /// Computes the formal derivative $P'(x) = c_1 + 2 c_2 x + 3 c_3 x^2 + \dots$
  Polynomial<T> differentiate() {
    final deg = degree;
    if (deg <= 0) return Polynomial<T>.zero(type: type);

    final f = type.field;
    final newCoeffs = List<T>.generate(deg, (i) {
      final exp = i + 1;
      return f.scale(this[exp], exp.toDouble());
    }, growable: false);

    return Polynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  /// Computes the formal antiderivative $\int P(x) dx = C + c_0 x + \frac{c_1}{2} x^2 + \dots$
  Polynomial<T> integrate([T? constant]) {
    final f = type.field;
    final c0 = constant ?? f.additiveIdentity;
    final deg = degree;
    if (deg < 0) {
      return Polynomial<T>.fromCoefficients([c0], type: type);
    }

    final newCoeffs = List<T>.filled(
      deg + 2,
      f.additiveIdentity,
      growable: false,
    );
    newCoeffs[0] = c0;
    for (var i = 0; i <= deg; i++) {
      final denom = (i + 1).toDouble();
      final scaled = f.scale(this[i], 1.0 / denom);
      newCoeffs[i + 1] = scaled;
    }

    return Polynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  /// Computes the complex roots of this polynomial.
  List<Complex> get roots {
    final deg = degree;
    if (deg <= 0) return const [];
    if (deg == 1) {
      final c0 = (this[0] as num).toDouble();
      final c1 = (this[1] as num).toDouble();
      return [Complex(-c0 / c1)];
    }
    if (deg == 2) {
      final c0 = (this[0] as num).toDouble();
      final c1 = (this[1] as num).toDouble();
      final c2 = (this[2] as num).toDouble();
      final disc = c1 * c1 - 4.0 * c2 * c0;
      if (disc >= 0) {
        final sqrtDisc = math.sqrt(disc);
        return [
          Complex((-c1 + sqrtDisc) / (2.0 * c2)),
          Complex((-c1 - sqrtDisc) / (2.0 * c2)),
        ];
      } else {
        final realPart = -c1 / (2.0 * c2);
        final imagPart = math.sqrt(-disc) / (2.0 * c2);
        return [Complex(realPart, imagPart), Complex(realPart, -imagPart)];
      }
    }

    // High degree: companion matrix eigenvalue decomposition
    final lead = (this[deg] as num).toDouble();
    final companion = Matrix<double>.generate(deg, deg, (r, c) {
      if (r == deg - 1) {
        return -(this[c] as num).toDouble() / lead;
      } else if (r + 1 == c) {
        return 1.0;
      } else {
        return 0.0;
      }
    }, type: DataType.float64);

    return companion.eigenvalue.eigenvalues;
  }

  /// Generates the Chebyshev polynomial of the first kind $T_n(x)$.
  static Polynomial<double> chebyshevT(int n) {
    if (n < 0) throw ArgumentError('Degree must be non-negative: $n');
    if (n == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (n == 1) {
      return Polynomial<double>.fromCoefficients([
        0.0,
        1.0,
      ], type: DataType.float64);
    }
    var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    var p1 = Polynomial<double>.fromCoefficients([
      0.0,
      1.0,
    ], type: DataType.float64);
    final twoX = Polynomial<double>.fromCoefficients([
      0.0,
      2.0,
    ], type: DataType.float64);

    for (var k = 2; k <= n; k++) {
      final pNext = twoX * p1 - p0;
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Generates the Chebyshev polynomial of the second kind $U_n(x)$.
  static Polynomial<double> chebyshevU(int n) {
    if (n < 0) throw ArgumentError('Degree must be non-negative: $n');
    if (n == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (n == 1) {
      return Polynomial<double>.fromCoefficients([
        0.0,
        2.0,
      ], type: DataType.float64);
    }
    var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    var p1 = Polynomial<double>.fromCoefficients([
      0.0,
      2.0,
    ], type: DataType.float64);
    final twoX = Polynomial<double>.fromCoefficients([
      0.0,
      2.0,
    ], type: DataType.float64);

    for (var k = 2; k <= n; k++) {
      final pNext = twoX * p1 - p0;
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Generates the Legendre polynomial $P_n(x)$.
  static Polynomial<double> legendreP(int n) {
    if (n < 0) throw ArgumentError('Degree must be non-negative: $n');
    if (n == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (n == 1) {
      return Polynomial<double>.fromCoefficients([
        0.0,
        1.0,
      ], type: DataType.float64);
    }
    var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    var p1 = Polynomial<double>.fromCoefficients([
      0.0,
      1.0,
    ], type: DataType.float64);

    for (var k = 1; k < n; k++) {
      final alpha = (2.0 * k + 1.0) / (k + 1.0);
      final gamma = k.toDouble() / (k + 1.0);
      final alphaX = Polynomial<double>.fromCoefficients([
        0.0,
        alpha,
      ], type: DataType.float64);
      final pNext = alphaX * p1 - p0.scale(gamma);
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Generates the Physicists' Hermite polynomial $H_n(x)$.
  static Polynomial<double> hermiteH(int n) {
    if (n < 0) throw ArgumentError('Degree must be non-negative: $n');
    if (n == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (n == 1) {
      return Polynomial<double>.fromCoefficients([
        0.0,
        2.0,
      ], type: DataType.float64);
    }
    var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    var p1 = Polynomial<double>.fromCoefficients([
      0.0,
      2.0,
    ], type: DataType.float64);
    final twoX = Polynomial<double>.fromCoefficients([
      0.0,
      2.0,
    ], type: DataType.float64);

    for (var k = 1; k < n; k++) {
      final pNext = twoX * p1 - p0.scale(2.0 * k);
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Generates the Probabilists' Hermite polynomial $He_n(x)$.
  static Polynomial<double> hermiteHe(int n) {
    if (n < 0) throw ArgumentError('Degree must be non-negative: $n');
    if (n == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (n == 1) {
      return Polynomial<double>.fromCoefficients([
        0.0,
        1.0,
      ], type: DataType.float64);
    }
    var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    var p1 = Polynomial<double>.fromCoefficients([
      0.0,
      1.0,
    ], type: DataType.float64);
    final x = Polynomial<double>.fromCoefficients([
      0.0,
      1.0,
    ], type: DataType.float64);

    for (var k = 1; k < n; k++) {
      final pNext = x * p1 - p0.scale(k.toDouble());
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  @override
  String toString() {
    final deg = degree;
    if (deg < 0) return '0';
    final parts = <String>[];
    for (var i = deg; i >= 0; i--) {
      final c = this[i];
      if (c == type.field.additiveIdentity && deg > 0) continue;
      if (i == 0) {
        parts.add('$c');
      } else if (i == 1) {
        parts.add(c == type.field.multiplicativeIdentity ? 'x' : '${c}x');
      } else {
        parts.add(c == type.field.multiplicativeIdentity ? 'x^$i' : '${c}x^$i');
      }
    }
    return parts.join(' + ');
  }
}
