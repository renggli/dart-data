import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('NativeBuffer', () {
    test('allocation and properties', () {
      final buf = NativeBuffer<double>(10, type: DataType.float64);
      check(buf.length).equals(10);
      check(buf.type).equals(DataType.float64);
      check(buf.isDisposed).isFalse();

      if (NativeBuffer.isSupported) {
        check(buf.pointer).isNotNull();
        check(buf.asDoublePointer).isNotNull();
      }

      buf.dispose();
      check(buf.isDisposed).isTrue();
      if (NativeBuffer.isSupported) {
        check(buf.asDoublePointer).isNull();
      }
    });

    test('all primitive native types allocate', () {
      final types = <DataType<num>>[
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
      for (final type in types) {
        final buf = NativeBuffer<num>(5, type: type);
        check(buf.length).equals(5);
        check(buf.type).equals(type);
        buf.dispose();
      }
    });

    test('unsupported data type throws', () {
      check(() => NativeBuffer<String>(5, type: DataType.string))
          .throws<ArgumentError>();
      check(() => NativeBuffer<bool>(5, type: DataType.boolean))
          .throws<ArgumentError>();
      check(() => NativeBuffer<Object?>(5, type: DataType.object))
          .throws<ArgumentError>();
    });

    test('negative length throws', () {
      check(() => NativeBuffer<double>(-1, type: DataType.float64))
          .throws<RangeError>();
    });

    test('register and find', () {
      final buf = NativeBuffer<double>(5, type: DataType.float64);
      final list = buf.data;
      NativeBuffer.register(list, buf);
      if (NativeBuffer.isSupported) {
        check(NativeBuffer.find(list)).identicalTo(buf);
      }
      buf.dispose();
    });
  });
}
