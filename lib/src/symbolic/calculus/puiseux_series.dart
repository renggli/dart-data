import 'dart:collection';

import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../functions/fn.dart';
import '../oracle/zero_equivalence.dart';
import 'series.dart';

/// Extension providing formal Puiseux series expansion on [Expr].
extension PuiseuxSeriesExtension on Expr {
  /// Computes the truncated formal [PuiseuxSeries] representation of this
  /// expression around [point] up to [order].
  PuiseuxSeries toPuiseuxSeries(
    String variable, {
    Object point = 0,
    int order = 6,
    Assumptions assumptions = Assumptions.none,
  }) {
    final pointExpr = Expr.wrap(point);
    final orderRat = IntegerNumber.of(order);
    final result = expandToPuiseuxSeries(
      assumptions.isEmpty ? this : simplify(assumptions: assumptions),
      variable,
      pointExpr,
      orderRat,
      assumptions,
    );
    return result.order.compareTo(orderRat) > 0
        ? PuiseuxSeries(variable, result.point, result.coefficients, orderRat)
        : result;
  }
}

extension _RationalOrdering on RationalNumber {
  bool operator <(RationalNumber other) => compareTo(other) < 0;
  bool operator <=(RationalNumber other) => compareTo(other) <= 0;
  bool operator >(RationalNumber other) => compareTo(other) > 0;
  bool operator >=(RationalNumber other) => compareTo(other) >= 0;
  bool get isPositive => sign > 0;
}

/// Truncated formal Puiseux series with sorted rational exponents:
/// `sum_{q in Q, q < N} c_q * (x - a)^q + O((x - a)^N)`.
class PuiseuxSeries {
  /// Creates a truncated Puiseux series with sparse rational-exponent
  /// [coefficients] strictly below [order].
  new(
    this.variable,
    this.point,
    Map<RationalNumber, Expr> coefficients,
    this.order,
  ) : coefficients = _cleanCoefficients(coefficients, order);

  /// Wraps a [PowerSeries] as a [PuiseuxSeries] with integer exponents.
  factory fromPowerSeries(PowerSeries series) {
    final converted = SplayTreeMap<RationalNumber, Expr>(
      (a, b) => a.compareTo(b),
    );
    for (final entry in series.coefficients.entries) {
      converted[IntegerNumber.of(entry.key)] = entry.value;
    }
    return PuiseuxSeries._fromClean(
      series.variable,
      series.point,
      UnmodifiableMapView<RationalNumber, Expr>(converted),
      IntegerNumber.of(series.order),
    );
  }

  new _fromClean(this.variable, this.point, this.coefficients, this.order);

  /// Expansion variable name `x`.
  final String variable;

  /// Expansion center point `a`.
  final Expr point;

  /// Non-zero coefficients indexed in strictly ascending rational exponent order.
  final Map<RationalNumber, Expr> coefficients;

  /// Rational truncation order `N`.
  final RationalNumber order;

  /// Whether all non-zero coefficients are identically zero below [order].
  bool get isZero => coefficients.isEmpty;

  /// The lowest-order non-zero term `(exponent, coefficient)`, or `null` if zero.
  ({RationalNumber exponent, Expr coefficient})? get leadingTerm {
    if (coefficients.isEmpty) return null;
    final first = coefficients.entries.first;
    return (exponent: first.key, coefficient: first.value);
  }

  /// Minimum rational exponent `m` such that `c_m != 0`.
  RationalNumber get valuation {
    final lead = leadingTerm;
    if (lead == null) {
      throw StateError('Zero Puiseux series has undefined valuation');
    }
    return lead.exponent;
  }

  /// Pole order `max(0, -valuation)`.
  RationalNumber get poleOrder {
    final lead = leadingTerm;
    if (lead == null || !lead.exponent.isNegative) {
      return IntegerNumber.zero;
    }
    return (-lead.exponent) as RationalNumber;
  }

  /// Constant term `c_0`.
  Expr get constantTerm =>
      coefficients[IntegerNumber.zero] ?? IntegerNumber.zero;

  /// Whether every non-zero exponent in this series is an integer.
  bool get hasOnlyIntegerExponents =>
      coefficients.keys.every((exponent) => exponent.isInteger);

  /// Whether every fractional exponent has an odd denominator.
  bool get hasOnlyOddDenominators =>
      coefficients.keys.every((exponent) => exponent.denominator.isOdd);

  /// Addition of two Puiseux series: remainder order is `min(N_A, N_B)`.
  PuiseuxSeries operator +(PuiseuxSeries other) {
    _checkCompatible(other);
    final newOrder = order <= other.order ? order : other.order;
    final newCoeffs = _newSortedMap();
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
    return PuiseuxSeries(variable, point, newCoeffs, newOrder);
  }

  /// Subtraction of two Puiseux series: remainder order is `min(N_A, N_B)`.
  PuiseuxSeries operator -(PuiseuxSeries other) {
    _checkCompatible(other);
    final newOrder = order <= other.order ? order : other.order;
    final newCoeffs = _newSortedMap();
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
    return PuiseuxSeries(variable, point, newCoeffs, newOrder);
  }

  /// Unary negation.
  PuiseuxSeries operator -() {
    final newCoeffs = _newSortedMap();
    for (final entry in coefficients.entries) {
      newCoeffs[entry.key] = (-entry.value).simplify();
    }
    return PuiseuxSeries._fromClean(
      variable,
      point,
      UnmodifiableMapView<RationalNumber, Expr>(newCoeffs),
      order,
    );
  }

  /// Scalar multiplication by a constant [Expr].
  PuiseuxSeries scale(Expr scalar) {
    final s = scalar.simplify();
    if (isZeroExpr(s)) {
      return PuiseuxSeries._fromClean(
        variable,
        point,
        const <RationalNumber, Expr>{},
        order,
      );
    }
    final newCoeffs = _newSortedMap();
    for (final entry in coefficients.entries) {
      final prod = (s * entry.value).simplify();
      if (!isZeroExpr(prod)) {
        newCoeffs[entry.key] = prod;
      }
    }
    return PuiseuxSeries._fromClean(
      variable,
      point,
      UnmodifiableMapView<RationalNumber, Expr>(newCoeffs),
      order,
    );
  }

  /// Truncated Cauchy multiplication of two Puiseux series.
  PuiseuxSeries operator *(PuiseuxSeries other) {
    _checkCompatible(other);
    if (coefficients.isEmpty || other.coefficients.isEmpty) {
      final newOrder = order <= other.order ? order : other.order;
      return PuiseuxSeries(variable, point, const {}, newOrder);
    }
    final minA = valuation;
    final minB = other.valuation;
    final orderA = (order + minB) as RationalNumber;
    final orderB = (other.order + minA) as RationalNumber;
    final newOrder = orderA <= orderB ? orderA : orderB;
    final prod = _newSortedMap();
    for (final entryA in coefficients.entries) {
      for (final entryB in other.coefficients.entries) {
        final exp = (entryA.key + entryB.key) as RationalNumber;
        if (exp >= newOrder) break;
        final term = entryA.value * entryB.value;
        final existing = prod[exp];
        prod[exp] = existing == null ? term : existing + term;
      }
    }
    return PuiseuxSeries(variable, point, prod, newOrder);
  }

  /// Reciprocal of a non-zero Puiseux series.
  PuiseuxSeries reciprocal() {
    final lead = leadingTerm;
    if (lead == null) {
      throw UnsupportedError(
        'Cannot invert a zero Puiseux series: division by zero',
      );
    }
    final m = lead.exponent;
    final c0 = lead.coefficient;
    final invC0 = (IntegerNumber.one / c0).simplify();
    final unitOrder = (order - m) as RationalNumber;
    final positiveUnit = <({RationalNumber exp, Expr coeff})>[];
    for (final entry in coefficients.entries) {
      if (entry.key > m) {
        positiveUnit.add((
          exp: (entry.key - m) as RationalNumber,
          coeff: entry.value,
        ));
      }
    }

    final v = _newSortedMap();
    if (IntegerNumber.zero < unitOrder) {
      v[IntegerNumber.zero] = invC0;
    }

    final pending = _newSortedSet();
    for (final item in positiveUnit) {
      if (item.exp < unitOrder) {
        pending.add(item.exp);
      }
    }

    while (pending.isNotEmpty) {
      final k = pending.first;
      pending.remove(k);
      final terms = <Expr>[];
      for (final item in positiveUnit) {
        if (item.exp > k) break;
        final remainder = (k - item.exp) as RationalNumber;
        final vj = v[remainder];
        if (vj != null && !isZeroExpr(vj)) {
          terms.add(item.coeff * vj);
        }
      }
      if (terms.isNotEmpty) {
        final sum = (terms.length == 1 ? terms.first : Add.of(terms))
            .simplify();
        if (!isZeroExpr(sum)) {
          final vk = (-(invC0 * sum)).simplify();
          if (!isZeroExpr(vk)) {
            v[k] = vk;
            for (final item in positiveUnit) {
              final next = (k + item.exp) as RationalNumber;
              if (next < unitOrder) {
                pending.add(next);
              }
            }
          }
        }
      }
    }

    final newOrder = (order - IntegerNumber.two * m) as RationalNumber;
    final shifted = _newSortedMap();
    for (final entry in v.entries) {
      final shiftedExp = (entry.key - m) as RationalNumber;
      if (shiftedExp < newOrder) {
        shifted[shiftedExp] = entry.value;
      }
    }
    return PuiseuxSeries(variable, point, shifted, newOrder);
  }

  /// Truncated Cauchy division.
  PuiseuxSeries operator /(PuiseuxSeries other) => this * other.reciprocal();

  /// Computes `P(x)^exponent` for an arbitrary rational [exponent].
  PuiseuxSeries powRational(RationalNumber exponent) {
    if (exponent.isZero) {
      return PuiseuxSeries(variable, point, {
        IntegerNumber.zero: IntegerNumber.one,
      }, order);
    }
    if (exponent.isOne) return this;
    if (exponent case IntegerNumber(asInt: final n?)) {
      if (n > 1) {
        return _binaryIntPow(n);
      }
      return reciprocal().powRational(IntegerNumber.of(-n));
    }

    if (coefficients.isEmpty) {
      if (exponent.isNegative) {
        throw UnsupportedError(
          'Cannot invert a zero Puiseux series: division by zero',
        );
      }
      final newOrder = order.isPositive
          ? (order * exponent) as RationalNumber
          : order;
      return PuiseuxSeries(variable, point, const {}, newOrder);
    }

    final m = valuation;
    final unitCoeffs = _newSortedMap();
    for (final entry in coefficients.entries) {
      unitCoeffs[(entry.key - m) as RationalNumber] = entry.value;
    }
    final unitOrder = (order - m) as RationalNumber;
    final unitSeries = PuiseuxSeries._fromClean(
      variable,
      point,
      UnmodifiableMapView<RationalNumber, Expr>(unitCoeffs),
      unitOrder,
    );
    final poweredUnit = unitSeries._unitPowExpr(exponent);
    final shiftedM = (m * exponent) as RationalNumber;
    final resultCoeffs = _newSortedMap();
    for (final entry in poweredUnit.coefficients.entries) {
      resultCoeffs[(entry.key + shiftedM) as RationalNumber] = entry.value;
    }
    return PuiseuxSeries(
      variable,
      point,
      resultCoeffs,
      (poweredUnit.order + shiftedM) as RationalNumber,
    );
  }

  /// Raises this series to an arbitrary constant symbolic [exponent].
  PuiseuxSeries pow(Expr exponent) {
    if (exponent is RationalNumber) {
      return powRational(exponent);
    }
    if (coefficients.isEmpty) {
      if (exponent is RealNumeric && exponent.isNegative) {
        throw UnsupportedError(
          'Cannot invert a zero Puiseux series: division by zero',
        );
      }
      return PuiseuxSeries(variable, point, const {}, order);
    }
    if (!valuation.isZero) {
      throw UnsupportedError(
        'Non-rational power $exponent requires zero leading valuation (got $valuation)',
      );
    }
    return _unitPowExpr(exponent);
  }

  /// Term-by-term formal derivative.
  PuiseuxSeries derivative() {
    final newOrder = order.isZero
        ? IntegerNumber.zero
        : (order - IntegerNumber.one) as RationalNumber;
    final newCoeffs = _newSortedMap();
    for (final entry in coefficients.entries) {
      final k = entry.key;
      if (!k.isZero) {
        final newK = (k - IntegerNumber.one) as RationalNumber;
        if (newK < newOrder) {
          newCoeffs[newK] = (k * entry.value).simplify();
        }
      }
    }
    return PuiseuxSeries(variable, point, newCoeffs, newOrder);
  }

  /// Term-by-term formal anti-derivative.
  PuiseuxSeries integrate({Expr? constant}) {
    if (coefficients.containsKey(IntegerNumber.negativeOne)) {
      throw UnsupportedError(
        'Cannot formally integrate Puiseux series with pole of order 1 (logarithmic singularity)',
      );
    }
    final newOrder = (order + IntegerNumber.one) as RationalNumber;
    final newCoeffs = _newSortedMap();
    if (constant != null && !isZeroExpr(constant)) {
      newCoeffs[IntegerNumber.zero] = constant;
    }
    for (final entry in coefficients.entries) {
      final newK = (entry.key + IntegerNumber.one) as RationalNumber;
      if (newK < newOrder) {
        newCoeffs[newK] = (entry.value / newK).simplify();
      }
    }
    return PuiseuxSeries(variable, point, newCoeffs, newOrder);
  }

  /// Converts this series into a canonical [Expr] AST.
  Expr toExpr({bool includeOrder = true}) {
    final isCenterZero = isZeroExpr(point);
    final delta = isCenterZero
        ? Variable(variable)
        : Variable(variable) - point;
    final terms = <Expr>[];
    for (final entry in coefficients.entries) {
      final k = entry.key;
      final c = entry.value;
      if (k.isZero) {
        terms.add(c);
      } else {
        final power = k.isOne ? delta : Pow.of(delta, k);
        terms.add(switch (c) {
          Number(isOne: true) => power,
          Number(isNegativeOne: true) => -power,
          _ => c * power,
        });
      }
    }
    if (includeOrder) {
      if (order case IntegerNumber(:final asInt?)) {
        terms.add(OrderTerm(variable, asInt, point: point));
      }
    }
    return switch (terms) {
      [] => IntegerNumber.zero,
      [final single] => single,
      _ => Add.of(terms),
    };
  }

  PuiseuxSeries _binaryIntPow(int n) {
    var base = this;
    var exp = n;
    PuiseuxSeries? result;
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

  PuiseuxSeries _unitPowExpr(Expr exponent) {
    final c0 = coefficients[IntegerNumber.zero]!;
    final invC0 = (IntegerNumber.one / c0).simplify();
    final positiveTerms = <({RationalNumber exp, Expr coeff})>[];
    for (final entry in coefficients.entries) {
      if (entry.key.isPositive) {
        positiveTerms.add((exp: entry.key, coeff: entry.value));
      }
    }

    final q = _newSortedMap();
    q[IntegerNumber.zero] = Pow.of(c0, exponent).simplify();

    final pending = _newSortedSet();
    for (final item in positiveTerms) {
      if (item.exp < order) {
        pending.add(item.exp);
      }
    }

    final onePlusExp = (IntegerNumber.one + exponent).simplify();
    while (pending.isNotEmpty) {
      final k = pending.first;
      pending.remove(k);
      final terms = <Expr>[];
      for (final item in positiveTerms) {
        if (item.exp > k) break;
        final remainder = (k - item.exp) as RationalNumber;
        final qj = q[remainder];
        if (qj != null && !isZeroExpr(qj)) {
          final factor = (onePlusExp * item.exp - k).simplify();
          terms.add(factor * item.coeff * qj);
        }
      }
      if (terms.isNotEmpty) {
        final sum = (terms.length == 1 ? terms.first : Add.of(terms))
            .simplify();
        if (!isZeroExpr(sum)) {
          final qk = ((invC0 * sum) / k).simplify();
          if (!isZeroExpr(qk)) {
            q[k] = qk;
            for (final item in positiveTerms) {
              final next = (k + item.exp) as RationalNumber;
              if (next < order) {
                pending.add(next);
              }
            }
          }
        }
      }
    }
    return PuiseuxSeries(variable, point, q, order);
  }

  void _checkCompatible(PuiseuxSeries other) {
    if (variable != other.variable) {
      throw ArgumentError(
        'Cannot combine Puiseux series with different variables: $variable vs ${other.variable}',
      );
    }
    if (point != other.point) {
      throw ArgumentError(
        'Cannot combine Puiseux series with different expansion points: $point vs ${other.point}',
      );
    }
  }

  static SplayTreeMap<RationalNumber, Expr> _newSortedMap() =>
      SplayTreeMap<RationalNumber, Expr>((a, b) => a.compareTo(b));

  static SplayTreeSet<RationalNumber> _newSortedSet() =>
      SplayTreeSet<RationalNumber>((a, b) => a.compareTo(b));

  static Map<RationalNumber, Expr> _cleanCoefficients(
    Map<RationalNumber, Expr> raw,
    RationalNumber order,
  ) {
    final result = _newSortedMap();
    for (final entry in raw.entries) {
      if (entry.key < order) {
        final simplified = entry.value.simplify();
        if (!isZeroExpr(simplified)) {
          result[entry.key] = simplified;
        }
      }
    }
    return UnmodifiableMapView<RationalNumber, Expr>(result);
  }
}

/// Expands [expr] as a [PuiseuxSeries] at `0`, using [PowerSeries] fast path
/// when all exponents are integers and falling back to [expandToPuiseuxSeries]
/// for fractional branch points.
PuiseuxSeries expandSeriesForLimit(
  Expr expr,
  String variable,
  int order,
  Assumptions assumptions, {
  bool requireOddDenominators = false,
}) {
  try {
    return PuiseuxSeries.fromPowerSeries(
      expr.toPowerSeries(
        variable,
        point: IntegerNumber.zero,
        order: order,
        assumptions: assumptions,
      ),
    );
  } on UnsupportedError {
    final puiseux = expr.toPuiseuxSeries(
      variable,
      point: IntegerNumber.zero,
      order: order,
      assumptions: assumptions,
    );
    if (requireOddDenominators && !puiseux.hasOnlyOddDenominators) {
      throw UnsupportedError(
        'Real fractional power requires right-hand limit at $variable -> 0+',
      );
    }
    return puiseux;
  } on ArgumentError {
    final puiseux = expr.toPuiseuxSeries(
      variable,
      point: IntegerNumber.zero,
      order: order,
      assumptions: assumptions,
    );
    if (requireOddDenominators && !puiseux.hasOnlyOddDenominators) {
      throw UnsupportedError(
        'Real fractional power requires right-hand limit at $variable -> 0+',
      );
    }
    return puiseux;
  }
}

/// Expands [expr] into a truncated [PuiseuxSeries] around [point] up to [order].
PuiseuxSeries expandToPuiseuxSeries(
  Expr expr,
  String variable,
  Expr point,
  RationalNumber order, [
  Assumptions assumptions = Assumptions.none,
]) => switch (expr) {
  Variable(:final name) when name == variable =>
    isZeroExpr(point)
        ? PuiseuxSeries(variable, point, {
            IntegerNumber.one: IntegerNumber.one,
          }, order)
        : PuiseuxSeries(variable, point, {
            IntegerNumber.zero: point,
            IntegerNumber.one: IntegerNumber.one,
          }, order),

  Number() || Constant() || Variable() => PuiseuxSeries(variable, point, {
    IntegerNumber.zero: expr,
  }, order),

  _ when !expr.dependsOn(variable) => PuiseuxSeries(variable, point, {
    IntegerNumber.zero: expr.simplify(assumptions: assumptions),
  }, order),

  Add(:final terms) => () {
    var sum = PuiseuxSeries(variable, point, const {}, order);
    for (final term in terms) {
      sum =
          sum +
          expandToPuiseuxSeries(term, variable, point, order, assumptions);
    }
    return sum;
  }(),

  Mul(:final factors) => _expandMulFactorsPuiseux(
    factors,
    variable,
    point,
    order,
    assumptions,
  ),

  Pow(base: Constant.e, :final exponent) => _expandExpPuiseux(
    exponent,
    variable,
    point,
    order,
    assumptions,
  ),

  Pow(:final base, :final exponent) => _expandPowPuiseux(
    base,
    exponent,
    variable,
    point,
    order,
    assumptions,
  ),

  Call(:final spec, :final id, :final args) => _expandCallPuiseux(
    expr,
    spec,
    id,
    args,
    variable,
    point,
    order,
    assumptions,
  ),

  _ => throw UnsupportedError(
    'Puiseux series expansion not supported for ${expr.runtimeType}',
  ),
};

PuiseuxSeries _expandMulFactorsPuiseux(
  List<Expr> factors,
  String variable,
  Expr point,
  RationalNumber order,
  Assumptions assumptions,
) {
  if (factors.isEmpty) {
    return PuiseuxSeries(variable, point, {
      IntegerNumber.zero: IntegerNumber.one,
    }, order);
  }
  if (factors.length == 1) {
    return expandToPuiseuxSeries(
      factors.first,
      variable,
      point,
      order,
      assumptions,
    );
  }
  final initial = [
    for (final factor in factors)
      expandToPuiseuxSeries(factor, variable, point, order, assumptions),
  ];
  var maxPole = IntegerNumber.zero as RationalNumber;
  var minValuationSum = IntegerNumber.zero as RationalNumber;
  for (final s in initial) {
    if (s.isZero) {
      return PuiseuxSeries(variable, point, const {}, order);
    }
    final pole = s.poleOrder;
    if (pole > maxPole) maxPole = pole;
    if (s.valuation.isNegative) {
      minValuationSum = (minValuationSum + s.valuation) as RationalNumber;
    }
  }
  if (maxPole.isZero) {
    var acc = initial.first;
    for (var i = 1; i < initial.length; i++) {
      acc = acc * initial[i];
    }
    return acc;
  }
  final boosted = <PuiseuxSeries>[];
  for (var i = 0; i < factors.length; i++) {
    final selfNeg = initial[i].valuation.isNegative
        ? initial[i].valuation
        : IntegerNumber.zero;
    final othersPole = (selfNeg - minValuationSum) as RationalNumber;
    final targetOrder = (order + othersPole) as RationalNumber;
    if (targetOrder > initial[i].order) {
      boosted.add(
        expandToPuiseuxSeries(
          factors[i],
          variable,
          point,
          targetOrder,
          assumptions,
        ),
      );
    } else {
      boosted.add(initial[i]);
    }
  }
  var acc = boosted.first;
  for (var i = 1; i < boosted.length; i++) {
    acc = acc * boosted[i];
  }
  return acc;
}

PuiseuxSeries _expandExpPuiseux(
  Expr exponent,
  String variable,
  Expr point,
  RationalNumber order,
  Assumptions assumptions,
) {
  final u = expandToPuiseuxSeries(
    exponent,
    variable,
    point,
    order,
    assumptions,
  );
  return _expFromPuiseuxSeries(u);
}

PuiseuxSeries _expFromPuiseuxSeries(PuiseuxSeries u) {
  if (!u.isZero && u.valuation.isNegative) {
    throw UnsupportedError(
      'Essential singularity: cannot expand exp of a series with a pole',
    );
  }
  final u0 = u.constantTerm;
  final positiveTerms = <({RationalNumber exp, Expr coeff})>[];
  for (final entry in u.coefficients.entries) {
    if (entry.key.isPositive) {
      positiveTerms.add((exp: entry.key, coeff: entry.value));
    }
  }
  final q = SplayTreeMap<RationalNumber, Expr>((a, b) => a.compareTo(b));
  q[IntegerNumber.zero] = IntegerNumber.one;

  final pending = SplayTreeSet<RationalNumber>((a, b) => a.compareTo(b));
  for (final item in positiveTerms) {
    if (item.exp < u.order) {
      pending.add(item.exp);
    }
  }

  while (pending.isNotEmpty) {
    final k = pending.first;
    pending.remove(k);
    final terms = <Expr>[];
    for (final item in positiveTerms) {
      if (item.exp > k) break;
      final qj = q[(k - item.exp) as RationalNumber];
      if (qj != null && !isZeroExpr(qj)) {
        terms.add(item.exp * item.coeff * qj);
      }
    }
    if (terms.isNotEmpty) {
      final sum = (terms.length == 1 ? terms.first : Add.of(terms)).simplify();
      if (!isZeroExpr(sum)) {
        final qk = (sum / k).simplify();
        if (!isZeroExpr(qk)) {
          q[k] = qk;
          for (final item in positiveTerms) {
            final next = (k + item.exp) as RationalNumber;
            if (next < u.order) {
              pending.add(next);
            }
          }
        }
      }
    }
  }

  final series = PuiseuxSeries(u.variable, u.point, q, u.order);
  return isZeroExpr(u0)
      ? series
      : series.scale(Pow.of(Constant.e, u0).simplify());
}

PuiseuxSeries _expandPowPuiseux(
  Expr base,
  Expr exponent,
  String variable,
  Expr point,
  RationalNumber order,
  Assumptions assumptions,
) {
  if (!base.dependsOn(variable)) {
    final sBase = base.simplify(assumptions: assumptions);
    if (isZeroExpr(sBase)) {
      if (!exponent.dependsOn(variable)) {
        final sExp = exponent.simplify(assumptions: assumptions);
        return PuiseuxSeries(variable, point, {
          IntegerNumber.zero: Pow.of(sBase, sExp).simplify(),
        }, order);
      }
      throw UnsupportedError(
        'Cannot expand 0^f($variable) with variable exponent',
      );
    }
    return _expandExpPuiseux(
      exponent * Fn.ln(sBase),
      variable,
      point,
      order,
      assumptions,
    );
  }

  if (!exponent.dependsOn(variable)) {
    final sExp = exponent.simplify(assumptions: assumptions);
    var sBase = expandToPuiseuxSeries(
      base,
      variable,
      point,
      order,
      assumptions,
    );
    if (sBase.isZero) {
      for (final extra in const [4, 12, 24]) {
        final probeOrder = (order + IntegerNumber.of(extra)) as RationalNumber;
        sBase = expandToPuiseuxSeries(
          base,
          variable,
          point,
          probeOrder,
          assumptions,
        );
        if (!sBase.isZero) break;
      }
    }
    if (sBase.isZero) {
      return sExp is RationalNumber ? sBase.powRational(sExp) : sBase.pow(sExp);
    }
    if (sExp is RationalNumber) {
      final m = sBase.valuation;
      final neededOrder =
          (order + m * (IntegerNumber.one - sExp)) as RationalNumber;
      if (neededOrder > sBase.order) {
        sBase = expandToPuiseuxSeries(
          base,
          variable,
          point,
          neededOrder,
          assumptions,
        );
      }
      return sBase.powRational(sExp);
    }
    return sBase.pow(sExp);
  }

  final uBase = expandToPuiseuxSeries(
    base,
    variable,
    point,
    order,
    assumptions,
  );
  if (uBase.isZero || !uBase.valuation.isZero) {
    throw UnsupportedError(
      'Essential or zero-base variable power requires non-zero valuation-0 base',
    );
  }
  final lnBase = _lnFromPuiseuxSeries(uBase, assumptions);
  var probeExp = expandToPuiseuxSeries(
    exponent,
    variable,
    point,
    order,
    assumptions,
  );
  if (!probeExp.isZero && probeExp.valuation.isNegative) {
    final boost = (order + probeExp.poleOrder) as RationalNumber;
    final lnBoosted = _lnFromPuiseuxSeries(
      expandToPuiseuxSeries(base, variable, point, boost, assumptions),
      assumptions,
    );
    probeExp = expandToPuiseuxSeries(
      exponent,
      variable,
      point,
      boost,
      assumptions,
    );
    return _expFromPuiseuxSeries(probeExp * lnBoosted);
  }
  return _expFromPuiseuxSeries(probeExp * lnBase);
}

PuiseuxSeries _lnFromPuiseuxSeries(PuiseuxSeries u, Assumptions assumptions) {
  if (u.isZero || !u.valuation.isZero) {
    throw UnsupportedError(
      'Logarithm of Puiseux series requires non-zero constant leading term',
    );
  }
  final c0 = u.constantTerm;
  final positiveTerms = <({RationalNumber exp, Expr coeff})>[];
  for (final entry in u.coefficients.entries) {
    if (entry.key.isPositive) {
      positiveTerms.add((exp: entry.key, coeff: entry.value));
    }
  }
  final q = SplayTreeMap<RationalNumber, Expr>((a, b) => a.compareTo(b));
  q[IntegerNumber.zero] = Fn.ln(c0).simplify(assumptions: assumptions);

  final pending = SplayTreeSet<RationalNumber>((a, b) => a.compareTo(b));
  for (final item in positiveTerms) {
    if (item.exp < u.order) {
      pending.add(item.exp);
    }
  }

  while (pending.isNotEmpty) {
    final k = pending.first;
    pending.remove(k);
    final numeratorTerms = <Expr>[];
    final uk = u.coefficients[k];
    if (uk != null) {
      numeratorTerms.add(k * uk);
    }
    for (final item in positiveTerms) {
      if (item.exp >= k) break;
      final rem = (k - item.exp) as RationalNumber;
      final qRem = q[rem];
      if (qRem != null && !isZeroExpr(qRem)) {
        numeratorTerms.add(-(rem * item.coeff * qRem));
      }
    }
    if (numeratorTerms.isNotEmpty) {
      final sum =
          (numeratorTerms.length == 1
                  ? numeratorTerms.first
                  : Add.of(numeratorTerms))
              .simplify(assumptions: assumptions);
      if (!isZeroExpr(sum)) {
        final qk = (sum / (k * c0)).simplify(assumptions: assumptions);
        if (!isZeroExpr(qk)) {
          q[k] = qk;
          for (final item in positiveTerms) {
            final next = (k + item.exp) as RationalNumber;
            if (next < u.order) {
              pending.add(next);
            }
          }
        }
      }
    }
  }

  return PuiseuxSeries(u.variable, u.point, q, u.order);
}

PuiseuxSeries _expandCallPuiseux(
  Expr expr,
  FunctionSpec spec,
  FunctionId id,
  List<Expr> args,
  String variable,
  Expr point,
  RationalNumber order,
  Assumptions assumptions,
) {
  if (id == FunctionId.ln && args.length == 1) {
    final u = expandToPuiseuxSeries(
      args.first,
      variable,
      point,
      order,
      assumptions,
    );
    return _lnFromPuiseuxSeries(u, assumptions);
  }
  if (args.length != 1) {
    throw UnsupportedError(
      'Puiseux series expansion not supported for ${id.name}',
    );
  }

  final u = expandToPuiseuxSeries(
    args.first,
    variable,
    point,
    order,
    assumptions,
  );
  if (!u.isZero && u.valuation.isNegative) {
    throw UnsupportedError(
      'Essential singularity: cannot expand ${id.name} of a series with a pole',
    );
  }
  if (u.hasOnlyIntegerExponents && order is IntegerNumber) {
    final intOrder = order.asInt;
    if (intOrder != null) {
      return PuiseuxSeries.fromPowerSeries(
        expandToPowerSeries(expr, variable, point, intOrder, assumptions),
      );
    }
  }

  final c0 = u.constantTerm;
  final positiveKeys = u.coefficients.keys.where((k) => k.isPositive).toList();
  if (positiveKeys.isEmpty) {
    return PuiseuxSeries(variable, point, {
      IntegerNumber.zero: Call(spec, [c0]).simplify(assumptions: assumptions),
    }, order);
  }

  final minPos = positiveKeys.first;
  final deg = _ceilQuotient(order, minPos).clamp(1, 128);
  final deltaCoeffs = SplayTreeMap<RationalNumber, Expr>(
    (a, b) => a.compareTo(b),
  );
  for (final k in positiveKeys) {
    deltaCoeffs[k] = u.coefficients[k]!;
  }
  final delta = PuiseuxSeries(variable, point, deltaCoeffs, order);

  const tempVar = '_puiseux_y';
  final outer = Call(
    spec,
    [const Variable(tempVar)],
  ).toPowerSeries(tempVar, point: c0, order: deg + 1, assumptions: assumptions);
  if (outer.poleOrder > 0) {
    throw UnsupportedError(
      'Puiseux composition encountered pole for ${id.name} at $c0',
    );
  }

  final maxK = outer.coefficients.keys.isEmpty
      ? -1
      : outer.coefficients.keys.reduce((a, b) => a > b ? a : b);
  if (maxK < 0) {
    return PuiseuxSeries(variable, point, const {}, order);
  }

  var acc = PuiseuxSeries(variable, point, {
    IntegerNumber.zero: outer.coefficients[maxK] ?? IntegerNumber.zero,
  }, order);
  for (var k = maxK - 1; k >= 0; k--) {
    final ck = outer.coefficients[k] ?? IntegerNumber.zero;
    acc =
        acc * delta +
        PuiseuxSeries(variable, point, {IntegerNumber.zero: ck}, order);
  }
  return acc;
}

int _ceilQuotient(RationalNumber order, RationalNumber step) {
  if (!order.isPositive) return 1;
  final q = (order / step) as RationalNumber;
  final whole = (q.numerator ~/ q.denominator).toInt();
  return q.isInteger ? whole : whole + 1;
}
