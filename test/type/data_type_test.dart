import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Native attributes', () {
    test('attributes and mapping for all types', () {
      final nativeTypes = <DataType<num>>[
        DataType.float32,
        DataType.float64,
        DataType.int8,
        DataType.uint8,
        DataType.int16,
        DataType.uint16,
        DataType.int32,
        DataType.uint32,
        DataType.int64,
        DataType.uint64,
      ];
      for (final nt in nativeTypes) {
        check(nt.bytesPerElement).isGreaterThan(0);
        check(nt.bits).isGreaterThan(0);
        check(nt.isNative).isTrue();
      }

      check(DataType.float32.isFloat).isTrue();
      check(DataType.float64.isFloat).isTrue();
      check(DataType.int32.isFloat).isFalse();

      check(DataType.int8.isInteger).isTrue();
      check(DataType.uint8.isInteger).isTrue();
      check(DataType.int16.isInteger).isTrue();
      check(DataType.uint16.isInteger).isTrue();
      check(DataType.int32.isInteger).isTrue();
      check(DataType.uint32.isInteger).isTrue();
      check(DataType.int64.isInteger).isTrue();
      check(DataType.uint64.isInteger).isTrue();
      check(DataType.float64.isInteger).isFalse();

      check(DataType.float32.isNumeric).isTrue();
      check(DataType.int32.isNumeric).isTrue();

      check(DataType.int8.isSigned).isTrue();
      check(DataType.int16.isSigned).isTrue();
      check(DataType.int32.isSigned).isTrue();
      check(DataType.int64.isSigned).isTrue();
      check(DataType.float32.isSigned).isTrue();
      check(DataType.float64.isSigned).isTrue();

      check(DataType.uint8.isSigned).isFalse();
      check(DataType.uint16.isSigned).isFalse();
      check(DataType.uint32.isSigned).isFalse();
      check(DataType.uint64.isSigned).isFalse();

      check(DataType.int8.bytesPerElement).equals(1);
      check(DataType.int16.bytesPerElement).equals(2);
      check(DataType.int32.bytesPerElement).equals(4);
      check(DataType.int64.bytesPerElement).equals(8);
      check(DataType.float32.bytesPerElement).equals(4);
      check(DataType.float64.bytesPerElement).equals(8);

      check(DataType.boolean.isNative).isFalse();
      check(DataType.string.isNative).isFalse();
      check(DataType.object.isNative).isFalse();
    });
  });

  group('DataType promotion and factory methods', () {
    test('defaults are immutable const', () {
      check(DefaultDataType.index).equals(DataType.uint32);
      check(DefaultDataType.integer).equals(DataType.int32);
      check(DefaultDataType.float).equals(DataType.float64);
    });

    test('safe promotion', () {
      // Self
      check(DataType.int32.promoteWith(DataType.int32)).equals(DataType.int32);
      // Complex
      check(DataType.int32.promoteWith(DataType.complex))
          .equals(DataType.complex);
      check(DataType.complex.promoteWith(DataType.float64))
          .equals(DataType.complex);
      // Float64
      check(DataType.int32.promoteWith(DataType.float64))
          .equals(DataType.float64);
      check(DataType.float64.promoteWith(DataType.int8))
          .equals(DataType.float64);
      // Float32
      check(DataType.float32.promoteWith(DataType.float64))
          .equals(DataType.float64);
      check(DataType.float32.promoteWith(DataType.int32))
          .equals(DataType.float64);
      check(DataType.int32.promoteWith(DataType.float32))
          .equals(DataType.float64);
      check(DataType.float32.promoteWith(DataType.float32))
          .equals(DataType.float32);
      // Integers
      check(DataType.int8.promoteWith(DataType.int8)).equals(DataType.int8);
      check(DataType.uint8.promoteWith(DataType.uint8)).equals(DataType.uint8);
      check(DataType.uint8.promoteWith(DataType.int8)).equals(DataType.int8);
      check(DataType.uint8.promoteWith(DataType.uint16))
          .equals(DataType.uint16);
      check(DataType.int8.promoteWith(DataType.uint16)).equals(DataType.int16);
      check(DataType.int16.promoteWith(DataType.int32)).equals(DataType.int32);
      check(DataType.uint16.promoteWith(DataType.uint32))
          .equals(DataType.uint32);
      check(DataType.int32.promoteWith(DataType.uint32)).equals(DataType.int32);
      check(DataType.int32.promoteWith(DataType.int64)).equals(DataType.int64);
      check(DataType.uint32.promoteWith(DataType.uint64))
          .equals(DataType.uint64);
      check(DataType.uint64.promoteWith(DataType.int64)).equals(DataType.int64);
      // Object fallback
      check(DataType.string.promoteWith(DataType.int32))
          .equals(DataType.object);
    });

    test('fromInstance', () {
      check(DataType.fromInstance(1)).equals(DataType.int32);
      check(DataType.fromInstance(1.5)).equals(DataType.float64);
      check(DataType.fromInstance(true)).equals(DataType.boolean);
      check(DataType.fromInstance('hello')).equals(DataType.string);
      check(DataType.fromInstance(const Complex(1, 2)))
          .equals(DataType.complex);
      check(DataType.fromInstance(Fraction(1, 2))).equals(DataType.fraction);
      check(DataType.fromInstance(BigInt.from(10))).equals(DataType.bigInt);
      check(DataType.fromInstance([1, 2])).isA<ObjectDataType<List<int>>>();
    });

    test('fromType', () {
      check(DataType.fromType<int>()).equals(DataType.int32);
      check(DataType.fromType<double>()).equals(DataType.float64);
      check(DataType.fromType<bool>()).equals(DataType.boolean);
      check(DataType.fromType<String>()).equals(DataType.string);
      check(DataType.fromType<Complex>()).equals(DataType.complex);
      check(DataType.fromType<Fraction>()).equals(DataType.fraction);
      check(DataType.fromType<BigInt>()).equals(DataType.bigInt);
      check(DataType.fromType<Object?>()).isA<ObjectDataType<Object?>>();
    });

    test('fromIterable', () {
      check(DataType.fromIterable([1, 2, 3])).equals(DataType.int32);
      check(DataType.fromIterable(<double>[])).equals(DataType.float64);
    });
  });

  group('DataTypes lists and operations', () {
    test('Float data types', () {
      for (final type in [DataType.float64, DataType.float32]) {
        check(type.name).contains('float');
        check(type.defaultValue).equals(0.0);
        check(type.comparator(1.0, 2.0)).isLessThan(0);
        check(type.cast(42)).equals(42.0);
        check(type.toString()).contains('DataType.');

        final list = type.newList(5, fillValue: 3.5);
        check(list.length).equals(5);
        check(list[0]).equals(3.5);

        final roList = type.newList(5, fillValue: 1.0, readonly: true);
        check(roList.length).equals(5);
        check(() => roList[0] = 2.0).throws<UnsupportedError>();
      }
    });

    test('Integer data types', () {
      final intTypes = [
        DataType.int8,
        DataType.uint8,
        DataType.int16,
        DataType.uint16,
        DataType.int32,
        DataType.uint32,
        DataType.int64,
        DataType.uint64,
      ];
      for (final type in intTypes) {
        check(type.defaultValue).equals(0);
        check(type.comparator(1, 2)).isLessThan(0);
        check(type.cast(42.8)).equals(42);
        check(type.toString()).contains('DataType.');

        final list = type.newList(4, fillValue: 7);
        check(list.length).equals(4);
        check(list[0]).equals(7);

        final roList = type.newList(4, fillValue: 3, readonly: true);
        check(roList.length).equals(4);
        check(() => roList[0] = 5).throws<UnsupportedError>();
      }
    });

    test('Boolean, String, and Object data types', () {
      // Boolean
      check(DataType.boolean.name).equals('boolean');
      check(DataType.boolean.defaultValue).isFalse();
      check(DataType.boolean.cast(true)).isTrue();
      check(DataType.boolean.newList(3, fillValue: true))
          .which((l) => l.every((b) => b));
      check(() => DataType.boolean.field).throws<UnsupportedError>();

      // String
      check(DataType.string.name).equals('string');
      check(DataType.string.defaultValue).equals('');
      check(DataType.string.cast(123)).equals('123');
      check(DataType.string.newList(3, fillValue: 'hi'))
          .deepEquals(['hi', 'hi', 'hi']);
      check(() => DataType.string.field).throws<UnsupportedError>();

      // Object
      const objType = DataType.object;
      check(objType.name).equals('object');
      check(objType.defaultValue).isNull();
      check(objType.cast('abc')).equals('abc');
      final objList = objType.newList(3, fillValue: 42);
      check(objList[0]).equals(42);
    });

    test('Complex, Fraction, BigInt, and Quaternion data types', () {
      // Complex
      check(DataType.complex.name).equals('complex');
      check(DataType.complex.defaultValue).equals(Complex.zero);
      check(DataType.complex.cast(5)).equals(const Complex(5, 0));
      check(DataType.complex.cast(const Complex(1, 2)))
          .equals(const Complex(1, 2));
      final cList = DataType.complex.newList(2, fillValue: const Complex(1, 1));
      check(cList[0]).equals(const Complex(1, 1));

      // Fraction
      check(DataType.fraction.name).equals('fraction');
      check(DataType.fraction.defaultValue).equals(Fraction.zero);
      check(DataType.fraction.cast(3)).equals(Fraction(3, 1));
      check(DataType.fraction.cast(Fraction(2, 3))).equals(Fraction(2, 3));
      final fList = DataType.fraction.newList(2, fillValue: Fraction(1, 2));
      check(fList[0]).equals(Fraction(1, 2));

      // BigInt
      check(DataType.bigInt.name).equals('bigInt');
      check(DataType.bigInt.defaultValue).equals(BigInt.zero);
      check(DataType.bigInt.cast(50)).equals(BigInt.from(50));
      check(DataType.bigInt.cast(BigInt.from(50))).equals(BigInt.from(50));
      final bList = DataType.bigInt.newList(2, fillValue: BigInt.from(99));
      check(bList[0]).equals(BigInt.from(99));

      // Quaternion
      check(DataType.quaternion.name).equals('quaternion');
      check(DataType.quaternion.defaultValue).equals(Quaternion.zero);
      check(DataType.quaternion.cast(5.0)).equals(const Quaternion(5.0));
      check(DataType.quaternion.cast(const Quaternion(1, 2, 3, 4)))
          .equals(const Quaternion(1, 2, 3, 4));
      check(DataType.quaternion.cast(const Complex(3, 4)))
          .equals(const Quaternion(3, 4));
      check(DataType.quaternion.cast('1 + 2i + 3j + 4k'))
          .equals(const Quaternion(1, 2, 3, 4));
      check(() => DataType.quaternion.cast(true)).throws<ArgumentError>();
      check(() => DataType.quaternion.cast('invalid')).throws<ArgumentError>();
      final qList = DataType.quaternion.newList(
        2,
        fillValue: const Quaternion(1, 2, 3, 4),
      );
      check(qList[0]).equals(const Quaternion(1, 2, 3, 4));
    });

    test('NativeBuffer allocation and operations', () {
      if (!NativeBuffer.isSupported) {
        check(NativeBuffer.isActive).isFalse();
        final buf = NativeBuffer<double>(5, type: DataType.float64);
        check(buf.length).equals(5);
        check(buf.isDisposed).isFalse();
        check(buf.asDoublePointer).isNull();
        check(NativeBuffer.find(buf)).isNull();
        buf.dispose();
        check(buf.isDisposed).isTrue();
        return;
      }
      final prev = NativeBuffer.isEnabled;
      try {
        NativeBuffer.isEnabled = true;
        check(NativeBuffer.isActive).isTrue();

        final buf = NativeBuffer<double>(5, type: DataType.float64);
        check(buf.length).equals(5);
        check(buf.isDisposed).isFalse();
        check(buf.asDoublePointer).isNotNull();
        check(buf.asFloatPointer).isNotNull();
        check(buf.asInt32Pointer).isNotNull();
        check(buf.asInt64Pointer).isNotNull();
        check(buf.asUint8Pointer).isNotNull();

        check(NativeBuffer.find(buf.data)).equals(buf);
        check(NativeBuffer.find(buf)).equals(buf);

        buf.dispose();
        check(buf.isDisposed).isTrue();
        check(buf.asDoublePointer).isNull();

        // All types
        final types = <DataType<dynamic>>[
          DataType.float32,
          DataType.int8,
          DataType.uint8,
          DataType.int16,
          DataType.uint16,
          DataType.int32,
          DataType.uint32,
          DataType.int64,
          DataType.uint64,
        ];
        for (final t in types) {
          final b = NativeBuffer(2, type: t);
          check(b.length).equals(2);
          b.dispose();
        }

        // Negative length throws
        check(() => NativeBuffer(-1, type: DataType.float64))
            .throws<RangeError>();

        // Zero length
        final zeroBuf = NativeBuffer(0, type: DataType.float64);
        check(zeroBuf.length).equals(0);
        zeroBuf.dispose();

        // Unsupported type throws
        check(() => NativeBuffer(5, type: DataType.string))
            .throws<ArgumentError>();

        // Fallback when disabled
        NativeBuffer.isEnabled = false;
        check(NativeBuffer.isActive).isFalse();
        final fallbackList = DataType.float64.newList(
          4,
          fillValue: 1.5,
          readonly: true,
        );
        check(fallbackList.length).equals(4);
        check(fallbackList[0]).equals(1.5);
      } finally {
        NativeBuffer.isEnabled = prev;
      }
    });
  });

  group('Field operations', () {
    test('Float field', () {
      final f = DataType.float64.field;
      check(f.additiveIdentity).equals(0.0);
      check(f.multiplicativeIdentity).equals(1.0);
      check(f.add(2.0, 3.0)).equals(5.0);
      check(f.sub(5.0, 2.0)).equals(3.0);
      check(f.neg(4.0)).equals(-4.0);
      check(f.mul(4.0, 2.5)).equals(10.0);
      check(f.div(10.0, 2.0)).equals(5.0);
      check(f.inv(2.0)).equals(0.5);
      check(f.scale(3.0, 4)).equals(12.0);
      check(f.pow(2.0, 3.0)).equals(8.0);
      check(f.abs(-4.5)).equals(4.5);
      check(f.norm(-3.0)).equals(3.0);
      check(f.sqrt(16.0)).equals(4.0);
      check(f.exp(0.0)).equals(1.0);
      check(f.log(1.0)).equals(0.0);
      check(f.conjugate(5.0)).equals(5.0);
    });

    test('Integer field', () {
      final f = DataType.int32.field;
      check(f.additiveIdentity).equals(0);
      check(f.multiplicativeIdentity).equals(1);
      check(f.add(2, 3)).equals(5);
      check(f.sub(5, 2)).equals(3);
      check(f.neg(4)).equals(-4);
      check(f.mul(4, 3)).equals(12);
      check(f.div(10, 2)).equals(5);
      check(f.inv(1)).equals(1);
      check(f.scale(3, 4)).equals(12);
      check(f.pow(2, 3)).equals(8);
      check(f.abs(-7)).equals(7);
      check(f.norm(-7)).equals(7.0);
      check(f.sqrt(25)).equals(5);
      check(f.exp(0)).equals(1);
      check(f.log(1)).equals(0);
      check(f.conjugate(7)).equals(7);
    });

    test('Complex field', () {
      final f = DataType.complex.field;
      check(f.additiveIdentity).equals(Complex.zero);
      check(f.multiplicativeIdentity).equals(Complex.one);
      const c1 = Complex(3, 4);
      const c2 = Complex(1, 2);
      check(f.add(c1, c2)).equals(const Complex(4, 6));
      check(f.sub(c1, c2)).equals(const Complex(2, 2));
      check(f.neg(c1)).equals(const Complex(-3, -4));
      check(f.mul(c1, c2)).equals(c1 * c2);
      check(f.div(c1, c2)).equals(c1 / c2);
      check(f.inv(c1)).equals(c1.reciprocal());
      check(f.scale(c1, 2)).equals(const Complex(6, 8));
      check(f.pow(c1, c2)).equals(c1.pow(c2));
      check(f.norm(c1)).equals(5.0);
      check(f.abs(c1)).equals(const Complex(5, 0));
      check(f.sqrt(c1)).equals(c1.sqrt());
      check(f.exp(c1)).equals(c1.exp());
      check(f.log(c1)).equals(c1.log());
      check(f.conjugate(c1)).equals(const Complex(3, -4));
    });

    test('Fraction field', () {
      final f = DataType.fraction.field;
      check(f.additiveIdentity).equals(Fraction.zero);
      check(f.multiplicativeIdentity).equals(Fraction.one);
      final frac1 = Fraction(3, 4);
      final frac2 = Fraction(1, 2);
      check(f.add(frac1, frac2)).equals(Fraction(5, 4));
      check(f.sub(frac1, frac2)).equals(Fraction(1, 4));
      check(f.neg(frac1)).equals(Fraction(-3, 4));
      check(f.mul(frac1, frac2)).equals(Fraction(3, 8));
      check(f.div(frac1, frac2)).equals(Fraction(3, 2));
      check(f.inv(frac1)).equals(Fraction(4, 3));
      check(f.scale(frac1, 2)).equals(Fraction(3, 2));
      check(f.pow(frac1, Fraction(2, 1))).equals(Fraction(9, 16));
      check(f.abs(Fraction(-3, 4))).equals(Fraction(3, 4));
      check(f.norm(frac1)).equals(0.75);
      check(f.sqrt(Fraction(4, 9))).equals(Fraction(2, 3));
      check(f.exp(Fraction.zero)).equals(Fraction.one);
      check(f.log(Fraction.one)).equals(Fraction.zero);
      check(f.conjugate(frac1)).equals(frac1);
    });

    test('BigInt field', () {
      final f = DataType.bigInt.field;
      check(f.additiveIdentity).equals(BigInt.zero);
      check(f.multiplicativeIdentity).equals(BigInt.one);
      final b1 = BigInt.from(10);
      final b2 = BigInt.from(3);
      check(f.add(b1, b2)).equals(BigInt.from(13));
      check(f.sub(b1, b2)).equals(BigInt.from(7));
      check(f.neg(b1)).equals(BigInt.from(-10));
      check(f.mul(b1, b2)).equals(BigInt.from(30));
      check(f.div(b1, b2)).equals(BigInt.from(3));
      check(f.inv(BigInt.one)).equals(BigInt.one);
      check(f.pow(b1, BigInt.from(2))).equals(BigInt.from(100));
      check(f.abs(BigInt.from(-10))).equals(BigInt.from(10));
      check(f.norm(BigInt.from(-10))).equals(10.0);
      check(f.sqrt(BigInt.zero)).equals(BigInt.zero);
      check(f.sqrt(BigInt.one)).equals(BigInt.one);
      check(f.sqrt(BigInt.from(100))).equals(BigInt.from(10));
      check(() => f.sqrt(BigInt.from(-5))).throws<ArgumentError>();
      check(f.scale(b1, 2)).equals(BigInt.from(20));
      check(f.scale(b1, 0.5)).equals(BigInt.from(5));
      check(f.exp(BigInt.zero)).equals(BigInt.one);
      check(f.log(BigInt.one)).equals(BigInt.zero);
      check(f.conjugate(b1)).equals(b1);
    });

    test('Quaternion field', () {
      final f = DataType.quaternion.field;
      check(f.additiveIdentity).equals(Quaternion.zero);
      check(f.multiplicativeIdentity).equals(Quaternion.one);
      const q1 = Quaternion(1.0, 2.0, 3.0, 4.0);
      const q2 = Quaternion(2.0, 0.0, 1.0, -1.0);
      check(f.add(q1, q2)).equals(const Quaternion(3.0, 2.0, 4.0, 3.0));
      check(f.sub(q1, q2)).equals(const Quaternion(-1.0, 2.0, 2.0, 5.0));
      check(f.neg(q1)).equals(const Quaternion(-1.0, -2.0, -3.0, -4.0));
      check(f.mul(q1, q2)).equals(q1 * q2);
      check(f.div(q1, q2)).equals(q1 / q2);
      check(f.inv(q1)).equals(q1.reciprocal());
      check(f.scale(q1, 2)).equals(q1 * 2);
      check(f.pow(q1, const Quaternion(2))).equals(q1.pow(const Quaternion(2)));
      check(f.abs(q1)).equals(Quaternion(q1.abs()));
      check(f.norm(q1)).equals(q1.abs());
      check(f.conjugate(q1)).equals(const Quaternion(1.0, -2.0, -3.0, -4.0));
      check(() => f.sqrt(q1)).throws<UnsupportedError>();
      check(() => f.exp(q1)).throws<UnsupportedError>();
      check(() => f.log(q1)).throws<UnsupportedError>();
    });
  });

  group('Equality', () {
    test('NaturalEquality', () {
      const eq = NaturalEquality<String>();
      check(eq.isEqual('a', 'a')).isTrue();
      check(eq.isEqual('a', 'b')).isFalse();
      check(eq.isClose('a', 'a', 0.1)).isTrue();
      check(eq.hash('a')).equals('a'.hashCode);
    });

    test('FloatEquality', () {
      const eq = FloatEquality();
      check(eq.isEqual(1.0, 1.0)).isTrue();
      check(eq.isEqual(1.0, 2.0)).isFalse();
      check(eq.isClose(1.0, 1.05, 0.1)).isTrue();
      check(eq.isClose(1.0, 1.2, 0.1)).isFalse();
      check(eq.hash(1.0)).equals((1.0).hashCode);
    });
  });

  group('MemoryBuffer', () {
    test('identity and overlap', () {
      final list1 = Float64List(10);
      final list2 = Float64List(10);
      final subList1 = Float64List.sublistView(list1, 0, 5);
      final subList2 = Float64List.sublistView(list1, 3, 8);

      check(MemoryBuffer.sharesMemory(list1, list2)).isFalse();
      check(MemoryBuffer.sharesMemory(list1, subList1)).isTrue();
      check(MemoryBuffer.sharesMemory(subList1, subList2)).isTrue();

      final buf1 = MemoryBuffer(subList1);
      final buf2 = MemoryBuffer(subList2);
      check(buf1.id).equals(buf2.id);
      check(buf1.overlaps(buf2, 0, 0, 5)).isTrue();

      // MemoryBuffer.empty
      const emptyBuf = MemoryBuffer<int>.empty();
      check(emptyBuf.id).equals(0);
      check(emptyBuf.length).equals(0);

      // Overlaps with identical generic List
      final objList = <int>[1, 2, 3, 4, 5];
      final objBuf1 = MemoryBuffer(objList);
      final objBuf2 = MemoryBuffer(objList);
      check(objBuf1.overlaps(objBuf2, 0, 2, 3)).isTrue();
      check(objBuf1.overlaps(objBuf2, 0, 3, 2)).isFalse();
    });
  });

  group('DataType coverage', () {
    test('isNative, bits, and comparator', () {
      final nativeTypes = <DataType<dynamic>>[
        DataType.int8,
        DataType.int16,
        DataType.int32,
        DataType.int64,
        DataType.uint8,
        DataType.uint16,
        DataType.uint32,
        DataType.uint64,
        DataType.float32,
        DataType.float64,
      ];
      for (final t in nativeTypes) {
        check(t.isNative).isTrue();
      }
      check(DataType.boolean.isNative).isFalse();
      check(DataType.string.isNative).isFalse();
      check(DataType.object.isNative).isFalse();
      check(DataType.float32.bits).equals(32);
      check(DataType.float64.bits).equals(64);
      check(DataType.string.comparator('apple', 'banana')).isLessThan(0);
    });
  });
}
