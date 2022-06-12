import 'package:data/vector.dart';
import 'package:test/expect.dart';

dynamic isCloseTo(dynamic expected, {double epsilon = 1.0e-5}) {
  if (expected is num) {
    return expected.isNaN
        ? isNaN
        : expected.isInfinite
            ? expected
            : closeTo(expected, epsilon);
  } else if (expected is List) {
    return containsAllInOrder(
        expected.map((each) => isCloseTo(each, epsilon: epsilon)));
  } else if (expected is Map) {
    return allOf([
      hasLength(expected.length),
      ...expected.entries.map((each) =>
          containsPair(each.key, isCloseTo(each.value, epsilon: epsilon)))
    ]);
  } else if (expected is Vector) {
    return isA<Vector>().having((v) => v.count, 'count', expected.count).having(
        (v) => v.iterable,
        'values',
        isCloseTo(expected.iterable, epsilon: epsilon));
  } else {
    throw ArgumentError.value(expected, 'expected');
  }
}
