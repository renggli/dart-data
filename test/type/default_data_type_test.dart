import 'package:checks/checks.dart';
import 'package:data/linear.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

void main() {
  group('DefaultDataType root defaults', () {
    test('constants and getters', () {
      check(DefaultDataType.index).equals(DataType.uint32);
      check(DefaultDataType.integer).equals(DataType.int32);
      check(DefaultDataType.float).equals(DataType.float64);
    });

    test('attributes of default types', () {
      check(DefaultDataType.index.isInteger).isTrue();
      check(DefaultDataType.index.isSigned).isFalse();
      check(DefaultDataType.index.bits).equals(32);

      check(DefaultDataType.integer.isInteger).isTrue();
      check(DefaultDataType.integer.isSigned).isTrue();
      check(DefaultDataType.integer.bits).equals(32);

      check(DefaultDataType.float.isFloat).isTrue();
      check(DefaultDataType.float.bits).equals(64);
    });
  });

  group('withDefault zone scoping', () {
    test('floating-point precision scoping', () {
      check(DefaultDataType.float).equals(DataType.float64);

      DefaultDataType.withDefault(() {
        check(DefaultDataType.float).equals(DataType.float32);
      }, float: DataType.float32);

      check(DefaultDataType.float).equals(DataType.float64);
    });

    test('integer precision scoping', () {
      check(DefaultDataType.integer).equals(DataType.int32);

      DefaultDataType.withDefault(() {
        check(DefaultDataType.integer).equals(DataType.int64);
      }, integer: DataType.int64);

      check(DefaultDataType.integer).equals(DataType.int32);
    });

    test('closure invocation patterns', () {
      final res1 = DefaultDataType.withDefault(
        () => DefaultDataType.float,
        float: DataType.float32,
      );
      check(res1).equals(DataType.float32);

      final res2 = DefaultDataType.withDefault(
        () => DefaultDataType.integer,
        integer: DataType.int16,
      );
      check(res2).equals(DataType.int16);
    });
  });

  group('withDefault nested zone restoration', () {
    test('nested precision restoration', () {
      check(DefaultDataType.float).equals(DataType.float64);

      DefaultDataType.withDefault(() {
        check(DefaultDataType.float).equals(DataType.float32);

        DefaultDataType.withDefault(() {
          check(DefaultDataType.float).equals(DataType.float64);
        }, float: DataType.float64);

        check(DefaultDataType.float).equals(DataType.float32);
      }, float: DataType.float32);

      check(DefaultDataType.float).equals(DataType.float64);
    });

    test('nested multi-property inheritance and overrides', () {
      DefaultDataType.withDefault(() {
        check(DefaultDataType.float).equals(DataType.float32);
        check(DefaultDataType.integer).equals(DataType.int32);

        DefaultDataType.withDefault(() {
          // Inherited from outer zone
          check(DefaultDataType.float).equals(DataType.float32);
          // Overridden in inner zone
          check(DefaultDataType.integer).equals(DataType.int64);
        }, integer: DataType.int64);

        check(DefaultDataType.float).equals(DataType.float32);
        check(DefaultDataType.integer).equals(DataType.int32);
      }, float: DataType.float32);
    });

    test('exception unwinding restores zone', () {
      check(DefaultDataType.float).equals(DataType.float64);

      check(() {
        DefaultDataType.withDefault(() {
          check(DefaultDataType.float).equals(DataType.float32);
          throw StateError('Simulated failure');
        }, float: DataType.float32);
      }).throws<StateError>();

      check(DefaultDataType.float).equals(DataType.float64);
    });
  });

  group('Default container allocations', () {
    test('Tensor and Matrix respect zone float precision', () {
      DefaultDataType.withDefault(() {
        final t = Tensor.filled(1.0, shape: [2, 3]);
        check(t.type).equals(DataType.float32);

        final tGen = Tensor<double>.generate((k) => 1.0, shape: [2, 2]);
        check(tGen.type).equals(DataType.float32);

        final m = Matrix.filled(2, 3, 1.0);
        check(m.tensor.type).equals(DataType.float32);

        final mGen = Matrix<double>.generate(2, 2, (r, c) => 1.0);
        check(mGen.tensor.type).equals(DataType.float32);
      }, float: DataType.float32);

      final tRoot = Tensor.filled(1.0, shape: [2, 3]);
      check(tRoot.type).equals(DataType.float64);
    });

    test('Tensor and Matrix respect zone integer precision', () {
      DefaultDataType.withDefault(() {
        final t = Tensor.filled(1, shape: [2, 3]);
        check(t.type).equals(DataType.int64);

        final tGen = Tensor<int>.generate((k) => 1, shape: [2, 2]);
        check(tGen.type).equals(DataType.int64);

        final m = Matrix.filled(2, 3, 1);
        check(m.tensor.type).equals(DataType.int64);

        final mGen = Matrix<int>.generate(2, 2, (r, c) => 1);
        check(mGen.tensor.type).equals(DataType.int64);
      }, integer: DataType.int64);

      final tRoot = Tensor.filled(1, shape: [2, 3]);
      check(tRoot.type).equals(DataType.int32);
    });

    test('DataType resolution helpers respect zone defaults', () {
      check(DataType.fromType<double>()).equals(DataType.float64);
      check(DataType.fromType<int>()).equals(DataType.int32);
      check(DataType.fromInstance(1.0)).equals(DataType.float64);
      check(DataType.fromInstance(1)).equals(DataType.int32);
      check(DataType.fromIterable([1.0, 2.0])).equals(DataType.float64);
      check(DataType.fromIterable([1, 2])).equals(DataType.int32);

      DefaultDataType.withDefault(
        () {
          check(DataType.fromType<double>()).equals(DataType.float32);
          check(DataType.fromType<int>()).equals(DataType.int64);
          check(DataType.fromInstance(1.0)).equals(DataType.float32);
          check(DataType.fromInstance(1)).equals(DataType.int64);
          check(DataType.fromIterable([1.0, 2.0])).equals(DataType.float32);
          check(DataType.fromIterable([1, 2])).equals(DataType.int64);
        },
        float: DataType.float32,
        integer: DataType.int64,
      );
    });

    test(
      'async zone propagation across Future and microtask boundaries',
      () async {
        await DefaultDataType.withDefault(() async {
          check(DefaultDataType.float).equals(DataType.float32);

          await Future<void>.delayed(Duration.zero);

          check(DefaultDataType.float).equals(DataType.float32);

          final tAsync = Tensor.filled(2.0, shape: [2, 2]);
          check(tAsync.type).equals(DataType.float32);
        }, float: DataType.float32);

        check(DefaultDataType.float).equals(DataType.float64);
      },
    );
  });
}
