import 'dart:math' as math;

import '../algebra/approximate.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';

/// Extension providing formal power series and Laurent expansion on [Expr].
extension SeriesExtension on Expr {
  /// Computes the truncated formal power series expansion of this expression
  /// around [point] up to [order], returning an [Expr] with an [OrderTerm].
  ///
  /// Conceptually, this approximates a mathematical function as a polynomial
  /// plus an asymptotic remainder term $O((x - a)^n)$ tracking the truncation
  /// error. Formally, it computes the Taylor or Laurent series in the ring
  /// of formal power series $\mathbb{Q}\[\[x - a\]\]$.
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
  }) => _expandToPowerSeries(
    assumptions.isEmpty ? this : simplify(assumptions: assumptions),
    variable,
    _wrapSeriesPoint(point),
    order,
  );
}

Expr _wrapSeriesPoint(Object point) => switch (point) {
  Expr() => point,
  int() => IntegerNumber(Integer.from(point)),
  BigInt() => IntegerNumber(Integer.big(point)),
  double() => _doubleToPoint(point),
  _ => throw ArgumentError.value(
    point,
    'point',
    'Series expansion point must be an Expr, int, BigInt, or double',
  ),
};

Expr _doubleToPoint(double value) {
  final real = RealNumber.fromDouble(value);
  if (!value.isFinite) return real;
  if (real.rationalize(maxDenominator: 64) case final RationalNumber rat
      when (rat.toDouble() - value).abs() < 1e-12) {
    return rat;
  }
  return real;
}

/// Truncated formal Laurent and power series:
/// $\sum_{k=-p}^{N-1} c_k (x - a)^k + O((x - a)^N)$.
///
/// In mathematical analysis, a formal power series represents a function as an
/// infinite polynomial. When truncated to order $N$, it provides exact local
/// asymptotic approximations with rigorous remainder propagation.
class PowerSeries {
  /// Creates a truncated power series with sparse [coefficients] up to [order].
  new(this.variable, this.point, Map<int, Expr> coefficients, this.order)
    : coefficients = _cleanCoefficients(coefficients, order);

  /// Expansion variable name.
  final String variable;

  /// Expansion point $a$ (defaults to [IntegerNumber.zero]).
  final Expr point;

  /// Sparse mapping from integer exponent $k$ to symbolic coefficient $c_k$.
  final Map<int, Expr> coefficients;

  /// Truncation order $N$ such that remainder is $O((x - a)^N)$.
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

  /// Pole order $p = \max(0, -\text{valuation})$.
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

  /// Constant term $c_0$, or [IntegerNumber.zero] if absent.
  Expr get constantTerm => coefficients[0] ?? IntegerNumber.zero;

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

  /// Addition of two power series: remainder order is $\min(N_A, N_B)$.
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

  /// Subtraction of two power series: remainder order is $\min(N_A, N_B)$.
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
    if (_isZero(s)) {
      return PowerSeries(variable, point, const {}, order);
    }
    final newCoeffs = <int, Expr>{};
    for (final entry in coefficients.entries) {
      newCoeffs[entry.key] = (entry.value * s).simplify();
    }
    return PowerSeries(variable, point, newCoeffs, order);
  }

  /// Truncated Cauchy multiplication with remainder degradation:
  /// $A(x) B(x) = \sum e_n (x-a)^n + O((x-a)^{\min(M - p, N - q)})$.
  PowerSeries operator *(PowerSeries other) {
    _checkCompatible(other);
    final p = poleOrder;
    final q = other.poleOrder;
    final newOrder = math.min(other.order - p, order - q);

    final newCoeffs = <int, Expr>{};
    for (final entryA in coefficients.entries) {
      final j = entryA.key;
      final cj = entryA.value;
      for (final entryB in other.coefficients.entries) {
        final k = entryB.key;
        final dk = entryB.value;
        final n = j + k;
        if (n < newOrder) {
          final prod = (cj * dk).simplify();
          final existing = newCoeffs[n];
          newCoeffs[n] = existing == null ? prod : (existing + prod).simplify();
        }
      }
    }
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Laurent series inversion recurrence:
  /// $P(x) = (x - a)^m U(x) \implies P(x)^{-1} = (x - a)^{-m} U(x)^{-1} + O((x - a)^{N - 2m})$.
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
      Expr sum = IntegerNumber.zero;
      for (var j = 1; j <= k; j++) {
        final uj = u[j];
        final vj = v[k - j] ?? IntegerNumber.zero;
        if (!_isZero(uj) && !_isZero(vj)) {
          final term = (uj * vj).simplify();
          sum = (sum + term).simplify();
        }
      }
      if (!_isZero(sum)) {
        v[k] = (-(invC0 * sum)).simplify();
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

  /// Power of a power series $P(x)^\alpha$.
  PowerSeries pow(Expr exponent) {
    if (exponent case IntegerNumber(asInt: final n?)) {
      if (n == 0) {
        return PowerSeries(variable, point, {0: IntegerNumber.one}, order);
      }
      if (n == 1) return this;
      if (n > 1) {
        var result = this;
        for (var i = 1; i < n; i++) {
          result = result * this;
        }
        return result;
      }
      return reciprocal().pow(IntegerNumber.of(-n));
    }

    // Euler logarithmic derivative power recurrence for non-integer powers
    if (coefficients.isEmpty) {
      return PowerSeries(variable, point, const {}, order);
    }
    final m = valuation;
    if (m != 0) {
      if (exponent is RationalNumber) {
        final prod = Integer(m) * exponent.numerator;
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
      Expr sum = IntegerNumber.zero;
      for (var j = 1; j <= k; j++) {
        final cj = coefficients[j];
        final qj = q[k - j] ?? IntegerNumber.zero;
        if (cj != null && !_isZero(cj) && !_isZero(qj)) {
          final factor =
              ((IntegerNumber.one + exponent) * IntegerNumber.of(j) -
                      IntegerNumber.of(k))
                  .simplify();
          final term = (factor * cj * qj).simplify();
          sum = (sum + term).simplify();
        }
      }
      if (!_isZero(sum)) {
        q[k] = ((invC0 * sum) / IntegerNumber.of(k)).simplify();
      }
    }
    return PowerSeries(variable, point, q, order);
  }

  /// Term-by-term derivative.
  PowerSeries derivative() {
    final newOrder = order - 1;
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
    if (constant != null && !_isZero(constant)) {
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
    final isCenterZero = _isZero(point);
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

  static Map<int, Expr> _cleanCoefficients(Map<int, Expr> raw, int order) {
    final result = <int, Expr>{};
    for (final entry in raw.entries) {
      if (entry.key < order) {
        final simplified = entry.value.simplify();
        if (!_isZero(simplified)) {
          result[entry.key] = simplified;
        }
      }
    }
    return Map.unmodifiable(result);
  }

  static bool _isZero(Expr expr) {
    if (expr is Number) return expr.isZero;
    final s = expr.simplify();
    return s is Number && s.isZero;
  }
}

PowerSeries _expandToPowerSeries(
  Expr expr,
  String variable,
  Expr point,
  int order,
) => switch (expr) {
  Variable(:final name) when name == variable => _expandVariable(
    variable,
    point,
    order,
  ),

  Number() ||
  Constant() ||
  Variable() => PowerSeries(variable, point, {0: expr}, order),

  _ when !expr.dependsOn(variable) => PowerSeries(variable, point, {
    0: expr.simplify(),
  }, order),

  Add(:final terms) => () {
    var sum = PowerSeries(variable, point, const {}, order);
    for (final term in terms) {
      sum = sum + _expandToPowerSeries(term, variable, point, order);
    }
    return sum;
  }(),

  Mul(:final factors) => _expandMulFactors(factors, variable, point, order),

  Pow(base: Constant.e, :final exponent) => _expandExp(
    exponent,
    variable,
    point,
    order,
  ),

  Pow(:final base, :final exponent) => _expandPow(
    base,
    exponent,
    variable,
    point,
    order,
  ),

  Ln(:final expr) => _expandLn(expr, variable, point, order),

  Sin(:final expr) => _expandSin(expr, variable, point, order),

  Cos(:final expr) => _expandCos(expr, variable, point, order),

  Tan(:final expr) => () {
    final sc = _expandSinCos(expr, variable, point, order);
    return sc.sin / sc.cos;
  }(),

  Sinh(:final expr) => _expandSinh(expr, variable, point, order),

  Cosh(:final expr) => _expandCosh(expr, variable, point, order),

  Tanh(:final expr) => () {
    final sc = _expandSinhCosh(expr, variable, point, order);
    return sc.sinh / sc.cosh;
  }(),

  Asin(:final expr) => _expandAsin(expr, variable, point, order),

  Acos(:final expr) =>
    PowerSeries(variable, point, {
          0: (Constant.pi / IntegerNumber.two).simplify(),
        }, order) -
        _expandAsin(expr, variable, point, order),

  Atan(:final expr) => _expandAtan(expr, variable, point, order),

  Abs(:final expr) => _expandAbs(expr, variable, point, order),

  LambertW(:final expr, :final branch) =>
    branch == 0
        ? _expandLambertW(expr, variable, point, order)
        : throw UnsupportedError(
            'Power series only supported for principal branch W_0',
          ),

  Erf(:final expr) => _expandErf(expr, variable, point, order),

  Erfc(:final expr) =>
    PowerSeries(variable, point, const {0: IntegerNumber.one}, order) -
        _expandErf(expr, variable, point, order),

  Asinh(:final expr) => _expandAsinh(expr, variable, point, order),

  Acosh(:final expr) => _expandAcosh(expr, variable, point, order),

  Atanh(:final expr) => _expandAtanh(expr, variable, point, order),

  Piecewise(:final branches, :final otherwise) => _expandPiecewise(
    branches,
    otherwise,
    variable,
    point,
    order,
  ),

  Re() ||
  Im() ||
  Arg() ||
  Conjugate() ||
  Gamma() ||
  Beta() ||
  Factorial() ||
  Binomial() ||
  Floor() ||
  Ceil() ||
  Round() ||
  Sign() ||
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

void _checkNoPole(PowerSeries u, String functionName) {
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
  int order,
) {
  var res = _expandBinaryMul(factors[0], factors[1], variable, point, order);
  for (var j = 2; j < factors.length; j++) {
    res = _expandSeriesTimesExpr(res, factors[j], variable, point, order);
  }
  return res;
}

PowerSeries _expandBinaryMul(
  Expr left,
  Expr right,
  String variable,
  Expr point,
  int order,
) {
  final sLeft = _expandToPowerSeries(left, variable, point, order);
  final sRight = _expandToPowerSeries(right, variable, point, order);
  final p = sLeft.poleOrder;
  final q = sRight.poleOrder;
  if (p == 0 && q == 0) return sLeft * sRight;
  final boostedLeft = q == 0
      ? sLeft
      : _expandToPowerSeries(left, variable, point, order + q);
  final boostedRight = p == 0
      ? sRight
      : _expandToPowerSeries(right, variable, point, order + p);
  return boostedLeft * boostedRight;
}

PowerSeries _expandSeriesTimesExpr(
  PowerSeries sLeft,
  Expr right,
  String variable,
  Expr point,
  int order,
) {
  final p = sLeft.poleOrder;
  final sRight = _expandToPowerSeries(right, variable, point, order + p);
  final q = sRight.poleOrder;
  if (q == 0) return sLeft * sRight;
  final boostedLeft = sLeft
      .toExpr(includeOrder: false)
      .toPowerSeries(variable, point: point, order: sLeft.order + q);
  return boostedLeft * sRight;
}

PowerSeries _expandExp(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  return _expandExpFromSeries(u);
}

PowerSeries _expandExpFromSeries(PowerSeries u) {
  _checkNoPole(u, 'exp');
  final u0 = u.constantTerm;
  final isU0Zero = PowerSeries._isZero(u0);
  final order = u.order;

  final q = <int, Expr>{};
  q[0] = IntegerNumber.one;

  for (var k = 1; k < order; k++) {
    Expr sum = IntegerNumber.zero;
    for (var j = 1; j <= k; j++) {
      final uj = u.coefficients[j];
      final qj = q[k - j] ?? IntegerNumber.zero;
      if (uj != null && !PowerSeries._isZero(uj) && !PowerSeries._isZero(qj)) {
        final term = (IntegerNumber.of(j) * uj * qj).simplify();
        sum = (sum + term).simplify();
      }
    }
    if (!PowerSeries._isZero(sum)) {
      q[k] = (sum / IntegerNumber.of(k)).simplify();
    }
  }
  final baseExp = PowerSeries(u.variable, u.point, q, order);
  return isU0Zero ? baseExp : baseExp.scale(Pow(Constant.e, u0).simplify());
}

PowerSeries _expandLn(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'ln');
  final u0 = u.constantTerm;
  if (PowerSeries._isZero(u0)) {
    throw UnsupportedError(
      'Logarithmic singularity: cannot expand ln(u) when u(0) = 0',
    );
  }

  final q = <int, Expr>{};
  q[0] = Ln(u0).simplify();
  final invU0 = (IntegerNumber.one / u0).simplify();

  for (var k = 1; k < order; k++) {
    final uk = u.coefficients[k] ?? IntegerNumber.zero;
    Expr sum = IntegerNumber.zero;
    for (var j = 1; j < k; j++) {
      final uj = u.coefficients[j];
      final qj = q[k - j] ?? IntegerNumber.zero;
      if (uj != null && !PowerSeries._isZero(uj) && !PowerSeries._isZero(qj)) {
        final term = (IntegerNumber.of(k - j) * uj * qj).simplify();
        sum = (sum + term).simplify();
      }
    }
    final adjusted = (uk - (sum / IntegerNumber.of(k))).simplify();
    if (!PowerSeries._isZero(adjusted)) {
      q[k] = (invU0 * adjusted).simplify();
    }
  }
  return PowerSeries(variable, point, q, order);
}

PowerSeries _expandSin(Expr inner, String variable, Expr point, int order) =>
    _expandSinCos(inner, variable, point, order).sin;

PowerSeries _expandCos(Expr inner, String variable, Expr point, int order) =>
    _expandSinCos(inner, variable, point, order).cos;

({PowerSeries sin, PowerSeries cos}) _expandSinCos(
  Expr inner,
  String variable,
  Expr point,
  int order,
) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'sin/cos');
  final u0 = u.constantTerm;

  final s = <int, Expr>{};
  final c = <int, Expr>{};
  s[0] = IntegerNumber.zero;
  c[0] = IntegerNumber.one;

  for (var k = 1; k < order; k++) {
    Expr sumS = IntegerNumber.zero;
    Expr sumC = IntegerNumber.zero;
    for (var j = 1; j <= k; j++) {
      final uj = u.coefficients[j];
      if (uj != null && !PowerSeries._isZero(uj)) {
        final weight = (IntegerNumber.of(j) * uj).simplify();
        final cPrev = c[k - j] ?? IntegerNumber.zero;
        if (!PowerSeries._isZero(cPrev)) {
          sumS = (sumS + weight * cPrev).simplify();
        }
        final sPrev = s[k - j] ?? IntegerNumber.zero;
        if (!PowerSeries._isZero(sPrev)) {
          sumC = (sumC + weight * sPrev).simplify();
        }
      }
    }
    if (!PowerSeries._isZero(sumS)) {
      s[k] = (sumS / IntegerNumber.of(k)).simplify();
    }
    if (!PowerSeries._isZero(sumC)) {
      c[k] = (-(sumC / IntegerNumber.of(k))).simplify();
    }
  }

  final sinBase = PowerSeries(variable, point, s, order);
  final cosBase = PowerSeries(variable, point, c, order);

  if (PowerSeries._isZero(u0)) {
    return (sin: sinBase, cos: cosBase);
  }
  final sinVal = Sin(u0).simplify();
  final cosVal = Cos(u0).simplify();
  final sinFull = cosBase.scale(sinVal) + sinBase.scale(cosVal);
  final cosFull = cosBase.scale(cosVal) - sinBase.scale(sinVal);
  return (sin: sinFull, cos: cosFull);
}

({PowerSeries sinh, PowerSeries cosh}) _expandSinhCosh(
  Expr inner,
  String variable,
  Expr point,
  int order,
) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'sinh/cosh');
  final expU = _expandExpFromSeries(u);
  final expNegU = _expandExpFromSeries(-u);
  return (
    sinh: (expU - expNegU).scale(FractionNumber.half),
    cosh: (expU + expNegU).scale(FractionNumber.half),
  );
}

PowerSeries _expandSinh(Expr inner, String variable, Expr point, int order) =>
    _expandSinhCosh(inner, variable, point, order).sinh;

PowerSeries _expandCosh(Expr inner, String variable, Expr point, int order) =>
    _expandSinhCosh(inner, variable, point, order).cosh;

PowerSeries _expandAtan(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'atan');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final denom =
      PowerSeries(variable, point, {0: IntegerNumber.one}, order) + (u * u);
  final deriv = uPrime / denom;
  final constant = Atan(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries _expandAsin(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'asin');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final oneMinusU2 =
      PowerSeries(variable, point, {0: IntegerNumber.one}, order) - (u * u);
  final invSqrt = oneMinusU2.pow(FractionNumber.negativeHalf);
  final deriv = uPrime * invSqrt;
  final constant = Asin(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries _expandPow(
  Expr base,
  Expr exponent,
  String variable,
  Expr point,
  int order,
) {
  if (!exponent.dependsOn(variable)) {
    final expSimp = exponent.simplify();
    final sBase = _expandToPowerSeries(base, variable, point, order);
    if (expSimp is IntegerNumber && expSimp.isNegative) {
      final k = -(expSimp.asInt ?? 1);
      final m = sBase.valuation;
      if (m > 0) {
        final boostedBase = _expandToPowerSeries(
          base,
          variable,
          point,
          order + 2 * k * m,
        );
        return boostedBase.pow(expSimp);
      }
    }
    return sBase.pow(expSimp);
  }
  return _expandExp(exponent * Ln(base), variable, point, order);
}

PowerSeries _expandAbs(Expr inner, String variable, Expr point, int order) {
  final sInner = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(sInner, 'abs');
  final c0 = sInner.constantTerm;
  if (c0 is RealNumeric) {
    if (c0.sign > 0) return sInner;
    if (c0.sign < 0) return -sInner;
  }
  if (!c0.dependsOn(variable) && c0.freeVariables.isEmpty) {
    try {
      final val = c0.evaluate();
      if (val > 0) return sInner;
      if (val < 0) return -sInner;
    } on Object {
      // Fall through
    }
  }
  throw UnsupportedError('abs is non-differentiable at zero');
}

RationalNumber _lambertWMaclaurinCoeff(int k) {
  final numBig = BigInt.from(k).pow(k - 1);
  final denBig = Integer(k).factorial().toBigInt();
  final g = numBig.gcd(denBig);
  var numRed = Integer.big(numBig ~/ g);
  final denRed = Integer.big(denBig ~/ g);
  if ((k - 1).isOdd) {
    numRed = -numRed;
  }
  return RationalNumber.of(numRed, denRed);
}

PowerSeries _expandLambertW(
  Expr inner,
  String variable,
  Expr point,
  int order,
) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'lambertw');
  if (!PowerSeries._isZero(u.constantTerm)) {
    throw UnsupportedError(
      'Lambert W series expansion around non-zero value not supported',
    );
  }
  var res = PowerSeries(variable, point, const {}, order);
  var uPow = PowerSeries(variable, point, const {0: IntegerNumber.one}, order);
  for (var k = 1; k < order; k++) {
    uPow = uPow * u;
    final ck = _lambertWMaclaurinCoeff(k);
    res = res + uPow.scale(ck);
  }
  return res;
}

PowerSeries _expandErf(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'erf');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final expNegU2 = _expandExpFromSeries(-(u * u));
  final factor = IntegerNumber.two / Pow(Constant.pi, FractionNumber.half);
  final deriv = (uPrime * expNegU2).scale(factor);
  final constant = Erf(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries _expandAsinh(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'asinh');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final onePlusU2 =
      PowerSeries(variable, point, const {0: IntegerNumber.one}, order) +
      (u * u);
  final invSqrt = onePlusU2.pow(FractionNumber.negativeHalf);
  final deriv = uPrime * invSqrt;
  final constant = Asinh(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries _expandAcosh(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'acosh');
  final u0 = u.constantTerm;
  if (!u0.dependsOn(variable)) {
    try {
      if (u0.evaluate(const {}) <= 1.0) {
        throw UnsupportedError(
          'Acosh series requires inner constant term > 1 (got $u0)',
        );
      }
    } on UnsupportedError {
      rethrow;
    } on Object {
      // Ignore numeric evaluation errors on symbolic constants
    }
  }
  final uPrime = u.derivative();
  final u2MinusOne =
      (u * u) -
      PowerSeries(variable, point, const {0: IntegerNumber.one}, order);
  final invSqrt = u2MinusOne.pow(FractionNumber.negativeHalf);
  final deriv = uPrime * invSqrt;
  final constant = Acosh(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries _expandAtanh(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  _checkNoPole(u, 'atanh');
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final oneMinusU2 =
      PowerSeries(variable, point, const {0: IntegerNumber.one}, order) -
      (u * u);
  final deriv = uPrime / oneMinusU2;
  final constant = Atanh(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries _expandPiecewise(
  List<PiecewiseBranch> branches,
  Expr? otherwise,
  String variable,
  Expr point,
  int order,
) {
  if (!point.dependsOn(variable)) {
    try {
      final ptVal = point.evaluate(const {});
      for (final (:relation, :expr) in branches) {
        final atPt = relation.evaluate({variable: ptVal});
        final leftVal = relation.evaluate({variable: ptVal - 1e-7});
        final rightVal = relation.evaluate({variable: ptVal + 1e-7});
        if (atPt != leftVal || atPt != rightVal) {
          throw UnsupportedError(
            'Piecewise expression is not analytic at boundary point $point',
          );
        }
        if (atPt == 1.0) {
          return _expandToPowerSeries(expr, variable, point, order);
        }
      }
      if (otherwise != null) {
        return _expandToPowerSeries(otherwise, variable, point, order);
      }
    } on UnsupportedError {
      rethrow;
    } on Object {
      // Fall through if point is not numerically evaluable
    }
  }
  throw UnsupportedError(
    'Power series expansion not supported for Piecewise at $point',
  );
}
