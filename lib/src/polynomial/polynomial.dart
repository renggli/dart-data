import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../linear/decomposition/eigenvalue.dart';
import '../linear/matrix.dart';
import '../type/data_type.dart';
import 'impl/compressed_polynomial.dart';
import 'impl/dense_polynomial.dart';
import 'impl/formatting.dart';

/// 1-dimensional algebraic univariate polynomial with coefficients in [T].
///
/// Coefficients are ordered in ascending power of $x$:
/// $P(x) = c_0 + c_1 x + c_2 x^2 + \dots + c_n x^n$.
abstract class Polynomial<T> {
  /// Base constructor for polynomial implementations.
  const new();

  /// Constructs a dense polynomial from [coefficients] where index $i$
  /// corresponds to the power $x^i$.
  ///
  /// Conceptually, a polynomial is a linear combination of powers of an
  /// indeterminate, such as $3 + 2x + 5x^2$. The list `[3, 2, 5]` sets the
  /// constant term to 3, the linear coefficient to 2, and the quadratic
  /// coefficient to 5. Formally, this models an element $\sum_{i=0}^n c_i x^i$
  /// of the polynomial ring $R\[x\]$ over algebraic field $T$.
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([3, 2, 5]); // 3 + 2x + 5x^2
  /// ```
  factory fromCoefficients(Iterable<T> coefficients, {DataType<T>? type}) =
      DensePolynomial<T>.fromCoefficients;

  /// Constructs a sparse compressed polynomial from [entries] mapping exponents
  /// to non-zero coefficients.
  ///
  /// ```dart
  /// final p = Polynomial<double>.sparse({0: -1.0, 10000: 1.0}); // x^10000 - 1
  /// ```
  factory sparse(Map<int, T> entries, {DataType<T>? type}) =
      CompressedPolynomial<T>.fromMap;

  /// Constructs a sparse compressed polynomial from parallel [exponents] and
  /// [coefficients].
  ///
  /// ```dart
  /// final p = Polynomial<double>.compressed(
  ///   [0, 10000],
  ///   [-1.0, 1.0],
  /// ); // x^10000 - 1
  /// ```
  factory compressed(
    Iterable<int> exponents,
    Iterable<T> coefficients, {
    DataType<T>? type,
  }) = CompressedPolynomial<T>;

  /// Constructs a polynomial using [generator] for each exponent from 0 to
  /// [degree].
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
    return DensePolynomial<T>.fromCoefficients(coeffs, type: effectiveType);
  }

  /// Constructs a zero polynomial with degree -1.
  factory zero({DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    return DensePolynomial<T>.fromCoefficients(const [], type: effectiveType);
  }

  /// Constructs a monic polynomial from its real [roots]:
  /// $P(x) = (x - r_1)(x - r_2)\dots(x - r_k)$.
  ///
  /// Conceptually, given roots where the polynomial curve crosses the
  /// horizontal axis (such as $x = 2$ and $x = 3$), this constructs the
  /// factored expansion $(x - 2)(x - 3) = x^2 - 5x + 6$. Formally, it computes
  /// the polynomial expansion of the linear root factors by sequential
  /// convolution.
  ///
  /// ```dart
  /// final p = Polynomial<double>.fromRoots([2.0, 3.0]);
  /// // p: 6.0 - 5.0*x + 1.0*x^2
  /// ```
  factory fromRoots(Iterable<T> roots, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromIterable(roots);
    final field = effectiveType.field;
    var result = Polynomial<T>.fromCoefficients([
      field.multiplicativeIdentity,
    ], type: effectiveType);
    for (final root in roots) {
      final rootVal = effectiveType.cast(root);
      final factor = Polynomial<T>.fromCoefficients([
        field.neg(rootVal),
        field.multiplicativeIdentity,
      ], type: effectiveType);
      result = result * factor;
    }
    return result;
  }

  /// The data type of the coefficients.
  DataType<T> get type;

  /// The list of coefficients from exponent 0 to [degree].
  List<T> get coefficients;

  /// The degree of this polynomial (the highest power with a non-zero
  /// coefficient), or -1 if the polynomial is zero.
  int get degree;

  /// The number of non-zero terms in this polynomial.
  int get termCount;

  /// Returns the coefficient for $x^{exponent}$, or zero if beyond the stored
  /// degree.
  T operator [](int exponent);

  /// The leading coefficient of the polynomial (coefficient of $x^{\deg(P)}$),
  /// or zero if the polynomial is empty.
  T get leadingCoefficient;

  /// Evaluates $P(x)$ at [x] using Horner's method or binary exponentiation in
  /// $\mathcal{O}(n)$ time.
  ///
  /// Conceptually, this evaluates the polynomial at a given coordinate without
  /// computing powers explicitly. Formally, Horner's algorithm computes nested
  /// multiplications $c_0 + x(c_1 + x(c_2 + \dots))$ ensuring minimal operation
  /// count and numerical stability.
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([1, 2, 3]); // 1 + 2x + 3x^2
  /// final y = p.evaluate(2); // 1 + 2(2) + 3(4) = 17
  /// ```
  T evaluate(T x);

  /// Evaluates $P(x)$ for a numeric value [x] as a double.
  double evaluateDouble(num x);

  /// Evaluates $P(x)$ for a complex value [x].
  Complex evaluateComplex(Complex x);

  /// Polynomial addition $P(x) + Q(x)$.
  Polynomial<T> operator +(Polynomial<T> other);

  /// Polynomial subtraction $P(x) - Q(x)$.
  Polynomial<T> operator -(Polynomial<T> other);

  /// Unary polynomial negation $-P(x)$.
  Polynomial<T> operator -();

  /// Multiplies every coefficient by [scalar].
  Polynomial<T> scale(T scalar);

  /// Polynomial multiplication $P(x) \cdot Q(x)$.
  Polynomial<T> operator *(Polynomial<T> other);

  /// Computes the polynomial composition $(P \circ Q)(x) = P(Q(x))$ using
  /// Horner's recurrence.
  ///
  /// Conceptually, this substitutes the polynomial [other] everywhere $x$
  /// appears in this polynomial.
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([0, 0, 1]); // x^2
  /// final q = Polynomial.fromCoefficients([1, 1]); // x + 1
  /// final comp = p.compose(q); // (x + 1)^2 = 1 + 2x + x^2
  /// ```
  Polynomial<T> compose(Polynomial<T> other);

  /// Polynomial division with remainder: $A(x) = Q(x) \cdot B(x) + R(x)$.
  ({Polynomial<T> quotient, Polynomial<T> remainder}) divide(
    Polynomial<T> divisor,
  );

  /// Returns the quotient polynomial $A(x) / B(x)$.
  Polynomial<T> operator /(Polynomial<T> divisor) => divide(divisor).quotient;

  /// Returns the remainder polynomial $A(x) \pmod{B(x)}$.
  Polynomial<T> operator %(Polynomial<T> divisor) => divide(divisor).remainder;

  /// Computes the monic greatest common divisor (GCD) using Euclid's algorithm.
  Polynomial<T> gcd(Polynomial<T> other) {
    var a = this;
    var b = other;
    while (b.degree >= 0) {
      final rem = a % b;
      var cleanRem = rem;
      if (type.defaultValue is double && rem.degree >= 0) {
        var maxA = 0.0;
        for (var i = 0; i <= a.degree; i++) {
          final v = (a[i] as num).toDouble().abs();
          if (v > maxA) maxA = v;
        }
        var maxB = 0.0;
        for (var i = 0; i <= b.degree; i++) {
          final v = (b[i] as num).toDouble().abs();
          if (v > maxB) maxB = v;
        }
        final tol = 1e-12 * (maxA > maxB ? maxA : maxB);
        final field = type.field;
        final zero = field.additiveIdentity;
        final cleanCoeffs = List<T>.generate(rem.degree + 1, (i) {
          final c = rem[i];
          return (c as num).toDouble().abs() <= tol ? zero : c;
        });
        cleanRem = Polynomial<T>.fromCoefficients(cleanCoeffs, type: type);
      }
      if (cleanRem.degree >= b.degree) {
        throw UnsupportedError(
          'Polynomial GCD requires exact division or pseudo-division over field/ring.',
        );
      }
      a = b;
      b = cleanRem;
    }
    if (a.degree < 0) {
      return Polynomial<T>.zero(type: type);
    }
    final field = type.field;
    final one = field.multiplicativeIdentity;
    if (a.degree == 0) {
      return Polynomial<T>.fromCoefficients([one], type: type);
    }
    // Make monic
    final lead = a.leadingCoefficient;
    if (lead == one || lead == field.additiveIdentity) {
      return a;
    }
    final invLead = field.div(one, lead);
    if (invLead == field.additiveIdentity) {
      return a;
    }
    if (a is CompressedPolynomial<T>) {
      return CompressedPolynomial<T>(
        a.nonZeroTerms.map((t) => t.exponent),
        a.nonZeroTerms.map(
          (t) => t.exponent == a.degree ? one : field.div(t.coefficient, lead),
        ),
        type: type,
      );
    }
    return DensePolynomial<T>.fromCoefficients(
      List<T>.generate(
        a.degree + 1,
        (i) => i == a.degree ? one : field.div(a[i], lead),
        growable: false,
      ),
      type: type,
    );
  }

  /// Computes the formal derivative $P'(x) = c_1 + 2 c_2 x + 3 c_3 x^2 + \dots$
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([1, 2, 3]); // 1 + 2x + 3x^2
  /// final dp = p.derivative(); // 2 + 6x
  /// ```
  Polynomial<T> derivative();

  /// Computes the formal antiderivative
  /// $\int P(x) dx = C + c_0 x + \frac{c_1}{2} x^2 + \dots$
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([2, 6]); // 2 + 6x
  /// final intP = p.integrate(); // 2x + 3x^2
  /// ```
  Polynomial<T> integrate([T? constant]);

  /// Computes all complex roots of this polynomial.
  ///
  /// Conceptually, this finds all values $x$ where $P(x) = 0$ (the zeros of the
  /// polynomial). Formally, it uses the closed-form quadratic formula for
  /// degree 2, and constructs the Frobenius companion matrix computing its
  /// eigenvalues via Schur/QR iteration for higher degrees.
  ///
  /// ```dart
  /// final p = Polynomial<double>.fromCoefficients(
  ///   [-4.0, 0.0, 1.0],
  /// ); // x^2 - 4
  /// final r = p.roots; // [Complex(-2.0), Complex(2.0)]
  /// ```
  List<Complex> get roots => _computeRoots(this);

  /// Converts this polynomial to a sparse [CompressedPolynomial].
  CompressedPolynomial<T> toCompressed();

  /// Converts this polynomial to a [DensePolynomial].
  DensePolynomial<T> toDense();

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Polynomial<T> || type != other.type) return false;
    final deg = degree;
    if (deg != other.degree) return false;
    if (deg < 0) return true;
    for (var i = 0; i <= deg; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final deg = degree;
    var hash = Object.hash(deg, type);
    if (deg < 0) return hash;
    final zero = type.field.additiveIdentity;
    for (var i = 0; i <= deg; i++) {
      final c = this[i];
      if (c != zero) {
        hash = Object.hash(hash, i, c);
      }
    }
    return hash;
  }

  /// Generates the Chebyshev polynomial of the first kind $T_n(x)$.
  static Polynomial<double> chebyshevT(int degree) {
    if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
    if (degree == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (degree == 1) {
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

    for (var k = 2; k <= degree; k++) {
      final pNext = twoX * p1 - p0;
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Generates the Chebyshev polynomial of the second kind $U_n(x)$.
  static Polynomial<double> chebyshevU(int degree) {
    if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
    if (degree == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (degree == 1) {
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

    for (var k = 2; k <= degree; k++) {
      final pNext = twoX * p1 - p0;
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Generates the Legendre polynomial $P_n(x)$.
  static Polynomial<double> legendreP(int degree) {
    if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
    if (degree == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (degree == 1) {
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

    for (var k = 1; k < degree; k++) {
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
  static Polynomial<double> hermiteH(int degree) {
    if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
    if (degree == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (degree == 1) {
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

    for (var k = 1; k < degree; k++) {
      final pNext = twoX * p1 - p0.scale(2.0 * k);
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Generates the Probabilists' Hermite polynomial $He_n(x)$.
  static Polynomial<double> hermiteHe(int degree) {
    if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
    if (degree == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (degree == 1) {
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

    for (var k = 1; k < degree; k++) {
      final pNext = x * p1 - p0.scale(k.toDouble());
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Generates the generalized Laguerre polynomial $L_n^{(\alpha)}(x)$.
  ///
  /// Conceptually, Laguerre polynomials are orthogonal functions frequently
  /// used in quantum physics (such as modeling the radial wavefunctions of
  /// hydrogen atoms) and numerical analysis. Formally, these are classical
  /// orthogonal polynomials on $[0, \infty)$ with respect to weighting measure
  /// $w(x) = x^\alpha e^{-x}$.
  ///
  /// ```dart
  /// final l2 = Polynomial.laguerreL(2); // 1 - 2x + 0.5x^2
  /// ```
  static Polynomial<double> laguerreL(int degree, {double alpha = 0.0}) {
    if (degree < 0) throw ArgumentError('Degree must be non-negative: $degree');
    if (degree == 0) {
      return Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    }
    if (degree == 1) {
      return Polynomial<double>.fromCoefficients([
        1.0 + alpha,
        -1.0,
      ], type: DataType.float64);
    }
    var p0 = Polynomial<double>.fromCoefficients([1.0], type: DataType.float64);
    var p1 = Polynomial<double>.fromCoefficients([
      1.0 + alpha,
      -1.0,
    ], type: DataType.float64);

    for (var k = 1; k < degree; k++) {
      final term1 = Polynomial<double>.fromCoefficients([
        2.0 * k + 1.0 + alpha,
        -1.0,
      ], type: DataType.float64);
      final pNext = (term1 * p1 - p0.scale(k + alpha)).scale(1.0 / (k + 1.0));
      p0 = p1;
      p1 = pNext;
    }
    return p1;
  }

  /// Computes complex roots for [poly] using closed-form solutions for low degrees
  /// and Frobenius companion matrix eigenvalue decomposition for higher degrees.
  static List<Complex> _computeRoots<T>(
    Polynomial<T> poly, {
    int maxCompanionDegree = 1000,
  }) {
    final deg = poly.degree;
    if (deg <= 0) return const [];

    Complex toComplex(T val) {
      try {
        return coeffToComplex(val);
      } on UnsupportedError {
        throw ArgumentError(
          'Polynomial roots require numeric or complex coefficients, but found ${poly.type}.',
        );
      }
    }

    if (deg == 1) {
      final c0 = toComplex(poly[0]);
      final c1 = toComplex(poly[1]);
      if (c1 == Complex.zero) {
        throw ArgumentError('Leading coefficient cannot be zero.');
      }
      return [-c0 / c1];
    }
    if (deg == 2) {
      final c0 = toComplex(poly[0]);
      final c1 = toComplex(poly[1]);
      final c2 = toComplex(poly[2]);
      if (c2 == Complex.zero) {
        throw ArgumentError('Leading coefficient cannot be zero.');
      }
      // If all coefficients are real, use numerically stable real q formula.
      if (c0.b == 0.0 && c1.b == 0.0 && c2.b == 0.0) {
        final a = c2.a;
        final b = c1.a;
        final c = c0.a;
        final disc = b * b - 4.0 * a * c;
        if (disc >= 0) {
          final sgn = b >= 0 ? 1.0 : -1.0;
          final q = -0.5 * (b + sgn * math.sqrt(disc));
          final r1 = q / a;
          final r2 = (q == 0.0) ? 0.0 : c / q;
          return [Complex(r1), Complex(r2)];
        } else {
          final realPart = -b / (2.0 * a);
          final imagPart = math.sqrt(-disc) / (2.0 * a);
          return [Complex(realPart, imagPart), Complex(realPart, -imagPart)];
        }
      } else {
        // Complex coefficients: discriminant in C and sign-aligned q formula
        final disc = c1 * c1 - const Complex(4.0) * c2 * c0;
        final s = _complexSqrt(disc);
        final dot = c1.a * s.a + c1.b * s.b;
        final sign = dot >= 0 ? 1.0 : -1.0;
        final q = (c1 + s * sign) * -0.5;
        final r1 = q / c2;
        final r2 = (q.a == 0.0 && q.b == 0.0) ? Complex.zero : c0 / q;
        return [r1, r2];
      }
    }
    if (deg > maxCompanionDegree) {
      throw UnsupportedError(
        'Roots via companion matrix eigenvalue decomposition is not supported '
        'for high-degree sparse polynomials (degree $deg > $maxCompanionDegree).',
      );
    }
    for (var i = 0; i <= deg; i++) {
      if (toComplex(poly[i]).b != 0.0) {
        throw UnsupportedError(
          'Roots of polynomials with complex coefficients are only supported for degrees <= 2.',
        );
      }
    }
    final lead = toComplex(poly[deg]).a;
    final companion = Matrix<double>.generate(deg, deg, (row, col) {
      if (row == deg - 1) {
        return -toComplex(poly[col]).a / lead;
      } else if (row + 1 == col) {
        return 1.0;
      } else {
        return 0.0;
      }
    }, type: DataType.float64);

    return companion.eigenvalue.eigenvalues;
  }

  static Complex _complexSqrt(Complex z) {
    if (z.b == 0.0) {
      if (z.a >= 0.0) return Complex(math.sqrt(z.a));
      return Complex(0.0, math.sqrt(-z.a));
    }
    final r = math.sqrt(z.a * z.a + z.b * z.b);
    final theta = math.atan2(z.b, z.a);
    final sqrtR = math.sqrt(r);
    return Complex(
      sqrtR * math.cos(theta / 2.0),
      sqrtR * math.sin(theta / 2.0),
    );
  }
}
