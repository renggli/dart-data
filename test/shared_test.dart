library data.test.shared;

import 'package:data/src/shared/config.dart' as config;
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('config', () {
    group('isVm', () {
      test('on vm', () {
        expect(config.isVm, isTrue);
      }, testOn: '!js');
      test('in browser', () {
        expect(config.isVm, isFalse);
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
}
