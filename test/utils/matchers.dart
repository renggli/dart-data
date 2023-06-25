import 'package:data/matrix.dart';
import 'package:data/polynomial.dart';
import 'package:data/tensor.dart';
import 'package:data/vector.dart';
import 'package:more/number.dart';
import 'package:test/test.dart';

/// Returns [true], if assertions are enabled.
bool hasAssertionsEnabled() {
  try {
    assert(false);
    return false;
  } catch (exception) {
    return true;
  }
}

/// Returns a [Matcher] that asserts on a [AssertionError].
final isAssertionError = hasAssertionsEnabled()
    ? const TypeMatcher<AssertionError>()
    : throw UnsupportedError('Assertions are disabled');

/// Returns an [Matcher] that asserts on an [AssertionError] being thrown.
final throwsAssertionError = throwsA(isAssertionError);

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
            expected.map((each) => isCloseTo(each, epsilon: epsilon)).toList());
  } else if (expected is Map) {
    return allOf([
      hasLength(expected.length),
      ...expected.entries.map((each) =>
          containsPair(each.key, isCloseTo(each.value, epsilon: epsilon)))
    ]);
  } else if (expected is Vector) {
    return isA<Vector<Object?>>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.count, 'count', expected.count)
        .having((actual) => actual.iterable, 'iterable',
            isCloseTo(expected.iterable, epsilon: epsilon));
  } else if (expected is Matrix) {
    return isA<Matrix<Object?>>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.rowCount, 'rowCount', expected.rowCount)
        .having((actual) => actual.colCount, 'columnCount', expected.colCount)
        .having((actual) => actual.rows, 'rows',
            isCloseTo(expected.rows, epsilon: epsilon));
  } else if (expected is Polynomial) {
    return isA<Polynomial<Object?>>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.degree, 'degree', expected.degree)
        .having((actual) => actual.iterable, 'iterable',
            isCloseTo(expected.iterable, epsilon: epsilon));
  } else {
    throw ArgumentError.value(expected, 'expected');
  }
}

dynamic isTensor<T>({
  dynamic type = anything,
  dynamic data = anything,
  dynamic offset = 0,
  dynamic dimensions = anything,
  dynamic shape = anything,
  dynamic stride = anything,
  dynamic isContiguous = true,
  dynamic object = anything,
  dynamic format = anything,
}) =>
    isA<Tensor<T>>()
        .having((array) => array.type, 'type', type)
        .having((array) => array.data, 'data', data)
        .having((array) => array.offset, 'offset', offset)
        .having((array) => array.dimensions, 'dimensions', dimensions)
        .having((array) => array.shape, 'shape', shape)
        .having((array) => array.stride, 'stride', stride)
        .having((array) => array.isContiguous, 'isContiguous', isContiguous)
        .having((array) => array.toObject(), 'toObject', object)
        .having((array) => TensorPrinter<T>()(array), 'format', format);
