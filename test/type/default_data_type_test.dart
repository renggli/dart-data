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
      check(DefaultDataType.isNative).equals(NativeBuffer.isActive);
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

    test('native frames scoping', () {
      check(DefaultDataType.isNative).equals(NativeBuffer.isActive);

      DefaultDataType.withDefault(() {
        check(DefaultDataType.isNative).isTrue();
      }, native: true);

      check(DefaultDataType.isNative).equals(NativeBuffer.isActive);

      DefaultDataType.withDefault(() {
        check(DefaultDataType.isNative).isFalse();
      }, native: false);

      check(DefaultDataType.isNative).equals(NativeBuffer.isActive);
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
      DefaultDataType.withDefault(
        () {
          check(DefaultDataType.float).equals(DataType.float32);
          check(DefaultDataType.isNative).isTrue();
          check(DefaultDataType.integer).equals(DataType.int32);

          DefaultDataType.withDefault(() {
            // Inherited from outer zone
            check(DefaultDataType.float).equals(DataType.float32);
            check(DefaultDataType.isNative).isTrue();
            // Overridden in inner zone
            check(DefaultDataType.integer).equals(DataType.int64);
          }, integer: DataType.int64);

          check(DefaultDataType.float).equals(DataType.float32);
          check(DefaultDataType.isNative).isTrue();
          check(DefaultDataType.integer).equals(DataType.int32);
        },
        float: DataType.float32,
        native: true,
      );
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

    test('Tensor, Matrix, and Vector respect native zone frames', () {
      DefaultDataType.withDefault(() {
        final t = Tensor.filled(1.0, shape: [2, 2]);
        check(NativeBuffer.find(t.data)).isNotNull();

        final m = Matrix.filled(2, 2, 1.0);
        check(NativeBuffer.find(m.tensor.data)).isNotNull();

        final v = Vector.filled(4, 1.0);
        check(NativeBuffer.find(v.tensor.data)).isNotNull();
      }, native: true);

      DefaultDataType.withDefault(() {
        final t = Tensor.filled(1.0, shape: [2, 2]);
        check(NativeBuffer.find(t.data)).isNull();

        final m = Matrix.filled(2, 2, 1.0);
        check(NativeBuffer.find(m.tensor.data)).isNull();

        final v = Vector.filled(4, 1.0);
        check(NativeBuffer.find(v.tensor.data)).isNull();
      }, native: false);
    });

    test('explicit native constructor parameter overrides zone defaults', () {
      DefaultDataType.withDefault(() {
        final tExplicitHeap = Tensor.filled(1.0, shape: [2, 2], native: false);
        check(NativeBuffer.find(tExplicitHeap.data)).isNull();

        final mExplicitHeap = Matrix.filled(2, 2, 1.0, native: false);
        check(NativeBuffer.find(mExplicitHeap.tensor.data)).isNull();

        final vExplicitHeap = Vector.filled(4, 1.0, native: false);
        check(NativeBuffer.find(vExplicitHeap.tensor.data)).isNull();
      }, native: true);

      DefaultDataType.withDefault(() {
        final tExplicitNative = Tensor.filled(1.0, shape: [2, 2], native: true);
        check(NativeBuffer.find(tExplicitNative.data)).isNotNull();

        final mExplicitNative = Matrix.filled(2, 2, 1.0, native: true);
        check(NativeBuffer.find(mExplicitNative.tensor.data)).isNotNull();

        final vExplicitNative = Vector.filled(4, 1.0, native: true);
        check(NativeBuffer.find(vExplicitNative.tensor.data)).isNotNull();
      }, native: false);
    });

    test(
      'all container constructor variants respect native zone and overrides',
      () {
        DefaultDataType.withDefault(() {
          // Tensor generate, fromIterable, fromObject
          final tGen = Tensor<double>.generate((k) => 1.0, shape: [2, 2]);
          check(NativeBuffer.find(tGen.data)).isNotNull();

          final tFromIter = Tensor<double>.fromIterable([1.0, 2.0, 3.0]);
          check(NativeBuffer.find(tFromIter.data)).isNotNull();

          final tFromObj = Tensor<double>.fromObject([
            [1.0, 2.0],
            [3.0, 4.0],
          ]);
          check(NativeBuffer.find(tFromObj.data)).isNotNull();

          // Matrix generate, identity, fromRows, fromColumns, diagonal
          final mGen = Matrix<double>.generate(2, 2, (r, c) => 1.0);
          check(NativeBuffer.find(mGen.tensor.data)).isNotNull();

          final mIdent = Matrix<double>.identity(3);
          check(NativeBuffer.find(mIdent.tensor.data)).isNotNull();

          final mRows = Matrix<double>.fromRows([
            [1.0, 2.0],
            [3.0, 4.0],
          ]);
          check(NativeBuffer.find(mRows.tensor.data)).isNotNull();

          final mCols = Matrix<double>.fromColumns([
            [1.0, 2.0],
            [3.0, 4.0],
          ]);
          check(NativeBuffer.find(mCols.tensor.data)).isNotNull();

          final diagVec = Vector<double>.filled(3, 2.0);
          final mDiag = Matrix<double>.diagonal(diagVec);
          check(NativeBuffer.find(mDiag.tensor.data)).isNotNull();

          // Vector generate, fromList, fromIterable
          final vGen = Vector<double>.generate(4, (i) => 1.0);
          check(NativeBuffer.find(vGen.tensor.data)).isNotNull();

          final vList = Vector<double>.fromList([1.0, 2.0]);
          check(NativeBuffer.find(vList.tensor.data)).isNotNull();

          final vIter = Vector<double>.fromIterable([1.0, 2.0]);
          check(NativeBuffer.find(vIter.tensor.data)).isNotNull();

          // Explicit overrides inside native: true zone
          final tGenHeap = Tensor<double>.generate(
            (k) => 1.0,
            shape: [2, 2],
            native: false,
          );
          check(NativeBuffer.find(tGenHeap.data)).isNull();

          final mRowsHeap = Matrix<double>.fromRows([
            [1.0, 2.0],
          ], native: false);
          check(NativeBuffer.find(mRowsHeap.tensor.data)).isNull();

          final vListHeap = Vector<double>.fromList([1.0, 2.0], native: false);
          check(NativeBuffer.find(vListHeap.tensor.data)).isNull();
        }, native: true);
      },
    );

    test('non-typed container allocations in native zone succeed safely', () {
      DefaultDataType.withDefault(() {
        final tStr = Tensor<String>.filled('hello', shape: [2, 2]);
        check(NativeBuffer.find(tStr.data)).isNull();
        check(tStr.getValue([0, 0])).equals('hello');

        final mStr = Matrix<String>.filled(2, 2, 'matrix');
        check(NativeBuffer.find(mStr.tensor.data)).isNull();
        check(mStr.get(0, 0)).equals('matrix');

        final vStr = Vector<String>.filled(3, 'vector');
        check(NativeBuffer.find(vStr.tensor.data)).isNull();
        check(vStr[0]).equals('vector');
      }, native: true);
    });

    test(
      'nested native zone frames: outer native, inner heap, restored outer',
      () {
        DefaultDataType.withDefault(() {
          check(DefaultDataType.isNative).isTrue();
          final t1 = Tensor.filled(1.0, shape: [2]);
          check(NativeBuffer.find(t1.data)).isNotNull();

          DefaultDataType.withDefault(() {
            check(DefaultDataType.isNative).isFalse();
            final t2 = Tensor.filled(1.0, shape: [2]);
            check(NativeBuffer.find(t2.data)).isNull();
          }, native: false);

          check(DefaultDataType.isNative).isTrue();
          final t3 = Tensor.filled(1.0, shape: [2]);
          check(NativeBuffer.find(t3.data)).isNotNull();
        }, native: true);
      },
    );

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
        await DefaultDataType.withDefault(
          () async {
            check(DefaultDataType.float).equals(DataType.float32);
            check(DefaultDataType.isNative).isTrue();

            await Future<void>.delayed(Duration.zero);

            check(DefaultDataType.float).equals(DataType.float32);
            check(DefaultDataType.isNative).isTrue();

            final tAsync = Tensor.filled(2.0, shape: [2, 2]);
            check(tAsync.type).equals(DataType.float32);
            check(NativeBuffer.find(tAsync.data)).isNotNull();
          },
          float: DataType.float32,
          native: true,
        );

        check(DefaultDataType.float).equals(DataType.float64);
        check(DefaultDataType.isNative).equals(NativeBuffer.isActive);
      },
    );

    test('copyList respects native zone and explicit native parameter', () {
      DefaultDataType.withDefault(() {
        final listNative = DataType.float64.copyList([1.0, 2.0, 3.0]);
        check(NativeBuffer.find(listNative)).isNotNull();

        final listExplicitHeap = DataType.float64.copyList([
          1.0,
          2.0,
          3.0,
        ], native: false);
        check(NativeBuffer.find(listExplicitHeap)).isNull();
      }, native: true);

      DefaultDataType.withDefault(() {
        final listHeap = DataType.float64.copyList([1.0, 2.0, 3.0]);
        check(NativeBuffer.find(listHeap)).isNull();

        final listExplicitNative = DataType.float64.copyList([
          1.0,
          2.0,
          3.0,
        ], native: true);
        check(NativeBuffer.find(listExplicitNative)).isNotNull();
      }, native: false);
    });
  });
}
