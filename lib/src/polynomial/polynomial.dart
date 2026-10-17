import '../../symbolic.dart';
import '../../type.dart';
import 'impl/compressed_polynomial.dart';
import 'impl/dense_polynomial.dart';
import 'orthogonal.dart' as orthogonal;

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
  factory fromRoots(Iterable<num> roots, {DataType<T>? type}) {
    final effectiveType = (type ?? DataType.float64) as DataType<T>;
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

  /// Constructs a polynomial from a symbolic [expr] by computing its Taylor
  /// expansion with respect to [variable] up to [order] around [around].
  ///
  /// Conceptually, this converts a symbolic algebraic expression into a
  /// polynomial approximation. Formally, it maps an analytic function to its
  /// truncated Taylor series representation.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final p = Polynomial<double>.fromExpr(Exp(x), 'x', order: 2);
  /// // coefficients: [1.0, 1.0, 0.5]
  /// ```
  factory fromExpr(
    Expr expr,
    String variable, {
    double around = 0.0,
    int order = 4,
    DataType<T>? type,
  }) {
    final effectiveType = (type ?? DataType.float64) as DataType<T>;
    final field = effectiveType.field;
    if (order < 0) {
      return Polynomial<T>.zero(type: effectiveType);
    }
    if (around == 0.0) {
      final coeffs = List<T>.filled(order + 1, field.additiveIdentity);
      var currentDeriv = expr;
      var factorial = 1.0;
      for (var k = 0; k <= order; k++) {
        if (k > 0) {
          currentDeriv = currentDeriv.derivative(variable);
          factorial *= k;
        }
        final valExpr = currentDeriv
            .substitute(variable, IntegerNumber.zero)
            .simplify();
        final val = valExpr is Number
            ? valExpr.toDouble()
            : valExpr.evaluate(const {});
        coeffs[k] = effectiveType.cast(val / factorial);
      }
      return Polynomial<T>.fromCoefficients(coeffs, type: effectiveType);
    } else {
      var result = Polynomial<T>.zero(type: effectiveType);
      final xMinusA = Polynomial<T>.fromCoefficients([
        effectiveType.cast(-around),
        field.multiplicativeIdentity,
      ], type: effectiveType);
      var currentPower = Polynomial<T>.fromCoefficients([
        field.multiplicativeIdentity,
      ], type: effectiveType);
      var currentDeriv = expr;
      var factorial = 1.0;
      for (var k = 0; k <= order; k++) {
        if (k > 0) {
          currentDeriv = currentDeriv.derivative(variable);
          factorial *= k;
        }
        final valExpr = currentDeriv
            .substitute(variable, RealNumber(around).rationalize())
            .simplify();
        final val = valExpr is Number
            ? valExpr.toDouble()
            : valExpr.evaluate(const {});
        final coeff = effectiveType.cast(val / factorial);
        if (coeff != field.additiveIdentity) {
          result = result + currentPower.scale(coeff);
        }
        if (k < order) {
          currentPower = currentPower * xMinusA;
        }
      }
      return result;
    }
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
      final remainder = a % b;
      a = b;
      b = remainder;
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
  ///
  /// ```dart
  /// final p = Polynomial.fromCoefficients([1, 2, 3]); // 1 + 2x + 3x^2
  /// final dp = p.differentiate(); // 2 + 6x
  /// ```
  Polynomial<T> differentiate();

  /// Computes the formal derivative $P'(x)$.
  Polynomial<T> derivative() => differentiate();

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
  List<Complex> get roots;

  /// Converts this polynomial to a sparse [CompressedPolynomial].
  CompressedPolynomial<T> toCompressed();

  /// Converts this polynomial to a [DensePolynomial].
  DensePolynomial<T> toDense();

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
  static Polynomial<double> laguerreL(int degree, {double alpha = 0.0}) =>
      orthogonal.laguerreL(degree, alpha: alpha);
}
