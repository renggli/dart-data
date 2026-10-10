import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:test/test.dart';

void main() {
  group('TupleKey', () {
    test('equality and hashCode', () {
      final key1 = TupleKey(['a', 1, true, 3.14]);
      final key2 = TupleKey(['a', 1, true, 3.14]);
      final key3 = TupleKey(['a', 2, true, 3.14]);
      final key4 = TupleKey(['a', '1', true, 3.14]);

      check(key1 == key2).isTrue();
      check(key1.hashCode).equals(key2.hashCode);

      check(key1 == key3).isFalse();
      check(key1 == key4).isFalse();
      check(key1 == Object()).isFalse();
      check(key1 == key1).isTrue();
    });

    test('toString formatting', () {
      final key = TupleKey([1, 'foo', null]);
      check(key.toString()).equals('TupleKey([1, foo, null])');
    });

    test('null element handling', () {
      final keyWithNull = TupleKey([null, 1, 2, 3]);
      final keyWithStringNull = TupleKey(['null', 1, 2, 3]);

      check(keyWithNull == keyWithStringNull).isFalse();
      check(keyWithNull == TupleKey([null, 1, 2, 3])).isTrue();
    });
  });

  group('extractKey', () {
    test('specialized return types based on length', () {
      check(extractKey([42])).equals(42);
      check(extractKey(['a', 'b'])).equals(('a', 'b'));
      check(extractKey(['a', 1, false])).equals(('a', 1, false));

      final key4 = extractKey([1, 2, 3, 4]);
      check(key4).isA<TupleKey>();
      check((key4 as TupleKey).values).deepEquals([1, 2, 3, 4]);

      final key0 = extractKey([]);
      check(key0).isA<TupleKey>();
      check((key0 as TupleKey).values).isEmpty();
    });
  });

  group('RowKeyExtractor', () {
    test('1 column extractor', () {
      final col = Series<num>.fromList('c0', [10, null, 20]);
      final extractor = RowKeyExtractor([col]);

      check(extractor.extractKey(0)).equals(10);
      check(extractor.extractKeyOrNull(0)).equals(10);
      check(extractor.hasNull(0)).isFalse();

      check(extractor.extractKey(1)).isNull();
      check(extractor.extractKeyOrNull(1)).isNull();
      check(extractor.hasNull(1)).isTrue();

      check(extractor.extractKey(2)).equals(20);
      check(extractor.extractKeyOrNull(2)).equals(20);
      check(extractor.hasNull(2)).isFalse();
    });

    test('2 column extractor', () {
      final c0 = Series<String>.fromList('c0', ['x', 'x', null, 'x']);
      final c1 = Series<num>.fromList('c1', [1, null, 2, 3]);
      final extractor = RowKeyExtractor([c0, c1]);

      check(extractor.extractKey(0)).equals(('x', 1));
      check(extractor.extractKeyOrNull(0)).equals(('x', 1));
      check(extractor.hasNull(0)).isFalse();

      check(extractor.extractKey(1)).equals(('x', null));
      check(extractor.extractKeyOrNull(1)).isNull();
      check(extractor.hasNull(1)).isTrue();

      check(extractor.extractKey(2)).equals((null, 2));
      check(extractor.extractKeyOrNull(2)).isNull();
      check(extractor.hasNull(2)).isTrue();

      check(extractor.extractKey(3)).equals(('x', 3));
      check(extractor.extractKeyOrNull(3)).equals(('x', 3));
      check(extractor.hasNull(3)).isFalse();
    });

    test('3 column extractor', () {
      final c0 = Series<num>.fromList('c0', [1, 1]);
      final c1 = Series<String>.fromList('c1', ['a', null]);
      final c2 = Series<bool>.fromList('c2', [true, false]);
      final extractor = RowKeyExtractor([c0, c1, c2]);

      check(extractor.extractKey(0)).equals((1, 'a', true));
      check(extractor.extractKeyOrNull(0)).equals((1, 'a', true));
      check(extractor.hasNull(0)).isFalse();

      check(extractor.extractKey(1)).equals((1, null, false));
      check(extractor.extractKeyOrNull(1)).isNull();
      check(extractor.hasNull(1)).isTrue();
    });

    test('4 column extractor (TupleKey fallback)', () {
      final c0 = Series<num>.fromList('c0', [1, 1]);
      final c1 = Series<num>.fromList('c1', [2, 2]);
      final c2 = Series<num>.fromList('c2', [3, null]);
      final c3 = Series<num>.fromList('c3', [4, 4]);
      final extractor = RowKeyExtractor([c0, c1, c2, c3]);

      final key0 = extractor.extractKey(0);
      check(key0).isA<TupleKey>();
      check((key0 as TupleKey).values).deepEquals([1, 2, 3, 4]);
      check(extractor.extractKeyOrNull(0)).isA<TupleKey>();
      check(extractor.hasNull(0)).isFalse();

      check(extractor.extractKeyOrNull(1)).isNull();
      check(extractor.hasNull(1)).isTrue();
    });

    test('0 column extractor', () {
      final extractor = RowKeyExtractor([]);
      check(extractor.extractKey(0)).isA<TupleKey>();
      check(extractor.extractKeyOrNull(0)).isA<TupleKey>();
      check(extractor.hasNull(0)).isFalse();
    });
  });
}
