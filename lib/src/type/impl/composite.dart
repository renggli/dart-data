library data.type.impl.composite;

import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/src/type/models/equality.dart';
import 'package:data/src/type/models/field.dart';
import 'package:data/src/type/type.dart';
import 'package:more/printer.dart';

abstract class CompositeDataType<T, B> extends DataType<T> {
  const CompositeDataType();

  /// Returns the [DataType] of the base values in this composite.
  DataType<B> get base;

  /// Returns the number of base values in this composite.
  int get size;

  /// Converts the composite value to its base values.
  List<B> toList(T value);

  /// Converts the base values to its composite.
  T fromList(List<B> values);

  @override
  String get name => '${base.name}x$size';

  @override
  bool get isNullable => false;

  @override
  T cast(Object value) {
    if (value is T) {
      return value;
    } else if (value is List<B>) {
      return fromList(value);
    } else if (value is List) {
      return fromList(value.map(base.cast).toList());
    } else if (value is String) {
      return fromList(value
          .split(RegExp(r'[,;|[\] ]'))
          .map((each) => each.trim())
          .where((each) => each.isNotEmpty)
          .map((each) => base.cast(each))
          .toList());
    }
    return super.cast(value);
  }

  @override
  Printer get printer => Printer.of((value) {
        final values = toList(value).map(base.printer).join(', ');
        return '[$values]';
      });
}

// Float64x2
class Float64x2DataType extends CompositeDataType<Float64x2, double> {
  const Float64x2DataType();

  @override
  DataType<double> get base => DataType.float64;

  @override
  int get size => 2;

  @override
  Float64x2 get nullValue => Float64x2.zero();

  @override
  Equality<Float64x2> get equality => const Float64x2Equality();

  @override
  Field<Float64x2> get field => const Float64x2Field();

  @override
  List<Float64x2> newList(int length) => Float64x2List(length);

  @override
  List<double> toList(Float64x2 value) => [value.x, value.y];

  @override
  Float64x2 fromList(List<double> values) => Float64x2(values[0], values[1]);
}

class Float64x2Equality extends Equality<Float64x2> {
  const Float64x2Equality();

  @override
  bool isEqual(Float64x2 a, Float64x2 b) => a.x == b.x && a.y == b.y;

  @override
  int hash(Float64x2 a) => a.x.hashCode ^ a.y.hashCode;
}

class Float64x2Field extends Field<Float64x2> {
  const Float64x2Field();

  @override
  Float64x2 get additiveIdentity => Float64x2.zero();

  @override
  Float64x2 neg(Float64x2 a) => -a;

  @override
  Float64x2 add(Float64x2 a, Float64x2 b) => a + b;

  @override
  Float64x2 sub(Float64x2 a, Float64x2 b) => a - b;

  @override
  Float64x2 get multiplicativeIdentity => Float64x2(1, 0);

  @override
  Float64x2 inv(Float64x2 a) => Float64x2(1.0 / a.x, 1.0 / a.y);

  @override
  Float64x2 mul(Float64x2 a, Float64x2 b) => a * b;

  @override
  Float64x2 scale(Float64x2 a, num f) => a * Float64x2.splat(f);

  @override
  Float64x2 div(Float64x2 a, Float64x2 b) => a / b;

  @override
  Float64x2 mod(Float64x2 a, Float64x2 b) => Float64x2(a.x % b.x, a.y % b.y);

  @override
  Float64x2 pow(Float64x2 a, Float64x2 b) =>
      Float64x2(math.pow(a.x, b.x), math.pow(a.y, b.y));
}

// Float32x4
class Float32x4DataType extends CompositeDataType<Float32x4, double> {
  const Float32x4DataType();

  @override
  DataType<double> get base => DataType.float32;

  @override
  int get size => 4;

  @override
  Float32x4 get nullValue => Float32x4.zero();

  @override
  Equality<Float32x4> get equality => const Float32x4Equality();

  @override
  Field<Float32x4> get field => const Float32x4Field();

  @override
  List<Float32x4> newList(int length) => Float32x4List(length);

  @override
  List<double> toList(Float32x4 value) => [value.x, value.y, value.z, value.w];

  @override
  Float32x4 fromList(List<double> values) =>
      Float32x4(values[0], values[1], values[2], values[3]);
}

class Float32x4Equality extends Equality<Float32x4> {
  const Float32x4Equality();

  @override
  bool isEqual(Float32x4 a, Float32x4 b) =>
      a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w;

  @override
  int hash(Float32x4 a) =>
      a.x.hashCode ^ a.y.hashCode ^ a.z.hashCode ^ a.w.hashCode;
}

class Float32x4Field extends Field<Float32x4> {
  const Float32x4Field();

  @override
  Float32x4 get additiveIdentity => Float32x4.zero();

  @override
  Float32x4 neg(Float32x4 a) => -a;

  @override
  Float32x4 add(Float32x4 a, Float32x4 b) => a + b;

  @override
  Float32x4 sub(Float32x4 a, Float32x4 b) => a - b;

  @override
  Float32x4 get multiplicativeIdentity => Float32x4.splat(1.0);

  @override
  Float32x4 inv(Float32x4 a) => a.reciprocal();

  @override
  Float32x4 mul(Float32x4 a, Float32x4 b) => a * b;

  @override
  Float32x4 scale(Float32x4 a, num f) => a * Float32x4.splat(f);

  @override
  Float32x4 div(Float32x4 a, Float32x4 b) => a / b;

  @override
  Float32x4 mod(Float32x4 a, Float32x4 b) =>
      Float32x4(a.x % b.x, a.y % b.y, a.z % b.z, a.w % b.w);

  @override
  Float32x4 pow(Float32x4 a, Float32x4 b) => Float32x4(math.pow(a.x, b.x),
      math.pow(a.y, b.y), math.pow(a.z, b.z), math.pow(a.w, b.w));
}

// Int32x4
class Int32x4DataType extends CompositeDataType<Int32x4, int> {
  const Int32x4DataType();

  @override
  DataType<int> get base => DataType.int32;

  @override
  int get size => 4;

  @override
  Int32x4 get nullValue => Int32x4(0, 0, 0, 0);

  @override
  Equality<Int32x4> get equality => const Int32x4Equality();

  @override
  Field<Int32x4> get field => const Int32x4Field();

  @override
  List<Int32x4> newList(int length) => Int32x4List(length);

  @override
  List<int> toList(Int32x4 value) => <int>[value.x, value.y, value.z, value.w];

  @override
  Int32x4 fromList(List<int> values) =>
      Int32x4(values[0], values[1], values[2], values[3]);
}

class Int32x4Equality extends Equality<Int32x4> {
  const Int32x4Equality();

  @override
  bool isEqual(Int32x4 a, Int32x4 b) =>
      a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w;

  @override
  int hash(Int32x4 a) =>
      a.x.hashCode ^ a.y.hashCode ^ a.z.hashCode ^ a.w.hashCode;
}

class Int32x4Field extends Field<Int32x4> {
  const Int32x4Field();

  @override
  Int32x4 get additiveIdentity => Int32x4(0, 0, 0, 0);

  @override
  Int32x4 neg(Int32x4 a) => additiveIdentity - a;

  @override
  Int32x4 add(Int32x4 a, Int32x4 b) => a + b;

  @override
  Int32x4 sub(Int32x4 a, Int32x4 b) => a - b;

  @override
  Int32x4 get multiplicativeIdentity => Int32x4(1, 1, 1, 1);

  @override
  Int32x4 inv(Int32x4 a) => Int32x4(1 ~/ a.x, 1 ~/ a.y, 1 ~/ a.z, 1 ~/ a.w);

  @override
  Int32x4 mul(Int32x4 a, Int32x4 b) =>
      Int32x4(a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w);

  @override
  Int32x4 scale(Int32x4 a, num f) =>
      Int32x4(a.x * f, a.y * f, a.z * f, a.w * f);

  @override
  Int32x4 div(Int32x4 a, Int32x4 b) =>
      Int32x4(a.x ~/ b.x, a.y ~/ b.y, a.z ~/ b.z, a.w ~/ b.w);

  @override
  Int32x4 mod(Int32x4 a, Int32x4 b) =>
      Int32x4(a.x % b.x, a.y % b.y, a.z % b.z, a.w % b.w);

  @override
  Int32x4 pow(Int32x4 a, Int32x4 b) => Int32x4(
      math.pow(a.x, b.x).truncate(),
      math.pow(a.y, b.y).truncate(),
      math.pow(a.z, b.z).truncate(),
      math.pow(a.w, b.w).truncate());
}
