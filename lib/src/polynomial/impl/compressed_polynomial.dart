import '../../../type.dart';
import '../polynomial.dart';
import 'dense_polynomial.dart';
import 'formatting.dart';

/// Sparse compressed univariate polynomial storing non-zero
/// `(exponent, coefficient)` pairs.
///
/// Conceptually, a sparse polynomial represents an algebraic polynomial where
/// only a small subset of possible terms have non-zero coefficients (for
/// example, $x^{10000} - 1$). Formally, it stores strictly increasing exponents
/// and their corresponding non-zero coefficients in unmodifiable parallel
/// arrays, avoiding the memory overhead of allocating contiguous dense arrays
/// of size $\mathcal{O}(\deg(P))$.
///
/// ```dart
/// final p = CompressedPolynomial<double>.fromMap(
///   {0: -1.0, 10000: 1.0},
/// ); // x^10000 - 1
/// final deg = p.degree; // 10000
/// final val = p.evaluate(1.0); // 0.0
/// ```
class CompressedPolynomial<T> extends Polynomial<T> {
  /// Internal constructor with pre-validated, unmodifiable parallel arrays.
  const new _(this._exponents, this._coefficients, {required this.type});

  /// Constructs a [CompressedPolynomial] from parallel [exponents] and
  /// [coefficients].
  ///
  /// Combines like exponents, strips zero coefficients, and validates
  /// non-negative exponents.
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
      final coeff = coeffList[i];
      if (coeff != zero) {
        final existing = terms[exp];
        if (existing == null) {
          terms[exp] = coeff;
        } else {
          final sum = field.add(existing, coeff);
          if (sum == zero) {
            terms.remove(exp);
          } else {
            terms[exp] = sum;
          }
        }
      }
    }

    final sortedExps = terms.keys.toList()..sort();
    final sortedCoeffs = sortedExps
        .map((e) => terms[e]!)
        .toList(growable: false);

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
    final field = effectiveType.field;
    final zero = field.additiveIdentity;

    final sortedExps = <int>[];
    final sortedCoeffs = <T>[];
    final keys = entries.keys.toList()..sort();
    for (final exp in keys) {
      RangeError.checkNotNegative(exp, 'exponent');
      final val = entries[exp];
      if (val != null && val != zero) {
        sortedExps.add(exp);
        sortedCoeffs.add(val);
      }
    }

    return CompressedPolynomial._(
      List.unmodifiable(sortedExps),
      List.unmodifiable(sortedCoeffs),
      type: effectiveType,
    );
  }

  /// Constructs an empty zero polynomial of degree -1.
  factory zero({DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromType<T>();
    return CompressedPolynomial._(const [], const [], type: effectiveType);
  }

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

  /// Returns the non-zero terms as `(exponent, coefficient)` pairs.
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
    var low = 0;
    var high = _exponents.length - 1;
    while (low <= high) {
      final mid = (low + high) >>> 1;
      final midExp = _exponents[mid];
      if (midExp == exponent) {
        return _coefficients[mid];
      } else if (midExp < exponent) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return type.field.additiveIdentity;
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
    var sum = field.additiveIdentity;
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final coeff = _coefficients[i];
      final term = field.mul(coeff, _fieldPower(field, x, exp));
      sum = field.add(sum, term);
    }
    return sum;
  }

  @override
  double evaluateDouble(num x) {
    if (_exponents.isEmpty) return 0.0;
    final xd = x.toDouble();
    var sum = 0.0;
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final coeff = (_coefficients[i] as num).toDouble();
      final p = _doublePower(xd, exp);
      sum += coeff * p;
    }
    return sum;
  }

  @override
  Complex evaluateComplex(Complex x) {
    if (_exponents.isEmpty) return Complex.zero;
    var sum = Complex.zero;
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final coeff = Complex((_coefficients[i] as num).toDouble());
      sum = sum + coeff * x.pow(exp);
    }
    return sum;
  }

  @override
  Polynomial<T> operator +(Polynomial<T> other) {
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
        final sum = field.add(_coefficients[i], comp._coefficients[j]);
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
        final diff = field.sub(_coefficients[i], comp._coefficients[j]);
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
        resCoeffs.add(field.neg(comp._coefficients[j]));
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
      resCoeffs.add(field.neg(comp._coefficients[j]));
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
    final field = type.field;
    final negCoeffs = _coefficients.map(field.neg).toList(growable: false);
    return CompressedPolynomial<T>._(
      _exponents,
      List.unmodifiable(negCoeffs),
      type: type,
    );
  }

  @override
  Polynomial<T> scale(T scalar) {
    final field = type.field;
    if (scalar == field.additiveIdentity || _exponents.isEmpty) {
      return CompressedPolynomial<T>.zero(type: type);
    }
    if (scalar == field.multiplicativeIdentity) {
      return this;
    }
    final resExps = <int>[];
    final resCoeffs = <T>[];
    for (var i = 0; i < _exponents.length; i++) {
      final prod = field.mul(_coefficients[i], scalar);
      if (prod != field.additiveIdentity) {
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
        final prod = field.mul(c1, c2);
        if (prod != zero) {
          final existing = terms[exp];
          if (existing == null) {
            terms[exp] = prod;
          } else {
            final sum = field.add(existing, prod);
            if (sum == zero) {
              terms.remove(exp);
            } else {
              terms[exp] = sum;
            }
          }
        }
      }
    }
    final sortedExps = terms.keys.toList()..sort();
    final sortedCoeffs = sortedExps
        .map((e) => terms[e]!)
        .toList(growable: false);
    return CompressedPolynomial<T>._(
      List.unmodifiable(sortedExps),
      List.unmodifiable(sortedCoeffs),
      type: type,
    );
  }

  @override
  Polynomial<T> compose(Polynomial<T> other) {
    if (_exponents.isEmpty) return CompressedPolynomial<T>.zero(type: type);
    var result = Polynomial<T>.zero(type: type);
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final coeff = _coefficients[i];
      final power = _polyPower(other, exp);
      result = result + power.scale(coeff);
    }
    return result;
  }

  @override
  ({Polynomial<T> quotient, Polynomial<T> remainder}) divide(
    Polynomial<T> divisor,
  ) {
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
    final qTerms = <int, T>{};
    var rem = this;

    while (rem.degree >= degB && rem.degree >= 0) {
      final degR = rem.degree;
      final leadR = rem.leadingCoefficient;
      final factor = field.div(leadR, leadB);
      if (factor == zero) {
        break;
      }
      final qExp = degR - degB;
      final existing = qTerms[qExp];
      qTerms[qExp] = existing == null ? factor : field.add(existing, factor);
      final term = CompressedPolynomial<T>._([qExp], [factor], type: type);
      rem = (rem - (term * compDivisor)).toCompressed();
      if (rem.degree >= degR) {
        final newExps = <int>[];
        final newCoeffs = <T>[];
        for (var k = 0; k < rem._exponents.length; k++) {
          if (rem._exponents[k] < degR) {
            newExps.add(rem._exponents[k]);
            newCoeffs.add(rem._coefficients[k]);
          }
        }
        rem = CompressedPolynomial<T>._(
          List.unmodifiable(newExps),
          List.unmodifiable(newCoeffs),
          type: type,
        );
      }
    }

    return (
      quotient: CompressedPolynomial<T>.fromMap(qTerms, type: type),
      remainder: rem,
    );
  }

  @override
  Polynomial<T> derivative() {
    if (_exponents.isEmpty) return CompressedPolynomial<T>.zero(type: type);
    final field = type.field;
    final zero = field.additiveIdentity;
    final resExps = <int>[];
    final resCoeffs = <T>[];
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      if (exp > 0) {
        final coeff = field.scale(_coefficients[i], exp.toDouble());
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

  @override
  Polynomial<T> integrate([T? constant]) {
    final field = type.field;
    final zero = field.additiveIdentity;
    final c0 = constant ?? zero;
    final resExps = <int>[];
    final resCoeffs = <T>[];
    if (c0 != zero) {
      resExps.add(0);
      resCoeffs.add(c0);
    }
    for (var i = 0; i < _exponents.length; i++) {
      final exp = _exponents[i];
      final newExp = exp + 1;
      final coeff = field.scale(_coefficients[i], 1.0 / newExp.toDouble());
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
    if (other is! Polynomial<T>) return false;
    final deg = degree;
    if (deg != other.degree) return false;
    if (deg < 0) return true;
    if (other is CompressedPolynomial<T>) {
      if (_exponents.length != other._exponents.length) return false;
      for (var i = 0; i < _exponents.length; i++) {
        if (_exponents[i] != other._exponents[i] ||
            _coefficients[i] != other._coefficients[i]) {
          return false;
        }
      }
      return true;
    }
    for (var i = 0; i <= deg; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final deg = degree;
    if (deg < 0) return 0;
    var hash = Object.hash(deg, type);
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

Polynomial<T> _polyPower<T>(Polynomial<T> base, int exponent) {
  if (exponent == 0) {
    return Polynomial<T>.fromCoefficients([
      base.type.field.multiplicativeIdentity,
    ], type: base.type);
  }
  if (exponent == 1) return base;
  var res = Polynomial<T>.fromCoefficients([
    base.type.field.multiplicativeIdentity,
  ], type: base.type);
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
