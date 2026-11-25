import 'dart:math' as math;
import 'dart:typed_data';

import 'package:collection/collection.dart' show ListEquality;
import 'package:more/number.dart' show Complex;

import '../../acceleration/fft/fft.dart';
import '../../type/data_type.dart';
import '../polynomial.dart';
import 'compressed_polynomial.dart';
import 'formatting.dart';

/// Dense univariate polynomial backed by a contiguous unmodifiable list of
/// coefficients.
///
/// Coefficients are stored in ascending power of `x`:
/// `P(x) = c_0 + c_1 x + c_2 x^2 + ... + c_n x^n`.
class DensePolynomial<T> extends Polynomial<T> {
  /// Constructs a dense polynomial from [coefficients] where index `i`
  /// corresponds to the power `x^i`.
  factory fromCoefficients(Iterable<T> coefficients, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromIterable(coefficients);
    final zero = effectiveType.field.additiveIdentity;
    final list = coefficients.toList(growable: false);
    var lastNonZero = list.length - 1;
    while (lastNonZero >= 0 && list[lastNonZero] == zero) {
      lastNonZero--;
    }
    if (lastNonZero < 0) {
      return DensePolynomial._(const [], effectiveType);
    }
    final trimmed = List<T>.generate(
      lastNonZero + 1,
      (i) => normalizeCoefficient(list[i], zero),
      growable: false,
    );
    return DensePolynomial._(List<T>.unmodifiable(trimmed), effectiveType);
  }

  const new _(this._coefficients, this.type);

  @override
  final DataType<T> type;

  final List<T> _coefficients;

  @override
  List<T> get coefficients => _coefficients;

  @override
  int get degree => _coefficients.length - 1;

  @override
  int get termCount {
    final zero = type.field.additiveIdentity;
    var count = 0;
    for (var i = 0; i < _coefficients.length; i++) {
      if (_coefficients[i] != zero) count++;
    }
    return count;
  }

  @override
  Iterable<({int exponent, T coefficient})> get nonZeroTerms sync* {
    final zero = type.field.additiveIdentity;
    for (var i = 0; i < _coefficients.length; i++) {
      final c = _coefficients[i];
      if (c != zero) {
        yield (exponent: i, coefficient: c);
      }
    }
  }

  @override
  T operator [](int exponent) {
    if (exponent < 0 || exponent >= _coefficients.length) {
      return type.field.additiveIdentity;
    }
    return _coefficients[exponent];
  }

  @override
  T get leadingCoefficient =>
      _coefficients.isEmpty ? type.field.additiveIdentity : _coefficients.last;

  @override
  T evaluate(T x) {
    final deg = degree;
    if (deg < 0) return type.field.additiveIdentity;
    final field = type.field;
    var acc = _coefficients[deg];
    for (var i = deg - 1; i >= 0; i--) {
      acc = field.add(field.mul(acc, x), _coefficients[i]);
    }
    return acc;
  }

  @override
  double evaluateDouble(num x) {
    final deg = degree;
    if (deg < 0) return 0.0;
    final xd = x.toDouble();
    var acc = coeffToDouble(_coefficients[deg]);
    for (var i = deg - 1; i >= 0; i--) {
      acc = acc * xd + coeffToDouble(_coefficients[i]);
    }
    return acc;
  }

  @override
  Complex evaluateComplex(Complex x) {
    final deg = degree;
    if (deg < 0) return Complex.zero;
    var acc = coeffToComplex(_coefficients[deg]);
    for (var i = deg - 1; i >= 0; i--) {
      acc = acc * x + coeffToComplex(_coefficients[i]);
    }
    return acc;
  }

  @override
  Polynomial<T> operator +(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    if (other is CompressedPolynomial<T>) {
      return other + this;
    }
    final field = type.field;
    final maxLen = math.max(_coefficients.length, other.coefficients.length);
    final newCoeffs = List<T>.generate(
      maxLen,
      (i) => field.add(this[i], other[i]),
      growable: false,
    );
    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  @override
  Polynomial<T> operator -(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    if (other is CompressedPolynomial<T>) {
      return (-other) + this;
    }
    final field = type.field;
    final maxLen = math.max(_coefficients.length, other.coefficients.length);
    final newCoeffs = List<T>.generate(
      maxLen,
      (i) => field.sub(this[i], other[i]),
      growable: false,
    );
    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  @override
  Polynomial<T> operator -() {
    if (_coefficients.isEmpty) return this;
    final field = type.field;
    final newCoeffs = List<T>.generate(
      _coefficients.length,
      (i) => field.neg(_coefficients[i]),
      growable: false,
    );
    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  @override
  Polynomial<T> scale(T scalar) {
    final field = type.field;
    if (scalar == field.additiveIdentity || _coefficients.isEmpty) {
      return Polynomial<T>.zero(type: type);
    }
    if (scalar == field.multiplicativeIdentity) {
      return this;
    }
    final newCoeffs = List<T>.generate(
      _coefficients.length,
      (i) => field.mul(_coefficients[i], scalar),
      growable: false,
    );
    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  @override
  Polynomial<T> operator *(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    if (other is CompressedPolynomial<T>) {
      return other * this;
    }
    final deg1 = degree;
    final deg2 = other.degree;
    if (deg1 < 0 || deg2 < 0) return Polynomial<T>.zero(type: type);

    final outDegree = deg1 + deg2;
    if (outDegree >= 64 &&
        math.min(deg1, deg2) >= 16 &&
        isFloatPolynomialType(type)) {
      final fftProduct = _multiplyFft(other, deg1, deg2, outDegree);
      if (fftProduct != null) return fftProduct;
    }

    final field = type.field;
    final zero = field.additiveIdentity;
    final resultCoeffs = List<T>.filled(outDegree + 1, zero, growable: false);

    for (var i = 0; i <= deg1; i++) {
      final ci = _coefficients[i];
      if (ci == zero) continue;
      for (var j = 0; j <= deg2; j++) {
        final cj = other[j];
        if (cj == zero) continue;
        resultCoeffs[i + j] = field.add(resultCoeffs[i + j], field.mul(ci, cj));
      }
    }

    return DensePolynomial<T>.fromCoefficients(resultCoeffs, type: type);
  }

  @override
  Polynomial<T> compose(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    final deg = degree;
    if (deg < 0) return this;
    if (deg == 0) return this;
    if (other.isZero) {
      return DensePolynomial<T>.fromCoefficients([
        _coefficients[0],
      ], type: type);
    }
    final zero = type.field.additiveIdentity;
    Polynomial<T> acc = DensePolynomial<T>.fromCoefficients([
      _coefficients[deg],
    ], type: type);
    for (var i = deg - 1; i >= 0; i--) {
      acc = acc * other;
      final ci = _coefficients[i];
      if (ci != zero) {
        acc = acc + DensePolynomial<T>.fromCoefficients([ci], type: type);
      }
    }
    return acc;
  }

  @override
  ({Polynomial<T> quotient, Polynomial<T> remainder}) divide(
    Polynomial<T> divisor,
  ) {
    checkSamePolynomialType(type, divisor.type);
    final degB = divisor.degree;
    if (degB < 0) {
      throw UnsupportedError('Division by zero polynomial.');
    }
    final degA = degree;
    if (degA < degB) {
      return (quotient: Polynomial<T>.zero(type: type), remainder: this);
    }

    final field = type.field;
    final zero = field.additiveIdentity;
    final leadB = divisor.leadingCoefficient;
    final qCoeffs = List<T>.filled(degA - degB + 1, zero, growable: false);
    final rCoeffs = List<T>.of(_coefficients, growable: false);
    final isFloat = isFloatPolynomialType(type);
    final Float64List? absScale;
    if (isFloat) {
      final scale = Float64List(degA + 1);
      for (var i = 0; i <= degA; i++) {
        scale[i] = (rCoeffs[i] as num).toDouble().abs();
      }
      absScale = scale;
    } else {
      absScale = null;
    }

    for (var i = degA; i >= degB; i--) {
      final curCoeff = rCoeffs[i];
      if (curCoeff != zero) {
        final factor = field.div(curCoeff, leadB);
        if (factor == zero) continue;
        final qIdx = i - degB;
        qCoeffs[qIdx] = factor;
        if (isFloat) {
          rCoeffs[i] = zero;
          final factorAbs = (factor as num).toDouble().abs();
          for (var j = 0; j < degB; j++) {
            final dj = divisor[j];
            if (dj == zero) continue;
            final term = field.mul(factor, dj);
            final target = qIdx + j;
            rCoeffs[target] = field.sub(rCoeffs[target], term);
            final contrib = factorAbs * (dj as num).toDouble().abs();
            if (contrib > absScale![target]) {
              absScale[target] = contrib;
            }
          }
        } else {
          for (var j = 0; j <= degB; j++) {
            final dj = divisor[j];
            if (dj == zero) continue;
            final term = field.mul(factor, dj);
            rCoeffs[qIdx + j] = field.sub(rCoeffs[qIdx + j], term);
          }
        }
      }
    }

    if (isFloat) {
      for (var j = 0; j < degB; j++) {
        final s = absScale![j];
        if (s.isFinite && (rCoeffs[j] as num).toDouble().abs() <= 1e-12 * s) {
          rCoeffs[j] = zero;
        }
      }
    }

    return (
      quotient: DensePolynomial<T>.fromCoefficients(qCoeffs, type: type),
      remainder: DensePolynomial<T>.fromCoefficients(rCoeffs, type: type),
    );
  }

  @override
  Polynomial<T> derivative({int order = 1}) {
    RangeError.checkNotNegative(order, 'order');
    if (order == 0) return this;
    if (order > degree) return Polynomial<T>.zero(type: type);
    var current = _derivativeOnce();
    for (var k = 1; k < order; k++) {
      if (current.isZero) return current;
      current = current._derivativeOnce();
    }
    return current;
  }

  @override
  Polynomial<T> integrate([T? constant]) {
    final field = type.field;
    final c0 = constant ?? field.additiveIdentity;
    final deg = degree;
    if (deg < 0) {
      return DensePolynomial<T>.fromCoefficients([c0], type: type);
    }

    final newCoeffs = List<T>.filled(
      deg + 2,
      field.additiveIdentity,
      growable: false,
    );
    newCoeffs[0] = c0;
    for (var i = 0; i <= deg; i++) {
      final denom = field.scale(field.multiplicativeIdentity, i + 1);
      newCoeffs[i + 1] = field.div(_coefficients[i], denom);
    }

    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  @override
  CompressedPolynomial<T> toCompressed() {
    final zero = type.field.additiveIdentity;
    final exps = <int>[];
    final coeffs = <T>[];
    for (var i = 0; i < _coefficients.length; i++) {
      final c = _coefficients[i];
      if (c != zero) {
        exps.add(i);
        coeffs.add(c);
      }
    }
    return CompressedPolynomial<T>(exps, coeffs, type: type);
  }

  @override
  DensePolynomial<T> toDense() => this;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Polynomial<T> || type != other.type) return false;
    final deg = degree;
    if (deg != other.degree) return false;
    if (deg < 0) return true;
    if (other is DensePolynomial<T>) {
      return ListEquality<T>().equals(_coefficients, other._coefficients);
    }
    if (termCount != other.termCount) return false;
    for (final term in nonZeroTerms) {
      if (term.coefficient != other[term.exponent]) return false;
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
      final c = _coefficients[i];
      if (c != zero) {
        hash = Object.hash(hash, i, c);
      }
    }
    return hash;
  }

  @override
  String toString() {
    final deg = degree;
    if (deg < 0) return '0';
    final zero = type.field.additiveIdentity;
    final terms = <({int exponent, T coefficient})>[];
    for (var i = deg; i >= 0; i--) {
      final coeff = _coefficients[i];
      if (coeff == zero && deg > 0) continue;
      terms.add((exponent: i, coefficient: coeff));
    }
    return formatPolynomialTerms(type, terms);
  }

  DensePolynomial<T> _derivativeOnce() {
    final deg = degree;
    final field = type.field;
    final newCoeffs = List<T>.generate(
      deg,
      (i) => field.scale(_coefficients[i + 1], i + 1),
      growable: false,
    );
    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  Polynomial<T>? _multiplyFft(
    Polynomial<T> other,
    int deg1,
    int deg2,
    int outDegree,
  ) {
    final n = Fft.nextPowerOf2(value: outDegree + 1);
    final aList = DataType.complex.newList(n);
    final bList = DataType.complex.newList(n);

    final aData = aList.data;
    for (var i = 0; i <= deg1; i++) {
      final v = (_coefficients[i] as num).toDouble();
      if (!v.isFinite) return null;
      aData[2 * i] = v;
    }
    final bData = bList.data;
    for (var i = 0; i <= deg2; i++) {
      final v = (other[i] as num).toDouble();
      if (!v.isFinite) return null;
      bData[2 * i] = v;
    }

    Fft.fft(buffer: aList);
    Fft.fft(buffer: bList);

    for (var i = 0; i < n; i++) {
      final idx = 2 * i;
      final ar = aData[idx];
      final ai = aData[idx + 1];
      final br = bData[idx];
      final bi = bData[idx + 1];
      aData[idx] = ar * br - ai * bi;
      aData[idx + 1] = ar * bi + ai * br;
    }
    Fft.fft(buffer: aList, inverse: true);

    var maxCoeff = 0.0;
    for (var i = 0; i <= outDegree; i++) {
      final v = aData[2 * i].abs();
      if (v > maxCoeff) maxCoeff = v;
    }
    final tol = maxCoeff.isFinite ? 1e-14 * maxCoeff : 0.0;
    final resultCoeffs = List<T>.generate(outDegree + 1, (i) {
      final val = aData[2 * i];
      final cleaned = val.abs() <= tol ? 0.0 : val;
      return cleaned as T;
    }, growable: false);

    return DensePolynomial<T>.fromCoefficients(resultCoeffs, type: type);
  }
}
