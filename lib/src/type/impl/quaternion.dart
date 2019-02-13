library data.type.impl.quaternion;

import 'dart:math' as math;

import 'package:data/src/type/impl/complex.dart';
import 'package:data/src/type/models/system.dart';
import 'package:data/src/type/type.dart';

/// Base class of a quaternion number.
class Quaternion {
  static final Quaternion zero = Quaternion(0, 0, 0, 0);
  static final Quaternion one = Quaternion(1, 0, 0, 0);
  static final Quaternion i = Quaternion(0, 1, 0, 0);
  static final Quaternion j = Quaternion(0, 0, 1, 0);
  static final Quaternion k = Quaternion(0, 0, 0, 1);

  /// Constructs a quaternion number.
  Quaternion(this.a, [this.b = 0, this.c = 0, this.d = 0]);

  /// The 1st quaternion unit (scalar part).
  final num a;

  /// The 2nd quaternion unit (1st vector/imaginary part).
  final num b;

  /// The 3rd quaternion unit (2nd vector/imaginary part).
  final num c;

  /// The 4th quaternion unit (3rd vector/imaginary part).
  final num d;

  /// Compute the norm of the quaternion.
  double norm() => math.sqrt(a * a + b * b + c * c + d * d);

  /// Compute the negated form of this number.
  Quaternion operator -() => Quaternion(-a, -b, -c, -d);

  /// Compute the conjugate form of this number.
  Quaternion conjugate() => Quaternion(a, -b, -c, -d);

  /// Compute the sum of this number and another one.
  Quaternion operator +(Object other) {
    if (other is num) {
      return Quaternion(a + other, b, c, d);
    } else if (other is Complex) {
      return Quaternion(a + other.re, b + other.im, c, d);
    } else if (other is Quaternion) {
      return Quaternion(
        a + other.a,
        b + other.b,
        c + other.c,
        d + other.d,
      );
    } else {
      return _invalidArgument(other);
    }
  }

  /// Compute the difference of this number and another one.
  Quaternion operator -(Object other) {
    if (other is num) {
      return Quaternion(a - other, b, c, d);
    } else if (other is Complex) {
      return Quaternion(a - other.re, b - other.im, c, d);
    } else if (other is Quaternion) {
      return Quaternion(
        a - other.a,
        b - other.b,
        c - other.c,
        d - other.d,
      );
    } else {
      return _invalidArgument(other);
    }
  }

  /// Compute the product of this number and another one.
  Quaternion operator *(Object other) {
    if (other is num) {
      return Quaternion(a * other, b * other, c * other, d * other);
    } else if (other is Complex) {
      return Quaternion(
        a * other.re - b * other.im,
        a * other.im + b * other.re,
        c * other.re + d * other.im,
        d * other.re - c * other.im,
      );
    } else if (other is Quaternion) {
      return Quaternion(
        a * other.a - b * other.b - c * other.c - d * other.d,
        a * other.b + b * other.a + c * other.d - d * other.c,
        a * other.c + c * other.a + d * other.b - b * other.d,
        a * other.d + d * other.a + b * other.c - c * other.b,
      );
    } else {
      return _invalidArgument(other);
    }
  }

  /// Compute the multiplicative inverse of this quaternion.
  Quaternion reciprocal() {
    final det = 1.0 / (a * a + b * b + c * c + d * d);
    return Quaternion(
      a * det,
      b * -det,
      c * -det,
      d * -det,
    );
  }

  /// Compute the division of this number and another one.
  Quaternion operator /(Object other) {
    if (other is num) {
      return Quaternion(
        a / other,
        b / other,
        c / other,
        d / other,
      );
    } else if (other is Complex) {
      final det = 1.0 / (a * a + b * b + c * c + d * d);
      return Quaternion(
        (a * other.re - b * other.im) * det,
        (a * other.im + b * other.re) * -det,
        (c * other.re + d * other.im) * -det,
        (d * other.re - c * other.im) * -det,
      );
    } else if (other is Quaternion) {
      final det = 1.0 / (a * a + b * b + c * c + d * d);
      return Quaternion(
        (a * other.a - b * other.b - c * other.c - d * other.d) * det,
        (a * other.b + b * other.a + c * other.d - d * other.c) * -det,
        (a * other.c + c * other.a + d * other.b - b * other.d) * -det,
        (a * other.d + d * other.a + b * other.c - c * other.b) * -det,
      );
    } else {
      return _invalidArgument(other);
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Quaternion &&
      a == other.a &&
      b == other.b &&
      c == other.c &&
      d == other.d;

  @override
  int get hashCode => a.hashCode ^ b.hashCode ^ c.hashCode ^ d.hashCode;

  @override
  String toString() => '$a + $b*i + $c*j + $d*k';

  Quaternion _invalidArgument(Object argument) =>
      throw ArgumentError('$argument must be a num, Complex or Quaternion.');
}

class QuaternionDataType extends DataType<Quaternion> {
  const QuaternionDataType() : super();

  @override
  String get name => 'quaternion';

  @override
  bool get isNullable => true;

  @override
  Quaternion get nullValue => null;

  @override
  System<Quaternion> get system => QuaternionSystem();
}

class QuaternionSystem extends System<Quaternion> {
  @override
  Quaternion get additiveIdentity => Quaternion.zero;

  @override
  Quaternion neg(Quaternion a) => -a;

  @override
  Quaternion add(Quaternion a, Quaternion b) => a + b;

  @override
  Quaternion sub(Quaternion a, Quaternion b) => a - b;

  @override
  Quaternion get multiplicativeIdentity => Quaternion.one;

  @override
  Quaternion inv(Quaternion a) => a.reciprocal();

  @override
  Quaternion mul(Quaternion a, Quaternion b) => a * b;

  @override
  Quaternion scale(Quaternion a, num f) => a * f;

  @override
  Quaternion div(Quaternion a, Quaternion b) => a / b;

  @override
  Quaternion mod(Quaternion a, Quaternion b) => throw UnsupportedError('');

  @override
  Quaternion pow(Quaternion a, Quaternion b) => throw UnsupportedError('');
}
