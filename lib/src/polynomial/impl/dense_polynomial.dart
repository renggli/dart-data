import 'dart:math' as math;

import '../../../type.dart';
import '../../acceleration/acceleration_manager.dart';
import '../../acceleration/fallback/pure_dart_fft.dart';
import '../polynomial.dart';
import 'compressed_polynomial.dart';

/// Dense univariate polynomial backed by a contiguous list of coefficients.
///
/// Coefficients are stored in ascending power of $x$:
/// $P(x) = c_0 + c_1 x + c_2 x^2 + \dots + c_n x^n$.
class DensePolynomial<T> extends Polynomial<T> {
  /// Constructs a dense polynomial from [coefficients] where index $i$
  /// corresponds to the power $x^i$.
  new fromCoefficients(Iterable<T> coefficients, {DataType<T>? type})
    : type = type ?? DataType.fromIterable(coefficients),
      _coefficients = coefficients.toList(growable: false);

  @override
  final DataType<T> type;

  final List<T> _coefficients;

  @override
  List<T> get coefficients => _coefficients;

  @override
  int get degree {
    final field = type.field;
    final zero = field.additiveIdentity;
    for (var i = _coefficients.length - 1; i >= 0; i--) {
      if (_coefficients[i] != zero) return i;
    }
    return -1;
  }

  @override
  int get termCount {
    final field = type.field;
    final zero = field.additiveIdentity;
    var count = 0;
    for (var i = 0; i < _coefficients.length; i++) {
      if (_coefficients[i] != zero) count++;
    }
    return count;
  }

  @override
  T operator [](int exponent) {
    if (exponent < 0 || exponent >= _coefficients.length) {
      return type.field.additiveIdentity;
    }
    return _coefficients[exponent];
  }

  @override
  T get leadingCoefficient {
    final deg = degree;
    return deg < 0 ? type.field.additiveIdentity : _coefficients[deg];
  }

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
    var acc = (this[deg] as num).toDouble();
    for (var i = deg - 1; i >= 0; i--) {
      acc = acc * xd + (this[i] as num).toDouble();
    }
    return acc;
  }

  @override
  Complex evaluateComplex(Complex x) {
    final deg = degree;
    if (deg < 0) return Complex.zero;
    var acc = Complex((this[deg] as num).toDouble());
    for (var i = deg - 1; i >= 0; i--) {
      acc = acc * x + Complex((this[i] as num).toDouble());
    }
    return acc;
  }

  @override
  Polynomial<T> operator +(Polynomial<T> other) {
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
    final newCoeffs = List<T>.generate(
      _coefficients.length,
      (i) => field.mul(_coefficients[i], scalar),
      growable: false,
    );
    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  @override
  Polynomial<T> operator *(Polynomial<T> other) {
    if (other is CompressedPolynomial<T>) {
      return other * this;
    }
    final deg1 = degree;
    final deg2 = other.degree;
    if (deg1 < 0 || deg2 < 0) return Polynomial<T>.zero(type: type);

    final outDegree = deg1 + deg2;
    final dynamicType = type as DataType<dynamic>;
    if (outDegree >= 64 &&
        (dynamicType == DataType.float64 || dynamicType == DataType.float32)) {
      final n = PureDartFft.nextPowerOf2(outDegree + 1);
      final aList = List<Complex>.generate(
        n,
        (i) =>
            i <= deg1 ? Complex((this[i] as num).toDouble(), 0) : Complex.zero,
        growable: false,
      );
      final bList = List<Complex>.generate(
        n,
        (i) =>
            i <= deg2 ? Complex((other[i] as num).toDouble(), 0) : Complex.zero,
        growable: false,
      );

      final fftA = AccelerationManager.fft(aList);
      final fftB = AccelerationManager.fft(bList);
      final fftC = List<Complex>.generate(
        n,
        (i) => fftA[i] * fftB[i],
        growable: false,
      );
      final reconstructed = AccelerationManager.ifft(fftC);

      final resultCoeffs = List<T>.generate(outDegree + 1, (i) {
        final val = reconstructed[i].a.toDouble();
        return (dynamicType == DataType.float32 ? val.toDouble() : val) as T;
      }, growable: false);

      return DensePolynomial<T>.fromCoefficients(resultCoeffs, type: type);
    }

    final field = type.field;
    final resultCoeffs = List<T>.filled(
      outDegree + 1,
      field.additiveIdentity,
      growable: false,
    );

    for (var i = 0; i <= deg1; i++) {
      final ci = this[i];
      if (ci == field.additiveIdentity) continue;
      for (var j = 0; j <= deg2; j++) {
        final cj = other[j];
        if (cj == field.additiveIdentity) continue;
        resultCoeffs[i + j] = field.add(resultCoeffs[i + j], field.mul(ci, cj));
      }
    }

    return DensePolynomial<T>.fromCoefficients(resultCoeffs, type: type);
  }

  @override
  Polynomial<T> compose(Polynomial<T> other) {
    final deg = degree;
    if (deg < 0) return Polynomial<T>.zero(type: type);
    if (deg == 0) {
      return DensePolynomial<T>.fromCoefficients([
        _coefficients[0],
      ], type: type);
    }
    Polynomial<T> acc = DensePolynomial<T>.fromCoefficients([
      _coefficients[deg],
    ], type: type);
    for (var i = deg - 1; i >= 0; i--) {
      acc =
          (acc * other) +
          DensePolynomial<T>.fromCoefficients([_coefficients[i]], type: type);
    }
    return acc;
  }

  @override
  ({Polynomial<T> quotient, Polynomial<T> remainder}) divide(
    Polynomial<T> divisor,
  ) {
    final degB = divisor.degree;
    if (degB < 0) {
      throw UnsupportedError('Division by zero polynomial.');
    }
    final degA = degree;
    if (degA < degB) {
      return (quotient: Polynomial<T>.zero(type: type), remainder: this);
    }

    final field = type.field;
    final leadB = divisor.leadingCoefficient;
    final qCoeffs = List<T>.filled(
      degA - degB + 1,
      field.additiveIdentity,
      growable: false,
    );
    final rCoeffs = List<T>.generate(degA + 1, (i) => this[i]);

    for (var i = degA; i >= degB; i--) {
      final curCoeff = rCoeffs[i];
      if (curCoeff != field.additiveIdentity) {
        final factor = field.div(curCoeff, leadB);
        final qIdx = i - degB;
        qCoeffs[qIdx] = factor;
        for (var j = 0; j <= degB; j++) {
          final term = field.mul(factor, divisor[j]);
          rCoeffs[qIdx + j] = field.sub(rCoeffs[qIdx + j], term);
        }
      }
    }

    return (
      quotient: DensePolynomial<T>.fromCoefficients(qCoeffs, type: type),
      remainder: DensePolynomial<T>.fromCoefficients(rCoeffs, type: type),
    );
  }

  @override
  Polynomial<T> differentiate() {
    final deg = degree;
    if (deg <= 0) return Polynomial<T>.zero(type: type);

    final field = type.field;
    final newCoeffs = List<T>.generate(deg, (i) {
      final exp = i + 1;
      return field.scale(this[exp], exp.toDouble());
    }, growable: false);

    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
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
      final denom = (i + 1).toDouble();
      final scaled = field.scale(this[i], 1.0 / denom);
      newCoeffs[i + 1] = scaled;
    }

    return DensePolynomial<T>.fromCoefficients(newCoeffs, type: type);
  }

  @override
  List<Complex> get roots => Polynomial.computeRoots(this);

  @override
  CompressedPolynomial<T> toCompressed() {
    final field = type.field;
    final zero = field.additiveIdentity;
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
    if (other is! Polynomial<T>) return false;
    final deg = degree;
    if (deg != other.degree) return false;
    if (deg < 0) return true;
    for (var i = 0; i <= deg; i++) {
      if (this[i] != other[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    final deg = degree;
    if (deg < 0) return 0;
    var hash = deg;
    for (var i = 0; i <= deg; i++) {
      hash = Object.hash(hash, this[i]);
    }
    return hash;
  }

  @override
  String toString() {
    final deg = degree;
    if (deg < 0) return '0';
    final parts = <String>[];
    for (var i = deg; i >= 0; i--) {
      final coeff = this[i];
      if (coeff == type.field.additiveIdentity && deg > 0) continue;
      if (i == 0) {
        parts.add('$coeff');
      } else if (i == 1) {
        parts.add(
          coeff == type.field.multiplicativeIdentity ? 'x' : '${coeff}x',
        );
      } else {
        parts.add(
          coeff == type.field.multiplicativeIdentity ? 'x^$i' : '${coeff}x^$i',
        );
      }
    }
    return parts.join(' + ');
  }
}
