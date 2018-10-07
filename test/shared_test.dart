library data.test.shared;

import 'package:data/src/shared/config.dart' as config;
import 'package:data/src/shared/lists.dart' as lists;
import 'package:data/src/shared/math.dart' as math;
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('config', () {
    group('isVm', () {
      test('on vm', () {
        expect(config.isJavaScript, isFalse);
      }, testOn: '!js');
      test('in browser', () {
        expect(config.isJavaScript, isTrue);
      }, testOn: 'js');
    });
    group('data types', () {
      test('index', () {
        expect(config.indexDataType, DataType.uint32);
      });
      test('value', () {
        expect(config.valueDataType, DataType.float64);
      });
    });
  });
  group('lists', () {
    final list = ['a', 'b', 'c', 'd', 'e'];
    test('insertAt', () {
      final list1 = ['a', 'b', 'c', null];
      final list2 = lists.insertAt(DataType.object, list1, 3, 2, 'i');
      expect(list2, ['a', 'b', 'i', 'c']);
      final list3 = lists.insertAt(DataType.object, list2, 4, 1, 'g');
      expect(list3, ['a', 'g', 'b', 'i', 'c', null, null]);
      final list4 = lists.insertAt(DataType.object, list3, 5, 0, 'x');
      expect(list4, ['x', 'a', 'g', 'b', 'i', 'c', null]);
      final list5 = lists.insertAt(DataType.object, list4, 6, 6, 'y');
      expect(list5, ['x', 'a', 'g', 'b', 'i', 'c', 'y']);
    });
    test('removeAt', () {
      final list1 = ['a', 'g', 'b', 'i', 'c', null, null];
      final list2 = lists.removeAt(DataType.object, list1, 5, 1);
      expect(list2, ['a', 'b', 'i', 'c', null, null, null]);
      final list3 = lists.removeAt(DataType.object, list2, 4, 2);
      expect(list3, ['a', 'b', 'c', null, null, null, null]);
      final list4 = lists.removeAt(DataType.object, list3, 3, 0);
      expect(list4, ['b', 'c', null, null]);
      final list5 = lists.removeAt(DataType.object, list4, 2, 1);
      expect(list5, ['b', null, null, null]);
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
    test('hypot', () {
      expect(math.hypot(3, 4), 5);
      expect(math.hypot(4, 3), 5);
    });
    test('hupot (edge cases)', () {
      expect(math.hypot(0, 3), 3);
      expect(math.hypot(3, 0), 3);
      expect(math.hypot(0, 0), 0);
    });
  });
}
