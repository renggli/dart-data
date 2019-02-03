library data.type.impl.numeric;

import 'dart:math' as math;

import 'package:data/src/type/models/system.dart';
import 'package:data/src/type/type.dart';

class NumericDataType extends DataType<num> {
  const NumericDataType();

  @override
  String get name => 'numeric';

  @override
  bool get isNullable => true;

  @override
  num get nullValue => null;

  @override
  System<num> get system => const NumericSystem();

  @override
  num convert(Object value) {
    if (value == null || value is num) {
      return value;
    } else if (value is String) {
      final intValue = int.tryParse(value);
      if (intValue != null) {
        return intValue;
      }
      final doubleValue = double.tryParse(value);
      if (doubleValue != null) {
        return doubleValue;
      }
    }
    return super.convert(value);
  }
}

class NumericSystem extends System<num> {
  const NumericSystem();

  @override
  num get additiveIdentity => 0;

  @override
  num neg(num a) => -a;

  @override
  num add(num a, num b) => a + b;

  @override
  num sub(num a, num b) => a - b;

  @override
  num get multiplicativeIdentity => 1;

  @override
  num inv(num a) => 1 / a;

  @override
  num mul(num a, num b) => a * b;

  @override
  num scale(num a, num b) => a * b;

  @override
  num div(num a, num b) => a / b;

  @override
  num mod(num a, num b) => a % b;

  @override
  num pow(num a, num b) => math.pow(a, b);
}
