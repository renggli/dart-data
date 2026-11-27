import 'dart:math' as math;
import 'dart:typed_data';

import '../../special/erf.dart' as special_erf;
import '../ast.dart';

/// Sound real interval enclosure with openness tracking and IEEE-754 outward
/// rounding across VM, JavaScript, and WebAssembly targets.
final class RealInterval {
  /// Creates a real interval with bounds `[lo, hi]` and endpoint inclusivity.
  const new _(
    this.lo,
    this.hi, {
    this.loInclusive = true,
    this.hiInclusive = true,
  });

  /// Constructs a bounded/unbounded enclosure if non-empty, or [empty].
  factory fromBounds(
    double lo,
    double hi, {
    bool loInclusive = true,
    bool hiInclusive = true,
  }) {
    if (lo.isNaN || hi.isNaN) return empty;
    if (lo > hi) return empty;
    final cleanLo = lo == 0.0 ? 0.0 : lo;
    final cleanHi = hi == 0.0 ? 0.0 : hi;
    final normLoInc = cleanLo.isInfinite ? false : loInclusive;
    final normHiInc = cleanHi.isInfinite ? false : hiInclusive;
    if (cleanLo == cleanHi && (!normLoInc || !normHiInc)) {
      return empty;
    }
    return RealInterval._(
      cleanLo,
      cleanHi,
      loInclusive: normLoInc,
      hiInclusive: normHiInc,
    );
  }

  /// Exact singleton interval `[x, x]`.
  factory point(double x) {
    if (x.isNaN || x.isInfinite) return empty;
    final v = x == 0.0 ? 0.0 : x;
    return RealInterval._(v, v);
  }

  /// Closed interval `[lo, hi]`.
  factory closed(double lo, double hi) => RealInterval.fromBounds(lo, hi);

  /// Open interval `(lo, hi)`.
  factory open(double lo, double hi) =>
      RealInterval.fromBounds(lo, hi, loInclusive: false, hiInclusive: false);

  /// Empty interval sentinel.
  static const RealInterval empty = RealInterval._(
    double.nan,
    double.nan,
    loInclusive: false,
    hiInclusive: false,
  );

  /// Entire real line `(-oo, +oo)`.
  static const RealInterval all = RealInterval._(
    double.negativeInfinity,
    double.infinity,
    loInclusive: false,
    hiInclusive: false,
  );

  /// Strictly positive reals `(0, +oo)`.
  static const RealInterval positive = RealInterval._(
    0.0,
    double.infinity,
    loInclusive: false,
    hiInclusive: false,
  );

  /// Non-negative reals `[0, +oo)`.
  static const RealInterval nonNegative = RealInterval._(
    0.0,
    double.infinity,
    loInclusive: true,
    hiInclusive: false,
  );

  /// Strictly negative reals `(-oo, 0)`.
  static const RealInterval negative = RealInterval._(
    double.negativeInfinity,
    0.0,
    loInclusive: false,
    hiInclusive: false,
  );

  /// Non-positive reals `(-oo, 0]`.
  static const RealInterval nonPositive = RealInterval._(
    double.negativeInfinity,
    0.0,
    loInclusive: false,
    hiInclusive: true,
  );

  /// Closed unit interval `[-1, 1]`.
  static const RealInterval unitClosed = RealInterval._(-1.0, 1.0);

  /// Lower endpoint (`double.nan` when empty).
  final double lo;

  /// Upper endpoint (`double.nan` when empty).
  final double hi;

  /// Whether [lo] belongs to the interval.
  final bool loInclusive;

  /// Whether [hi] belongs to the interval.
  final bool hiInclusive;

  /// Whether this interval is empty.
  bool get isEmpty => lo.isNaN || hi.isNaN;

  /// Whether this interval equals `(-oo, +oo)`.
  bool get isAll => lo == double.negativeInfinity && hi == double.infinity;

  /// Whether both endpoints are finite.
  bool get isFinite => lo.isFinite && hi.isFinite;

  /// Whether this interval represents a single finite point `[x, x]`.
  bool get isPoint => isFinite && lo == hi && loInclusive && hiInclusive;

  /// Whether this interval is exactly `[0, 0]`.
  bool get isZero => isPoint && lo == 0.0;

  /// Whether every element in this non-empty interval is strictly `> 0`.
  bool get isStrictlyPositive =>
      !isEmpty && (lo > 0.0 || (lo == 0.0 && !loInclusive));

  /// Whether every element in this non-empty interval is `>= 0`.
  bool get isNonNegative => !isEmpty && lo >= 0.0;

  /// Whether every element in this non-empty interval is strictly `< 0`.
  bool get isStrictlyNegative =>
      !isEmpty && (hi < 0.0 || (hi == 0.0 && !hiInclusive));

  /// Whether every element in this non-empty interval is `<= 0`.
  bool get isNonPositive => !isEmpty && hi <= 0.0;

  /// Whether `0.0` belongs to this interval.
  bool get containsZero =>
      !isEmpty &&
      (lo < 0.0 || (lo == 0.0 && loInclusive)) &&
      (hi > 0.0 || (hi == 0.0 && hiInclusive));

  /// Whether [x] belongs to this interval.
  bool contains(double x) {
    if (isEmpty || !x.isFinite) return false;
    final aboveLo = x > lo || (x == lo && loInclusive);
    final belowHi = x < hi || (x == hi && hiInclusive);
    return aboveLo && belowHi;
  }

  /// Whether every element of `this` is contained in [other].
  bool isSubsetOf(RealInterval other) {
    if (isEmpty) return true;
    if (other.isEmpty) return false;
    final loOk =
        lo > other.lo ||
        (lo == other.lo && (!loInclusive || other.loInclusive));
    final hiOk =
        hi < other.hi ||
        (hi == other.hi && (!hiInclusive || other.hiInclusive));
    return loOk && hiOk;
  }

  /// Set intersection `this ∩ other`.
  RealInterval intersect(RealInterval other) {
    if (isEmpty || other.isEmpty) return empty;
    final (newLo, newLoInc) = _pickBound(
      lo,
      loInclusive,
      other.lo,
      other.loInclusive,
      pickMax: true,
      tieAnd: true,
    );
    final (newHi, newHiInc) = _pickBound(
      hi,
      hiInclusive,
      other.hi,
      other.hiInclusive,
      pickMax: false,
      tieAnd: true,
    );
    return RealInterval.fromBounds(
      newLo,
      newHi,
      loInclusive: newLoInc,
      hiInclusive: newHiInc,
    );
  }

  /// Convex hull enclosure containing both `this` and [other].
  RealInterval hull(RealInterval other) {
    if (isEmpty) return other;
    if (other.isEmpty) return this;
    final (newLo, newLoInc) = _pickBound(
      lo,
      loInclusive,
      other.lo,
      other.loInclusive,
      pickMax: false,
      tieAnd: false,
    );
    final (newHi, newHiInc) = _pickBound(
      hi,
      hiInclusive,
      other.hi,
      other.hiInclusive,
      pickMax: true,
      tieAnd: false,
    );
    return RealInterval.fromBounds(
      newLo,
      newHi,
      loInclusive: newLoInc,
      hiInclusive: newHiInc,
    );
  }

  static (double, bool) _pickBound(
    double a,
    bool aInc,
    double b,
    bool bInc, {
    required bool pickMax,
    required bool tieAnd,
  }) {
    if (a == b) return (a, tieAnd ? (aInc && bInc) : (aInc || bInc));
    final chooseA = pickMax ? a > b : a < b;
    return chooseA ? (a, aInc) : (b, bInc);
  }

  /// Unary negation `-this`.
  RealInterval operator -() {
    if (isEmpty) return empty;
    return RealInterval.fromBounds(
      -hi,
      -lo,
      loInclusive: hiInclusive,
      hiInclusive: loInclusive,
    );
  }

  /// Sound interval addition `this + other`.
  RealInterval operator +(RealInterval other) {
    if (isEmpty || other.isEmpty) return empty;
    final newLo =
        (lo == double.negativeInfinity || other.lo == double.negativeInfinity)
        ? double.negativeInfinity
        : _addLo(lo, other.lo);
    final newHi = (hi == double.infinity || other.hi == double.infinity)
        ? double.infinity
        : _addHi(hi, other.hi);
    return RealInterval.fromBounds(
      newLo,
      newHi,
      loInclusive: loInclusive && other.loInclusive,
      hiInclusive: hiInclusive && other.hiInclusive,
    );
  }

  /// Sound interval subtraction `this - other`.
  RealInterval operator -(RealInterval other) => this + (-other);

  /// Sound interval multiplication `this * other`.
  RealInterval operator *(RealInterval other) {
    if (isEmpty || other.isEmpty) return empty;
    if (isZero || other.isZero) return RealInterval.point(0.0);

    final pairs = [
      _mulPair(lo, loInclusive, other.lo, other.loInclusive),
      _mulPair(lo, loInclusive, other.hi, other.hiInclusive),
      _mulPair(hi, hiInclusive, other.lo, other.loInclusive),
      _mulPair(hi, hiInclusive, other.hi, other.hiInclusive),
    ];

    var minVal = pairs[0].lo;
    var minInc = pairs[0].inc;
    var maxVal = pairs[0].hi;
    var maxInc = pairs[0].inc;
    for (var i = 1; i < 4; i++) {
      final p = pairs[i];
      if (p.lo < minVal) {
        minVal = p.lo;
        minInc = p.inc;
      } else if (p.lo == minVal) {
        minInc = minInc || p.inc;
      }
      if (p.hi > maxVal) {
        maxVal = p.hi;
        maxInc = p.inc;
      } else if (p.hi == maxVal) {
        maxInc = maxInc || p.inc;
      }
    }

    return RealInterval.fromBounds(
      minVal,
      maxVal,
      loInclusive: minInc,
      hiInclusive: maxInc,
    );
  }

  /// Sound interval division `this / other`.
  RealInterval operator /(RealInterval other) {
    if (isEmpty || other.isEmpty) return empty;
    if (other.isZero) return empty;
    if (!other.containsZero) {
      final invLo = other.hi.isInfinite ? 0.0 : _outLo(1.0 / other.hi);
      final invHi = other.lo.isInfinite ? 0.0 : _outHi(1.0 / other.lo);
      final inv = RealInterval.fromBounds(
        invLo,
        invHi,
        loInclusive: other.hi.isFinite && other.hiInclusive,
        hiInclusive: other.lo.isFinite && other.loInclusive,
      );
      return this * inv;
    }
    if (isZero) return RealInterval.point(0.0);
    if (other.lo == 0.0 && other.hi > 0.0) {
      final invLo = other.hi.isInfinite ? 0.0 : _outLo(1.0 / other.hi);
      final posInv = RealInterval.fromBounds(
        invLo,
        double.infinity,
        loInclusive: other.hi.isFinite && other.hiInclusive,
        hiInclusive: false,
      );
      return this * posInv;
    }
    if (other.hi == 0.0 && other.lo < 0.0) {
      final invHi = other.lo.isInfinite ? 0.0 : _outHi(1.0 / other.lo);
      final negInv = RealInterval.fromBounds(
        double.negativeInfinity,
        invHi,
        loInclusive: false,
        hiInclusive: other.lo.isFinite && other.loInclusive,
      );
      return this * negInv;
    }
    return all;
  }

  /// Absolute value enclosure `|this|`.
  RealInterval abs() {
    if (isEmpty) return empty;
    if (isNonNegative) return this;
    if (isNonPositive) return -this;
    final negLo = -lo;
    if (negLo > hi) {
      return RealInterval.fromBounds(0.0, negLo, hiInclusive: loInclusive);
    }
    if (hi > negLo) {
      return RealInterval.fromBounds(0.0, hi, hiInclusive: hiInclusive);
    }
    return RealInterval.fromBounds(
      0.0,
      hi,
      hiInclusive: loInclusive || hiInclusive,
    );
  }

  /// Square root enclosure `sqrt(this ∩ [0, +oo))`.
  RealInterval sqrt() {
    final domain = intersect(nonNegative);
    if (domain.isEmpty) return empty;
    return RealInterval.fromBounds(
      domain.lo == 0.0 ? 0.0 : _outLo(math.sqrt(domain.lo)),
      domain.hi.isInfinite ? double.infinity : _outHi(math.sqrt(domain.hi)),
      loInclusive: domain.loInclusive,
      hiInclusive: domain.hiInclusive,
    );
  }

  /// Integer power enclosure `this^n`.
  RealInterval powInt(int n) {
    if (isEmpty) return empty;
    if (n == 0) return RealInterval.point(1.0);
    if (n == 1) return this;
    if (n < 0) {
      if (isZero) return empty;
      final inv = RealInterval.point(1.0) / this;
      return n == -1 ? inv : inv.powInt(-n);
    }
    if (n.isEven) {
      final a = abs();
      final newLo = a.lo == 0.0
          ? 0.0
          : (a.lo == 1.0 ? 1.0 : _outLo(math.pow(a.lo, n).toDouble()));
      final newHi = a.hi.isInfinite
          ? double.infinity
          : (a.hi == 1.0 || a.hi == 0.0
                ? a.hi
                : _outHi(math.pow(a.hi, n).toDouble()));
      return RealInterval.fromBounds(
        newLo,
        newHi,
        loInclusive: a.loInclusive,
        hiInclusive: a.hiInclusive,
      );
    }
    final newLo = lo.isInfinite
        ? double.negativeInfinity
        : (lo == 0.0 || lo == 1.0 || lo == -1.0
              ? lo
              : _outLo(_oddIntPow(lo, n)));
    final newHi = hi.isInfinite
        ? double.infinity
        : (hi == 0.0 || hi == 1.0 || hi == -1.0
              ? hi
              : _outHi(_oddIntPow(hi, n)));
    return RealInterval.fromBounds(
      newLo,
      newHi,
      loInclusive: loInclusive,
      hiInclusive: hiInclusive,
    );
  }

  /// General power enclosure `this^exp` when both are non-empty.
  RealInterval pow(RealInterval exp) {
    if (isEmpty || exp.isEmpty) return empty;
    if (exp.isPoint && exp.lo == exp.lo.roundToDouble() && exp.lo.abs() <= 64) {
      return powInt(exp.lo.toInt());
    }
    if (!isNonNegative) return empty;
    if (isZero) {
      if (exp.isStrictlyPositive) return RealInterval.point(0.0);
      return empty;
    }
    if (lo == 0.0) {
      if (exp.isStrictlyPositive) {
        return RealInterval.fromBounds(
          0.0,
          hi.isInfinite && !exp.isZero ? double.infinity : all.hi,
          loInclusive: loInclusive,
          hiInclusive: false,
        ).intersect(nonNegative);
      }
      return empty;
    }
    return (ln() * exp).exp();
  }

  /// Natural exponential enclosure `exp(this)`.
  RealInterval exp() =>
      _monotoneIncreasing(math.exp, negInf: 0.0, posInf: double.infinity);

  /// Natural logarithm enclosure `ln(this ∩ (0, +oo))`.
  RealInterval ln() {
    final dom = intersect(positive);
    if (dom.isEmpty) return empty;
    return RealInterval.fromBounds(
      dom.lo == 0.0
          ? double.negativeInfinity
          : (dom.lo == 1.0 ? 0.0 : _outLo(math.log(dom.lo))),
      dom.hi.isInfinite
          ? double.infinity
          : (dom.hi == 1.0 ? 0.0 : _outHi(math.log(dom.hi))),
      loInclusive: dom.lo > 0.0 && dom.loInclusive,
      hiInclusive: dom.hi.isFinite && dom.hiInclusive,
    );
  }

  /// Sine enclosure `sin(this)`.
  RealInterval sin() {
    if (isEmpty) return empty;
    if (!isFinite) return unitClosed;
    final width = hi - lo;
    if (width >= 2.0 * math.pi) return unitClosed;
    if (lo == hi) {
      final v = math.sin(lo);
      return RealInterval.closed(_outLo(v), _outHi(v)).intersect(unitClosed);
    }
    final sLo = math.sin(lo);
    final sHi = math.sin(hi);
    var minV = math.min(sLo, sHi);
    var maxV = math.max(sLo, sHi);
    const twoPi = 2.0 * math.pi;
    final kMax = ((hi - math.pi / 2.0) / twoPi).floor();
    final critMax = math.pi / 2.0 + kMax * twoPi;
    final hasMax = critMax >= lo && critMax <= hi;
    final kMin = ((hi + math.pi / 2.0) / twoPi).floor();
    final critMin = -math.pi / 2.0 + kMin * twoPi;
    final hasMin = critMin >= lo && critMin <= hi;
    if (hasMax) maxV = 1.0;
    if (hasMin) minV = -1.0;
    var resLo = hasMin ? -1.0 : math.max(-1.0, _outLo(minV));
    var resHi = hasMax ? 1.0 : math.min(1.0, _outHi(maxV));
    if (lo >= 0.0 && hi <= math.pi && resLo < 0.0) {
      resLo = 0.0;
    }
    if (lo >= -math.pi && hi <= 0.0 && resHi > 0.0) {
      resHi = 0.0;
    }
    return RealInterval.closed(resLo, resHi);
  }

  /// Cosine enclosure `cos(this)`.
  RealInterval cos() {
    if (isEmpty) return empty;
    if (!isFinite) return unitClosed;
    return (this + RealInterval.point(math.pi / 2.0)).sin();
  }

  /// Tangent enclosure `tan(this)`.
  RealInterval tan() {
    if (isEmpty) return empty;
    if (!isFinite) return all;
    if (hi - lo >= math.pi) return all;
    final shiftedLo = (lo + math.pi / 2.0) / math.pi;
    final shiftedHi = (hi + math.pi / 2.0) / math.pi;
    if (shiftedLo.floor() != shiftedHi.floor()) return all;
    final tLo = math.tan(lo);
    final tHi = math.tan(hi);
    if (!tLo.isFinite || !tHi.isFinite) return all;
    return RealInterval.fromBounds(
      _outLo(tLo),
      _outHi(tHi),
      loInclusive: loInclusive,
      hiInclusive: hiInclusive,
    );
  }

  /// Arcsine enclosure `asin(this ∩ [-1, 1])`.
  RealInterval asin() {
    final dom = intersect(unitClosed);
    if (dom.isEmpty) return empty;
    return RealInterval.fromBounds(
      math.max(-math.pi / 2.0, _outLo(math.asin(dom.lo))),
      math.min(math.pi / 2.0, _outHi(math.asin(dom.hi))),
      loInclusive: dom.loInclusive,
      hiInclusive: dom.hiInclusive,
    );
  }

  /// Arccosine enclosure `acos(this ∩ [-1, 1])`.
  RealInterval acos() {
    final dom = intersect(unitClosed);
    if (dom.isEmpty) return empty;
    return RealInterval.fromBounds(
      math.max(0.0, _outLo(math.acos(dom.hi))),
      math.min(math.pi, _outHi(math.acos(dom.lo))),
      loInclusive: dom.hiInclusive,
      hiInclusive: dom.loInclusive,
    );
  }

  /// Arctangent enclosure `atan(this)`.
  RealInterval atan() => _monotoneIncreasing(
    math.atan,
    negInf: -math.pi / 2.0,
    posInf: math.pi / 2.0,
  );

  /// Hyperbolic sine enclosure `sinh(this)`.
  RealInterval sinh() => _monotoneIncreasing(
    _sinh,
    negInf: double.negativeInfinity,
    posInf: double.infinity,
  );

  /// Hyperbolic cosine enclosure `cosh(this)`.
  RealInterval cosh() {
    if (isEmpty) return empty;
    final a = abs();
    return RealInterval.fromBounds(
      a.lo == 0.0 ? 1.0 : _outLo(_cosh(a.lo)),
      a.hi.isInfinite ? double.infinity : _outHi(_cosh(a.hi)),
      loInclusive: a.loInclusive,
      hiInclusive: a.hi.isFinite && a.hiInclusive,
    );
  }

  /// Hyperbolic tangent enclosure `tanh(this)`.
  RealInterval tanh() => _monotoneIncreasing(
    _tanh,
    negInf: -1.0,
    posInf: 1.0,
    clampLo: -1.0,
    clampHi: 1.0,
  );

  /// Inverse hyperbolic sine enclosure `asinh(this)`.
  RealInterval asinh() => _monotoneIncreasing(
    _asinh,
    negInf: double.negativeInfinity,
    posInf: double.infinity,
  );

  /// Inverse hyperbolic cosine enclosure `acosh(this ∩ [1, +oo))`.
  RealInterval acosh() {
    final dom = intersect(
      const RealInterval._(1.0, double.infinity, hiInclusive: false),
    );
    if (dom.isEmpty) return empty;
    return RealInterval.fromBounds(
      dom.lo == 1.0 ? 0.0 : _outLo(_acosh(dom.lo)),
      dom.hi.isInfinite ? double.infinity : _outHi(_acosh(dom.hi)),
      loInclusive: dom.loInclusive,
      hiInclusive: dom.hi.isFinite && dom.hiInclusive,
    );
  }

  /// Inverse hyperbolic tangent enclosure `atanh(this ∩ (-1, 1))`.
  RealInterval atanh() {
    final dom = intersect(RealInterval.open(-1.0, 1.0));
    if (dom.isEmpty) return empty;
    return RealInterval.fromBounds(
      dom.lo == -1.0 ? double.negativeInfinity : _outLo(_atanh(dom.lo)),
      dom.hi == 1.0 ? double.infinity : _outHi(_atanh(dom.hi)),
      loInclusive: dom.lo > -1.0 && dom.loInclusive,
      hiInclusive: dom.hi < 1.0 && dom.hiInclusive,
    );
  }

  /// Floor enclosure `floor(this)`.
  RealInterval floor() {
    if (isEmpty) return empty;
    final newLo = lo.isInfinite ? double.negativeInfinity : lo.floorToDouble();
    final newHi = hi.isInfinite
        ? double.infinity
        : (hiInclusive ? hi.floorToDouble() : nextDown(hi).floorToDouble());
    return RealInterval.fromBounds(newLo, newHi);
  }

  /// Ceiling enclosure `ceil(this)`.
  RealInterval ceil() {
    if (isEmpty) return empty;
    final newLo = lo.isInfinite
        ? double.negativeInfinity
        : (loInclusive ? lo.ceilToDouble() : nextUp(lo).ceilToDouble());
    final newHi = hi.isInfinite ? double.infinity : hi.ceilToDouble();
    return RealInterval.fromBounds(newLo, newHi);
  }

  /// Round enclosure `round(this)`.
  RealInterval round() {
    if (isEmpty) return empty;
    final newLo = lo.isInfinite ? double.negativeInfinity : lo.roundToDouble();
    final newHi = hi.isInfinite ? double.infinity : hi.roundToDouble();
    return RealInterval.fromBounds(newLo, newHi);
  }

  /// Sign enclosure `sign(this)`.
  RealInterval sign() {
    if (isEmpty) return empty;
    if (isZero) return RealInterval.point(0.0);
    if (isStrictlyPositive) return RealInterval.point(1.0);
    if (isStrictlyNegative) return RealInterval.point(-1.0);
    final sLo = lo < 0.0 ? -1.0 : 0.0;
    final sHi = hi > 0.0 ? 1.0 : 0.0;
    return RealInterval.closed(sLo, sHi);
  }

  /// Error function enclosure `erf(this)`.
  RealInterval erf() => _monotoneIncreasing(
    special_erf.erf,
    negInf: -1.0,
    posInf: 1.0,
    clampLo: -1.0,
    clampHi: 1.0,
  );

  /// Complementary error function enclosure `erfc(this)`.
  RealInterval erfc() => _monotoneDecreasing(
    special_erf.erfc,
    negInf: 2.0,
    posInf: 0.0,
    clampLo: 0.0,
    clampHi: 2.0,
  );

  RealInterval _monotoneIncreasing(
    double Function(double) fn, {
    required double negInf,
    required double posInf,
    double? clampLo,
    double? clampHi,
  }) {
    if (isEmpty) return empty;
    var newLo = lo.isInfinite ? negInf : _outLo(fn(lo));
    var newHi = hi.isInfinite ? posInf : _outHi(fn(hi));
    if (clampLo != null && newLo < clampLo) newLo = clampLo;
    if (clampHi != null && newHi > clampHi) newHi = clampHi;
    return RealInterval.fromBounds(
      newLo,
      newHi,
      loInclusive: lo.isFinite && loInclusive,
      hiInclusive: hi.isFinite && hiInclusive,
    );
  }

  RealInterval _monotoneDecreasing(
    double Function(double) fn, {
    required double negInf,
    required double posInf,
    double? clampLo,
    double? clampHi,
  }) {
    if (isEmpty) return empty;
    var newLo = hi.isInfinite ? posInf : _outLo(fn(hi));
    var newHi = lo.isInfinite ? negInf : _outHi(fn(lo));
    if (clampLo != null && newLo < clampLo) newLo = clampLo;
    if (clampHi != null && newHi > clampHi) newHi = clampHi;
    return RealInterval.fromBounds(
      newLo,
      newHi,
      loInclusive: hi.isFinite && hiInclusive,
      hiInclusive: lo.isFinite && loInclusive,
    );
  }

  /// Returns the base real enclosure associated with [domain].
  static RealInterval forDomain(VariableDomain domain) => switch (domain) {
    VariableDomain.positive => positive,
    VariableDomain.real || VariableDomain.integer => all,
    VariableDomain.unknown || VariableDomain.complex => empty,
  };

  /// Returns the smallest IEEE-754 double strictly greater than [x].
  static double nextUp(double x) {
    if (x.isNaN || x == double.infinity) return x;
    if (x == 0.0) return double.minPositive;
    _scratchBytes.setFloat64(0, x, Endian.big);
    var hiWord = _scratchBytes.getUint32(0, Endian.big);
    var loWord = _scratchBytes.getUint32(4, Endian.big);
    if (x > 0.0) {
      loWord = (loWord + 1) & 0xFFFFFFFF;
      if (loWord == 0) {
        hiWord = (hiWord + 1) & 0xFFFFFFFF;
      }
    } else {
      if (loWord == 0) {
        loWord = 0xFFFFFFFF;
        hiWord = (hiWord - 1) & 0xFFFFFFFF;
      } else {
        loWord = (loWord - 1) & 0xFFFFFFFF;
      }
    }
    _scratchBytes.setUint32(0, hiWord, Endian.big);
    _scratchBytes.setUint32(4, loWord, Endian.big);
    final res = _scratchBytes.getFloat64(0, Endian.big);
    return res == 0.0 ? 0.0 : res;
  }

  /// Returns the greatest IEEE-754 double strictly less than [x].
  static double nextDown(double x) => -nextUp(-x);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RealInterval) return false;
    if (isEmpty && other.isEmpty) return true;
    return lo == other.lo &&
        hi == other.hi &&
        loInclusive == other.loInclusive &&
        hiInclusive == other.hiInclusive;
  }

  @override
  int get hashCode =>
      isEmpty ? 0 : Object.hash(lo, hi, loInclusive, hiInclusive);

  @override
  String toString() {
    if (isEmpty) return '∅';
    final l = loInclusive ? '[' : '(';
    final r = hiInclusive ? ']' : ')';
    final loStr = lo == double.negativeInfinity ? '-oo' : '$lo';
    final hiStr = hi == double.infinity ? 'oo' : '$hi';
    return '$l$loStr, $hiStr$r';
  }

  static final ByteData _scratchBytes = ByteData(8);

  static double _outLo(double v) => (v.isNaN || v == double.negativeInfinity)
      ? v
      : nextDown(v == 0.0 ? 0.0 : v);

  static double _outHi(double v) =>
      (v.isNaN || v == double.infinity) ? v : nextUp(v == 0.0 ? 0.0 : v);

  static bool _isExactSafeInt(double x, double limit) =>
      x.isFinite && x == x.truncateToDouble() && x.abs() <= limit;

  static double _addLo(double a, double b) {
    if (a == 0.0) return b;
    if (b == 0.0) return a;
    if (a == -b) return 0.0;
    if (a.isInfinite || b.isInfinite) return a + b;
    if (_isExactSafeInt(a, 4503599627370496.0) &&
        _isExactSafeInt(b, 4503599627370496.0)) {
      return a + b;
    }
    return _outLo(a + b);
  }

  static double _addHi(double a, double b) {
    if (a == 0.0) return b;
    if (b == 0.0) return a;
    if (a == -b) return 0.0;
    if (a.isInfinite || b.isInfinite) return a + b;
    if (_isExactSafeInt(a, 4503599627370496.0) &&
        _isExactSafeInt(b, 4503599627370496.0)) {
      return a + b;
    }
    return _outHi(a + b);
  }

  static ({double lo, double hi, bool inc}) _mulPair(
    double a,
    bool aInc,
    double b,
    bool bInc,
  ) {
    if (a == 0.0 || b == 0.0) {
      return (lo: 0.0, hi: 0.0, inc: (a == 0.0 && aInc) || (b == 0.0 && bInc));
    }
    final inc = aInc && bInc;
    if (a == 1.0) return (lo: b, hi: b, inc: inc);
    if (b == 1.0) return (lo: a, hi: a, inc: inc);
    if (a == -1.0) return (lo: -b, hi: -b, inc: inc);
    if (b == -1.0) return (lo: -a, hi: -a, inc: inc);
    final p = a * b;
    if (a.isInfinite || b.isInfinite) {
      return (lo: p, hi: p, inc: inc);
    }
    if (_isExactSafeInt(a, 67108864.0) && _isExactSafeInt(b, 67108864.0)) {
      return (lo: p, hi: p, inc: inc);
    }
    final sameSign = (a > 0.0 && b > 0.0) || (a < 0.0 && b < 0.0);
    var pLo = _outLo(p);
    var pHi = _outHi(p);
    if (sameSign && pLo < 0.0) pLo = 0.0;
    if (!sameSign && pHi > 0.0) pHi = 0.0;
    return (lo: pLo, hi: pHi, inc: inc);
  }

  static double _oddIntPow(double x, int n) =>
      x < 0 ? -math.pow(-x, n).toDouble() : math.pow(x, n).toDouble();

  static double _sinh(double x) => 0.5 * (math.exp(x) - math.exp(-x));

  static double _cosh(double x) => 0.5 * (math.exp(x) + math.exp(-x));

  static double _tanh(double x) {
    if (x > 20.0) return 1.0;
    if (x < -20.0) return -1.0;
    final e2x = math.exp(2.0 * x);
    return (e2x - 1.0) / (e2x + 1.0);
  }

  static double _asinh(double x) => x < 0.0
      ? -math.log(-x + math.sqrt(x * x + 1.0))
      : math.log(x + math.sqrt(x * x + 1.0));

  static double _acosh(double x) => math.log(x + math.sqrt(x * x - 1.0));

  static double _atanh(double x) => 0.5 * math.log((1.0 + x) / (1.0 - x));
}
