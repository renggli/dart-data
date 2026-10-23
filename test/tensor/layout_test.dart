import 'package:checks/checks.dart';
import 'package:data/tensor.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Layout', () {
    group('immutability', () {
      test('shape is unmodifiable', () {
        final layout = Layout(shape: [2, 3]);
        check(() => layout.shape[0] = 999).throws<UnsupportedError>();
      });

      test('strides is unmodifiable', () {
        final layout = Layout(shape: [2, 3]);
        check(() => layout.strides[0] = 999).throws<UnsupportedError>();
      });
    });

    group('transpose', () {
      test('default axes reverses rank', () {
        final layout = Layout(shape: [2, 3, 4]);
        final transposed = layout.transpose();
        check(transposed.shape).deepEquals([4, 3, 2]);
        check(transposed.strides).deepEquals([1, 4, 12]);
      });

      test('valid permutation succeeds', () {
        final layout = Layout(shape: [2, 3, 4]);
        final transposed = layout.transpose([1, 2, 0]);
        check(transposed.shape).deepEquals([3, 4, 2]);
        check(transposed.strides).deepEquals([4, 1, 12]);
      });

      test('throws on duplicate axes', () {
        final layout = Layout(shape: [2, 3]);
        check(() => layout.transpose([0, 0])).throws<ArgumentError>();
      });

      test('throws on out-of-range axis', () {
        final layout = Layout(shape: [2, 3]);
        check(() => layout.transpose([0, 2])).throws<ArgumentError>();
        check(() => layout.transpose([-1, 0])).throws<ArgumentError>();
      });

      test('throws on length mismatch', () {
        final layout = Layout(shape: [2, 3]);
        check(() => layout.transpose([0])).throws<ArgumentError>();
        check(() => layout.transpose([1, 0, 2])).throws<ArgumentError>();
      });
    });

    group('broadcast', () {
      test('broadcast with 0-extent and 1-extent', () {
        final layout0 = Layout(shape: [0]);
        final layout1 = Layout(shape: [1]);
        final (b0, b1) = layout0.broadcast(layout1);
        check(b0.shape).deepEquals([0]);
        check(b0.length).equals(0);
        check(b0.strides).deepEquals([1]);
        check(b1.shape).deepEquals([0]);
        check(b1.length).equals(0);
        check(b1.strides).deepEquals([0]);
      });

      test('broadcast with 1-extent and 0-extent (reverse)', () {
        final layout1 = Layout(shape: [1]);
        final layout0 = Layout(shape: [0]);
        final (b1, b0) = layout1.broadcast(layout0);
        check(b1.shape).deepEquals([0]);
        check(b1.length).equals(0);
        check(b1.strides).deepEquals([0]);
        check(b0.shape).deepEquals([0]);
        check(b0.length).equals(0);
        check(b0.strides).deepEquals([1]);
      });

      test('broadcast multi-dimensional with 0-extent', () {
        final layoutA = Layout(shape: [2, 0, 3]);
        final layoutB = Layout(shape: [1, 1, 3]);
        final (bA, bB) = layoutA.broadcast(layoutB);
        check(bA.shape).deepEquals([2, 0, 3]);
        check(bA.length).equals(0);
        check(bB.shape).deepEquals([2, 0, 3]);
        check(bB.length).equals(0);
        check(bB.strides).deepEquals([0, 0, 1]);
      });

      test('broadcast 0-extent with non-1 extent throws', () {
        final layout0 = Layout(shape: [0]);
        final layout2 = Layout(shape: [2]);
        check(() => layout0.broadcast(layout2)).throws<ArgumentError>();
        check(() => layout2.broadcast(layout0)).throws<ArgumentError>();
      });

      test('standard broadcasting', () {
        final layout1 = Layout(shape: [1, 3]);
        final layout2 = Layout(shape: [4, 1]);
        final (b1, b2) = layout1.broadcast(layout2);
        check(b1.shape).deepEquals([4, 3]);
        check(b1.strides).deepEquals([0, 1]);
        check(b2.shape).deepEquals([4, 3]);
        check(b2.strides).deepEquals([1, 0]);
      });
    });

    group('tensor operation with 0-extent broadcasting', () {
      test('addition with 0-extent and 1-extent', () {
        final t0 = Tensor<int>.filled(0, shape: [0]);
        final t1 = Tensor<int>.filled(5, shape: [1]);
        final result = t0 + t1;
        check(result.shape).deepEquals([0]);
        check(result.length).equals(0);
      });
    });
  });
}
