import 'package:data/matrix.dart';
import 'package:data/polynomial.dart';
import 'package:data/vector.dart';
import 'package:more/number.dart';
import 'package:test/test.dart';

dynamic isCloseTo(dynamic expected, {num epsilon = 1.0e-5}) {
  if (expected is num) {
    return expected.isNaN
        ? isNaN
        : expected.isInfinite
            ? expected
            : closeTo(expected, epsilon);
  } else if (expected is CloseTo) {
    return predicate<CloseTo>(
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
    return isA<Vector>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.count, 'count', expected.count)
        .having((actual) => actual.iterable, 'iterable',
            isCloseTo(expected.iterable, epsilon: epsilon));
  } else if (expected is Matrix) {
    return isA<Matrix>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.rowCount, 'rowCount', expected.rowCount)
        .having((actual) => actual.colCount, 'columnCount', expected.colCount)
        .having((actual) => actual.rows, 'rows',
            isCloseTo(expected.rows, epsilon: epsilon));
  } else if (expected is Polynomial) {
    return isA<Polynomial>()
        .having((actual) => actual.dataType, 'dataType', expected.dataType)
        .having((actual) => actual.degree, 'degree', expected.degree)
        .having((actual) => actual.iterable, 'iterable',
            isCloseTo(expected.iterable, epsilon: epsilon));
  } else {
    throw ArgumentError.value(expected, 'expected');
  }
}
