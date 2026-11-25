import 'dart:math' as math;

import 'package:more/number.dart' show Complex;

import '../linear/decomposition/eigenvalue.dart';
import '../linear/matrix.dart';
import '../type/data_type.dart';
import 'impl/compressed_polynomial.dart';
import 'impl/dense_polynomial.dart';
import 'impl/formatting.dart';
import 'orthogonal.dart' as orthogonal;

/// 1-dimensional algebraic univariate polynomial with coefficients in [T].
///
/// Coefficients are ordered in ascending power of `x`:
/// `P(x) = c_0 + c_1 x + c_2 x^2 + ... + c_n x^n`.
abstract class Polynomial<T> {
  /// Base constructor for polynomial implementations.
  const new();

  /// Constructs a dense polynomial from [coefficients] where index `i`
  /// corresponds to the power `x^i`.
  ///
  /// Conceptually, a polynomial is a linear combination of powers of an
  /// indeterminate, such as `3 + 2x + 5x^2`. The list `[3, 2, 5]` sets the
  /// constant term to 3, the linear coefficient to 2, and the quadratic
  /// coefficient to 5. Formally, this models an element `∑ c_i x^i` of the
  /// polynomial ring `R[x]` over algebraic field `T`.
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

  /// Constructs a polynomial using [generator] for each exponent from `0` to
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

  /// Constructs a zero polynomial with degree `-1`.
  factory zero({DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    return DensePolynomial<T>.fromCoefficients(const [], type: effectiveType);
  }

  /// Constructs a monic polynomial from its [roots]:
  /// `P(x) = (x - r_1)(x - r_2)...(x - r_k)`.
  ///
  /// Conceptually, given roots where the polynomial curve crosses the
  /// horizontal axis (such as `x = 2` and `x = 3`), this constructs the
  /// factored expansion `(x - 2)(x - 3) = x^2 - 5x + 6`. Formally, it computes
  /// the polynomial expansion of the linear root factors in O(n²) time with a
  /// single coefficient allocation.
  ///
  /// ```dart
  /// final p = Polynomial<double>.fromRoots([2.0, 3.0]);
  /// // p: x^2 - 5.0x + 6.0
  /// ```
  factory fromRoots(Iterable<T> roots, {DataType<T>? type}) {
    final rootList = roots.toList(growable: false);
    final effectiveType = type ?? DataType.fromIterable(rootList);
    final field = effectiveType.field;
    final zero = field.additiveIdentity;
    final coeffs = List<T>.filled(rootList.length + 1, zero, growable: false);
    coeffs[0] = field.multiplicativeIdentity;
    for (var i = 0; i < rootList.length; i++) {
      final negRoot = field.neg(effectiveType.cast(rootList[i]));
      coeffs[i + 1] = coeffs[i];
      for (var j = i; j >= 1; j--) {
        coeffs[j] = field.add(coeffs[j - 1], field.mul(coeffs[j], negRoot));
      }
      coeffs[0] = field.mul(coeffs[0], negRoot);
    }
    return DensePolynomial<T>.fromCoefficients(coeffs, type: effectiveType);
  }

  /// The data type of the coefficients.
  DataType<T> get type;

  /// The list of coefficients from exponent `0` to [degree].
  List<T> get coefficients;

  /// The degree of this polynomial (the highest power with a non-zero
  /// coefficient), or `-1` if the polynomial is zero.
  int get degree;

  /// Whether this polynomial is identically zero ([degree] < 0).
  bool get isZero => degree < 0;

  /// Whether this polynomial is constant ([degree] <= 0), including the zero
  /// polynomial.
  bool get isConstant => degree <= 0;

  /// The number of non-zero terms in this polynomial.
  int get termCount;

  /// Returns the non-zero terms as `(exponent, coefficient)` pairs sorted by
  /// ascending exponent.
  Iterable<({int exponent, T coefficient})> get nonZeroTerms;

  /// Returns the coefficient for `x^exponent`, or zero if [exponent] is
  /// negative or beyond [degree].
  T operator [](int exponent);

  /// The leading coefficient of the polynomial (coefficient of `x^degree`),
  /// or zero if the polynomial is zero.
  T get leadingCoefficient;

  /// Evaluates `P(x)` at [x] using Horner's method (dense) or incremental
  /// binary exponentiation (sparse) in O(n) time.
  ///
  /// Conceptually, this evaluates the polynomial at a given coordinate without
  /// computing powers redundantly. Formally, Horner's algorithm computes
  /// nested multiplications `c_0 + x(c_1 + x(c_2 + ...))` ensuring minimal
  /// operation count and numerical stability.
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([1, 2, 3]); // 1 + 2x + 3x^2
  /// final y = p.evaluate(2); // 1 + 2(2) + 3(4) = 17
  /// ```
  T evaluate(T x);

  /// Evaluates `P(x)` for a numeric value [x] as a `double`.
  double evaluateDouble(num x);

  /// Evaluates `P(x)` for a complex value [x].
  Complex evaluateComplex(Complex x);

  /// Polynomial addition `P(x) + Q(x)`.
  Polynomial<T> operator +(Polynomial<T> other);

  /// Polynomial subtraction `P(x) - Q(x)`.
  Polynomial<T> operator -(Polynomial<T> other);

  /// Unary polynomial negation `-P(x)`.
  Polynomial<T> operator -();

  /// Multiplies every coefficient by [scalar].
  Polynomial<T> scale(T scalar);

  /// Polynomial multiplication `P(x) * Q(x)`.
  Polynomial<T> operator *(Polynomial<T> other);

  /// Returns this polynomial raised to the non-negative integer [exponent]
  /// via binary exponentiation.
  ///
  /// Throws a [RangeError] if [exponent] is negative.
  Polynomial<T> pow(int exponent) {
    RangeError.checkNotNegative(exponent, 'exponent');
    final field = type.field;
    final one = field.multiplicativeIdentity;
    if (exponent == 0) {
      return this is CompressedPolynomial<T>
          ? CompressedPolynomial<T>([0], [one], type: type)
          : DensePolynomial<T>.fromCoefficients([one], type: type);
    }
    if (exponent == 1 || isZero) return this;
    var res = this is CompressedPolynomial<T>
        ? CompressedPolynomial<T>([0], [one], type: type)
        : DensePolynomial<T>.fromCoefficients([one], type: type)
              as Polynomial<T>;
    var base = this;
    var e = exponent;
    while (e > 0) {
      if (e.isOdd) {
        res = res * base;
      }
      if (e > 1) {
        base = base * base;
      }
      e ~/= 2;
    }
    return res;
  }

  /// Returns a monic copy of this polynomial (`leadingCoefficient == 1`),
  /// preserving dense or compressed representation.
  ///
  /// Returns `this` if [isZero] or already monic. Throws an [UnsupportedError]
  /// if the leading coefficient is not invertible in [type].
  Polynomial<T> monic() {
    if (isZero) return this;
    final field = type.field;
    final one = field.multiplicativeIdentity;
    final lead = leadingCoefficient;
    if (lead == one) return this;
    final invLead = field.div(one, lead);
    if (invLead == field.additiveIdentity) {
      throw UnsupportedError(
        'Leading coefficient $lead is not invertible in $type.',
      );
    }
    final deg = degree;
    if (this is CompressedPolynomial<T>) {
      final exps = <int>[];
      final coeffs = <T>[];
      for (final term in nonZeroTerms) {
        exps.add(term.exponent);
        coeffs.add(
          term.exponent == deg ? one : field.div(term.coefficient, lead),
        );
      }
      return CompressedPolynomial<T>(exps, coeffs, type: type);
    }
    return DensePolynomial<T>.fromCoefficients(
      List<T>.generate(
        deg + 1,
        (i) => i == deg ? one : field.div(this[i], lead),
        growable: false,
      ),
      type: type,
    );
  }

  /// Computes the polynomial composition `(P ∘ Q)(x) = P(Q(x))` using
  /// Horner's recurrence.
  ///
  /// Conceptually, this substitutes the polynomial [other] everywhere `x`
  /// appears in this polynomial.
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([0, 0, 1]); // x^2
  /// final q = Polynomial.fromCoefficients([1, 1]); // x + 1
  /// final comp = p.compose(q); // (x + 1)^2 = 1 + 2x + x^2
  /// ```
  Polynomial<T> compose(Polynomial<T> other);

  /// Polynomial division with remainder: `A(x) = Q(x) * B(x) + R(x)`.
  ({Polynomial<T> quotient, Polynomial<T> remainder}) divide(
    Polynomial<T> divisor,
  );

  /// Returns the quotient polynomial `A(x) / B(x)`.
  Polynomial<T> operator /(Polynomial<T> divisor) => divide(divisor).quotient;

  /// Returns the remainder polynomial `A(x) mod B(x)`.
  Polynomial<T> operator %(Polynomial<T> divisor) => divide(divisor).remainder;

  /// Computes the monic greatest common divisor (GCD) using Euclid's algorithm.
  ///
  /// Throws an [ArgumentError] if [other] has a different [type] or if
  /// floating-point coefficients are non-finite. Throws an [UnsupportedError]
  /// if division over an integer ring produces an inexact remainder whose degree
  /// cannot be reduced.
  Polynomial<T> gcd(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    final isFloat = isFloatPolynomialType(type);
    if (isFloat) {
      _checkFiniteDoubleTerms(this);
      _checkFiniteDoubleTerms(other);
    }

    var a = this;
    var b = other;
    while (b.degree >= 0) {
      final rem = a % b;
      var cleanRem = rem;
      if (isFloat && rem.degree >= 0) {
        final maxA = _maxAbsDoubleTerm(a);
        final maxB = _maxAbsDoubleTerm(b);
        final tol = 1e-12 * (maxA > maxB ? maxA : maxB);
        final zero = type.field.additiveIdentity;
        if (rem is CompressedPolynomial<T>) {
          final terms = <int, T>{};
          for (final term in rem.nonZeroTerms) {
            final v = (term.coefficient as num).toDouble().abs();
            if (!v.isFinite) {
              throw ArgumentError(
                'Polynomial GCD encountered non-finite remainder.',
              );
            }
            if (v > tol) {
              terms[term.exponent] = term.coefficient;
            }
          }
          cleanRem = CompressedPolynomial<T>.fromMap(terms, type: type);
        } else {
          final cleanCoeffs = List<T>.generate(rem.degree + 1, (i) {
            final c = rem[i];
            final v = (c as num).toDouble().abs();
            if (!v.isFinite) {
              throw ArgumentError(
                'Polynomial GCD encountered non-finite remainder.',
              );
            }
            return v <= tol ? zero : c;
          }, growable: false);
          cleanRem = DensePolynomial<T>.fromCoefficients(
            cleanCoeffs,
            type: type,
          );
        }
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
      return this is CompressedPolynomial<T>
          ? CompressedPolynomial<T>.zero(type: type)
          : Polynomial<T>.zero(type: type);
    }

    final field = type.field;
    final one = field.multiplicativeIdentity;
    if (a.degree == 0) {
      return this is CompressedPolynomial<T>
          ? CompressedPolynomial<T>([0], [one], type: type)
          : DensePolynomial<T>.fromCoefficients([one], type: type);
    }

    final lead = a.leadingCoefficient;
    final result = field.div(one, lead) == field.additiveIdentity
        ? a
        : a.monic();
    return this is CompressedPolynomial<T> && result is! CompressedPolynomial<T>
        ? result.toCompressed()
        : result;
  }

  /// Computes the [order]-th formal derivative of this polynomial.
  ///
  /// Throws a [RangeError] if [order] is negative.
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([1, 2, 3]); // 1 + 2x + 3x^2
  /// final dp = p.derivative(); // 2 + 6x
  /// final d2p = p.derivative(order: 2); // 6
  /// ```
  Polynomial<T> derivative({int order = 1});

  /// Computes the formal antiderivative
  /// `∫ P(x) dx = C + c_0 x + (c_1 / 2) x^2 + ...`
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([2, 6]); // 2 + 6x
  /// final intP = p.integrate(); // 2x + 3x^2
  /// ```
  Polynomial<T> integrate([T? constant]);

  /// Computes all complex roots of this polynomial.
  ///
  /// Conceptually, this finds all values `x` where `P(x) = 0` (the zeros of the
  /// polynomial). Formally, it deflates zero roots (`x^k`), uses overflow-safe
  /// closed-form formulas for effective degrees `1` and `2`, and constructs
  /// the Frobenius companion matrix of the deflated polynomial computing its
  /// eigenvalues via Schur/QR iteration for higher degrees.
  ///
  /// Throws an [ArgumentError] if coefficients are non-numeric or non-finite,
  /// or an [UnsupportedError] if the effective degree exceeds `1000` or
  /// coefficients are complex for effective degree greater than `2`.
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

  /// Generates the Chebyshev polynomial of the first kind `T_n(x)`.
  static Polynomial<double> chebyshevT(int degree) =>
      orthogonal.chebyshevT(degree);

  /// Generates the Chebyshev polynomial of the second kind `U_n(x)`.
  static Polynomial<double> chebyshevU(int degree) =>
      orthogonal.chebyshevU(degree);

  /// Generates the Legendre polynomial `P_n(x)`.
  static Polynomial<double> legendreP(int degree) =>
      orthogonal.legendreP(degree);

  /// Generates the Physicists' Hermite polynomial `H_n(x)`.
  static Polynomial<double> hermiteH(int degree) => orthogonal.hermiteH(degree);

  /// Generates the Probabilists' Hermite polynomial `He_n(x)`.
  static Polynomial<double> hermiteHe(int degree) =>
      orthogonal.hermiteHe(degree);

  /// Generates the generalized Laguerre polynomial `L_n^(α)(x)`.
  ///
  /// Conceptually, Laguerre polynomials are orthogonal functions frequently
  /// used in quantum physics (such as modeling the radial wavefunctions of
  /// hydrogen atoms) and numerical analysis. Formally, these are classical
  /// orthogonal polynomials on `[0, ∞)` with respect to weighting measure
  /// `w(x) = x^α e^(-x)`.
  ///
  /// ```dart
  /// final l2 = Polynomial.laguerreL(2); // 1 - 2x + 0.5x^2
  /// ```
  static Polynomial<double> laguerreL(int degree, {double alpha = 0.0}) =>
      orthogonal.laguerreL(degree, alpha: alpha);

  static void _checkFiniteDoubleTerms<T>(Polynomial<T> poly) {
    for (final term in poly.nonZeroTerms) {
      if (!(term.coefficient as num).toDouble().isFinite) {
        throw ArgumentError('Polynomial coefficients must be finite.');
      }
    }
  }

  static double _maxAbsDoubleTerm<T>(Polynomial<T> poly) {
    var maxAbs = 0.0;
    for (final term in poly.nonZeroTerms) {
      final v = (term.coefficient as num).toDouble().abs();
      if (v > maxAbs) maxAbs = v;
    }
    return maxAbs;
  }

  /// Computes complex roots for [poly] by deflating zero roots and applying
  /// closed-form solutions for effective degrees <= 2 or companion matrix
  /// eigenvalue decomposition for higher degrees.
  static List<Complex> _computeRoots<T>(
    Polynomial<T> poly, {
    int maxCompanionDegree = 1000,
  }) {
    final deg = poly.degree;
    if (deg <= 0) return const [];

    Complex toFiniteComplex(T val) {
      final Complex c;
      try {
        c = coeffToComplex(val);
      } on UnsupportedError {
        throw ArgumentError(
          'Polynomial roots require numeric or complex coefficients, but found ${poly.type}.',
        );
      }
      if (!c.a.isFinite || !c.b.isFinite) {
        throw ArgumentError(
          'Polynomial coefficients must be finite to compute roots.',
        );
      }
      return c;
    }

    var minExp = deg;
    var hasComplex = false;
    var firstTerm = true;
    for (final term in poly.nonZeroTerms) {
      if (firstTerm) {
        minExp = term.exponent;
        firstTerm = false;
      }
      final c = toFiniteComplex(term.coefficient);
      if (c.b != 0.0) hasComplex = true;
    }

    final effDeg = deg - minExp;
    final zeroRoots = minExp > 0
        ? List<Complex>.filled(minExp, Complex.zero)
        : const <Complex>[];
    if (effDeg == 0) {
      return List<Complex>.of(zeroRoots, growable: false);
    }

    if (effDeg == 1) {
      final c0 = toFiniteComplex(poly[minExp]);
      final c1 = toFiniteComplex(poly[minExp + 1]);
      return [...zeroRoots, _complexDiv(-c0, c1)];
    }

    if (effDeg == 2) {
      final c0 = toFiniteComplex(poly[minExp]);
      final c1 = toFiniteComplex(poly[minExp + 1]);
      final c2 = toFiniteComplex(poly[minExp + 2]);
      if (!hasComplex) {
        var a = c2.a;
        var b = c1.a;
        var c = c0.a;
        final scale = math.max(a.abs(), math.max(b.abs(), c.abs()));
        a /= scale;
        b /= scale;
        c /= scale;
        final disc = b * b - 4.0 * a * c;
        if (disc >= 0.0) {
          final sgn = b >= 0.0 ? 1.0 : -1.0;
          final q = -0.5 * (b + sgn * math.sqrt(disc));
          final r1 = _normalizeZeroDouble(q / a);
          final r2 = q == 0.0 ? 0.0 : _normalizeZeroDouble(c / q);
          return [...zeroRoots, Complex(r1), Complex(r2)];
        } else {
          final realPart = _normalizeZeroDouble(-b / (2.0 * a));
          final imagPart = math.sqrt(-disc) / (2.0 * a).abs();
          return [
            ...zeroRoots,
            Complex(realPart, imagPart),
            Complex(realPart, -imagPart),
          ];
        }
      } else {
        final scale = math.max(
          _complexMaxComponent(c2),
          math.max(_complexMaxComponent(c1), _complexMaxComponent(c0)),
        );
        final a = Complex(c2.a / scale, c2.b / scale);
        final b = Complex(c1.a / scale, c1.b / scale);
        final c = Complex(c0.a / scale, c0.b / scale);
        final disc = b * b - const Complex(4.0) * a * c;
        final s = _complexSqrt(disc);
        final dot = b.a * s.a + b.b * s.b;
        final sign = dot >= 0.0 ? 1.0 : -1.0;
        final q = (b + s * sign) * -0.5;
        final r1 = _complexDiv(q, a);
        final r2 = (q.a == 0.0 && q.b == 0.0)
            ? Complex.zero
            : _complexDiv(c, q);
        return [...zeroRoots, r1, r2];
      }
    }

    if (effDeg > maxCompanionDegree) {
      throw UnsupportedError(
        'Roots via companion matrix eigenvalue decomposition is not supported '
        'for high-degree polynomials (effective degree $effDeg > $maxCompanionDegree).',
      );
    }
    if (hasComplex) {
      throw UnsupportedError(
        'Roots of polynomials with complex coefficients are only supported for degrees <= 2.',
      );
    }

    final lead = toFiniteComplex(poly[deg]).a;
    final companion = Matrix<double>.generate(effDeg, effDeg, (row, col) {
      if (row == effDeg - 1) {
        return -toFiniteComplex(poly[minExp + col]).a / lead;
      } else if (row + 1 == col) {
        return 1.0;
      } else {
        return 0.0;
      }
    }, type: DataType.float64);

    return [...zeroRoots, ...companion.eigenvalue.eigenvalues];
  }

  static double _normalizeZeroDouble(double v) => v == 0.0 ? 0.0 : v;

  static double _complexMaxComponent(Complex z) =>
      math.max(z.a.toDouble().abs(), z.b.toDouble().abs());

  static Complex _complexDiv(Complex numVal, Complex denVal) {
    final scale = math.max(
      _complexMaxComponent(numVal),
      _complexMaxComponent(denVal),
    );
    if (scale == 0.0) return Complex.zero;
    final n = Complex(numVal.a.toDouble() / scale, numVal.b.toDouble() / scale);
    final d = Complex(denVal.a.toDouble() / scale, denVal.b.toDouble() / scale);
    final denom = d.a * d.a + d.b * d.b;
    final re = _normalizeZeroDouble((n.a * d.a + n.b * d.b) / denom);
    final im = _normalizeZeroDouble((n.b * d.a - n.a * d.b) / denom);
    return Complex(re, im);
  }

  static Complex _complexSqrt(Complex z) {
    final u = z.a.toDouble();
    final v = z.b.toDouble();
    if (u == 0.0 && v == 0.0) return Complex.zero;
    final m = math.max(u.abs(), v.abs());
    final su = u / m;
    final sv = v / m;
    final r = m * math.sqrt(su * su + sv * sv);
    if (u >= 0.0) {
      final re = math.sqrt(0.5 * (r + u));
      final im = re == 0.0 ? 0.0 : _normalizeZeroDouble(v / (2.0 * re));
      return Complex(re, im);
    }
    final im = (v >= 0.0 ? 1.0 : -1.0) * math.sqrt(0.5 * (r - u));
    final re = _normalizeZeroDouble(v / (2.0 * im));
    return Complex(re, im);
  }
}
