import 'package:data/data.dart';
import 'package:test/test.dart';

import 'matchers.dart';

void verifySamples<T>(
  DataType<T> dataType, {
  required UnaryFunction<T> actual,
  required Vector<T> xs,
  required Vector<T> ys,
}) {
  for (var i = 0; i < xs.count; i++) {
    expect(actual(xs[i]), isCloseTo(ys[i]), reason: 'f(${xs[i]})');
  }
}

void verifyFunction<T>(
  DataType<T> dataType, {
  required UnaryFunction<T> actual,
  required UnaryFunction<T> expected,
  required Iterable<T> range,
}) {
  final xs = Vector<T>.fromIterable(dataType, range);
  final ys = Vector<T>.fromIterable(dataType, range.map((x) => expected(x)));
  verifySamples<T>(dataType, actual: actual, xs: xs, ys: ys);
}
