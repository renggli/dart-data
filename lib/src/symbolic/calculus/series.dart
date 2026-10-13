import 'dart:math' as math;

import '../algebra/simplify.dart';
import '../ast.dart';

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
    Expr point = RationalNumber.zero,
    int order = 6,
  }) => toPowerSeries(variable, point: point, order: order).toExpr();

  /// Computes the truncated formal [PowerSeries] representation of this
  /// expression around [point] up to [order].
  PowerSeries toPowerSeries(
    String variable, {
    Expr point = RationalNumber.zero,
    int order = 6,
  }) => _expandToPowerSeries(this, variable, point, order);
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

  /// Expansion point $a$ (defaults to [RationalNumber.zero]).
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

  /// Constant term $c_0$, or [RationalNumber.zero] if absent.
  Expr get constantTerm => coefficients[0] ?? RationalNumber.zero;

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
            : Add(existing, entry.value).simplify();
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
            ? Neg(entry.value).simplify()
            : Sub(existing, entry.value).simplify();
      }
    }
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Unary negation.
  PowerSeries operator -() {
    final newCoeffs = <int, Expr>{};
    for (final entry in coefficients.entries) {
      newCoeffs[entry.key] = Neg(entry.value).simplify();
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
      newCoeffs[entry.key] = Mul(entry.value, s).simplify();
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
          final prod = Mul(cj, dk).simplify();
          final existing = newCoeffs[n];
          newCoeffs[n] = existing == null
              ? prod
              : Add(existing, prod).simplify();
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
    if (nu <= 0) {
      throw UnsupportedError('Insufficient series order to compute reciprocal');
    }

    final u = List<Expr>.generate(
      nu,
      (j) => coefficients[j + m] ?? RationalNumber.zero,
    );

    final v = <int, Expr>{};
    final invC0 = Div(RationalNumber.one, cm).simplify();
    v[0] = invC0;

    for (var k = 1; k < nu; k++) {
      Expr sum = RationalNumber.zero;
      for (var j = 1; j <= k; j++) {
        final uj = u[j];
        final vj = v[k - j] ?? RationalNumber.zero;
        if (!_isZero(uj) && !_isZero(vj)) {
          final term = Mul(uj, vj).simplify();
          sum = Add(sum, term).simplify();
        }
      }
      if (!_isZero(sum)) {
        v[k] = Neg(Mul(invC0, sum)).simplify();
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
    if (exponent is RationalNumber && exponent.isInteger) {
      final n = exponent.numerator;
      if (n == 0) {
        return PowerSeries(variable, point, {0: RationalNumber.one}, order);
      }
      if (n == 1) return this;
      if (n > 1) {
        var result = this;
        for (var i = 1; i < n; i++) {
          result = result * this;
        }
        return result;
      }
      return reciprocal().pow(RationalNumber(-n));
    }

    // Euler logarithmic derivative power recurrence for non-integer powers
    if (coefficients.isEmpty) {
      return PowerSeries(variable, point, const {}, order);
    }
    final m = valuation;
    if (m != 0) {
      throw UnsupportedError(
        'Puiseux series with fractional powers of roots not supported in M3',
      );
    }
    final c0 = coefficients[0]!;
    final q = <int, Expr>{};
    q[0] = Pow(c0, exponent).simplify();

    final invC0 = Div(RationalNumber.one, c0).simplify();
    for (var k = 1; k < order; k++) {
      Expr sum = RationalNumber.zero;
      for (var j = 1; j <= k; j++) {
        final cj = coefficients[j];
        final qj = q[k - j] ?? RationalNumber.zero;
        if (cj != null && !_isZero(cj) && !_isZero(qj)) {
          final factor = Sub(
            Mul(Add(RationalNumber.one, exponent), RationalNumber(j)),
            RationalNumber(k),
          ).simplify();
          final term = Mul(factor, Mul(cj, qj)).simplify();
          sum = Add(sum, term).simplify();
        }
      }
      if (!_isZero(sum)) {
        q[k] = Div(Mul(invC0, sum), RationalNumber(k)).simplify();
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
          newCoeffs[newK] = Mul(RationalNumber(k), entry.value).simplify();
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
        newCoeffs[newK] = Div(entry.value, RationalNumber(newK)).simplify();
      }
    }
    return PowerSeries(variable, point, newCoeffs, newOrder);
  }

  /// Converts this power series to a canonical [Expr] AST with [OrderTerm].
  Expr toExpr({bool includeOrder = true}) {
    final sortedKeys = coefficients.keys.toList()..sort();
    final isCenterZero =
        point is RationalNumber && (point as RationalNumber).isZero;

    Expr? result;
    for (final k in sortedKeys) {
      final c = coefficients[k]!;
      Expr term;
      var isSub = false;
      if (k == 0) {
        if (c is RationalNumber && c.isNegative) {
          isSub = true;
          term = RationalNumber(-c.numerator, c.denominator);
        } else {
          term = c;
        }
      } else {
        final delta = isCenterZero
            ? Variable(variable)
            : Sub(Variable(variable), point);
        final power = k == 1 ? delta : Pow(delta, RationalNumber(k));
        if (c is RationalNumber && c.isOne) {
          term = power;
        } else if (c is RationalNumber && c.isNegativeOne) {
          isSub = true;
          term = power;
        } else if (c is RationalNumber && c.isNegative) {
          isSub = true;
          term = Mul(RationalNumber(-c.numerator, c.denominator), power);
        } else {
          term = Mul(c, power);
        }
      }

      if (result == null) {
        result = isSub ? Neg(term) : term;
      } else if (isSub) {
        result = Sub(result, term);
      } else {
        result = Add(result, term);
      }
    }

    if (includeOrder) {
      final orderTerm = OrderTerm(variable, order, point: point);
      result = result == null ? orderTerm : Add(result, orderTerm);
    }

    return result ?? RationalNumber.zero;
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
    if (expr is Neg && expr.expr is Number) {
      return (expr.expr as Number).isZero;
    }
    final s = expr.simplify();
    return s is Number && s.isZero;
  }
}

PowerSeries _expandToPowerSeries(
  Expr expr,
  String variable,
  Expr point,
  int order,
) {
  if (!expr.dependsOn(variable)) {
    return PowerSeries(variable, point, {0: expr.simplify()}, order);
  }

  return switch (expr) {
    Variable(:final name) when name == variable => _expandVariable(
      variable,
      point,
      order,
    ),

    Number() || Variable() => PowerSeries(variable, point, {0: expr}, order),

    Add(:final left, :final right) =>
      _expandToPowerSeries(left, variable, point, order) +
          _expandToPowerSeries(right, variable, point, order),

    Sub(:final left, :final right) =>
      _expandToPowerSeries(left, variable, point, order) -
          _expandToPowerSeries(right, variable, point, order),

    Neg(:final expr) => -_expandToPowerSeries(expr, variable, point, order),

    Mul(:final left, :final right) => _expandMul(
      left,
      right,
      variable,
      point,
      order,
    ),

    Div(:final left, :final right) => _expandDiv(
      left,
      right,
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

    Exp(:final expr) => _expandExp(expr, variable, point, order),

    Ln(:final expr) => _expandLn(expr, variable, point, order),

    Sin(:final expr) => _expandSin(expr, variable, point, order),

    Cos(:final expr) => _expandCos(expr, variable, point, order),

    Tan(:final expr) =>
      _expandSin(expr, variable, point, order) /
          _expandCos(expr, variable, point, order),

    Sinh(:final expr) => _expandSinh(expr, variable, point, order),

    Cosh(:final expr) => _expandCosh(expr, variable, point, order),

    Tanh(:final expr) =>
      _expandSinh(expr, variable, point, order) /
          _expandCosh(expr, variable, point, order),

    Asin(:final expr) => _expandAsin(expr, variable, point, order),

    Acos(:final expr) =>
      PowerSeries(variable, point, {
            0: const Div(ConstantNumber.pi, RationalNumber(2)).simplify(),
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

    Asinh(:final expr) => _expandAsinh(expr, variable, point, order),

    Atanh(:final expr) => _expandAtanh(expr, variable, point, order),

    Erfc() ||
    Gamma() ||
    Beta() ||
    Acosh() ||
    RelationalExpr() ||
    Piecewise() => throw UnsupportedError(
      'Power series expansion not supported for ${expr.runtimeType}',
    ),

    OrderTerm() => throw UnsupportedError(
      'Cannot expand an OrderTerm into a series',
    ),
  };
}

PowerSeries _expandVariable(String variable, Expr point, int order) {
  final isZero = point is RationalNumber && point.isZero;
  if (isZero) {
    return PowerSeries(variable, point, {1: RationalNumber.one}, order);
  }
  return PowerSeries(variable, point, {0: point, 1: RationalNumber.one}, order);
}

PowerSeries _expandMul(
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
  final boostedLeft = _expandToPowerSeries(left, variable, point, order + q);
  final boostedRight = _expandToPowerSeries(right, variable, point, order + p);
  return boostedLeft * boostedRight;
}

PowerSeries _expandDiv(
  Expr left,
  Expr right,
  String variable,
  Expr point,
  int order,
) {
  final sRight = _expandToPowerSeries(right, variable, point, order);
  final m = sRight.valuation;
  if (m <= 0) {
    final sLeft = _expandToPowerSeries(left, variable, point, order);
    return sLeft / sRight;
  }
  final boostedRight = _expandToPowerSeries(
    right,
    variable,
    point,
    order + 2 * m,
  );
  final boostedLeft = _expandToPowerSeries(left, variable, point, order + m);
  return boostedLeft / boostedRight;
}

PowerSeries _expandExp(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  final u0 = u.constantTerm;
  final isU0Zero = PowerSeries._isZero(u0);

  final q = <int, Expr>{};
  q[0] = RationalNumber.one;

  for (var k = 1; k < order; k++) {
    Expr sum = RationalNumber.zero;
    for (var j = 1; j <= k; j++) {
      final uj = u.coefficients[j];
      final qj = q[k - j] ?? RationalNumber.zero;
      if (uj != null && !PowerSeries._isZero(uj) && !PowerSeries._isZero(qj)) {
        final term = Mul(Mul(RationalNumber(j), uj), qj).simplify();
        sum = Add(sum, term).simplify();
      }
    }
    if (!PowerSeries._isZero(sum)) {
      q[k] = Div(sum, RationalNumber(k)).simplify();
    }
  }
  final baseExp = PowerSeries(variable, point, q, order);
  return isU0Zero ? baseExp : baseExp.scale(Exp(u0).simplify());
}

PowerSeries _expandLn(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  final u0 = u.constantTerm;
  if (PowerSeries._isZero(u0)) {
    throw UnsupportedError(
      'Logarithmic singularity: cannot expand ln(u) when u(0) = 0',
    );
  }

  final q = <int, Expr>{};
  q[0] = Ln(u0).simplify();
  final invU0 = Div(RationalNumber.one, u0).simplify();

  for (var k = 1; k < order; k++) {
    final uk = u.coefficients[k] ?? RationalNumber.zero;
    Expr sum = RationalNumber.zero;
    for (var j = 1; j < k; j++) {
      final uj = u.coefficients[j];
      final qj = q[k - j] ?? RationalNumber.zero;
      if (uj != null && !PowerSeries._isZero(uj) && !PowerSeries._isZero(qj)) {
        final term = Mul(Mul(RationalNumber(k - j), uj), qj).simplify();
        sum = Add(sum, term).simplify();
      }
    }
    final adjusted = Sub(uk, Div(sum, RationalNumber(k))).simplify();
    if (!PowerSeries._isZero(adjusted)) {
      q[k] = Mul(invU0, adjusted).simplify();
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
  final u0 = u.constantTerm;

  final s = <int, Expr>{};
  final c = <int, Expr>{};
  s[0] = RationalNumber.zero;
  c[0] = RationalNumber.one;

  for (var k = 1; k < order; k++) {
    Expr sumS = RationalNumber.zero;
    Expr sumC = RationalNumber.zero;
    for (var j = 1; j <= k; j++) {
      final uj = u.coefficients[j];
      if (uj != null && !PowerSeries._isZero(uj)) {
        final weight = Mul(RationalNumber(j), uj).simplify();
        final cPrev = c[k - j] ?? RationalNumber.zero;
        if (!PowerSeries._isZero(cPrev)) {
          sumS = Add(sumS, Mul(weight, cPrev)).simplify();
        }
        final sPrev = s[k - j] ?? RationalNumber.zero;
        if (!PowerSeries._isZero(sPrev)) {
          sumC = Add(sumC, Mul(weight, sPrev)).simplify();
        }
      }
    }
    if (!PowerSeries._isZero(sumS)) {
      s[k] = Div(sumS, RationalNumber(k)).simplify();
    }
    if (!PowerSeries._isZero(sumC)) {
      c[k] = Neg(Div(sumC, RationalNumber(k))).simplify();
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

PowerSeries _expandSinh(Expr inner, String variable, Expr point, int order) {
  final expU = _expandExp(inner, variable, point, order);
  final expNegU = _expandExp(Neg(inner), variable, point, order);
  return (expU - expNegU).scale(const RationalNumber(1, 2));
}

PowerSeries _expandCosh(Expr inner, String variable, Expr point, int order) {
  final expU = _expandExp(inner, variable, point, order);
  final expNegU = _expandExp(Neg(inner), variable, point, order);
  return (expU + expNegU).scale(const RationalNumber(1, 2));
}

PowerSeries _expandAtan(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final denom =
      PowerSeries(variable, point, {0: RationalNumber.one}, order) + (u * u);
  final deriv = uPrime / denom;
  final constant = Atan(u0).simplify();
  return deriv.integrate(constant: constant);
}

PowerSeries _expandAsin(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  final u0 = u.constantTerm;
  final uPrime = u.derivative();
  final oneMinusU2 =
      PowerSeries(variable, point, {0: RationalNumber.one}, order) - (u * u);
  final invSqrt = oneMinusU2.pow(const RationalNumber(-1, 2));
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
    if (expSimp is RationalNumber &&
        expSimp.isInteger &&
        expSimp.numerator < 0) {
      final k = -expSimp.numerator;
      final sBaseCheck = _expandToPowerSeries(base, variable, point, order);
      final m = sBaseCheck.valuation;
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
    final sBase = _expandToPowerSeries(base, variable, point, order);
    return sBase.pow(expSimp);
  }
  return _expandExp(Mul(exponent, Ln(base)), variable, point, order);
}

PowerSeries _expandAbs(Expr inner, String variable, Expr point, int order) {
  final sInner = _expandToPowerSeries(inner, variable, point, order);
  final c0 = sInner.constantTerm;
  if (c0 is RationalNumber) {
    if (c0.numerator > 0) return sInner;
    if (c0.isNegative) return -sInner;
  }
  throw UnsupportedError('abs is non-differentiable at zero');
}

RationalNumber _lambertWMaclaurinCoeff(int k) {
  var num = 1;
  for (var i = 0; i < k - 1; i++) {
    num *= k;
  }
  var den = 1;
  for (var i = 2; i <= k; i++) {
    den *= i;
  }
  if ((k - 1) % 2 == 1) {
    num = -num;
  }
  return RationalNumber(num, den);
}

PowerSeries _expandLambertW(
  Expr inner,
  String variable,
  Expr point,
  int order,
) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  if (!PowerSeries._isZero(u.constantTerm)) {
    throw UnsupportedError(
      'Lambert W series expansion around non-zero value not supported',
    );
  }
  var res = PowerSeries(variable, point, const {}, order);
  var uPow = PowerSeries(variable, point, const {0: RationalNumber.one}, order);
  for (var k = 1; k < order; k++) {
    uPow = uPow * u;
    final ck = _lambertWMaclaurinCoeff(k);
    res = res + uPow.scale(ck);
  }
  return res;
}

PowerSeries _expandErf(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  if (!PowerSeries._isZero(u.constantTerm)) {
    throw UnsupportedError('Erf series around non-zero value not supported');
  }
  var res = PowerSeries(variable, point, const {}, order);
  const factor = Div(
    RationalNumber(2),
    Pow(ConstantNumber.pi, RationalNumber(1, 2)),
  );
  for (var n = 0; 2 * n + 1 < order; n++) {
    var fact = 1;
    for (var k = 2; k <= n; k++) {
      fact *= k;
    }
    final den = fact * (2 * n + 1);
    final sign = n % 2 == 0 ? 1 : -1;
    final ck = Mul(factor, RationalNumber(sign, den)).simplify();
    res = res + u.pow(RationalNumber(2 * n + 1)).scale(ck);
  }
  return res;
}

PowerSeries _expandAsinh(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  if (!PowerSeries._isZero(u.constantTerm)) {
    throw UnsupportedError('Asinh series around non-zero value not supported');
  }
  var res = PowerSeries(variable, point, const {}, order);
  for (var n = 0; 2 * n + 1 < order; n++) {
    var num = 1;
    for (var k = 2; k <= 2 * n; k++) {
      num *= k;
    }
    var factN = 1;
    for (var k = 2; k <= n; k++) {
      factN *= k;
    }
    var pow4 = 1;
    for (var k = 0; k < n; k++) {
      pow4 *= 4;
    }
    final den = pow4 * factN * factN * (2 * n + 1);
    final sign = n % 2 == 0 ? 1 : -1;
    final ck = RationalNumber(sign * num, den);
    res = res + u.pow(RationalNumber(2 * n + 1)).scale(ck);
  }
  return res;
}

PowerSeries _expandAtanh(Expr inner, String variable, Expr point, int order) {
  final u = _expandToPowerSeries(inner, variable, point, order);
  if (!PowerSeries._isZero(u.constantTerm)) {
    throw UnsupportedError('Atanh series around non-zero value not supported');
  }
  var res = PowerSeries(variable, point, const {}, order);
  for (var n = 0; 2 * n + 1 < order; n++) {
    final ck = RationalNumber(1, 2 * n + 1);
    res = res + u.pow(RationalNumber(2 * n + 1)).scale(ck);
  }
  return res;
}
