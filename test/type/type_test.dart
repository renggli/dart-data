import 'dart:typed_data';

import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('DType', () {
    test('attributes and mapping', () {
      expect(DType.float64.isFloat, isTrue);
      expect(DType.float64.bytesPerElement, 8);
      expect(DType.int32.isInteger, isTrue);
      expect(DType.int32.isSigned, isTrue);
      expect(DType.uint8.isSigned, isFalse);
      expect(DType.uint8.bytesPerElement, 1);
      expect(DataType.float64.dType, DType.float64);
      expect(DataType.int32.dType, DType.int32);
      expect(DataType.complex.dType, DType.complex128);
    });
  });

  group('DataType promotion and defaults', () {
    test('defaults are immutable const', () {
      expect(DataTypeDefaults.index, DataType.uint32);
      expect(DataTypeDefaults.integer, DataType.int32);
      expect(DataTypeDefaults.float, DataType.float64);
      expect(DataType.index, DataType.uint32);
      expect(DataType.integer, DataType.int32);
      expect(DataType.float, DataType.float64);
    });

    test('safe promotion', () {
      expect(DataType.int32.promoteWith(DataType.float64), DataType.float64);
      expect(DataType.float32.promoteWith(DataType.float64), DataType.float64);
      expect(DataType.float32.promoteWith(DataType.int32), DataType.float64);
      expect(DataType.int16.promoteWith(DataType.int32), DataType.int32);
      expect(DataType.int32.promoteWith(DataType.int64), DataType.int64);
      expect(DataType.float64.promoteWith(DataType.complex), DataType.complex);
    });
  });

  group('Field operations', () {
    test('Float', () {
      final f = DataType.float64.field;
      expect(f.add(2.0, 3.0), 5.0);
      expect(f.sub(5.0, 2.0), 3.0);
      expect(f.mul(4.0, 2.5), 10.0);
      expect(f.div(10.0, 2.0), 5.0);
      expect(f.abs(-4.5), 4.5);
      expect(f.norm(-3.0), 3.0);
      expect(f.sqrt(16.0), 4.0);
      expect(f.exp(0.0), 1.0);
      expect(f.log(1.0), 0.0);
      expect(f.conjugate(5.0), 5.0);
    });

    test('Integer', () {
      final f = DataType.int32.field;
      expect(f.add(2, 3), 5);
      expect(f.abs(-7), 7);
      expect(f.norm(-7), 7.0);
      expect(f.sqrt(25), 5);
      expect(f.conjugate(7), 7);
    });

    test('Complex', () {
      final f = DataType.complex.field;
      const c = Complex(3, 4);
      expect(f.norm(c), 5.0);
      expect(f.abs(c), const Complex(5, 0));
      expect(f.conjugate(c), const Complex(3, -4));
    });

    test('Fraction', () {
      final f = DataType.fraction.field;
      final frac = Fraction(-3, 4);
      expect(f.abs(frac), Fraction(3, 4));
      expect(f.norm(frac), 0.75);
      expect(f.sqrt(Fraction(4, 9)), Fraction(2, 3));
      expect(f.conjugate(frac), frac);
    });

    test('BigInt scale fix', () {
      final f = DataType.bigInt.field;
      expect(f.abs(BigInt.from(-10)), BigInt.from(10));
      expect(f.sqrt(BigInt.from(100)), BigInt.from(10));
      expect(f.conjugate(BigInt.from(5)), BigInt.from(5));
      expect(f.scale(BigInt.from(10), 0.4), BigInt.from(4));
      expect(f.scale(BigInt.from(10), 0.5), BigInt.from(5));
      expect(f.scale(BigInt.from(10), 2), BigInt.from(20));
    });
  });

  group('MemoryBuffer', () {
    test('identity and overlap', () {
      final list1 = Float64List(10);
      final list2 = Float64List(10);
      final subList1 = Float64List.sublistView(list1, 0, 5);
      final subList2 = Float64List.sublistView(list1, 3, 8);

      expect(MemoryBuffer.sharesMemory(list1, list2), isFalse);
      expect(MemoryBuffer.sharesMemory(list1, subList1), isTrue);
      expect(MemoryBuffer.sharesMemory(subList1, subList2), isTrue);

      final buf1 = MemoryBuffer(subList1);
      final buf2 = MemoryBuffer(subList2);
      expect(buf1.id, buf2.id);
      expect(buf1.overlaps(buf2, 0, 0, 5), isTrue);
    });
  });
}
