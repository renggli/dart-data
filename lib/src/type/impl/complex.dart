library data.type.impl.complex;

import 'dart:typed_data';

import 'package:data/src/type/impl/composite.dart';
import 'package:data/src/type/models/system.dart';
import 'package:more/printer.dart';

class ComplexDataType extends Float64x2DataType {
  const ComplexDataType();

  @override
  String get name => 'complex';

  @override
  System<Float64x2> get system => const ComplexSystem();

  @override
  Printer get printer => Printer.of(
      (value) => '${realPrinter(value.x)}' '${imaginaryPrinter(value.y)}i');

  static Printer realPrinter = Printer.scientific(
    exponentPadding: 3,
    exponentSign: Printer.negativeAndPositiveSign(),
    precision: 6,
  );

  static Printer imaginaryPrinter = Printer.scientific(
    exponentPadding: 3,
    exponentSign: Printer.negativeAndPositiveSign(),
    mantissaSign: Printer.negativeAndPositiveSign(),
    precision: 6,
  );
}

class ComplexSystem extends Float64x2System {
  const ComplexSystem();

  @override
  Float64x2 get multiplicativeIdentity => Float64x2(1, 0);

  @override
  Float64x2 inv(Float64x2 a) {
    final det = 1.0 / (a.x * a.x + a.y * a.y);
    return Float64x2(a.x * det, a.y * -det);
  }

  @override
  Float64x2 mul(Float64x2 a, Float64x2 b) => Float64x2(
        a.x * b.x - a.y * b.y,
        a.x * b.y + a.y * b.x,
      );

  @override
  Float64x2 div(Float64x2 a, Float64x2 b) {
    final det = 1.0 / (a.x * a.x + a.y * a.y);
    return Float64x2(
      (a.x * b.x - a.y * b.y) * det,
      (a.x * b.y + a.y * b.x) * -det,
    );
  }

  @override
  Float64x2 mod(Float64x2 a, Float64x2 b) =>
      throw UnsupportedError('Unable to compute mod($a, $b).');

  @override
  Float64x2 pow(Float64x2 a, Float64x2 b) =>
      throw UnsupportedError('Unable to compute pow($a, $b).');
}
