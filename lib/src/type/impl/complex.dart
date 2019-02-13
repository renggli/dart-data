library data.type.impl.complex;

import 'dart:math' as math;

import 'package:data/src/type/models/system.dart';
import 'package:data/src/type/type.dart';

/// Base class of a complex number.
class Complex {
  static final Complex zero = Complex(0, 0);
  static final Complex one = Complex(1, 0);
  static final Complex i = Complex(0, 1);

  /// Constructs a complex number.
  Complex(this.re, [this.im = 0]);

  /// The real part of this number.
  final num re;

  /// The imaginary part of this number.
  final num im;

  /// Compute the absolute value of this number (or the distance of the point
  /// in the complex plane from the origin).
  double abs() => math.sqrt(re * re + im * im);

  /// Compute the argument of this number (or the angle between the positive
  /// real axis and the point in the complex plane).
  double arg() => math.atan2(im, re);

  /// Compute the negated form of this number.
  Complex operator -() => Complex(-re, -im);

  /// Compute the conjugate form of this number.
  Complex conjugate() => Complex(re, -im);

  /// Compute the sum of this number and another one.
  Complex operator +(Object other) {
    if (other is num) {
      return Complex(re + other, im);
    } else if (other is Complex) {
      return Complex(re + other.re, im + other.im);
    } else {
      return _invalidArgument(other);
    }
  }

  /// Compute the difference of this number and another one.
  Complex operator -(Object other) {
    if (other is num) {
      return Complex(re - other, im);
    } else if (other is Complex) {
      return Complex(re - other.re, im - other.im);
    } else {
      return _invalidArgument(other);
    }
  }

  /// Compute the product of this number and another one.
  Complex operator *(Object other) {
    if (other is num) {
      return Complex(re * other, im * other);
    } else if (other is Complex) {
      return Complex(
        re * other.re - im * other.im,
        re * other.im + im * other.re,
      );
    } else {
      return _invalidArgument(other);
    }
  }

  /// Compute the multiplicative inverse of this complex number.
  Complex reciprocal() {
    final det = 1.0 / (re * re + im * im);
    return Complex(re * det, im * -det);
  }

  /// Compute the division of this number and another one.
  Complex operator /(Object other) {
    if (other is num) {
      return Complex(re / other, im / other);
    } else if (other is Complex) {
      final det = 1.0 / (re * re + im * im);
      return Complex(
        (re * other.re - im * other.im) * det,
        (re * other.im + im * other.re) * -det,
      );
    } else {
      return _invalidArgument(other);
    }
  }

  /// Compute the exponential function of this complex number.
  Complex exp() {
    final exp = math.exp(re);
    return Complex(
      exp * math.cos(im),
      exp * math.sin(im),
    );
  }

  /// Compute the natural logarithm of this complex number.
  Complex log() => Complex(
        math.log(math.sqrt(re * re + im * im)),
        math.atan2(im, re),
      );

  /// Compute the power of this complex number raised to `exponent`.
  Complex pow(Object exponent) => (log() * exponent).exp();

  @override
  bool operator ==(Object other) =>
      other is Complex && re == other.re && im == other.im;

  @override
  int get hashCode => re.hashCode ^ im.hashCode;

  @override
  String toString() => '$re + $im*i';

  Complex _invalidArgument(Object argument) =>
      throw ArgumentError('$argument must be a num or Complex.');
}

class ComplexDataType extends DataType<Complex> {
  const ComplexDataType() : super();

  @override
  String get name => 'complex';

  @override
  bool get isNullable => true;

  @override
  Complex get nullValue => null;

  @override
  System<Complex> get system => ComplexSystem();
}

class ComplexSystem extends System<Complex> {
  @override
  Complex get additiveIdentity => Complex.zero;

  @override
  Complex neg(Complex a) => -a;

  @override
  Complex add(Complex a, Complex b) => a + b;

  @override
  Complex sub(Complex a, Complex b) => a - b;

  @override
  Complex get multiplicativeIdentity => Complex.one;

  @override
  Complex inv(Complex a) => a.reciprocal();

  @override
  Complex mul(Complex a, Complex b) => a * b;

  @override
  Complex scale(Complex a, num f) => a * f;

  @override
  Complex div(Complex a, Complex b) => a / b;

  @override
  Complex mod(Complex a, Complex b) => throw UnsupportedError('');

  @override
  Complex pow(Complex a, Complex b) => a.pow(b);
}
