import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultDataType', () {
    test('constants', () {
      check(DefaultDataType.index).equals(DataType.uint32);
      check(DefaultDataType.integer).equals(DataType.int32);
      check(DefaultDataType.float).equals(DataType.float64);
    });

    test('attributes of default types', () {
      check(DefaultDataType.index.isInteger).isTrue();
      check(DefaultDataType.index.isSigned).isFalse();
      check(DefaultDataType.index.bits).equals(32);

      check(DefaultDataType.integer.isInteger).isTrue();
      check(DefaultDataType.integer.isSigned).isTrue();
      check(DefaultDataType.integer.bits).equals(32);

      check(DefaultDataType.float.isFloat).isTrue();
      check(DefaultDataType.float.bits).equals(64);
    });
  });
}
