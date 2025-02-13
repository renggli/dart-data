import 'package:data/matrix.dart';
import 'package:data/polynomial.dart';
import 'package:data/tensor.dart';
import 'package:data/vector.dart';
import 'package:more/number.dart';
import 'package:test/test.dart';

/// Returns `true`, if assertions are enabled.
bool hasAssertionsEnabled() {
  try {
    assert(false);
    return false;
  } catch (exception) {
    return true;
  }
}

/// Returns a [Matcher] that asserts on an [RangeError] being thrown.
Matcher throwsRangeErrorWith({
  dynamic name = anything,
  dynamic start = anything,
  dynamic end = anything,
  dynamic message = anything,
}) => throwsA(
  isRangeError
      .having((e) => e.name, 'name', name)
      .having((e) => e.start, 'start', start)
      .having((e) => e.end, 'end', end)
      .having((e) => e.message, 'message', message),
);

/// Returns a [Matcher] that asserts on an [LayoutError] being thrown.
Matcher throwsLayoutErrorWith({
  dynamic name = anything,
  dynamic message = anything,
}) => throwsA(
  isA<LayoutError>()
      .having((e) => e.name, 'name', name)
      .having((e) => e.message, 'message', message),
);

/// Returns a [Matcher] that asserts various data structures on numeric similarity.
dynamic isCloseTo(dynamic expected, {num epsilon = 1.0e-5}) {
  if (expected is num) {
    return expected.isNaN
        ? isNaN
        : expected.isInfinite
        ? expected
        : closeTo(expected, epsilon);
  } else if (expected is CloseTo) {
    return predicate<CloseTo<Object?>>(
      (actual) => expected.closeTo(actual, epsilon),
      '$expected differs by $epsilon',
    );
  } else if (expected is Iterable) {
    return expected.isEmpty
        ? isEmpty
        : orderedEquals(
          expected.map((each) => isCloseTo(each, epsilon: epsilon)).toList(),
        );
  } else if (expected is Map) {
    return allOf([
      hasLength(expected.length),
      ...expected.entries.map(
        (each) =>
            containsPair(each.key, isCloseTo(each.value, epsilon: epsilon)),
      ),
    ]);
  } else if (expected is Vector) {
    return isA<Vector<Object?>>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.count, 'count', expected.count)
        .having(
          (actual) => actual.iterable,
          'iterable',
          isCloseTo(expected.iterable, epsilon: epsilon),
        );
  } else if (expected is Matrix) {
    return isA<Matrix<Object?>>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.rowCount, 'rowCount', expected.rowCount)
        .having((actual) => actual.colCount, 'columnCount', expected.colCount)
        .having(
          (actual) => actual.rows,
          'rows',
          isCloseTo(expected.rows, epsilon: epsilon),
        );
  } else if (expected is Polynomial) {
    return isA<Polynomial<Object?>>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.degree, 'degree', expected.degree)
        .having(
          (actual) => actual.iterable,
          'iterable',
          isCloseTo(expected.iterable, epsilon: epsilon),
        );
  } else {
    throw ArgumentError.value(expected, 'expected');
  }
}

dynamic isTensor<T>({
  dynamic type = anything,
  dynamic layout = anything,
  dynamic data = anything,
  dynamic object = anything,
  dynamic string = anything,
  dynamic format = anything,
}) => isA<Tensor<T>>()
    .having((tensor) => tensor.type, 'type', type)
    .having((tensor) => tensor.layout, 'layout', layout)
    .having((tensor) => tensor.data, 'data', data)
    .having((tensor) => tensor.toObject(), 'toObject', object)
    .having((tensor) => tensor.toString(), 'toString', string)
    .having((tensor) => TensorPrinter<T>()(tensor), 'format', format);

dynamic isLayout({
  dynamic rank = anything,
  dynamic length = anything,
  dynamic offset = anything,
  dynamic shape = anything,
  dynamic strides = anything,
  dynamic isContiguous = anything,
  dynamic string = anything,
  dynamic indices = anything,
  dynamic keys = anything,
}) => isA<Layout>()
    .having((layout) => layout.rank, 'rank', rank)
    .having((layout) => layout.length, 'length', length)
    .having((layout) => layout.offset, 'offset', offset)
    .having((layout) => layout.shape, 'shape', shape)
    .having((layout) => layout.strides, 'strides', strides)
    .having((layout) => layout.isContiguous, 'isContiguous', isContiguous)
    .having((layout) => layout.toString(), 'toString', string)
    .having((layout) => layout.indices, 'indices', indices)
    .having(
      (layout) =>
          layout.indices.map((offset) => layout.toIndex(layout.toKey(offset))),
      'indices (round-trip)',
      indices,
    )
    .having((layout) => layout.keys, 'keys', keys)
    .having(
      (layout) =>
          layout.keys.map((index) => layout.toKey(layout.toIndex(index))),
      'keys (round-trip)',
      keys,
    );
