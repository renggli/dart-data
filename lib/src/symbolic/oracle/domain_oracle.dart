import 'dart:collection';
import 'dart:math' as math;

import '../assumptions.dart';
import '../ast.dart';
import '../compiler.dart';
import 'interval.dart';

/// Qualitative sign lattice inferred structurally from an expression and
/// optional [Assumptions].
enum Sign {
  /// Strictly negative (`< 0`).
  negative,

  /// Identically zero (`== 0`).
  zero,

  /// Strictly positive (`> 0`).
  positive,

  /// Real and non-negative (`>= 0`).
  nonNegative,

  /// Real and non-positive (`<= 0`).
  nonPositive,

  /// Provably non-zero (`!= 0`), sign possibly indeterminate or complex.
  nonZero,

  /// Unknown sign or domain.
  unknown,
}

/// Unified, memoized domain, interval, parity, and sign oracle over [Assumptions].
final class DomainOracle {
  /// Creates an oracle bound to [assumptions].
  new([this.assumptions = Assumptions.none]);

  /// Domain, interval, property, and relational assumptions used for queries.
  final Assumptions assumptions;

  Map<Expr, RealInterval>? _intervalCache;
  Map<Expr, Sign>? _signCache;
  Map<Expr, bool>? _realCache;
  Map<Expr, bool>? _intCache;
  Map<Expr, bool>? _evenCache;
  Map<Expr, bool>? _oddCache;
  Map<Expr, double?>? _staticRealCache;

  /// Evaluates [expr] to a constant finite real `double`, or returns `null`.
  double? tryStaticRealValue(Expr expr) {
    switch (expr) {
      case RealNumeric():
        return expr.toDouble();
      case Constant(:final isReal, :final value) when isReal:
        return value.a.toDouble();
      default:
        break;
    }
    if (expr.hasVariable) return null;
    final cache = _staticRealCache ??= HashMap<Expr, double?>();
    if (cache.containsKey(expr)) return cache[expr];
    double? resolved;
    try {
      final c = expr.evaluateComplex();
      if (c.b.abs() < 1e-12 && c.a.isFinite) {
        resolved = c.a.toDouble();
      }
    } on Object {
      resolved = null;
    }
    return cache[expr] = resolved;
  }

  /// Returns a sound real [RealInterval] enclosure for [expr], or
  /// [RealInterval.empty] if [expr] is not proven real-valued.
  RealInterval intervalOf(Expr expr) {
    switch (expr) {
      case RealNumeric():
        return RealInterval.point(expr.toDouble());
      case ComplexNumber(:final real, :final imaginary):
        return imaginary.isZero
            ? RealInterval.point(real.toDouble())
            : RealInterval.empty;
      case Constant(:final isReal, :final value):
        if (!isReal) return RealInterval.empty;
        final v = value.a.toDouble();
        if (!v.isFinite) return RealInterval.empty;
        return RealInterval.closed(
          RealInterval.nextDown(v),
          RealInterval.nextUp(v),
        );
      case Variable(:final name):
        var base = _baseIntervalForVar(name);
        final bound = assumptions.boundsOf(name);
        if (!bound.isUnbounded) {
          final boundIv = _boundToInterval(bound);
          base = base.isEmpty ? boundIv : base.intersect(boundIv);
        }
        return base;
      default:
        break;
    }
    final cache = _intervalCache ??= HashMap<Expr, RealInterval>();
    final cached = cache[expr];
    if (cached != null) return cached;
    final computed = _computeInterval(expr);
    cache[expr] = computed;
    return computed;
  }

  RealInterval _baseIntervalForVar(String name) {
    var iv = RealInterval.forDomain(assumptions.domainOf(name));
    if (iv.isEmpty && assumptions.isReal(name)) {
      iv = RealInterval.all;
    }
    if (assumptions.isPositive(name)) {
      iv = iv.isEmpty
          ? RealInterval.positive
          : iv.intersect(RealInterval.positive);
    } else if (assumptions.isNonNegative(name)) {
      iv = iv.isEmpty
          ? RealInterval.nonNegative
          : iv.intersect(RealInterval.nonNegative);
    }
    if (assumptions.isNegative(name)) {
      iv = iv.isEmpty
          ? RealInterval.negative
          : iv.intersect(RealInterval.negative);
    } else if (assumptions.isNonPositive(name)) {
      iv = iv.isEmpty
          ? RealInterval.nonPositive
          : iv.intersect(RealInterval.nonPositive);
    }
    return iv;
  }

  RealInterval _boundToInterval(VariableBounds bound) {
    var lo = double.negativeInfinity;
    var loInc = false;
    var hi = double.infinity;
    var hiInc = false;

    if (bound.lower case final l?) {
      final loIv = intervalOf(l);
      if (loIv.isEmpty) return RealInterval.empty;
      lo = loIv.lo;
      loInc = bound.lowerInclusive && loIv.loInclusive;
    }
    if (bound.upper case final u?) {
      final hiIv = intervalOf(u);
      if (hiIv.isEmpty) return RealInterval.empty;
      hi = hiIv.hi;
      hiInc = bound.upperInclusive && hiIv.hiInclusive;
    }
    return RealInterval.fromBounds(
      lo,
      hi,
      loInclusive: loInc,
      hiInclusive: hiInc,
    );
  }

  RealInterval _computeInterval(Expr expr) {
    switch (expr) {
      case Add(:final terms):
        if (terms.isEmpty) return RealInterval.point(0.0);
        var acc = intervalOf(terms.first);
        if (acc.isEmpty) return RealInterval.empty;
        for (var i = 1; i < terms.length; i++) {
          final next = intervalOf(terms[i]);
          if (next.isEmpty) return RealInterval.empty;
          acc = acc + next;
        }
        return acc;
      case Mul(:final factors):
        if (factors.isEmpty) return RealInterval.point(1.0);
        var acc = intervalOf(factors.first);
        if (acc.isEmpty) return RealInterval.empty;
        for (var i = 1; i < factors.length; i++) {
          final next = intervalOf(factors[i]);
          if (next.isEmpty) return RealInterval.empty;
          acc = acc * next;
        }
        return acc;
      case Pow(base: Constant.e, :final exponent):
        return intervalOf(exponent).exp();
      case Pow(:final base, :final exponent):
        final bIv = intervalOf(base);
        if (bIv.isEmpty) return RealInterval.empty;
        if (exponent case IntegerNumber(:final asInt)) {
          if (asInt != null && asInt.abs() <= 64) {
            return bIv.powInt(asInt);
          }
          if (bIv.containsZero && exponent.isNegative) {
            return RealInterval.empty;
          }
          if (!exponent.isNegative) {
            return exponent.value.isEven
                ? RealInterval.nonNegative
                : RealInterval.all;
          }
          return RealInterval.all;
        }
        if (exponent == FractionNumber.half) {
          return bIv.sqrt();
        }
        if (exponent == FractionNumber.negativeHalf) {
          final root = bIv.sqrt();
          if (root.isEmpty) return RealInterval.empty;
          return RealInterval.point(1.0) / root;
        }
        final eIv = intervalOf(exponent);
        if (eIv.isEmpty) return RealInterval.empty;
        if (exponent case FractionNumber(:final denominator)
            when denominator.isOdd && !exponent.isNegative) {
          return bIv.isNonNegative ? bIv.pow(eIv) : RealInterval.all;
        }
        return bIv.pow(eIv);
      case Call(:final id, :final args):
        return _callInterval(id, args);
      default:
        return isReal(expr) ? RealInterval.all : RealInterval.empty;
    }
  }

  RealInterval _callInterval(FunctionId id, List<Expr> args) {
    if (args.length == 1) {
      final a = args[0];
      switch (id) {
        case FunctionId.abs:
          final inner = intervalOf(a);
          if (!inner.isEmpty) return inner.abs();
          return a.anyNode((n) => n == Constant.undefined)
              ? RealInterval.empty
              : RealInterval.nonNegative;
        case FunctionId.re || FunctionId.im || FunctionId.arg:
          return a.anyNode((n) => n == Constant.undefined)
              ? RealInterval.empty
              : RealInterval.all;
        case FunctionId.floor:
          return intervalOf(a).floor();
        case FunctionId.ceil:
          return intervalOf(a).ceil();
        case FunctionId.round:
          return intervalOf(a).round();
        case FunctionId.sign:
          return intervalOf(a).sign();
        case FunctionId.sin:
          return intervalOf(a).sin();
        case FunctionId.cos:
          return intervalOf(a).cos();
        case FunctionId.tan:
          return intervalOf(a).tan();
        case FunctionId.asin:
          return intervalOf(a).asin();
        case FunctionId.acos:
          return intervalOf(a).acos();
        case FunctionId.atan:
          return intervalOf(a).atan();
        case FunctionId.sinh:
          return intervalOf(a).sinh();
        case FunctionId.cosh:
          return intervalOf(a).cosh();
        case FunctionId.tanh:
          return intervalOf(a).tanh();
        case FunctionId.asinh:
          return intervalOf(a).asinh();
        case FunctionId.acosh:
          return intervalOf(a).acosh();
        case FunctionId.atanh:
          return intervalOf(a).atanh();
        case FunctionId.ln:
          return intervalOf(a).ln();
        case FunctionId.erf:
          return intervalOf(a).erf();
        case FunctionId.erfc:
          return intervalOf(a).erfc();
        default:
          break;
      }
    }
    if (id == FunctionId.atan2 && args.length == 2) {
      if (isReal(args[0]) && isReal(args[1])) {
        return RealInterval.closed(-math.pi, math.pi);
      }
      return RealInterval.empty;
    }
    return _isRealCall(id, args) ? RealInterval.all : RealInterval.empty;
  }

  /// Infers the qualitative [Sign] of [expr] under [assumptions].
  Sign signOf(Expr expr) {
    switch (expr) {
      case RealNumeric(:final isZero, :final isNegative):
        if (expr is RealNumber && expr.value.isNaN) return Sign.unknown;
        if (isZero) return Sign.zero;
        return isNegative ? Sign.negative : Sign.positive;
      case ComplexNumber(:final isZero, :final imaginary):
        if (isZero) return Sign.zero;
        if (!imaginary.isZero) return Sign.nonZero;
        return expr.real.isNegative ? Sign.negative : Sign.positive;
      case Constant(:final isReal, :final value):
        if (expr == Constant.undefined) return Sign.unknown;
        if (expr == Constant.infinity) return Sign.positive;
        if (!isReal || value.b != 0.0) return Sign.unknown;
        if (value.a > 0.0) return Sign.positive;
        if (value.a < 0.0) return Sign.negative;
        return Sign.zero;
      case Variable(:final name):
        if (assumptions.isPositive(name)) return Sign.positive;
        if (assumptions.isNegative(name)) return Sign.negative;
        if (assumptions.isNonNegative(name)) return Sign.nonNegative;
        if (assumptions.isNonPositive(name)) return Sign.nonPositive;
        if (assumptions.isNonZero(name)) return Sign.nonZero;
        final bound = assumptions.boundsOf(name);
        if (!bound.isUnbounded) {
          final iv = _boundToInterval(bound);
          if (iv.isZero) return Sign.zero;
          if (iv.isStrictlyPositive) return Sign.positive;
          if (iv.isStrictlyNegative) return Sign.negative;
          if (iv.isNonNegative) return Sign.nonNegative;
          if (iv.isNonPositive) return Sign.nonPositive;
        }
        return Sign.unknown;
      default:
        break;
    }
    final cache = _signCache ??= HashMap<Expr, Sign>();
    final cached = cache[expr];
    if (cached != null) return cached;
    final computed = _computeSign(expr);
    cache[expr] = computed;
    return computed;
  }

  Sign _computeSign(Expr expr) {
    final structural = _inferStructuralSign(expr);
    if (structural == Sign.positive ||
        structural == Sign.negative ||
        structural == Sign.zero) {
      return structural;
    }

    final iv = intervalOf(expr);
    if (!iv.isEmpty) {
      if (iv.isZero) return Sign.zero;
      if (iv.isStrictlyPositive) return Sign.positive;
      if (iv.isStrictlyNegative) return Sign.negative;
      if (structural == Sign.nonNegative || iv.isNonNegative) {
        return Sign.nonNegative;
      }
      if (structural == Sign.nonPositive || iv.isNonPositive) {
        return Sign.nonPositive;
      }
    }
    if (structural != Sign.unknown) return structural;

    if (expr is! Number && expr is! Constant && !expr.hasVariable) {
      final val = tryStaticRealValue(expr);
      if (val != null && val.isFinite && val.abs() > 1e-12) {
        return val > 0.0 ? Sign.positive : Sign.negative;
      }
    }
    return Sign.unknown;
  }

  Sign _inferStructuralSign(Expr expr) => switch (expr) {
    Add(:final terms) => () {
      final relSign = _signFromRelations(expr);
      return relSign != Sign.unknown ? relSign : _combineAddSign(terms);
    }(),
    Mul(:final factors) => _combineMulSign(factors),
    Pow(:final base, :final exponent) => _inferPowSign(base, exponent),
    Call(:final id, :final args) => _inferCallSign(expr, id, args),
    _ => Sign.unknown,
  };

  Sign _signFromRelations(Expr expr) {
    for (final rel in assumptions.relations) {
      final diff = rel.left - rel.right;
      if (diff == expr) {
        return switch (rel.op) {
          RelOp.greaterThan => Sign.positive,
          RelOp.greaterEqual => Sign.nonNegative,
          RelOp.lessThan => Sign.negative,
          RelOp.lessEqual => Sign.nonPositive,
          RelOp.equal => Sign.zero,
          RelOp.notEqual => Sign.nonZero,
        };
      }
      if (-diff == expr) {
        return switch (rel.op) {
          RelOp.greaterThan => Sign.negative,
          RelOp.greaterEqual => Sign.nonPositive,
          RelOp.lessThan => Sign.positive,
          RelOp.lessEqual => Sign.nonNegative,
          RelOp.equal => Sign.zero,
          RelOp.notEqual => Sign.nonZero,
        };
      }
    }
    return Sign.unknown;
  }

  Sign _combineAddSign(List<Expr> terms) {
    if (terms.isEmpty) return Sign.zero;
    var allNonNeg = true;
    var allNonPos = true;
    var hasPos = false;
    var hasNeg = false;
    var allZero = true;

    for (final t in terms) {
      final s = signOf(t);
      switch (s) {
        case Sign.zero:
          break;
        case Sign.positive:
          allZero = false;
          allNonPos = false;
          hasPos = true;
        case Sign.nonNegative:
          allZero = false;
          allNonPos = false;
        case Sign.negative:
          allZero = false;
          allNonNeg = false;
          hasNeg = true;
        case Sign.nonPositive:
          allZero = false;
          allNonNeg = false;
        case Sign.nonZero || Sign.unknown:
          return Sign.unknown;
      }
    }

    if (allZero) return Sign.zero;
    if (allNonNeg) return hasPos ? Sign.positive : Sign.nonNegative;
    if (allNonPos) return hasNeg ? Sign.negative : Sign.nonPositive;
    return Sign.unknown;
  }

  Sign _combineMulSign(List<Expr> factors) {
    if (factors.isEmpty) return Sign.positive;
    var negCount = 0;
    var hasZero = false;
    var hasNonZeroOnly = false;
    var hasNonStrict = false;
    var negNonStrictCount = 0;

    for (final f in factors) {
      final s = signOf(f);
      switch (s) {
        case Sign.zero:
          hasZero = true;
        case Sign.positive:
          break;
        case Sign.negative:
          negCount++;
        case Sign.nonNegative:
          hasNonStrict = true;
        case Sign.nonPositive:
          hasNonStrict = true;
          negNonStrictCount++;
        case Sign.nonZero:
          hasNonZeroOnly = true;
        case Sign.unknown:
          return Sign.unknown;
      }
    }

    if (hasZero) {
      return factors.any(
            (x) => x == Constant.infinity || x == Constant.undefined,
          )
          ? Sign.unknown
          : Sign.zero;
    }
    if (hasNonZeroOnly) {
      return hasNonStrict ? Sign.unknown : Sign.nonZero;
    }
    if (hasNonStrict) {
      final totalNeg = negCount + negNonStrictCount;
      return totalNeg.isEven ? Sign.nonNegative : Sign.nonPositive;
    }
    return negCount.isEven ? Sign.positive : Sign.negative;
  }

  Sign _inferPowSign(Expr base, Expr exponent) {
    if (base == Constant.e && isReal(exponent)) {
      return Sign.positive;
    }
    final bSign = signOf(base);
    if (bSign == Sign.positive && isReal(exponent)) {
      return Sign.positive;
    }
    if (bSign == Sign.nonNegative) {
      if (exponent is Number && exponent.isZero) return Sign.positive;
      if (isNonNegative(exponent)) {
        return Sign.nonNegative;
      }
    }
    if (exponent case IntegerNumber(:final value)) {
      if (value == BigInt.zero && base != Constant.infinity) {
        return Sign.positive;
      }
      if (value.isEven && isReal(base)) {
        if (value > BigInt.zero) {
          return _isStrictNonZeroSign(bSign) ? Sign.positive : Sign.nonNegative;
        }
        if (_isStrictNonZeroSign(bSign)) return Sign.positive;
      }
      if (value.isOdd) {
        if (value > BigInt.zero) return bSign;
        if (_isStrictNonZeroSign(bSign)) return bSign;
      }
    }
    return Sign.unknown;
  }

  Sign _inferCallSign(Expr expr, FunctionId id, List<Expr> args) {
    switch (id) {
      case FunctionId.abs when !args[0].anyNode((n) => n == Constant.undefined):
        if (isNonZero(args[0]) || args[0] == Constant.infinity) {
          return Sign.positive;
        }
        return Sign.nonNegative;
      case FunctionId.cosh when isReal(args[0]):
        return Sign.positive;
      case FunctionId.ln:
        if (args[0] == Constant.e) return Sign.positive;
        final iv = intervalOf(args[0]);
        if (!iv.isEmpty) {
          if (iv.lo > 1.0 || (iv.lo == 1.0 && !iv.loInclusive)) {
            return Sign.positive;
          }
          if (iv.lo > 0.0 &&
              (iv.hi < 1.0 || (iv.hi == 1.0 && !iv.hiInclusive))) {
            return Sign.negative;
          }
          if (iv.isPoint && iv.lo == 1.0) return Sign.zero;
        }
        final v = tryStaticRealValue(args[0]);
        if (v == null) return Sign.unknown;
        if (v > 1.0) return Sign.positive;
        if (v > 0.0 && v < 1.0) return Sign.negative;
        if (v == 1.0) return Sign.zero;
        return Sign.unknown;
      case FunctionId.sin || FunctionId.cos:
        final v = tryStaticRealValue(expr);
        if (v == null) return Sign.unknown;
        if (v > 1e-12) return Sign.positive;
        if (v < -1e-12) return Sign.negative;
        return Sign.unknown;
      case FunctionId.gamma when isPositive(args[0]):
        return Sign.positive;
      case FunctionId.factorial when isNonNegative(args[0]):
        return Sign.positive;
      default:
        return Sign.unknown;
    }
  }

  static bool _isStrictNonZeroSign(Sign s) =>
      s == Sign.positive || s == Sign.negative || s == Sign.nonZero;

  /// Returns `true` if [expr] is proven strictly positive (`> 0`).
  bool isPositive(Expr expr) => signOf(expr) == Sign.positive;

  /// Returns `true` if [expr] is proven strictly negative (`< 0`).
  bool isNegative(Expr expr) => signOf(expr) == Sign.negative;

  /// Returns `true` if [expr] is proven non-negative (`>= 0`).
  bool isNonNegative(Expr expr) {
    final s = signOf(expr);
    return s == Sign.positive || s == Sign.nonNegative || s == Sign.zero;
  }

  /// Returns `true` if [expr] is proven non-positive (`<= 0`).
  bool isNonPositive(Expr expr) {
    final s = signOf(expr);
    return s == Sign.negative || s == Sign.nonPositive || s == Sign.zero;
  }

  /// Returns `true` if [expr] is proven identically zero (`== 0`).
  bool isZero(Expr expr) => signOf(expr) == Sign.zero;

  /// Returns `true` if [expr] is proven non-zero (`!= 0`).
  bool isNonZero(Expr expr) => _isStrictNonZeroSign(signOf(expr));

  /// Returns `true` if [expr] is proven integer-valued (`∈ Z`).
  bool isInteger(Expr expr) {
    if (expr is IntegerNumber) return true;
    if (expr is FractionNumber ||
        expr is RealNumber ||
        expr is ComplexNumber ||
        expr is Constant) {
      return false;
    }
    if (expr is Variable) return assumptions.isInteger(expr.name);
    final cache = _intCache ??= HashMap<Expr, bool>();
    final cached = cache[expr];
    if (cached != null) return cached;
    final res = switch (expr) {
      Call(
        id: FunctionId.floor ||
            FunctionId.ceil ||
            FunctionId.round ||
            FunctionId.sign,
        args: [final inner],
      ) =>
        isReal(inner),
      Call(id: FunctionId.factorial, args: [final inner]) =>
        isInteger(inner) && isNonNegative(inner),
      Call(id: FunctionId.binomial, args: [final left, final right]) =>
        isInteger(left) && isInteger(right),
      Add(:final terms) => terms.every(isInteger),
      Mul(:final factors) => factors.every(isInteger),
      Pow(:final base, :final exponent) =>
        isInteger(base) && exponent is IntegerNumber && !exponent.isNegative,
      _ => false,
    };
    cache[expr] = res;
    return res;
  }

  /// Returns `true` if [expr] is proven to be an even integer (`∈ 2Z`).
  bool isEvenInteger(Expr expr) {
    if (expr is IntegerNumber) return expr.value.isEven;
    if (expr is FractionNumber ||
        expr is RealNumber ||
        expr is ComplexNumber ||
        expr is Constant) {
      return false;
    }
    if (expr is Variable) return assumptions.isEven(expr.name);
    final cache = _evenCache ??= HashMap<Expr, bool>();
    final cached = cache[expr];
    if (cached != null) return cached;
    final res = switch (expr) {
      Mul(:final factors) =>
        factors.every(isInteger) && factors.any(isEvenInteger),
      Add(:final terms) => () {
        var oddCount = 0;
        for (final t in terms) {
          if (isEvenInteger(t)) continue;
          if (isOddInteger(t)) {
            oddCount++;
            continue;
          }
          return false;
        }
        return oddCount.isEven;
      }(),
      Pow(:final base, :final exponent) =>
        isEvenInteger(base) &&
            exponent is IntegerNumber &&
            exponent.value > BigInt.zero,
      _ => false,
    };
    cache[expr] = res;
    return res;
  }

  /// Returns `true` if [expr] is proven to be an odd integer (`∈ 2Z + 1`).
  bool isOddInteger(Expr expr) {
    if (expr is IntegerNumber) return expr.value.isOdd;
    if (expr is FractionNumber ||
        expr is RealNumber ||
        expr is ComplexNumber ||
        expr is Constant) {
      return false;
    }
    if (expr is Variable) return assumptions.isOdd(expr.name);
    final cache = _oddCache ??= HashMap<Expr, bool>();
    final cached = cache[expr];
    if (cached != null) return cached;
    final res = switch (expr) {
      Mul(:final factors) => factors.every(isOddInteger),
      Add(:final terms) => () {
        var oddCount = 0;
        for (final t in terms) {
          if (isEvenInteger(t)) continue;
          if (isOddInteger(t)) {
            oddCount++;
            continue;
          }
          return false;
        }
        return oddCount.isOdd;
      }(),
      Pow(:final base, exponent: IntegerNumber(:final value))
          when value >= BigInt.zero =>
        value == BigInt.zero || isOddInteger(base),
      _ => false,
    };
    cache[expr] = res;
    return res;
  }

  /// Returns `true` if [expr] is proven real-valued under [assumptions].
  bool isReal(Expr expr) {
    switch (expr) {
      case RealNumeric():
        return true;
      case ComplexNumber(:final imaginary):
        return imaginary.isZero;
      case Constant(:final isReal):
        return isReal;
      case Variable(:final name):
        return assumptions.isReal(name);
      default:
        break;
    }
    final cache = _realCache ??= HashMap<Expr, bool>();
    final cached = cache[expr];
    if (cached != null) return cached;
    final res = switch (expr) {
      Add(:final terms) => terms.every(isReal),
      Mul(:final factors) => factors.every(isReal),
      Pow(base: Constant.e, :final exponent) => isReal(exponent),
      Pow(:final base, :final exponent) =>
        (isReal(base) &&
                exponent is IntegerNumber &&
                (!exponent.isNegative || isNonZero(base))) ||
            (isPositive(base) && isReal(exponent)) ||
            (isNonNegative(base) && isPositive(exponent)) ||
            (isReal(base) &&
                exponent is FractionNumber &&
                exponent.denominator.isOdd &&
                (!exponent.isNegative || isNonZero(base))),
      Call(:final id, :final args) => _isRealCall(id, args),
      _ => false,
    };
    cache[expr] = res;
    return res;
  }

  bool _isRealCall(FunctionId id, List<Expr> args) => switch (id) {
    FunctionId.abs ||
    FunctionId.re ||
    FunctionId.im ||
    FunctionId.arg => !args[0].anyNode((n) => n == Constant.undefined),
    FunctionId.floor ||
    FunctionId.ceil ||
    FunctionId.round ||
    FunctionId.sign => isReal(args[0]),
    FunctionId.factorial =>
      isReal(args[0]) &&
          (isNonNegative(args[0]) ||
              switch (tryStaticRealValue(args[0])) {
                final v? => v >= 0.0 || (v != v.floorToDouble()),
                _ => false,
              }),
    FunctionId.binomial => isReal(args[0]) && isReal(args[1]),
    FunctionId.lambertW => () {
      final inner = args[0];
      if (!isReal(inner)) return false;
      final branch = args.length == 1
          ? 0
          : (args[1] is IntegerNumber
                ? (args[1] as IntegerNumber).asInt
                : null);
      if (branch == 0) {
        final iv = intervalOf(inner);
        if (iv.isNonNegative || (!iv.isEmpty && iv.lo >= -1.0 / math.e)) {
          return true;
        }
        return switch (tryStaticRealValue(inner)) {
          final v? => v >= -1.0 / math.e,
          _ => false,
        };
      }
      if (branch == -1) {
        final iv = intervalOf(inner);
        if (!iv.isEmpty && iv.lo >= -1.0 / math.e && iv.hi < 0.0) {
          return true;
        }
        return switch (tryStaticRealValue(inner)) {
          final v? => v >= -1.0 / math.e && v < 0.0,
          _ => false,
        };
      }
      return false;
    }(),
    FunctionId.sin ||
    FunctionId.cos ||
    FunctionId.tan ||
    FunctionId.atan ||
    FunctionId.sinh ||
    FunctionId.cosh ||
    FunctionId.tanh ||
    FunctionId.asinh ||
    FunctionId.erf ||
    FunctionId.erfc ||
    FunctionId.erfi ||
    FunctionId.fresnelS ||
    FunctionId.fresnelC ||
    FunctionId.ei ||
    FunctionId.si ||
    FunctionId.shi => isReal(args[0]),
    FunctionId.zeta =>
      isReal(args[0]) &&
          switch (tryStaticRealValue(args[0])) {
            final v? => v != 1.0,
            _ => false,
          } &&
          (args.length < 2 || isReal(args[1])),
    FunctionId.expIntegralE => isReal(args[0]) && isPositive(args[1]),
    FunctionId.hypergeometric => () {
      final upper = args[0] is Call && (args[0] as Call).id == FunctionId.tuple
          ? (args[0] as Call).args
          : [args[0]];
      final lower = args[1] is Call && (args[1] as Call).id == FunctionId.tuple
          ? (args[1] as Call).args
          : [args[1]];
      if (!upper.every(isReal) || !lower.every(isReal) || !isReal(args[2])) {
        return false;
      }
      final iv = intervalOf(args[2]);
      if (!iv.isEmpty && iv.hi <= 1.0) return true;
      return switch (tryStaticRealValue(args[2])) {
        final v? => v <= 1.0,
        _ => false,
      };
    }(),
    FunctionId.appellF1 => () {
      if (!args.every(isReal)) return false;
      final ivX = intervalOf(args[4]);
      final ivY = intervalOf(args[5]);
      if (!ivX.isEmpty && !ivY.isEmpty && ivX.hi < 1.0 && ivY.hi < 1.0) {
        return true;
      }
      return switch ((
        tryStaticRealValue(args[4]),
        tryStaticRealValue(args[5]),
      )) {
        (final vx?, final vy?) => vx < 1.0 && vy < 1.0,
        _ => false,
      };
    }(),
    FunctionId.logGamma || FunctionId.ln => isPositive(args[0]),
    FunctionId.min ||
    FunctionId.max ||
    FunctionId.gcd ||
    FunctionId.lcm ||
    FunctionId.tuple => args.every(isReal),
    FunctionId.gamma || FunctionId.digamma =>
      isReal(args[0]) &&
          (isPositive(args[0]) ||
              switch (tryStaticRealValue(args[0])) {
                final v? => v > 0.0 || (v != v.floorToDouble()),
                _ => false,
              }),
    FunctionId.li || FunctionId.ci || FunctionId.chi => isPositive(args[0]),
    FunctionId.ellipticK => () {
      if (!isReal(args[0])) return false;
      final iv = intervalOf(args[0]);
      if (!iv.isEmpty && iv.isSubsetOf(RealInterval.open(-1.0, 1.0))) {
        return true;
      }
      return switch (tryStaticRealValue(args[0])) {
        final v? => v.abs() < 1.0,
        _ => false,
      };
    }(),
    FunctionId.ellipticE => () {
      final modArg = args.length == 1 ? args[0] : args[1];
      if (args.length == 2 && !isReal(args[0])) return false;
      if (!isReal(modArg)) return false;
      final iv = intervalOf(modArg);
      if (!iv.isEmpty && iv.isSubsetOf(RealInterval.unitClosed)) return true;
      return switch (tryStaticRealValue(modArg)) {
        final v? => v.abs() <= 1.0,
        _ => false,
      };
    }(),
    FunctionId.polygamma ||
    FunctionId.ellipticF ||
    FunctionId.atan2 ||
    FunctionId.mod => isReal(args[0]) && isReal(args[1]),
    FunctionId.ellipticPi => args.every(isReal),
    FunctionId.besselJ || FunctionId.besselI =>
      isReal(args[0]) &&
          isReal(args[1]) &&
          (isInteger(args[0]) || isNonNegative(args[1])),
    FunctionId.besselY ||
    FunctionId.besselK ||
    FunctionId.upperGamma ||
    FunctionId.lowerGamma => isReal(args[0]) && isPositive(args[1]),
    FunctionId.polylog => () {
      if (!isReal(args[0]) || !isReal(args[1])) return false;
      final iv = intervalOf(args[1]);
      if (!iv.isEmpty && iv.hi <= 1.0) return true;
      return switch (tryStaticRealValue(args[1])) {
        final v? => v <= 1.0,
        _ => false,
      };
    }(),
    FunctionId.asin || FunctionId.acos => () {
      if (!isReal(args[0])) return false;
      final iv = intervalOf(args[0]);
      if (!iv.isEmpty && iv.isSubsetOf(RealInterval.unitClosed)) return true;
      return switch (tryStaticRealValue(args[0])) {
        final v? => v.abs() <= 1.0,
        _ => false,
      };
    }(),
    FunctionId.acosh => () {
      if (!isReal(args[0])) return false;
      final iv = intervalOf(args[0]);
      if (!iv.isEmpty && iv.lo >= 1.0) return true;
      return switch (tryStaticRealValue(args[0])) {
        final v? => v >= 1.0,
        _ => false,
      };
    }(),
    FunctionId.atanh => () {
      if (!isReal(args[0])) return false;
      final iv = intervalOf(args[0]);
      if (!iv.isEmpty && iv.isSubsetOf(RealInterval.open(-1.0, 1.0))) {
        return true;
      }
      return switch (tryStaticRealValue(args[0])) {
        final v? => v.abs() < 1.0,
        _ => false,
      };
    }(),
    FunctionId.beta => isPositive(args[0]) && isPositive(args[1]),
    _ => false,
  };
}
