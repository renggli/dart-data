import 'dart:typed_data';

import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('DType', () {
    test('token attributes', () {
      expect(DType.float64.isFloat, isTrue);
      expect(DType.float64.isNumeric, isTrue);
      expect(DType.float64.bytesPerElement, 8);
      expect(DType.float64.dataType, DataType.float64);

      expect(DType.int32.isInteger, isTrue);
      expect(DType.int32.isSigned, isTrue);
      expect(DType.int32.bytesPerElement, 4);

      expect(DType.uint8.isSigned, isFalse);
      expect(DType.uint8.bytesPerElement, 1);

      expect(DType.boolean.bytesPerElement, 1);
      expect(DType.complex128.bytesPerElement, 16);
    });

    test('DataType.dType mapping', () {
      expect(DataType.float64.dType, DType.float64);
      expect(DataType.float32.dType, DType.float32);
      expect(DataType.int32.dType, DType.int32);
      expect(DataType.uint8.dType, DType.uint8);
      expect(DataType.boolean.dType, DType.boolean);
      expect(DataType.string.dType, DType.string);
      expect(DataType.complex.dType, DType.complex128);
    });
  });

  group('DataTypeDefaults', () {
    test('immutable constants', () {
      expect(DataTypeDefaults.index, DataType.uint32);
      expect(DataTypeDefaults.integer, DataType.int32);
      expect(DataTypeDefaults.float, DataType.float64);
      expect(DataType.index, DataType.uint32);
      expect(DataType.integer, DataType.int32);
      expect(DataType.float, DataType.float64);
    });
  });

  group('Type Promotion', () {
    test('float promotions', () {
      expect(DataType.int32.promoteWith(DataType.float64), DataType.float64);
      expect(DataType.float32.promoteWith(DataType.float64), DataType.float64);
      expect(DataType.float32.promoteWith(DataType.int32), DataType.float64);
    });

    test('integer promotions', () {
      expect(DataType.int16.promoteWith(DataType.int32), DataType.int32);
      expect(DataType.uint8.promoteWith(DataType.int8), DataType.int8);
      expect(DataType.uint16.promoteWith(DataType.int32), DataType.int32);
      expect(DataType.int32.promoteWith(DataType.int64), DataType.int64);
    });

    test('complex promotions', () {
      expect(DataType.float64.promoteWith(DataType.complex), DataType.complex);
    });
  });

  group('ExtendedField', () {
    test('Float64 ExtendedField', () {
      final field = DataType.float64.field;
      expect(field.abs(-4.5), 4.5);
      expect(field.norm(-3.0), 3.0);
      expect(field.sqrt(16.0), 4.0);
      expect(field.exp(0.0), 1.0);
      expect(field.log(1.0), 0.0);
      expect(field.conjugate(5.0), 5.0);
    });

    test('Integer ExtendedField', () {
      final field = DataType.int32.field;
      expect(field.abs(-7), 7);
      expect(field.norm(-7), 7.0);
      expect(field.sqrt(25), 5);
      expect(field.conjugate(7), 7);
    });

    test('Complex ExtendedField', () {
      final field = DataType.complex.field;
      const c = Complex(3, 4);
      expect(field.norm(c), 5.0);
      expect(field.abs(c), const Complex(5, 0));
      expect(field.conjugate(c), const Complex(3, -4));
    });

    test('Fraction ExtendedField', () {
      final field = DataType.fraction.field;
      final f = Fraction(-3, 4);
      expect(field.abs(f), Fraction(3, 4));
      expect(field.norm(f), 0.75);
      expect(field.sqrt(Fraction(4, 9)), Fraction(2, 3));
      expect(field.conjugate(f), f);
    });

    test('BigInt ExtendedField and scale fix', () {
      final field = DataType.bigInt.field;
      expect(field.abs(BigInt.from(-10)), BigInt.from(10));
      expect(field.sqrt(BigInt.from(100)), BigInt.from(10));
      expect(field.conjugate(BigInt.from(5)), BigInt.from(5));

      // Correct BigIntField.scale rounding
      expect(field.scale(BigInt.from(10), 0.4), BigInt.from(4));
      expect(field.scale(BigInt.from(10), 0.5), BigInt.from(5));
      expect(field.scale(BigInt.from(10), 2), BigInt.from(20));
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
