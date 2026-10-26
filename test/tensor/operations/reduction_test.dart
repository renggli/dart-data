import 'dart:math' as math;

import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import '../../acceleration/test_utils.dart';

void main() {
  group('reduction', () {
    accelerationTest('sum global and along axis', () {
      final t = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
        type: DataType.float64,
      );

      // Global sum (routes to Vforce.sum for contiguous Float64)
      final globalSum = t.sum();
      check(globalSum.shape).isEmpty();
      check(globalSum.getValue([])).isCloseTo(21.0, 1e-10);

      // keepDims = true
      final globalKeep = t.sum(keepDims: true);
      check(globalKeep.shape).deepEquals([1, 1]);
      check(globalKeep.getValue([0, 0])).isCloseTo(21.0, 1e-10);

      // Axis 0: reduce rows -> [3]
      final sumAxis0 = t.sum(axis: 0);
      check(sumAxis0.shape).deepEquals([3]);
      check(sumAxis0.getValue([0])).isCloseTo(5.0, 1e-10);
      check(sumAxis0.getValue([1])).isCloseTo(7.0, 1e-10);
      check(sumAxis0.getValue([2])).isCloseTo(9.0, 1e-10);

      // Axis 1: reduce columns -> [2]
      final sumAxis1 = t.sum(axis: 1);
      check(sumAxis1.shape).deepEquals([2]);
      check(sumAxis1.getValue([0])).isCloseTo(6.0, 1e-10);
      check(sumAxis1.getValue([1])).isCloseTo(15.0, 1e-10);
    });

    test('mean along axis and global', () {
      final t = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0, 5.0, 6.0],
        shape: [2, 3],
        type: DataType.float64,
      );

      final m = t.mean();
      check(m.shape).isEmpty();
      check(m.getValue([])).isCloseTo(3.5, 1e-10);

      final m0 = t.mean(axis: 0);
      check(m0.shape).deepEquals([3]);
      check(m0.getValue([0])).isCloseTo(2.5, 1e-10);
      check(m0.getValue([1])).isCloseTo(3.5, 1e-10);
      check(m0.getValue([2])).isCloseTo(4.5, 1e-10);
    });

    test('variance and std', () {
      final t = Tensor<double>.fromIterable([
        2.0,
        4.0,
        4.0,
        4.0,
        5.0,
        5.0,
        7.0,
        9.0,
      ], type: DataType.float64);

      // Population variance (ddof=0): mean is 5.0, sum of sq diff is 32.0, var = 4.0
      final vPop = t.variance(ddof: 0);
      check(vPop.getValue([])).isCloseTo(4.0, 1e-10);

      // Sample variance (ddof=1): 32.0 / 7 = 4.5714285714
      final vSamp = t.variance(ddof: 1);
      check(vSamp.getValue([])).isCloseTo(32.0 / 7.0, 1e-10);

      // std: sqrt(4.0) = 2.0
      final sPop = t.std(ddof: 0);
      check(sPop.getValue([])).isCloseTo(2.0, 1e-10);
    });

    test('min, max, argmin, argmax', () {
      final t = Tensor<double>.fromIterable(
        [5.0, 1.0, 9.0, 3.0, 8.0, 2.0],
        shape: [2, 3],
        type: DataType.float64,
      );

      check(t.min().getValue([])).equals(1.0);
      check(t.max().getValue([])).equals(9.0);

      final minAxis1 = t.min(axis: 1);
      check(minAxis1.shape).deepEquals([2]);
      check(minAxis1.getValue([0])).equals(1.0);
      check(minAxis1.getValue([1])).equals(2.0);

      final argminGlobal = t.argmin();
      check(argminGlobal.shape).isEmpty();
      check(argminGlobal.getValue([])).equals(1);

      final argmaxGlobal = t.argmax();
      check(argmaxGlobal.shape).isEmpty();
      check(argmaxGlobal.getValue([])).equals(2);

      final argminAxis1 = t.argmin(axis: 1);
      check(argminAxis1.shape).deepEquals([2]);
      check(argminAxis1.getValue([0])).equals(1);
      check(argminAxis1.getValue([1])).equals(2);
    });

    accelerationTest('norm L1, L2, Linf, and general Lp', () {
      final t64 = Tensor<double>.fromIterable([
        3.0,
        -4.0,
      ], type: DataType.float64);
      check(t64.norm(1)).isCloseTo(7.0, 1e-10);
      check(t64.norm(2)).isCloseTo(5.0, 1e-10);
      check(t64.norm(double.infinity)).isCloseTo(4.0, 1e-10);
      check(t64.norm(3)).isCloseTo(math.pow(27.0 + 64.0, 1.0 / 3.0), 1e-10);

      final t32 = Tensor<double>.fromIterable([
        3.0,
        -4.0,
      ], type: DataType.float32);
      check(t32.norm(2)).isCloseTo(5.0, 1e-5);
    });

    test('edge cases on empty tensors and target validation', () {
      final empty = Tensor<double>.filled(0.0, shape: [0]);
      check(empty.sum().getValue([])).equals(0.0);
      check(empty.norm(2)).equals(0.0);

      check(empty.mean).throws<StateError>();
      check(empty.min).throws<StateError>();
      check(empty.max).throws<StateError>();
      check(empty.argmin).throws<StateError>();
      check(empty.argmax).throws<StateError>();

      final empty2D = Tensor<double>.filled(0.0, shape: [2, 0]);
      check(() => empty2D.argmin(axis: 1)).throws<StateError>();
      check(() => empty2D.argmax(axis: 1)).throws<StateError>();
      check(() => empty2D.min(axis: 1)).throws<StateError>();
      check(() => empty2D.max(axis: 1)).throws<StateError>();

      final t = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
      );
      check(() => t.mean(axis: 5)).throws<RangeError>();
      check(() => t.mean(axis: -5)).throws<RangeError>();
      check(() => t.variance(axis: 5)).throws<RangeError>();
      check(() => t.variance(axis: -5)).throws<RangeError>();

      final badTarget = Tensor<double>.filled(0.0, shape: [3]);
      check(() => t.sum(target: badTarget)).throws<ArgumentError>();
      check(() => t.sum(axis: 0, target: badTarget)).throws<ArgumentError>();
      check(() => t.min(target: badTarget)).throws<ArgumentError>();
      check(() => t.max(axis: 0, target: badTarget)).throws<ArgumentError>();

      final fracTensor = Tensor<Fraction>.fromIterable([
        Fraction(1, 2),
        Fraction(3, 2),
      ]);
      check(fracTensor.mean().getValue([])).equals(1.0);
      check(fracTensor.variance().getValue([])).equals(0.25);

      // NaN propagation in min, max, argmin, argmax, and norm(infinity)
      final nanTensor = Tensor<double>.fromIterable(
        [1.0, double.nan, 3.0, 4.0],
        shape: [2, 2],
      );
      check(nanTensor.min().getValue([]).isNaN).isTrue();
      check(nanTensor.max().getValue([]).isNaN).isTrue();
      check(nanTensor.min(axis: 1).toFlatList()[0].isNaN).isTrue();
      check(nanTensor.max(axis: 1).toFlatList()[0].isNaN).isTrue();
      check(nanTensor.argmin().getValue([])).equals(1);
      check(nanTensor.argmax().getValue([])).equals(1);
      check(nanTensor.argmin(axis: 1).toFlatList()).deepEquals([1, 0]);
      check(nanTensor.argmax(axis: 1).toFlatList()).deepEquals([1, 1]);
      check(nanTensor.norm(double.infinity).isNaN).isTrue();

      // min/max along non-empty axis on [0, 3] tensor returns [0] tensor
      final emptyRows = Tensor<double>.filled(0.0, shape: [0, 3]);
      check(emptyRows.min(axis: 1).shape).deepEquals([0]);
      check(emptyRows.max(axis: 1).shape).deepEquals([0]);
      check(() => emptyRows.min(axis: 0)).throws<StateError>();
      check(() => emptyRows.max(axis: 0)).throws<StateError>();

      // Complex 2-norm, min with target and memory hazard, and out-of-range axis
      final cTensor = Tensor<Complex>.fromIterable([
        const Complex(3, 4),
      ], type: DataType.complex);
      check(cTensor.norm(2)).isCloseTo(5.0, 1e-12);
      final scalarTarget = Tensor<double>.filled(0.0, shape: []);
      check(t.min(target: scalarTarget)).equals(scalarTarget);
      check(() => t.min(axis: 5)).throws<RangeError>();
      final sharedTarget = Tensor<double>.internal(
        type: DataType.float64,
        layout: Layout(shape: [2]),
        data: t.data,
      );
      check(t.min(axis: 1, target: sharedTarget)).equals(sharedTarget);
    });
  });
}
