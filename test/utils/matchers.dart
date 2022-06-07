import 'package:test/expect.dart';

dynamic isCloseTo(dynamic expected, {double epsilon = 1.0e-5}) {
  if (expected is num) {
    return expected.isInfinite
        ? expected
        : expected.isNaN
            ? isNaN
            : closeTo(expected, epsilon);
  } else if (expected is List) {
    return containsAllInOrder(
        expected.map((each) => isCloseTo(each, epsilon: epsilon)));
  } else {
    throw ArgumentError.value(expected, 'expected');
  }
}
