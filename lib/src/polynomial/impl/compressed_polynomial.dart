import 'dart:collection' show SplayTreeMap;

import 'package:collection/collection.dart' show ListEquality, binarySearch;
import 'package:more/number.dart' show Complex;

import '../../type/data_type.dart';
import '../../type/models/field.dart';
import '../polynomial.dart';
import 'dense_polynomial.dart';
import 'formatting.dart';

/// Sparse compressed univariate polynomial storing non-zero
/// `(exponent, coefficient)` pairs.
///
/// Conceptually, a sparse polynomial represents an algebraic polynomial where
/// only a small subset of possible terms have non-zero coefficients (for
/// example, `x^10000 - 1`). Formally, it stores strictly increasing exponents
/// and their corresponding non-zero coefficients in unmodifiable parallel
/// arrays, avoiding the memory overhead of allocating contiguous dense arrays
/// of size `O(degree)`.
///
/// ```dart
/// final p = CompressedPolynomial<double>.fromMap(
///   {0: -1.0, 10000: 1.0},
/// ); // x^10000 - 1
/// final deg = p.degree; // 10000
/// final val = p.evaluate(1.0); // 0.0
/// ```
class CompressedPolynomial<T> extends Polynomial<T> {
  /// Constructs a [CompressedPolynomial] from parallel [exponents] and
  /// [coefficients].
  ///
  /// Combines duplicate exponents, strips zero coefficients, normalizes negative
  /// zeros, and validates non-negative exponents.
  factory(
    Iterable<int> exponents,
    Iterable<T> coefficients, {
    DataType<T>? type,
  }) {
    final expList = exponents.toList(growable: false);
    final coeffList = coefficients.toList(growable: false);
    if (expList.length != coeffList.length) {
      throw ArgumentError(
        'Exponents and coefficients must have the same length: '
        '${expList.length} != ${coeffList.length}.',
      );
    }
    final effectiveType = type ?? DataType.fromIterable(coeffList);
    final field = effectiveType.field;
    final zero = field.additiveIdentity;

    final terms = <int, T>{};
    for (var i = 0; i < expList.length; i++) {
      final exp = expList[i];
      RangeError.checkNotNegative(exp, 'exponent');
      final coeff = normalizeCoefficient(coeffList[i], zero);
      if (coeff != zero) {
        final existing = terms[exp];
        if (existing == null) {
          terms[exp] = coeff;
        } else {
          final sum = normalizeCoefficient(field.add(existing, coeff), zero);
          if (sum == zero) {
            terms.remove(exp);
          } else {
            terms[exp] = sum;
          }
        }
      }
    }

    final sortedEntries = terms.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedExps = [for (final e in sortedEntries) e.key];
    final sortedCoeffs = [for (final e in sortedEntries) e.value];

    return CompressedPolynomial._(
      List.unmodifiable(sortedExps),
      List.unmodifiable(sortedCoeffs),
      type: effectiveType,
    );
  }

  /// Constructs a [CompressedPolynomial] from a map of exponent-to-coefficient
  /// [entries].
  factory fromMap(Map<int, T> entries, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromIterable(entries.values);
    final zero = effectiveType.field.additiveIdentity;

    final sortedExps = <int>[];
    final sortedCoeffs = <T>[];
    final keys = entries.keys.toList()..sort();
    for (final exp in keys) {
      RangeError.checkNotNegative(exp, 'exponent');
      final val = entries[exp];
      if (val != null && val != zero) {
        sortedExps.add(exp);
        sortedCoeffs.add(normalizeCoefficient(val, zero));
      }
    }

    return CompressedPolynomial._(
      List.unmodifiable(sortedExps),
      List.unmodifiable(sortedCoeffs),
      type: effectiveType,
    );
  }

  /// Constructs an empty zero polynomial of degree `-1`.
  factory zero({DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    return CompressedPolynomial._(const [], const [], type: effectiveType);
  }

  /// Internal constructor with pre-validated, unmodifiable parallel arrays.
  const new _(this._exponents, this._coefficients, {required this.type});

  @override
  final DataType<T> type;

  final List<int> _exponents;
  final List<T> _coefficients;

  @override
  int get degree => _exponents.isEmpty ? -1 : _exponents.last;

  @override
  T get leadingCoefficient =>
      _coefficients.isEmpty ? type.field.additiveIdentity : _coefficients.last;

  @override
  int get termCount => _exponents.length;

  @override
  Iterable<({int exponent, T coefficient})> get nonZeroTerms sync* {
    for (var i = 0; i < _exponents.length; i++) {
      yield (exponent: _exponents[i], coefficient: _coefficients[i]);
    }
  }

  /// Converts the non-zero terms to a map from exponent to coefficient.
  Map<int, T> toMap() => Map.fromIterables(_exponents, _coefficients);

  @override
  T operator [](int exponent) {
    if (exponent < 0 || _exponents.isEmpty || exponent > _exponents.last) {
      return type.field.additiveIdentity;
    }
    final idx = binarySearch(_exponents, exponent);
    return idx >= 0 ? _coefficients[idx] : type.field.additiveIdentity;
  }

  @override
  List<T> get coefficients {
    final deg = degree;
    if (deg < 0) return const [];
    if (deg > 100000) {
      throw StateError(
        'Polynomial degree ($deg) is too large to represent as a contiguous dense list. '
        'Use [nonZeroTerms], [toMap], or operator `[]` for sparse inspection.',
      );
    }
    final list = List<T>.filled(deg + 1, type.field.additiveIdentity);
    for (var i = 0; i < _exponents.length; i++) {
      list[_exponents[i]] = _coefficients[i];
    }
    return List.unmodifiable(list);
  }

  @override
  T evaluate(T x) {
    if (_exponents.isEmpty) return type.field.additiveIdentity;
    final field = type.field;
    var prevExp = 0;
    var power = field.multiplicativeIdentity;
    var sum = field.additiveIdentity;
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final delta = exp - prevExp;
      if (delta > 0) {
        power = field.mul(power, _fieldPower(field, x, delta));
        prevExp = exp;
      }
      sum = field.add(sum, field.mul(_coefficients[i], power));
    }
    return sum;
  }

  @override
  double evaluateDouble(num x) {
    if (_exponents.isEmpty) return 0.0;
    final xd = x.toDouble();
    var prevExp = 0;
    var power = 1.0;
    var sum = 0.0;
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final delta = exp - prevExp;
      if (delta > 0) {
        power *= _doublePower(xd, delta);
        prevExp = exp;
      }
      sum += coeffToDouble(_coefficients[i]) * power;
    }
    return sum;
  }

  @override
  Complex evaluateComplex(Complex x) {
    if (_exponents.isEmpty) return Complex.zero;
    var prevExp = 0;
    var power = Complex.one;
    var sum = Complex.zero;
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final delta = exp - prevExp;
      if (delta > 0) {
        power = power * _complexPower(x, delta);
        prevExp = exp;
      }
      sum = sum + coeffToComplex(_coefficients[i]) * power;
    }
    return sum;
  }

  @override
  Polynomial<T> operator +(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    final comp = other is CompressedPolynomial<T>
        ? other
        : other.toCompressed();
    final field = type.field;
    final zero = field.additiveIdentity;
    final resExps = <int>[];
    final resCoeffs = <T>[];
    var i = 0;
    var j = 0;
    while (i < _exponents.length && j < comp._exponents.length) {
      final e1 = _exponents[i];
      final e2 = comp._exponents[j];
      if (e1 == e2) {
        final sum = normalizeCoefficient(
          field.add(_coefficients[i], comp._coefficients[j]),
          zero,
        );
        if (sum != zero) {
          resExps.add(e1);
          resCoeffs.add(sum);
        }
        i++;
        j++;
      } else if (e1 < e2) {
        resExps.add(e1);
        resCoeffs.add(_coefficients[i]);
        i++;
      } else {
        resExps.add(e2);
        resCoeffs.add(comp._coefficients[j]);
        j++;
      }
    }
    while (i < _exponents.length) {
      resExps.add(_exponents[i]);
      resCoeffs.add(_coefficients[i]);
      i++;
    }
    while (j < comp._exponents.length) {
      resExps.add(comp._exponents[j]);
      resCoeffs.add(comp._coefficients[j]);
      j++;
    }
    return CompressedPolynomial<T>._(
      List.unmodifiable(resExps),
      List.unmodifiable(resCoeffs),
      type: type,
    );
  }

  @override
  Polynomial<T> operator -(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    final comp = other is CompressedPolynomial<T>
        ? other
        : other.toCompressed();
    final field = type.field;
    final zero = field.additiveIdentity;
    final resExps = <int>[];
    final resCoeffs = <T>[];
    var i = 0;
    var j = 0;
    while (i < _exponents.length && j < comp._exponents.length) {
      final e1 = _exponents[i];
      final e2 = comp._exponents[j];
      if (e1 == e2) {
        final diff = normalizeCoefficient(
          field.sub(_coefficients[i], comp._coefficients[j]),
          zero,
        );
        if (diff != zero) {
          resExps.add(e1);
          resCoeffs.add(diff);
        }
        i++;
        j++;
      } else if (e1 < e2) {
        resExps.add(e1);
        resCoeffs.add(_coefficients[i]);
        i++;
      } else {
        resExps.add(e2);
        resCoeffs.add(
          normalizeCoefficient(field.neg(comp._coefficients[j]), zero),
        );
        j++;
      }
    }
    while (i < _exponents.length) {
      resExps.add(_exponents[i]);
      resCoeffs.add(_coefficients[i]);
      i++;
    }
    while (j < comp._exponents.length) {
      resExps.add(comp._exponents[j]);
      resCoeffs.add(
        normalizeCoefficient(field.neg(comp._coefficients[j]), zero),
      );
      j++;
    }
    return CompressedPolynomial<T>._(
      List.unmodifiable(resExps),
      List.unmodifiable(resCoeffs),
      type: type,
    );
  }

  @override
  Polynomial<T> operator -() {
    if (_exponents.isEmpty) return this;
    final field = type.field;
    final zero = field.additiveIdentity;
    final negCoeffs = _coefficients
        .map((c) => normalizeCoefficient(field.neg(c), zero))
        .toList(growable: false);
    return CompressedPolynomial<T>._(
      _exponents,
      List.unmodifiable(negCoeffs),
      type: type,
    );
  }

  @override
  Polynomial<T> scale(T scalar) {
    final field = type.field;
    final zero = field.additiveIdentity;
    if (scalar == zero || _exponents.isEmpty) {
      return CompressedPolynomial<T>.zero(type: type);
    }
    if (scalar == field.multiplicativeIdentity) {
      return this;
    }
    final resExps = <int>[];
    final resCoeffs = <T>[];
    for (var i = 0; i < _exponents.length; i++) {
      final prod = normalizeCoefficient(
        field.mul(_coefficients[i], scalar),
        zero,
      );
      if (prod != zero) {
        resExps.add(_exponents[i]);
        resCoeffs.add(prod);
      }
    }
    return CompressedPolynomial<T>._(
      List.unmodifiable(resExps),
      List.unmodifiable(resCoeffs),
      type: type,
    );
  }

  @override
  Polynomial<T> operator *(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    final comp = other is CompressedPolynomial<T>
        ? other
        : other.toCompressed();
    if (_exponents.isEmpty || comp._exponents.isEmpty) {
      return CompressedPolynomial<T>.zero(type: type);
    }
    final field = type.field;
    final zero = field.additiveIdentity;
    final terms = <int, T>{};
    for (var i = 0; i < _exponents.length; i++) {
      final e1 = _exponents[i];
      final c1 = _coefficients[i];
      for (var j = 0; j < comp._exponents.length; j++) {
        final e2 = comp._exponents[j];
        final c2 = comp._coefficients[j];
        final exp = e1 + e2;
        final prod = normalizeCoefficient(field.mul(c1, c2), zero);
        if (prod != zero) {
          final existing = terms[exp];
          if (existing == null) {
            terms[exp] = prod;
          } else {
            final sum = normalizeCoefficient(field.add(existing, prod), zero);
            if (sum == zero) {
              terms.remove(exp);
            } else {
              terms[exp] = sum;
            }
          }
        }
      }
    }
    final sortedEntries = terms.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedExps = [for (final e in sortedEntries) e.key];
    final sortedCoeffs = [for (final e in sortedEntries) e.value];
    return CompressedPolynomial<T>._(
      List.unmodifiable(sortedExps),
      List.unmodifiable(sortedCoeffs),
      type: type,
    );
  }

  @override
  Polynomial<T> compose(Polynomial<T> other) {
    checkSamePolynomialType(type, other.type);
    if (_exponents.isEmpty) return this;
    final compOther = other is CompressedPolynomial<T>
        ? other
        : other.toCompressed();
    var result = CompressedPolynomial<T>.zero(type: type);
    var currentPower = CompressedPolynomial<T>._(
      const [0],
      [type.field.multiplicativeIdentity],
      type: type,
    );
    var currentExp = 0;
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final delta = exp - currentExp;
      if (delta > 0) {
        if (compOther._exponents.isEmpty) {
          break;
        }
        currentPower =
            (currentPower * compOther.pow(delta)) as CompressedPolynomial<T>;
        currentExp = exp;
      }
      result =
          (result + currentPower.scale(_coefficients[i]))
              as CompressedPolynomial<T>;
    }
    return result;
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
    final compDivisor = divisor is CompressedPolynomial<T>
        ? divisor
        : divisor.toCompressed();
    final degA = degree;
    if (degA < degB) {
      return (
        quotient: CompressedPolynomial<T>.zero(type: type),
        remainder: this,
      );
    }

    final field = type.field;
    final zero = field.additiveIdentity;
    final leadB = compDivisor.leadingCoefficient;
    final divLen = compDivisor._exponents.length;
    final qTerms = <int, T>{};
    final remMap = SplayTreeMap<int, T>();
    final isFloat = isFloatPolynomialType(type);
    final absScale = isFloat ? <int, double>{} : null;

    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final coeff = _coefficients[i];
      remMap[exp] = coeff;
      if (absScale != null) {
        absScale[exp] = (coeff as num).toDouble().abs();
      }
    }

    while (remMap.isNotEmpty) {
      final degR = remMap.lastKey()!;
      if (degR < degB) break;
      final leadR = remMap[degR] as T;
      final factor = field.div(leadR, leadB);
      if (factor == zero) break;

      final qExp = degR - degB;
      final existingQ = qTerms[qExp];
      qTerms[qExp] = existingQ == null ? factor : field.add(existingQ, factor);

      if (isFloat) {
        remMap.remove(degR);
        absScale!.remove(degR);
        final factorAbs = (factor as num).toDouble().abs();
        for (var j = 0; j < divLen - 1; j++) {
          final targetExp = qExp + compDivisor._exponents[j];
          final dc = compDivisor._coefficients[j];
          final subTerm = field.mul(factor, dc);
          final prev = remMap[targetExp] ?? zero;
          final updated = normalizeCoefficient(field.sub(prev, subTerm), zero);
          final contrib = factorAbs * (dc as num).toDouble().abs();
          final scale = absScale[targetExp] ?? 0.0;
          final newScale = contrib > scale ? contrib : scale;
          if (updated == zero ||
              (newScale.isFinite &&
                  (updated as num).toDouble().abs() <= 1e-12 * newScale)) {
            remMap.remove(targetExp);
            absScale.remove(targetExp);
          } else {
            remMap[targetExp] = updated;
            absScale[targetExp] = newScale;
          }
        }
      } else {
        for (var j = 0; j < divLen; j++) {
          final targetExp = qExp + compDivisor._exponents[j];
          final subTerm = field.mul(factor, compDivisor._coefficients[j]);
          final prev = remMap[targetExp] ?? zero;
          final updated = field.sub(prev, subTerm);
          if (updated == zero) {
            remMap.remove(targetExp);
          } else {
            remMap[targetExp] = updated;
          }
        }
        if (remMap.containsKey(degR)) {
          break;
        }
      }
    }

    final remainder = remMap.isEmpty
        ? CompressedPolynomial<T>.zero(type: type)
        : CompressedPolynomial<T>._(
            List<int>.unmodifiable(remMap.keys),
            List<T>.unmodifiable(remMap.values),
            type: type,
          );
    return (
      quotient: CompressedPolynomial<T>.fromMap(qTerms, type: type),
      remainder: remainder,
    );
  }

  @override
  Polynomial<T> derivative({int order = 1}) {
    RangeError.checkNotNegative(order, 'order');
    if (order == 0) return this;
    if (order > degree) return CompressedPolynomial<T>.zero(type: type);
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
    final zero = field.additiveIdentity;
    final c0 = normalizeCoefficient(constant ?? zero, zero);
    final resExps = <int>[];
    final resCoeffs = <T>[];
    if (c0 != zero) {
      resExps.add(0);
      resCoeffs.add(c0);
    }
    for (var i = 0; i < _exponents.length; i++) {
      final newExp = _exponents[i] + 1;
      final denom = field.scale(field.multiplicativeIdentity, newExp);
      final coeff = normalizeCoefficient(
        field.div(_coefficients[i], denom),
        zero,
      );
      if (coeff != zero) {
        resExps.add(newExp);
        resCoeffs.add(coeff);
      }
    }
    return CompressedPolynomial<T>._(
      List.unmodifiable(resExps),
      List.unmodifiable(resCoeffs),
      type: type,
    );
  }

  @override
  CompressedPolynomial<T> toCompressed() => this;

  @override
  DensePolynomial<T> toDense() =>
      DensePolynomial<T>.fromCoefficients(coefficients, type: type);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Polynomial<T> || type != other.type) return false;
    final deg = degree;
    if (deg != other.degree) return false;
    if (deg < 0) return true;
    if (other is CompressedPolynomial<T>) {
      return const ListEquality<int>().equals(_exponents, other._exponents) &&
          ListEquality<T>().equals(_coefficients, other._coefficients);
    }
    if (_exponents.length != other.termCount) return false;
    for (var i = 0; i < _exponents.length; i++) {
      if (_coefficients[i] != other[_exponents[i]]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final deg = degree;
    var hash = Object.hash(deg, type);
    if (deg < 0) return hash;
    for (var i = 0; i < _exponents.length; i++) {
      hash = Object.hash(hash, _exponents[i], _coefficients[i]);
    }
    return hash;
  }

  @override
  String toString() {
    final deg = degree;
    if (deg < 0) return '0';
    final terms = <({int exponent, T coefficient})>[];
    for (var i = _exponents.length - 1; i >= 0; i--) {
      terms.add((exponent: _exponents[i], coefficient: _coefficients[i]));
    }
    return formatPolynomialTerms(type, terms);
  }

  CompressedPolynomial<T> _derivativeOnce() {
    if (_exponents.isEmpty) return this;
    final field = type.field;
    final zero = field.additiveIdentity;
    final resExps = <int>[];
    final resCoeffs = <T>[];
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      if (exp > 0) {
        final coeff = normalizeCoefficient(
          field.scale(_coefficients[i], exp),
          zero,
        );
        if (coeff != zero) {
          resExps.add(exp - 1);
          resCoeffs.add(coeff);
        }
      }
    }
    return CompressedPolynomial<T>._(
      List.unmodifiable(resExps),
      List.unmodifiable(resCoeffs),
      type: type,
    );
  }
}

T _fieldPower<T>(Field<T> field, T base, int exponent) {
  if (exponent == 0) return field.multiplicativeIdentity;
  if (exponent == 1) return base;
  var res = field.multiplicativeIdentity;
  var b = base;
  var e = exponent;
  while (e > 0) {
    if (e.isOdd) {
      res = field.mul(res, b);
    }
    if (e > 1) {
      b = field.mul(b, b);
    }
    e ~/= 2;
  }
  return res;
}

double _doublePower(double base, int exponent) {
  if (exponent == 0) return 1.0;
  if (exponent == 1) return base;
  var res = 1.0;
  var b = base;
  var e = exponent;
  while (e > 0) {
    if (e.isOdd) {
      res *= b;
    }
    if (e > 1) {
      b *= b;
    }
    e ~/= 2;
  }
  return res;
}

Complex _complexPower(Complex base, int exponent) {
  if (exponent == 0) return Complex.one;
  if (exponent == 1) return base;
  var res = Complex.one;
  var b = base;
  var e = exponent;
  while (e > 0) {
    if (e.isOdd) {
      res = res * b;
    }
    if (e > 1) {
      b = b * b;
    }
    e ~/= 2;
  }
  return res;
}
