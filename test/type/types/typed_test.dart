import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('TypedDataType', () {
    test('newList returns specialized typed list', () {
      final floatList = DataType.float64.newList(5);
      check(floatList).isA<Float64List>();

      final int32List = DataType.int32.newList(5);
      check(int32List).isA<Int32List>();

      final uint8List = DataType.uint8.newList(5);
      check(uint8List).isA<Uint8List>();
    });

    test('copyList returns specialized typed list', () {
      final copy = DataType.float64.copyList([1.0, 2.0, 3.0]);
      check(copy).isA<Float64List>();
      check(copy).length.equals(3);
    });
  });
}
