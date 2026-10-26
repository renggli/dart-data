import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/dataframe.dart';
import 'package:data/type.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('ValidityMask.slice', () {
    test('slices valid and null bits across byte boundaries', () {
      final mask = ValidityMask(24);
      // Set nulls at indices 2, 7, 8, 15, 16, 23
      mask.setNull(2);
      mask.setNull(7);
      mask.setNull(8);
      mask.setNull(15);
      mask.setNull(16);
      mask.setNull(23);

      check(mask.nullCount).equals(6);

      // Slice crossing multiple byte boundaries: indices [5, 20) -> length 15
      // Expected nulls in slice:
      // index 7 (slice index 2)
      // index 8 (slice index 3)
      // index 15 (slice index 10)
      // index 16 (slice index 11)
      final slice = mask.slice(5, 20);
      check(slice.length).equals(15);
      check(slice.nullCount).equals(4);
      check(slice.isNull(0)).isFalse(); // orig 5
      check(slice.isNull(1)).isFalse(); // orig 6
      check(slice.isNull(2)).isTrue(); // orig 7
      check(slice.isNull(3)).isTrue(); // orig 8
      check(slice.isNull(4)).isFalse(); // orig 9
      check(slice.isNull(10)).isTrue(); // orig 15
      check(slice.isNull(11)).isTrue(); // orig 16
      check(slice.isNull(14)).isFalse(); // orig 19

      // Empty slice
      final emptySlice = mask.slice(10, 10);
      check(emptySlice.length).equals(0);
      check(emptySlice.nullCount).equals(0);

      // Error cases
      check(() => mask.slice(-1, 5)).throws<RangeError>();
      check(() => mask.slice(5, 4)).throws<RangeError>();
      check(() => mask.slice(0, 25)).throws<RangeError>();
    });
  });

  group('TypedSeries zero-allocation filter', () {
    test('preserves unboxed TypedData buffer type and filters correctly', () {
      final originalList = [1.5, 2.5, 3.5, 4.5, 5.5];
      final series = TypedSeries<double>.fromList('f64', originalList);

      check(series.data).isA<Float64List>();
      check(series.dataType).equals(DataType.float64);
      check(series.hasNulls).isFalse();
      check(series.nullCount).equals(0);

      final filterMask = [true, false, true, false, true];
      final filtered = series.filter(filterMask);

      check(filtered).isA<TypedSeries<double>>();
      final typedFiltered = filtered as TypedSeries<double>;
      check(typedFiltered.data).isA<Float64List>();
      check(typedFiltered.length).equals(3);
      check(typedFiltered.hasNulls).isFalse();
      check(typedFiltered.nullCount).equals(0);
      check(typedFiltered.toList()).deepEquals([1.5, 3.5, 5.5]);
    });

    test('preserves Int32List and handles null bitmask propagation', () {
      final originalList = <int?>[10, null, 30, null, 50, 60];
      final series = TypedSeries<int>.fromList('i32', originalList);

      check(series.data).isA<Int32List>();
      check(series.hasNulls).isTrue();
      check(series.nullCount).equals(2);

      // Filter keeping indices 0, 1, 2, 4 (three non-nulls, one null)
      final filterMask = [true, true, true, false, true, false];
      final filtered = series.filter(filterMask) as TypedSeries<int>;

      check(filtered.data).isA<Int32List>();
      check(filtered.length).equals(4);
      check(filtered.hasNulls).isTrue();
      check(filtered.nullCount).equals(1);
      check(filtered.toList()).deepEquals([10, null, 30, 50]);
      check(filtered.isNull(1)).isTrue();
      check(filtered.isNull(0)).isFalse();
    });

    test('filters when all rows match or no rows match', () {
      final series = TypedSeries<double>.fromList('values', [1.0, 2.0, 3.0]);

      final allTrue = series.filter([true, true, true]) as TypedSeries<double>;
      check(allTrue.length).equals(3);
      check(allTrue.toList()).deepEquals([1.0, 2.0, 3.0]);

      final allFalse =
          series.filter([false, false, false]) as TypedSeries<double>;
      check(allFalse.length).equals(0);
      check(allFalse.toList()).deepEquals([]);
    });

    test('throws ArgumentError on filter mask length mismatch', () {
      final series = TypedSeries<int>.fromList('col', [1, 2, 3]);
      check(() => series.filter([true, false])).throws<ArgumentError>();
      check(() => series.filter([true, false, true, false]))
          .throws<ArgumentError>();
    });
  });

  group('TypedSeries zero-allocation slice', () {
    test('slices unboxed buffer directly and slices bitmask', () {
      final series = TypedSeries<double>.fromList('floats', [
        10.0,
        20.0,
        null,
        40.0,
        50.0,
        null,
        70.0,
      ]);

      check(series.data).isA<Float64List>();
      check(series.nullCount).equals(2);

      // Slice indices [1, 5) -> [20.0, null, 40.0, 50.0]
      final sliced = series.slice(1, 5) as TypedSeries<double>;
      check(sliced.data).isA<Float64List>();
      check(sliced.length).equals(4);
      check(sliced.nullCount).equals(1);
      check(sliced.isNull(1)).isTrue();
      check(sliced.toList()).deepEquals([20.0, null, 40.0, 50.0]);

      // Slice with no nulls in target range drops mask
      final cleanSlice = series.slice(0, 2) as TypedSeries<double>;
      check(cleanSlice.hasNulls).isFalse();
      check(cleanSlice.nullCount).equals(0);
      check(cleanSlice.toList()).deepEquals([10.0, 20.0]);

      // Clamping bounds
      final clampedSlice = series.slice(-5, 100) as TypedSeries<double>;
      check(clampedSlice.length).equals(series.length);
    });
  });

  group('TypedSeries scalar indexing', () {
    test('getNonNull and getUnchecked scalar access', () {
      final series = TypedSeries<double>.fromList('data', [100.0, null, 300.0]);

      check(series.getNonNull(0)).equals(100.0);
      check(series.getUnchecked(0)).equals(100.0);
      check(series.getUnchecked(2)).equals(300.0);

      // getNonNull throws on null
      check(() => series.getNonNull(1)).throws<StateError>();

      // Non-null series
      final nonNullSeries = TypedSeries<int>.fromList('ids', [10, 20, 30]);
      check(nonNullSeries.hasNulls).isFalse();
      check(nonNullSeries.getNonNull(0)).equals(10);
      check(nonNullSeries.getNonNull(1)).equals(20);
      check(nonNullSeries.getNonNull(2)).equals(30);
      check(nonNullSeries.getUnchecked(1)).equals(20);
    });

    test('Series.getNonNull on generic series', () {
      final strSeries = Series<String>.fromList('names', [
        'Alice',
        null,
        'Bob',
      ]);
      check(strSeries.hasNulls).isTrue();
      check(strSeries.getNonNull(0)).equals('Alice');
      check(strSeries.getNonNull(2)).equals('Bob');
      check(() => strSeries.getNonNull(1)).throws<StateError>();
    });
  });

  group('Series tabular transformations', () {
    test('dropNulls filters out null entries', () {
      final s = Series<int>.fromList('x', [1, null, 2, null, 3]);
      final clean = s.dropNulls();
      check(clean.toList()).deepEquals([1, 2, 3]);
      check(clean.hasNulls).isFalse();

      final noNulls = Series<int>.fromList('y', [1, 2, 3]);
      check(noNulls.dropNulls().toList()).deepEquals([1, 2, 3]);
    });

    test('fillNull replaces null entries', () {
      final s = Series<int>.fromList('x', [1, null, 2, null, 3]);
      final filled = s.fillNull(0);
      check(filled.toList()).deepEquals([1, 0, 2, 0, 3]);

      final noNulls = Series<int>.fromList('y', [1, 2, 3]);
      check(identical(noNulls.fillNull(99), noNulls)).isTrue();
    });

    test('map transforms non-null elements preserving null positions', () {
      final s = Series<int>.fromList('x', [1, null, 3]);
      final mapped = s.map((v) => 'num_$v', name: 'strings');
      check(mapped.name).equals('strings');
      check(mapped.toList()).deepEquals(['num_1', null, 'num_3']);
    });

    test('unique returns distinct elements preserving order of appearance', () {
      final s = Series<int>.fromList('x', [3, null, 1, 3, null, 2, 1]);
      final u = s.unique();
      check(u.toList()).deepEquals([3, null, 1, 2]);

      final allUnique = Series<String>.fromList('words', ['a', 'b', 'c']);
      check(allUnique.unique().toList()).deepEquals(['a', 'b', 'c']);
    });

    test('valueCounts aggregates and sorts descending', () {
      final s = Series<String>.fromList('cat', [
        'apple',
        'banana',
        'apple',
        'orange',
        'apple',
        'banana',
      ]);
      final counts = s.valueCounts();
      check(counts.columnNames).deepEquals(['cat', 'count']);
      check(counts.rowCount).equals(3);
      check(counts['cat'].toList()).deepEquals(['apple', 'banana', 'orange']);
      check(counts['count'].toList()).deepEquals([3, 2, 1]);
    });

    test('validates mask length, isNull bounds, and NaN in min/max', () {
      check(
        () => TypedSeries<double>(
          name: 'x',
          data: [1.0, 2.0],
          dataType: DataType.float64,
          mask: ValidityMask(3),
        ),
      ).throws<ArgumentError>();

      final s = Series<double>.fromList('f', [1.0, 2.0]);
      check(() => s.isNull(-1)).throws<RangeError>();
      check(() => s.isNull(2)).throws<RangeError>();

      final sNan = Series<double>.fromList('nan', [2.0, double.nan, 1.0]);
      check(sNan.min!.isNaN).isTrue();
      check(sNan.max!.isNaN).isTrue();
    });
  });
}
