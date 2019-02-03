library data.type.impl.quaternion;

import 'dart:typed_data';

import 'package:data/src/type/impl/composite.dart';
import 'package:data/src/type/models/system.dart';
import 'package:more/printer.dart';

class QuaternionDataType extends Float32x4DataType {
  const QuaternionDataType();

  @override
  String get name => 'quaternion';

  @override
  System<Float32x4> get system => const QuaternionSystem();

  @override
  Printer get printer => Printer.of((value) => '${realPrinter(value.x)}'
      '${imaginaryPrinter(value.y)}i'
      '${imaginaryPrinter(value.z)}j'
      '${imaginaryPrinter(value.w)}k');

  static Printer realPrinter = Printer.scientific(
    exponentPadding: 3,
    exponentSign: Printer.negativeAndPositiveSign(),
    precision: 3,
  );

  static Printer imaginaryPrinter = Printer.scientific(
    exponentPadding: 3,
    exponentSign: Printer.negativeAndPositiveSign(),
    mantissaSign: Printer.negativeAndPositiveSign(),
    precision: 3,
  );
}

class QuaternionSystem extends Float32x4System {
  const QuaternionSystem();

  @override
  Float32x4 get multiplicativeIdentity => Float32x4(1, 0, 0, 0);

  @override
  Float32x4 inv(Float32x4 a) {
    final det = 1.0 / (a.x * a.x + a.y * a.y + a.z * a.z + a.w * a.w);
    return Float32x4(a.x * det, a.y * -det, a.z * -det, a.w * -det);
  }

  @override
  Float32x4 mul(Float32x4 a, Float32x4 b) => Float32x4(
        a.x * b.x - a.y * b.y - a.z * b.z - a.w * b.w,
        a.x * b.y + a.y * b.x + a.z * b.w - a.w * b.z,
        a.x * b.z + a.z * b.x + a.w * b.y - a.y * b.w,
        a.x * b.w + a.w * b.x + a.y * b.z - a.z * b.y,
      );

  @override
  Float32x4 div(Float32x4 a, Float32x4 b) {
    final det = 1.0 / (a.x * a.x + a.y * a.y + a.z * a.z + a.w * a.w);
    return Float32x4(
      (a.x * b.x - a.y * b.y - a.z * b.z - a.w * b.w) * det,
      (a.x * b.y + a.y * b.x + a.z * b.w - a.w * b.z) * -det,
      (a.x * b.z + a.z * b.x + a.w * b.y - a.y * b.w) * -det,
      (a.x * b.w + a.w * b.x + a.y * b.z - a.z * b.y) * -det,
    );
  }

  @override
  Float32x4 mod(Float32x4 a, Float32x4 b) =>
      throw UnsupportedError('Unable to compute mod($a, $b).');

  @override
  Float32x4 pow(Float32x4 a, Float32x4 b) =>
      throw UnsupportedError('Unable to compute pow($a, $b).');
}
