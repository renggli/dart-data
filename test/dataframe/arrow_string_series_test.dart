import 'dart:convert' show utf8;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('ArrowStringSeries', () {
    test('constructs from nullable string list', () {
      final series = ArrowStringSeries.fromList('names', [
        'Alice',
        null,
        'Bob',
        '',
        'Charlie 🚀',
      ]);

      check(series.name).equals('names');
      check(series.length).equals(5);
      check(series.hasNulls).isTrue();
      check(series.nullCount).equals(1);
      check(series.dataType).equals(DataType.string);

      check(series[0]).equals('Alice');
      check(series[1]).isNull();
      check(series[2]).equals('Bob');
      check(series[3]).equals('');
      check(series[4]).equals('Charlie 🚀');
    });

    test('getBytes returns correct zero-copy UTF-8 bytes', () {
      final raw = ['Hello', null, 'World', ''];
      final series = ArrowStringSeries.fromList('text', raw);

      final b0 = series.getBytes(0);
      check(utf8.decode(b0)).equals('Hello');

      final b1 = series.getBytes(1); // null
      check(b1.isEmpty).isTrue();

      final b2 = series.getBytes(2);
      check(utf8.decode(b2)).equals('World');

      final b3 = series.getBytes(3); // empty
      check(b3.isEmpty).isTrue();

      // Out of bounds throws RangeError
      check(() => series.getBytes(-1)).throws<RangeError>();
      check(() => series.getBytes(10)).throws<RangeError>();
    });

    test('filter subsets bytes and offsets correctly', () {
      final series = ArrowStringSeries.fromList('fruits', [
        'Apple',
        'Banana',
        null,
        'Date',
        'Elderberry',
      ]);

      // Keep Banana, null, Elderberry
      final filtered =
          series.filter([false, true, true, false, true]) as ArrowStringSeries;

      check(filtered.length).equals(3);
      check(filtered[0]).equals('Banana');
      check(filtered[1]).isNull();
      check(filtered[2]).equals('Elderberry');
      check(filtered.nullCount).equals(1);

      check(utf8.decode(filtered.getBytes(0))).equals('Banana');
      check(filtered.getBytes(1).isEmpty).isTrue();
      check(utf8.decode(filtered.getBytes(2))).equals('Elderberry');
    });

    test('slice creates subview with adjusted offsets', () {
      final series = ArrowStringSeries.fromList('data', [
        'A',
        'B',
        null,
        'D',
        'E',
      ]);

      final sliced = series.slice(1, 4) as ArrowStringSeries;
      check(sliced.length).equals(3);
      check(sliced[0]).equals('B');
      check(sliced[1]).isNull();
      check(sliced[2]).equals('D');

      check(sliced.offsets[0]).equals(0);
      check(sliced.offsets.last).equals(sliced.bytes.length);

      // Slice without nulls normalizes mask to null
      final nonNullSlice = series.slice(0, 2) as ArrowStringSeries;
      check(nonNullSlice.hasNulls).isFalse();
      check(nonNullSlice.nullCount).equals(0);
      check(nonNullSlice.mask).isNull();

      // Empty slice
      final empty = series.slice(2, 2) as ArrowStringSeries;
      check(empty.length).equals(0);
      check(empty.bytes.isEmpty).isTrue();
    });

    test('sort orders lexicographically with nulls last', () {
      final series = ArrowStringSeries.fromList('s', [
        'zebra',
        null,
        'apple',
        'mango',
      ]);

      final sortedAsc = series.sort() as ArrowStringSeries;
      check(sortedAsc.toList()).deepEquals(['apple', 'mango', 'zebra', null]);

      final sortedAscNullsFirst =
          series.sort(ascending: true, nullsLast: false) as ArrowStringSeries;
      check(sortedAscNullsFirst.toList())
          .deepEquals([null, 'apple', 'mango', 'zebra']);

      final sortedDesc = series.sort(ascending: false) as ArrowStringSeries;
      check(sortedDesc.toList()).deepEquals(['zebra', 'mango', 'apple', null]);

      final sortedDescNullsFirst =
          series.sort(ascending: false, nullsLast: false) as ArrowStringSeries;
      check(sortedDescNullsFirst.toList())
          .deepEquals([null, 'zebra', 'mango', 'apple']);
    });

    test('sort orders UTF-8 multibyte characters and prefixes', () {
      final series = ArrowStringSeries.fromList('unicode', [
        'café',
        'cafe',
        'cafés',
        'apple',
        '⚡',
        '✨',
      ]);
      final sortedAsc = series.sort().toList();
      check(sortedAsc).deepEquals(['apple', 'cafe', 'café', 'cafés', '⚡', '✨']);
    });

    test('aggregations min, max, sum, mean', () {
      final series = ArrowStringSeries.fromList('words', [
        'banana',
        'apple',
        null,
        'cherry',
      ]);

      check(series.min).equals('apple');
      check(series.max).equals('cherry');
      check(series.sum).isNull();
      check(series.mean).isNull();
    });

    test('rename', () {
      final series = ArrowStringSeries.fromList('words', ['one', null, 'two']);
      check(series.toList()).deepEquals(['one', null, 'two']);

      final renamed = series.rename('words_renamed');
      check(renamed.name).equals('words_renamed');
      check(renamed.length).equals(3);
    });

    test('validates offsets in generative constructor', () {
      check(
        () => ArrowStringSeries(
          name: 'test',
          bytes: Uint8List(0),
          offsets: Uint32List(0),
        ),
      ).throws<ArgumentError>();

      check(
        () => ArrowStringSeries(
          name: 'test',
          bytes: Uint8List(0),
          offsets: Uint32List.fromList([1, 2]),
        ),
      ).throws<ArgumentError>();

      // Non-monotonic offsets
      check(
        () => ArrowStringSeries(
          name: 'test',
          bytes: Uint8List(5),
          offsets: Uint32List.fromList([0, 4, 2, 5]),
        ),
      ).throws<ArgumentError>();

      // Last offset exceeds bytes length
      check(
        () => ArrowStringSeries(
          name: 'test',
          bytes: Uint8List(3),
          offsets: Uint32List.fromList([0, 5]),
        ),
      ).throws<ArgumentError>();

      // ValidityMask length mismatch
      check(
        () => ArrowStringSeries(
          name: 'test',
          bytes: Uint8List(5),
          offsets: Uint32List.fromList([0, 5]),
          mask: ValidityMask(3),
        ),
      ).throws<ArgumentError>();

      // Filter mask length mismatch
      final validSeries = ArrowStringSeries.fromList('s', ['a', 'b']);
      check(() => validSeries.filter([true])).throws<ArgumentError>();
    });
  });
}
