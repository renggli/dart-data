import 'package:checks/checks.dart';
import 'package:data/src/numeric/interpolation/search.dart';
import 'package:test/test.dart';

void main() {
  group('binarySearchInterval', () {
    final xs = [0.0, 1.0, 2.0, 4.0, 8.0];

    test('finds correct interval for interior points', () {
      check(binarySearchInterval(xs, 0.5)).equals(0);
      check(binarySearchInterval(xs, 1.0)).equals(1);
      check(binarySearchInterval(xs, 1.5)).equals(1);
      check(binarySearchInterval(xs, 2.0)).equals(2);
      check(binarySearchInterval(xs, 3.0)).equals(2);
      check(binarySearchInterval(xs, 4.0)).equals(3);
      check(binarySearchInterval(xs, 7.9)).equals(3);
    });

    test('handles boundary and out-of-range points', () {
      check(binarySearchInterval(xs, 0.0)).equals(0);
      check(binarySearchInterval(xs, -5.0)).equals(0);
      check(binarySearchInterval(xs, 8.0)).equals(3);
      check(binarySearchInterval(xs, 100.0)).equals(3);
    });

    test('two-element list', () {
      final two = [10.0, 20.0];
      check(binarySearchInterval(two, 5.0)).equals(0);
      check(binarySearchInterval(two, 10.0)).equals(0);
      check(binarySearchInterval(two, 15.0)).equals(0);
      check(binarySearchInterval(two, 20.0)).equals(0);
      check(binarySearchInterval(two, 25.0)).equals(0);
    });
  });
}
