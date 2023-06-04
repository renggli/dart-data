import 'package:data/data.dart';
import 'package:more/collection.dart';
import 'package:test/test.dart';

void main() {
  group('filled', () {
    test('basic', () {
      final array = Array<int>.filled(42, shape: Shape.forVector(6));
      expect(array.type, DataType.int32);
      expect(array.data, [42, 42, 42, 42, 42, 42]);
      expect(array.offset, 0);
      expect(IntegerRange(6).map((each) => array.getIndex([each])),
          IntegerRange(6));
    });
  });
  group('fromIterable', () {
    test('basic', () {
      final array = Array<int>.fromIterable(IntegerRange(1, 7));
      expect(array.type, DataType.uint8);
      expect(array.data, [1, 2, 3, 4, 5, 6]);
      expect(array.offset, 0);
      expect(IntegerRange(6).map((each) => array.getIndex([each])),
          IntegerRange(6));
    });
  });
  group('fromObject', () {
    test('basic', () {
      final array = Array<int>.fromObject([
        [1, 2, 3],
        [4, 5, 6]
      ]);
      expect(array.type, DataType.uint8);
      expect(array.data, [1, 2, 3, 4, 5, 6]);
      expect(array.offset, 0);
      expect(
          IntegerRange(2)
              .map((row) =>
                  IntegerRange(3).map((col) => array.getIndex([row, col])))
              .flatten(),
          IntegerRange(6));
    });
  });
}
