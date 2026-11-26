import 'dart:math' as math;

import '../../polynomial/polynomial.dart';
import '../../type/data_type.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import '../number/integer.dart';
import '../type/expr_data_type.dart';
import 'series_functions.dart';

/// Extension providing formal power series and Laurent expansion on [Expr].
extension SeriesExtension on Expr {
  /// Computes the truncated formal power series expansion of this expression
  /// around [point] up to [order], returning an [Expr] with an [OrderTerm].
  ///
  /// Conceptually, this approximates a mathematical function as a polynomial
  /// plus an asymptotic remainder term `O((x - a)^n)` tracking the truncation
  /// error. Formally, it computes the Taylor or Laurent series in the ring
  /// of formal power series `Q[[x - a]]`.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final s = Sin(x).series('x', order: 5);
  /// // x - 1/6 * x^3 + O(x^5)
  /// ```
  Expr series(
    String variable, {
    Object point = IntegerNumber.zero,
    int order = 6,
    bool includeOrder = true,
    Assumptions assumptions = Assumptions.none,
  }) => toPowerSeries(
    variable,
    point: point,
    order: order,
    assumptions: assumptions,
  ).toExpr(includeOrder: includeOrder);

  /// Computes the truncated formal [PowerSeries] representation of this
  /// expression around [point] up to [order].
  PowerSeries toPowerSeries(
    String variable, {
    Object point = IntegerNumber.zero,
    int order = 6,
    Assumptions assumptions = Assumptions.none,
  }) {
    final pointExpr = Expr.wrap(point);
    final result = expandToPowerSeries(
      assumptions.isEmpty ? this : simplify(assumptions: assumptions),
      variable,
      pointExpr,
      order,
      assumptions,
    );
    return result.order > order
        ? PowerSeries(variable, result.point, result.coefficients, order)
        : result;
  }

  /// Converts this symbolic expression into a [Polynomial] approximation by
  /// computing its Taylor expansion with respect to [variable] up to [order]
  /// around [point].
  ///
  /// Conceptually, this converts a symbolic algebraic expression into a
  /// polynomial approximation. Formally, it maps an analytic function to its
  /// truncated Taylor series representation.
  ///
  /// ```dart
  /// final x = Variable('x');
  /// final p = Pow(Constant.e, x).toPolynomial('x', order: 2);
  /// // coefficients: [1.0, 1.0, 0.5]
  /// ```
  Polynomial<T> toPolynomial<T>(
    String variable, {
    num point = 0,
    int order = 5,
    DataType<T>? type,
  }) {
    final effectiveType = (type ?? DataType.float64) as DataType<T>;
    final field = effectiveType.field;
    if (order < 0) {
      return Polynomial<T>.zero(type: effectiveType);
    }
    final around = point.toDouble();
    final pointExpr = Expr.wrap(point);
    final ps = toPowerSeries(variable, point: pointExpr, order: order + 1);
    if (ps.poleOrder > 0) {
      throw UnsupportedError(
        'Cannot convert Laurent series with pole to Polynomial',
      );
    }
    if (around == 0.0) {
      final coeffs = List<T>.filled(order + 1, field.additiveIdentity);
      for (var k = 0; k <= order; k++) {
        final cExpr = ps.coefficients[k];
        if (cExpr != null) {
          if (cExpr is T) {
            coeffs[k] = effectiveType.cast(cExpr);
          } else {
            final val = cExpr is Number
                ? cExpr.toDouble()
                : cExpr.evaluate(const {});
            coeffs[k] = effectiveType.cast(val);
          }
        }
      }
      return Polynomial<T>.fromCoefficients(coeffs, type: effectiveType);
    } else {
      var result = Polynomial<T>.zero(type: effectiveType);
      final negCenter = (-pointExpr).simplify();
      final negCenterTerm = negCenter is T
          ? effectiveType.cast(negCenter)
          : effectiveType.cast(-around);
      final xMinusA = Polynomial<T>.fromCoefficients([
        negCenterTerm,
        field.multiplicativeIdentity,
      ], type: effectiveType);
      var currentPower = Polynomial<T>.fromCoefficients([
        field.multiplicativeIdentity,
      ], type: effectiveType);
      for (var k = 0; k <= order; k++) {
        final cExpr = ps.coefficients[k];
        if (cExpr != null) {
          final T coeff;
          if (cExpr is T) {
            coeff = effectiveType.cast(cExpr);
          } else {
            final val = cExpr is Number
                ? cExpr.toDouble()
                : cExpr.evaluate(const {});
            coeff = effectiveType.cast(val);
          }
          if (coeff != field.additiveIdentity) {
            result = result + currentPower.scale(coeff);
          }
        }
        if (k < order) {
          currentPower = currentPower * xMinusA;
        }
      }
      return result;
    }
  }
}

/// Truncated formal Laurent and power series:
/// `sum_{k=-p}^N-1 c_k (x - a)^k + O((x - a)^N)`.
///
/// In mathematical analysis, a formal power series represents a function as an
/// infinite polynomial. When truncated to order `N`, it provides exact local
/// asymptotic approximations with rigorous remainder propagation.
class PowerSeries {
  /// Creates a truncated power series with sparse [coefficients] up to [order].
  new(this.variable, this.point, Map<int, Expr> coefficients, this.order)
    : coefficients = _cleanCoefficients(coefficients, order);

  /// Expansion variable name.
  final String variable;

  /// Expansion point `a` (defaults to [IntegerNumber.zero]).
  final Expr point;

  /// Sparse mapping from integer exponent `k` to symbolic coefficient `c_k`.
  final Map<int, Expr> coefficients;

  /// Truncation order `N` such that remainder is `O((x - a)^N)`.
  final int order;

  /// Lowest exponent with non-zero coefficient, or [order] if all zero.
  int get valuation {
    if (coefficients.isEmpty) return order;
    var minExp = order;
    for (final k in coefficients.keys) {
      if (k < minExp) minExp = k;
    }
    return minExp;
  }

  /// Pole order `p = max(0, -valuation)`.
  int get poleOrder {
    final v = valuation;
    return v < 0 ? -v : 0;
  }

  /// Leading non-zero term (minimal exponent and coefficient), or `null` if identically zero.
  ({int exponent, Expr coefficient})? get leadingTerm {
    if (coefficients.isEmpty) return null;
    final minExp = valuation;
    return (exponent: minExp, coefficient: coefficients[minExp]!);
  }

  /// Constant term `c_0`, or [IntegerNumber.zero] if absent.
  Expr get constantTerm => coefficients[0] ?? IntegerNumber.zero;

  /// Addition of two power series: remainder order is `min(N_A, N_B)`.
  PowerSeries operator +(PowerSeries other) {
    _checkCompatible(other);
    final newOrder = math.min(order, other.order);
    final newCoeffs = <int, Expr>{};
    for (final entry in coefficients.entries) {
      if (entry.key < newOrder) {
        newCoeffs[entry.key] = entry.value;
      }
    }
    for (final entry in other.coefficients.entries) {
      if (entry.key < newOrder) {
        final existing = newCoeffs[entry.key];
        newCoeffs[entry.key] = existing == null
            ? entry.value
            : (existing + entry.value).simplify();
      }
    }
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Subtraction of two power series: remainder order is `min(N_A, N_B)`.
  PowerSeries operator -(PowerSeries other) {
    _checkCompatible(other);
    final newOrder = math.min(order, other.order);
    final newCoeffs = <int, Expr>{};
    for (final entry in coefficients.entries) {
      if (entry.key < newOrder) {
        newCoeffs[entry.key] = entry.value;
      }
    }
    for (final entry in other.coefficients.entries) {
      if (entry.key < newOrder) {
        final existing = newCoeffs[entry.key];
        newCoeffs[entry.key] = existing == null
            ? (-entry.value).simplify()
            : (existing - entry.value).simplify();
      }
    }
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Unary negation.
  PowerSeries operator -() {
    final newCoeffs = <int, Expr>{};
    for (final entry in coefficients.entries) {
      newCoeffs[entry.key] = (-entry.value).simplify();
    }
    return PowerSeries(variable, point, newCoeffs, order);
  }

  /// Scalar multiplication.
  PowerSeries scale(Expr scalar) {
    final s = scalar.simplify();
    if (isZero(s)) {
      return PowerSeries(variable, point, const {}, order);
    }
    final newCoeffs = <int, Expr>{};
    for (final entry in coefficients.entries) {
      newCoeffs[entry.key] = (entry.value * s).simplify();
    }
    return PowerSeries(variable, point, newCoeffs, order);
  }

  /// Truncated Cauchy multiplication with remainder degradation:
  /// `A(x) B(x) = sume_n (x-a)^n + O((x-a)^{min(M - p, N - q)})`.
  PowerSeries operator *(PowerSeries other) {
    _checkCompatible(other);
    final effP = coefficients.isEmpty ? order : valuation;
    final effQ = other.coefficients.isEmpty ? other.order : other.valuation;
    final newOrder = math.min(effP + other.order, effQ + order);

    final buckets = <int, List<Expr>>{};
    for (final entryA in coefficients.entries) {
      final j = entryA.key;
      final cj = entryA.value;
      for (final entryB in other.coefficients.entries) {
        final k = entryB.key;
        final dk = entryB.value;
        final n = j + k;
        if (n < newOrder) {
          (buckets[n] ??= []).add(cj * dk);
        }
      }
    }
    final newCoeffs = <int, Expr>{
      for (final MapEntry(:key, :value) in buckets.entries)
        key: value.length == 1 ? value.first : Add(value),
    };
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Laurent series inversion recurrence:
  /// `P(x) = (x - a)^m U(x) => P(x)^-1 = (x - a)^-m U(x)^-1 + O((x - a)^{N - 2m})`.
  PowerSeries reciprocal() {
    if (coefficients.isEmpty) {
      throw UnsupportedError(
        'Cannot invert a zero power series: division by zero',
      );
    }
    final m = valuation;
    final cm = coefficients[m]!;
    final nu = order - m;

    final u = List<Expr>.generate(
      nu,
      (j) => coefficients[j + m] ?? IntegerNumber.zero,
    );

    final v = <int, Expr>{};
    final invC0 = (IntegerNumber.one / cm).simplify();
    v[0] = invC0;

    for (var k = 1; k < nu; k++) {
      final terms = <Expr>[];
      for (var j = 1; j <= k; j++) {
        final uj = u[j];
        final vj = v[k - j] ?? IntegerNumber.zero;
        if (!isZero(uj) && !isZero(vj)) {
          terms.add(uj * vj);
        }
      }
      if (terms.isNotEmpty) {
        final sum = (terms.length == 1 ? terms.first : Add(terms)).simplify();
        if (!isZero(sum)) {
          v[k] = (-(invC0 * sum)).simplify();
        }
      }
    }

    final newOrder = order - 2 * m;
    final newCoeffs = <int, Expr>{};
    for (final entry in v.entries) {
      final shiftedExp = entry.key - m;
      if (shiftedExp < newOrder) {
        newCoeffs[shiftedExp] = entry.value;
      }
    }
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Truncated Cauchy division.
  PowerSeries operator /(PowerSeries other) => this * other.reciprocal();

  /// Power of a power series `P(x)^alpha`.
  PowerSeries pow(Expr exponent) {
    if (exponent case IntegerNumber(asInt: final n?)) {
      if (n == 0) {
        return PowerSeries(variable, point, {0: IntegerNumber.one}, order);
      }
      if (n == 1) return this;
      if (n > 1) {
        var base = this;
        var exp = n;
        PowerSeries? result;
        while (exp > 0) {
          if (exp.isOdd) {
            result = result == null ? base : result * base;
          }
          exp >>= 1;
          if (exp > 0) {
            base = base * base;
          }
        }
        return result!;
      }
      return reciprocal().pow(IntegerNumber.of(-n));
    }

    // Euler logarithmic derivative power recurrence for non-integer powers
    if (coefficients.isEmpty) {
      if (exponent is RealNumeric && exponent.isNegative) {
        throw UnsupportedError(
          'Cannot invert a zero power series: division by zero',
        );
      }
      if (exponent is RationalNumber && !exponent.isNegative && order > 0) {
        final scaled =
            (Integer.from(order) * exponent.numerator) ~/ exponent.denominator;
        return PowerSeries(variable, point, const {}, scaled.toInt());
      }
      return PowerSeries(variable, point, const {}, order);
    }
    final m = valuation;
    if (m != 0) {
      if (exponent is RationalNumber) {
        final prod = Integer.from(m) * exponent.numerator;
        if ((prod % exponent.denominator).isZero) {
          final newM = (prod ~/ exponent.denominator).toInt();
          final shiftedCoeffs = <int, Expr>{
            for (final entry in coefficients.entries)
              entry.key - m: entry.value,
          };
          final unitSeries = PowerSeries(
            variable,
            point,
            shiftedCoeffs,
            order - m,
          );
          final poweredUnit = unitSeries.pow(exponent);
          final resultCoeffs = <int, Expr>{
            for (final entry in poweredUnit.coefficients.entries)
              entry.key + newM: entry.value,
          };
          return PowerSeries(
            variable,
            point,
            resultCoeffs,
            poweredUnit.order + newM,
          );
        }
      }
      throw UnsupportedError(
        'Fractional power series expansion requires integer leading exponent '
        '(got valuation $m with exponent $exponent)',
      );
    }
    final c0 = coefficients[0]!;
    final q = <int, Expr>{};
    q[0] = Pow(c0, exponent).simplify();

    final invC0 = (IntegerNumber.one / c0).simplify();
    for (var k = 1; k < order; k++) {
      final terms = <Expr>[];
      for (var j = 1; j <= k; j++) {
        final cj = coefficients[j];
        final qj = q[k - j] ?? IntegerNumber.zero;
        if (cj != null && !isZero(cj) && !isZero(qj)) {
          final factor =
              ((IntegerNumber.one + exponent) * IntegerNumber.of(j) -
                      IntegerNumber.of(k))
                  .simplify();
          terms.add(factor * cj * qj);
        }
      }
      if (terms.isNotEmpty) {
        final sum = (terms.length == 1 ? terms.first : Add(terms)).simplify();
        if (!isZero(sum)) {
          q[k] = ((invC0 * sum) / IntegerNumber.of(k)).simplify();
        }
      }
    }
    return PowerSeries(variable, point, q, order);
  }

  /// Term-by-term derivative.
  PowerSeries derivative() {
    final newOrder = order == 0 ? 0 : order - 1;
    final newCoeffs = <int, Expr>{};
    for (final entry in coefficients.entries) {
      final k = entry.key;
      if (k != 0) {
        final newK = k - 1;
        if (newK < newOrder) {
          newCoeffs[newK] = (IntegerNumber.of(k) * entry.value).simplify();
        }
      }
    }
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Term-by-term anti-derivative.
  PowerSeries integrate({Expr? constant}) {
    if (coefficients.containsKey(-1)) {
      throw UnsupportedError(
        'Cannot formally integrate Laurent series with pole of order 1 (logarithmic singularity)',
      );
    }
    final newOrder = order + 1;
    final newCoeffs = <int, Expr>{};
    if (constant != null && !isZero(constant)) {
      newCoeffs[0] = constant;
    }
    for (final entry in coefficients.entries) {
      final k = entry.key;
      final newK = k + 1;
      if (newK < newOrder) {
        newCoeffs[newK] = (entry.value / IntegerNumber.of(newK)).simplify();
      }
    }
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Converts this power series to a canonical [Expr] AST with [OrderTerm].
  Expr toExpr({bool includeOrder = true}) {
    final sortedKeys = coefficients.keys.toList()..sort();
    final isCenterZero = isZero(point);
    final terms = <Expr>[];

    for (final k in sortedKeys) {
      final c = coefficients[k]!;
      if (k == 0) {
        terms.add(c);
      } else {
        final delta = isCenterZero
            ? Variable(variable)
            : Variable(variable) - point;
        final power = k == 1 ? delta : Pow(delta, IntegerNumber.of(k));
        terms.add(switch (c) {
          Number(isOne: true) => power,
          Number(isNegativeOne: true) => -power,
          _ => c * power,
        });
      }
    }

    if (includeOrder) {
      terms.add(OrderTerm(variable, order, point: point));
    }

    return switch (terms) {
      [] => IntegerNumber.zero,
      [final single] => single,
      _ => Add(terms),
    };
  }

  void _checkCompatible(PowerSeries other) {
    if (variable != other.variable) {
      throw ArgumentError(
        'Cannot combine series with different variables: $variable vs ${other.variable}',
      );
    }
    if (point != other.point) {
      throw ArgumentError(
        'Cannot combine series with different expansion points: $point vs ${other.point}',
      );
    }
  }

  static Map<int, Expr> _cleanCoefficients(Map<int, Expr> raw, int order) {
    final result = <int, Expr>{};
    for (final entry in raw.entries) {
      if (entry.key < order) {
        final simplified = entry.value.simplify();
        if (!isZero(simplified)) {
          result[entry.key] = simplified;
        }
      }
    }
    return Map.unmodifiable(result);
  }

  static bool isZero(Expr expr) => isZeroExpr(expr);
}

PowerSeries expandToPowerSeries(
  Expr expr,
  String variable,
  Expr point,
  int order, [
  Assumptions assumptions = Assumptions.none,
]) => switch (expr) {
  Variable(:final name) when name == variable => _expandVariable(
    variable,
    point,
    order,
  ),

  Number() ||
  Constant() ||
  Variable() => PowerSeries(variable, point, {0: expr}, order),

  _ when !expr.dependsOn(variable) => PowerSeries(variable, point, {
    0: expr.simplify(assumptions: assumptions),
  }, order),

  Add(:final terms) => () {
    var sum = PowerSeries(variable, point, const {}, order);
    for (final term in terms) {
      sum =
          sum + expandToPowerSeries(term, variable, point, order, assumptions);
    }
    return sum;
  }(),

  Mul(:final factors) => _expandMulFactors(
    factors,
    variable,
    point,
    order,
    assumptions,
  ),

  Pow(base: Constant.e, :final exponent) => expandExp(
    exponent,
    variable,
    point,
    order,
    assumptions,
  ),

  Pow(:final base, :final exponent) => expandPow(
    base,
    exponent,
    variable,
    point,
    order,
    assumptions,
  ),

  Ln(:final expr) => _expandLn(expr, variable, point, order, assumptions),

  Sin(:final expr) => expandSin(expr, variable, point, order),

  Cos(:final expr) => expandCos(expr, variable, point, order),

  Tan(:final expr) => () {
    var sc = expandSinCos(expr, variable, point, order);
    if (sc.cos.coefficients.isEmpty) {
      var probeOrder = math.max(order, 0) + 4;
      while (sc.cos.coefficients.isEmpty &&
          probeOrder <= math.max(order, 0) + 32) {
        sc = expandSinCos(expr, variable, point, probeOrder);
        probeOrder *= 2;
      }
    }
    final cosVal = sc.cos.valuation;
    if (sc.cos.coefficients.isNotEmpty &&
        (cosVal > 0 || sc.cos.order < order + 2 * cosVal)) {
      sc = expandSinCos(expr, variable, point, math.max(1, order + 2 * cosVal));
    }
    return sc.sin / sc.cos;
  }(),

  Sinh(:final expr) => expandSinh(expr, variable, point, order),

  Cosh(:final expr) => expandCosh(expr, variable, point, order),

  Tanh(:final expr) => () {
    var sc = expandSinhCosh(expr, variable, point, order);
    if (sc.cosh.coefficients.isEmpty) {
      var probeOrder = math.max(order, 0) + 4;
      while (sc.cosh.coefficients.isEmpty &&
          probeOrder <= math.max(order, 0) + 32) {
        sc = expandSinhCosh(expr, variable, point, probeOrder);
        probeOrder *= 2;
      }
    }
    final coshVal = sc.cosh.valuation;
    if (sc.cosh.coefficients.isNotEmpty &&
        (coshVal > 0 || sc.cosh.order < order + 2 * coshVal)) {
      sc = expandSinhCosh(
        expr,
        variable,
        point,
        math.max(1, order + 2 * coshVal),
      );
    }
    return sc.sinh / sc.cosh;
  }(),

  Asin(:final expr) => expandAsin(expr, variable, point, order),

  Acos(:final expr) =>
    PowerSeries(variable, point, {
          0: (Constant.pi / IntegerNumber.two).simplify(),
        }, order) -
        expandAsin(expr, variable, point, order),

  Atan(:final expr) => expandAtan(expr, variable, point, order),

  Abs(:final expr) => expandAbs(expr, variable, point, order, assumptions),

  LambertW(:final expr, :final branch) =>
    branch == 0
        ? expandLambertW(expr, variable, point, order)
        : throw UnsupportedError(
            'Power series only supported for principal branch W_0',
          ),

  Erf(:final expr) => expandErf(expr, variable, point, order),

  Erfc(:final expr) =>
    PowerSeries(variable, point, const {0: IntegerNumber.one}, order) -
        expandErf(expr, variable, point, order),

  Erfi(:final expr) => expandErfi(expr, variable, point, order),

  FresnelS(:final expr) => expandFresnelS(expr, variable, point, order),

  FresnelC(:final expr) => expandFresnelC(expr, variable, point, order),

  SinIntegral(:final expr) => expandSinIntegralSi(expr, variable, point, order),

  SinhIntegral(:final expr) => expandSinhIntegralShi(
    expr,
    variable,
    point,
    order,
  ),

  Polylog(:final left, :final right) => expandPolylog(
    expr,
    left,
    right,
    variable,
    point,
    order,
  ),

  EllipticK(expr: final inner) => expandEllipticK(
    expr,
    inner,
    variable,
    point,
    order,
  ),
  EllipticE(expr: final inner, amplitude: null) => expandEllipticE(
    expr,
    inner,
    variable,
    point,
    order,
  ),
  ExpIntegral() ||
  LogIntegral() ||
  CosIntegral() ||
  CoshIntegral() ||
  UpperGamma() ||
  LowerGamma() ||
  EllipticF() ||
  EllipticE() ||
  EllipticPi() ||
  ExpIntegralE() ||
  LogGamma() ||
  AppellF1() ||
  Hypergeometric() => expandTaylorSeries(expr, variable, point, order),
  Atan2(:final left, :final right) => () {
    final y0 = left
        .substitute(variable, point)
        .simplify(assumptions: assumptions);
    final x0 = right
        .substitute(variable, point)
        .simplify(assumptions: assumptions);
    if ((y0 is Number && y0.isZero) &&
        (x0 is Number && (x0 is RealNumeric && (x0.isZero || x0.isNegative)))) {
      throw UnsupportedError(
        'Atan2 has a branch cut or singularity at ($y0, $x0)',
      );
    }
    return expandTaylorSeries(expr, variable, point, order);
  }(),
  Min() || Max() || Gcd() || Lcm() || Tuple() => throw UnsupportedError(
    'Power series expansion not supported for ${expr.runtimeType}',
  ),

  Asinh(:final expr) => expandAsinh(expr, variable, point, order),

  Acosh(:final expr) => expandAcosh(expr, variable, point, order),

  Atanh(:final expr) => expandAtanh(expr, variable, point, order),

  Piecewise(:final branches, :final otherwise) => expandPiecewise(
    branches,
    otherwise,
    variable,
    point,
    order,
  ),

  Sign(:final expr) => expandSign(expr, variable, point, order),

  Floor(:final expr) => expandFloor(expr, variable, point, order),

  Ceil(:final expr) => expandCeil(expr, variable, point, order),

  Round(:final expr) => expandRound(expr, variable, point, order),

  Gamma(:final expr) => expandGamma(expr, variable, point, order),

  Digamma(:final expr) => expandDigamma(expr, variable, point, order),

  Polygamma(:final left, :final right) => expandPolygamma(
    left,
    right,
    variable,
    point,
    order,
  ),

  Zeta(expr: final s, :final shift) =>
    shift == null
        ? expandZeta(s, variable, point, order)
        : expandTaylorSeries(expr, variable, point, order),

  BesselJ(:final left, :final right) => expandBessel(
    left,
    right,
    variable,
    point,
    order,
    isModified: false,
  ),
  BesselI(:final left, :final right) => expandBessel(
    left,
    right,
    variable,
    point,
    order,
    isModified: true,
  ),
  Factorial(:final expr) => expandGamma(
    (expr + IntegerNumber.one).simplify(),
    variable,
    point,
    order,
  ),
  Beta(:final left, :final right) => expandBeta(
    left,
    right,
    variable,
    point,
    order,
  ),
  Binomial(:final left, :final right) => expandBinomial(
    left,
    right,
    variable,
    point,
    order,
  ),

  Re() ||
  Im() ||
  Arg() ||
  Conjugate() ||
  BesselY() ||
  BesselK() ||
  Mod() ||
  RelationalExpr() ||
  Integral() ||
  Derivative() ||
  Limit() ||
  Sum() ||
  Product() ||
  VariableFunction() => throw UnsupportedError(
    'Power series expansion not supported for ${expr.runtimeType}',
  ),

  OrderTerm() => throw UnsupportedError(
    'Cannot expand an OrderTerm into a series',
  ),
};

void checkNoPole(PowerSeries u, String functionName) {
  if (u.valuation < 0) {
    throw UnsupportedError(
      'Essential singularity: cannot expand $functionName of a series with a pole of order ${-u.valuation}',
    );
  }
}

PowerSeries _expandVariable(String variable, Expr point, int order) {
  final isZero = point is Number && point.isZero;
  if (isZero) {
    return PowerSeries(variable, point, {1: IntegerNumber.one}, order);
  }
  return PowerSeries(variable, point, {0: point, 1: IntegerNumber.one}, order);
}

PowerSeries _expandMulFactors(
  List<Expr> factors,
  String variable,
  Expr point,
  int order, [
  Assumptions assumptions = Assumptions.none,
]) {
  if (factors.isEmpty) {
    return PowerSeries(variable, point, const {0: IntegerNumber.one}, order);
  }
  if (factors.length == 1) {
    return expandToPowerSeries(factors[0], variable, point, order, assumptions);
  }
  if (factors.length == 2) {
    return _expandBinaryMul(
      factors[0],
      factors[1],
      variable,
      point,
      order,
      assumptions,
    );
  }

  final seriesList = <PowerSeries>[];
  final poleOrders = <int>[];
  var totalPoleOrder = 0;

  for (final factor in factors) {
    final s = expandToPowerSeries(factor, variable, point, order, assumptions);
    final p = s.poleOrder;
    seriesList.add(s);
    poleOrders.add(p);
    totalPoleOrder += p;
  }

  if (totalPoleOrder == 0) {
    var res = seriesList[0];
    for (var i = 1; i < seriesList.length; i++) {
      res = res * seriesList[i];
    }
    return res;
  }

  final boostedSeriesList = <PowerSeries>[];
  for (var i = 0; i < factors.length; i++) {
    final otherPoles = totalPoleOrder - poleOrders[i];
    if (otherPoles == 0) {
      boostedSeriesList.add(seriesList[i]);
    } else {
      boostedSeriesList.add(
        expandToPowerSeries(
          factors[i],
          variable,
          point,
          order + otherPoles,
          assumptions,
        ),
      );
    }
  }

  var res = boostedSeriesList[0];
  for (var i = 1; i < boostedSeriesList.length; i++) {
    res = res * boostedSeriesList[i];
  }
  return res;
}

PowerSeries _expandBinaryMul(
  Expr left,
  Expr right,
  String variable,
  Expr point,
  int order, [
  Assumptions assumptions = Assumptions.none,
]) {
  final sLeft = expandToPowerSeries(left, variable, point, order, assumptions);
  final sRight = expandToPowerSeries(
    right,
    variable,
    point,
    order,
    assumptions,
  );
  final p = sLeft.poleOrder;
  final q = sRight.poleOrder;
  if (p == 0 && q == 0) return sLeft * sRight;
  final boostedLeft = q == 0
      ? sLeft
      : expandToPowerSeries(left, variable, point, order + q, assumptions);
  final boostedRight = p == 0
      ? sRight
      : expandToPowerSeries(right, variable, point, order + p, assumptions);
  return boostedLeft * boostedRight;
}

PowerSeries expandExp(
  Expr inner,
  String variable,
  Expr point,
  int order, [
  Assumptions assumptions = Assumptions.none,
]) {
  final u = expandToPowerSeries(inner, variable, point, order, assumptions);
  return expandExpFromSeries(u);
}

PowerSeries expandExpFromSeries(PowerSeries u) {
  checkNoPole(u, 'exp');
  final u0 = u.constantTerm;
  final isU0Zero = PowerSeries.isZero(u0);
  final order = u.order;

  final q = <int, Expr>{};
  q[0] = IntegerNumber.one;

  for (var k = 1; k < order; k++) {
    final terms = <Expr>[];
    for (var j = 1; j <= k; j++) {
      final uj = u.coefficients[j];
      final qj = q[k - j] ?? IntegerNumber.zero;
      if (uj != null && !PowerSeries.isZero(uj) && !PowerSeries.isZero(qj)) {
        terms.add(IntegerNumber.of(j) * uj * qj);
      }
    }
    if (terms.isNotEmpty) {
      final sum = (terms.length == 1 ? terms.first : Add(terms)).simplify();
      if (!PowerSeries.isZero(sum)) {
        q[k] = (sum / IntegerNumber.of(k)).simplify();
      }
    }
  }
  final baseExp = PowerSeries(u.variable, u.point, q, order);
  return isU0Zero ? baseExp : baseExp.scale(Pow(Constant.e, u0).simplify());
}

PowerSeries _expandLn(
  Expr inner,
  String variable,
  Expr point,
  int order, [
  Assumptions assumptions = Assumptions.none,
]) {
  final u = expandToPowerSeries(inner, variable, point, order, assumptions);
  checkNoPole(u, 'ln');
  final u0 = u.constantTerm;
  if (PowerSeries.isZero(u0)) {
    throw UnsupportedError(
      'Logarithmic singularity: cannot expand ln(u) when u(0) = 0',
    );
  }

  final q = <int, Expr>{};
  q[0] = Ln(u0).simplify(assumptions: assumptions);
  final invU0 = (IntegerNumber.one / u0).simplify(assumptions: assumptions);

  for (var k = 1; k < order; k++) {
    final uk = u.coefficients[k] ?? IntegerNumber.zero;
    final terms = <Expr>[];
    for (var j = 1; j < k; j++) {
      final uj = u.coefficients[j];
      final qj = q[k - j] ?? IntegerNumber.zero;
      if (uj != null && !PowerSeries.isZero(uj) && !PowerSeries.isZero(qj)) {
        terms.add(IntegerNumber.of(k - j) * uj * qj);
      }
    }
    final sum = terms.isEmpty
        ? IntegerNumber.zero
        : (terms.length == 1 ? terms.first : Add(terms)).simplify();
    final adjusted = (uk - (sum / IntegerNumber.of(k))).simplify(
      assumptions: assumptions,
    );
    if (!PowerSeries.isZero(adjusted)) {
      q[k] = (invU0 * adjusted).simplify(assumptions: assumptions);
    }
  }
  return PowerSeries(variable, point, q, order);
}
