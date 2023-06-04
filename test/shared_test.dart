import 'package:data/data.dart';
import 'package:data/src/shared/checks.dart';
import 'package:data/src/shared/lists.dart' as lists;
import 'package:data/src/shared/math.dart' as math;
import 'package:test/test.dart';

void main() {
  group('config', () {
    group('data types', () {
      test('index', () {
        expect(DataType.index, DataType.uint32);
      });

      test('float', () {
        expect(DataType.float, DataType.float64);
      });
    });
  });
  group('lists', () {
    final type = DataType.string.nullable;
    final list = ['a', 'b', 'c', 'd', 'e'];
    test('insertAt', () {
      final list1 = ['a', 'b', 'c', null];
      final list2 = lists.insertAt(type, list1, 3, 2, 'i');
      expect(list2, ['a', 'b', 'i', 'c']);
      final list3 = lists.insertAt(type, list2, 4, 1, 'g');
      expect(list3, ['a', 'g', 'b', 'i', 'c', null, null]);
      final list4 = lists.insertAt(type, list3, 5, 0, 'x');
      expect(list4, ['x', 'a', 'g', 'b', 'i', 'c', null]);
      final list5 = lists.insertAt(type, list4, 6, 6, 'y');
      expect(list5, ['x', 'a', 'g', 'b', 'i', 'c', 'y']);
    });
    test('insertAt (fill)', () {
      final list1 = ['a', 'b', 'c', '*'];
      final list2 = lists.insertAt(type, list1, 3, 2, 'i', fillValue: '*');
      expect(list2, ['a', 'b', 'i', 'c']);
      final list3 = lists.insertAt(type, list2, 4, 1, 'g', fillValue: '*');
      expect(list3, ['a', 'g', 'b', 'i', 'c', '*', '*']);
      final list4 = lists.insertAt(type, list3, 5, 0, 'x', fillValue: '*');
      expect(list4, ['x', 'a', 'g', 'b', 'i', 'c', '*']);
      final list5 = lists.insertAt(type, list4, 6, 6, 'y', fillValue: '*');
      expect(list5, ['x', 'a', 'g', 'b', 'i', 'c', 'y']);
    });
    test('removeAt', () {
      final list1 = ['a', 'g', 'b', 'i', 'c', null, null];
      final list2 = lists.removeAt(type, list1, 5, 1);
      expect(list2, ['a', 'b', 'i', 'c', null, null, null]);
      final list3 = lists.removeAt(type, list2, 4, 2);
      expect(list3, ['a', 'b', 'c', null, null, null, null]);
      final list4 = lists.removeAt(type, list3, 3, 0);
      expect(list4, ['b', 'c', null, null]);
      final list5 = lists.removeAt(type, list4, 2, 1);
      expect(list5, ['b', null, null, null]);
    });
    test('removeAt (fill)', () {
      final list1 = ['a', 'g', 'b', 'i', 'c', '*', '*'];
      final list2 = lists.removeAt(type, list1, 5, 1, fillValue: '*');
      expect(list2, ['a', 'b', 'i', 'c', '*', '*', '*']);
      final list3 = lists.removeAt(type, list2, 4, 2, fillValue: '*');
      expect(list3, ['a', 'b', 'c', '*', '*', '*', '*']);
      final list4 = lists.removeAt(type, list3, 3, 0, fillValue: '*');
      expect(list4, ['b', 'c', '*', '*']);
      final list5 = lists.removeAt(type, list4, 2, 1, fillValue: '*');
      expect(list5, ['b', '*', '*', '*']);
    });
    test('binarySearch (empty)', () {
      expect(lists.binarySearch(list, 0, 0, 'a'), -1);
      expect(lists.binarySearch(list, 4, 4, 'a'), -5);
      expect(lists.binarySearch(list, 5, 5, 'a'), -6);
    });
    test('binarySearch (single)', () {
      expect(lists.binarySearch(list, 0, 1, 'a'), 0);
      expect(lists.binarySearch(list, 1, 2, 'a'), -2);
      expect(lists.binarySearch(list, 1, 2, 'b'), 1);
    });
    test('binarySearch (present)', () {
      expect(lists.binarySearch(list, 0, list.length, 'a'), 0);
      expect(lists.binarySearch(list, 0, list.length, 'b'), 1);
      expect(lists.binarySearch(list, 0, list.length, 'c'), 2);
      expect(lists.binarySearch(list, 0, list.length, 'd'), 3);
      expect(lists.binarySearch(list, 0, list.length, 'e'), 4);
    });
    test('binarySearch (absent)', () {
      expect(lists.binarySearch(list, 0, list.length, '0'), -1);
      expect(lists.binarySearch(list, 0, list.length, 'cc'), -4);
      expect(lists.binarySearch(list, 0, list.length, 'f'), -6);
    });
  });
  group('math', () {
    test('hypotenuse', () {
      expect(math.hypot(3, 4), 5);
      expect(math.hypot(4, 3), 5);
    });
    test('hypotenuse (edge cases)', () {
      expect(math.hypot(0, 3), 3);
      expect(math.hypot(3, 0), 3);
      expect(math.hypot(0, 0), 0);
    });
  });
  group('checkPoints', () {
    test('same number of coordinates', () {
      checkPoints(
        DataType.numeric,
        xs: [1, 2, 3].toVector(),
        ys: [4, 5, 5].toVector(),
      );
      expect(
          () => checkPoints(
                DataType.numeric,
                xs: [1, 2, 3].toVector(),
                ys: [4, 5].toVector(),
              ),
          throwsArgumentError);
    });
    test('minimum number of coordinates', () {
      checkPoints(
        DataType.numeric,
        xs: [1, 2].toVector(),
        ys: [3, 4].toVector(),
        min: 2,
      );
      expect(
          () => checkPoints(
                DataType.numeric,
                xs: [1].toVector(),
                ys: [2].toVector(),
                min: 2,
              ),
          throwsArgumentError);
    });
    test('ordered x-coordinates', () {
      checkPoints(
        DataType.numeric,
        xs: [1, 2, 3].toVector(),
        ys: [4, 5, 6].toVector(),
        ordered: true,
      );
      expect(
          () => checkPoints(
                DataType.numeric,
                xs: [1, 3, 2].toVector(),
                ys: [4, 5, 6].toVector(),
                ordered: true,
              ),
          throwsArgumentError);
    });
    test('unique x-coordinates', () {
      checkPoints(
        DataType.numeric,
        xs: [1, 3, 2].toVector(),
        ys: [4, 5, 6].toVector(),
        unique: true,
      );
      expect(
          () => checkPoints(
                DataType.numeric,
                xs: [1, 2, 1].toVector(),
                ys: [4, 5, 6].toVector(),
                unique: true,
              ),
          throwsArgumentError);
    });
    test('ordered and unique x-coordinates', () {
      checkPoints(
        DataType.numeric,
        xs: [1, 2, 3].toVector(),
        ys: [4, 5, 6].toVector(),
        ordered: true,
        unique: true,
      );
      expect(
          () => checkPoints(
                DataType.numeric,
                xs: [1, 2, 2].toVector(),
                ys: [4, 5, 6].toVector(),
                ordered: true,
                unique: true,
              ),
          throwsArgumentError);
      expect(
          () => checkPoints(
                DataType.numeric,
                xs: [1, 3, 2].toVector(),
                ys: [4, 5, 6].toVector(),
                ordered: true,
                unique: true,
              ),
          throwsArgumentError);
    });
  });
}
