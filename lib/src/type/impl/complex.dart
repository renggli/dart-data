library data.type.impl.complex;

import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/system.dart';
import 'package:data/src/type/type.dart';
import 'package:more/number.dart';

class ComplexDataType extends DataType<Complex> {
  const ComplexDataType();

  @override
  String get name => 'complex';

  @override
  bool get isNullable => true;

  @override
  Complex get nullValue => null;

  @override
  Complex convert(Object value) {
    if (value == null || value is Complex) {
      return value;
    } else if (value is num) {
      return Complex(value);
    } else if (value is Fraction) {
      return Complex(value.toDouble());
    }
    return super.convert(value);
  }

  @override
  Equality<Complex> get equality => const ComplexEquality();

  @override
  System<Complex> get system => const ComplexSystem();
}

class ComplexEquality extends Equality<Complex> {
  const ComplexEquality();

  @override
  bool isClose(Complex a, Complex b, double epsilon) => a.closeTo(b, epsilon);
}

class ComplexSystem extends System<Complex> {
  const ComplexSystem();

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
  Complex scale(Complex a, num f) => Complex(a.a * f, a.b * f);

  @override
  Complex div(Complex a, Complex b) => a / b;

  @override
  Complex mod(Complex a, Complex b) => unsupportedOperation('mod');

  @override
  Complex pow(Complex a, Complex b) => a.pow(b);
}
