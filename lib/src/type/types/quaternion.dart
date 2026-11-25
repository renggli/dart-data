import 'dart:math' as math;

import 'package:more/number.dart';

import '../data_type.dart';
import '../models/equality.dart';
import '../models/field.dart';

/// Data type descriptor for quaternions ([Quaternion]).
final class QuaternionDataType extends DataType<Quaternion> {
  /// Creates a new [QuaternionDataType] instance.
  const new();

  @override
  String get name => 'quaternion';

  @override
  Quaternion get defaultValue => Quaternion.zero;

  @override
  Quaternion cast(Object? value) {
    if (value is Quaternion) {
      return value;
    } else if (value is num) {
      return Quaternion(value);
    } else if (value is BigInt) {
      return Quaternion(value.toDouble());
    } else if (value is Fraction) {
      return Quaternion(value.toDouble());
    } else if (value is Complex) {
      return Quaternion(value.a, value.b);
    } else if (value is String) {
      return Quaternion.tryParse(value) ?? super.cast(value);
    }
    return super.cast(value);
  }

  @override
  Field<Quaternion> get field => const QuaternionField();

  @override
  Equality<Quaternion> get equality => const QuaternionEquality();
}

/// Equality relation for [Quaternion] numbers with proximity testing.
final class QuaternionEquality extends NaturalEquality<Quaternion> {
  /// Creates a new [QuaternionEquality] instance.
  const new();

  @override
  bool isClose(Quaternion a, Quaternion b, double epsilon) =>
      !epsilon.isNaN &&
      epsilon >= 0 &&
      a.isFinite &&
      b.isFinite &&
      const QuaternionField().norm(a - b) <= epsilon;
}

/// Algebraic field operations over [Quaternion] numbers.
final class QuaternionField extends Field<Quaternion> {
  /// Creates a new [QuaternionField] instance.
  const new();

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
  Quaternion inv(Quaternion a) {
    if (!a.isFinite) return a.reciprocal();
    final scale = math.max(
      math.max(a.w.abs(), a.x.abs()),
      math.max(a.y.abs(), a.z.abs()),
    );
    if (scale == 0.0) return a.reciprocal();
    final sw = a.w / scale;
    final sx = a.x / scale;
    final sy = a.y / scale;
    final sz = a.z / scale;
    final sNorm = sw * sw + sx * sx + sy * sy + sz * sz;
    return Quaternion(
      (sw / sNorm) / scale,
      (-sx / sNorm) / scale,
      (-sy / sNorm) / scale,
      (-sz / sNorm) / scale,
    );
  }

  @override
  Quaternion mul(Quaternion a, Quaternion b) => a * b;

  @override
  Quaternion scale(Quaternion a, num factor) => a * factor;

  @override
  Quaternion div(Quaternion a, Quaternion b) {
    if (!a.isFinite || !b.isFinite) return a / b;
    final scaleB = math.max(
      math.max(b.w.abs(), b.x.abs()),
      math.max(b.y.abs(), b.z.abs()),
    );
    if (scaleB == 0.0) return a / b;
    final bw = b.w / scaleB;
    final bx = b.x / scaleB;
    final by = b.y / scaleB;
    final bz = b.z / scaleB;
    final sNorm = bw * bw + bx * bx + by * by + bz * bz;
    final scaleA = math.max(
      math.max(a.w.abs(), a.x.abs()),
      math.max(a.y.abs(), a.z.abs()),
    );
    if (scaleA == 0.0) return Quaternion.zero;
    final aw = a.w / scaleA;
    final ax = a.x / scaleA;
    final ay = a.y / scaleA;
    final az = a.z / scaleA;
    final factor = (scaleA / scaleB) / sNorm;
    return Quaternion(
      (aw * bw + ax * bx + ay * by + az * bz) * factor,
      (ax * bw - aw * bx - ay * bz + az * by) * factor,
      (ay * bw - aw * by - az * bx + ax * bz) * factor,
      (az * bw - aw * bz - ax * by + ay * bx) * factor,
    );
  }

  @override
  Quaternion pow(Quaternion base, Quaternion exponent) => base.pow(exponent);

  @override
  Quaternion abs(Quaternion a) => Quaternion(norm(a));

  @override
  double norm(Quaternion a) {
    final aw = a.w.abs().toDouble();
    final ax = a.x.abs().toDouble();
    final ay = a.y.abs().toDouble();
    final az = a.z.abs().toDouble();
    if (aw.isInfinite || ax.isInfinite || ay.isInfinite || az.isInfinite) {
      return double.infinity;
    }
    if (aw.isNaN || ax.isNaN || ay.isNaN || az.isNaN) {
      return double.nan;
    }
    final max = math.max(math.max(aw, ax), math.max(ay, az));
    if (max == 0.0) return 0.0;
    final sw = aw / max;
    final sx = ax / max;
    final sy = ay / max;
    final sz = az / max;
    return max * math.sqrt(sw * sw + sx * sx + sy * sy + sz * sz);
  }

  @override
  Quaternion conjugate(Quaternion a) => a.conjugate();
}
