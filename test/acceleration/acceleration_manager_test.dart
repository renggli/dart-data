import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/stats.dart';
import 'package:data/tensor.dart';
import 'package:data/type.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('AccelerationManager status', () {
    test('hardware availability probe', () {
      check(AccelerationManager.isBlasAvailable).isA<bool>();
      check(AccelerationManager.isAccelerated).equals(
        AccelerationManager.isBlasAvailable ||
            AccelerationManager.isVdspAvailable,
      );
    });
  });

  group('SimdEngine (Float32x4)', () {
    test('SIMD add, sub, mul, dot', () {
      final a = Float32List.fromList([1.0, 2.0, 3.0, 4.0, 5.0]);
      final b = Float32List.fromList([10.0, 20.0, 30.0, 40.0, 50.0]);
      final out = Float32List(5);

      SimdEngine.addFloat32(a, b, out);
      check(out).deepEquals([11.0, 22.0, 33.0, 44.0, 55.0]);

      SimdEngine.subFloat32(b, a, out);
      check(out).deepEquals([9.0, 18.0, 27.0, 36.0, 45.0]);

      SimdEngine.mulFloat32(a, b, out);
      check(out).deepEquals([10.0, 40.0, 90.0, 160.0, 250.0]);

      final dot = SimdEngine.dotFloat32(a, b);
      check(dot).equals(10.0 + 40.0 + 90.0 + 160.0 + 250.0);
    });
  });

  group('NativeBuffer and native-allocated containers', () {
    test('NativeBuffer float64 allocation, typed view, and dispose', () {
      final buffer = NativeBuffer<double>(10, type: DataType.float64);
      check(buffer.length).equals(10);
      check(buffer.isDisposed).isFalse();
      check(buffer.data).isA<Float64List>();
      check(buffer.byteLength).equals(80);

      // Read/write via typed data list
      for (var i = 0; i < 10; i++) {
        buffer.data[i] = i * 2.5;
      }
      for (var i = 0; i < 10; i++) {
        check(buffer.data[i]).equals(i * 2.5);
      }

      // Expando lookup succeeds
      final found = NativeBuffer.find(buffer.data);
      check(found).isNotNull();

      buffer.dispose();
      check(buffer.isDisposed).isTrue();
      check(NativeBuffer.find(buffer.data)).isNull();
    });

    test('NativeBuffer float32 allocation respects DataType.float32', () {
      final buffer = NativeBuffer<double>(10, type: DataType.float32);
      check(buffer.length).equals(10);
      check(buffer.isDisposed).isFalse();
      check(buffer.data).isA<Float32List>();
      check(buffer.byteLength).equals(40);

      buffer.data[0] = 3.14;
      check(buffer.data[0]).isCloseTo(3.14, 1e-5);

      buffer.dispose();
      check(buffer.isDisposed).isTrue();
    });

    test('NativeBuffer int32, int64, and uint8 allocation', () {
      final buf32 = NativeBuffer<int>(8, type: DataType.int32);
      check(buf32.data).isA<Int32List>();
      check(buf32.byteLength).equals(32);
      buf32.dispose();

      final buf64 = NativeBuffer<int>(8, type: DataType.int64);
      check(buf64.data).isA<Int64List>();
      check(buf64.byteLength).equals(64);
      buf64.dispose();

      final buf8 = NativeBuffer<int>(8, type: DataType.uint8);
      check(buf8.data).isA<Uint8List>();
      check(buf8.byteLength).equals(8);
      buf8.dispose();
    });

    test('Tensor, Matrix, and Vector native zero-copy BLAS', () {
      final tNativeA = Tensor<double>.filled(0.0, shape: [2, 2], native: true);
      final tNativeB = Tensor<double>.filled(0.0, shape: [2, 2], native: true);
      tNativeA.setValue([0, 0], 1.0);
      tNativeA.setValue([0, 1], 2.0);
      tNativeA.setValue([1, 0], 3.0);
      tNativeA.setValue([1, 1], 4.0);

      tNativeB.setValue([0, 0], 5.0);
      tNativeB.setValue([0, 1], 6.0);
      tNativeB.setValue([1, 0], 7.0);
      tNativeB.setValue([1, 1], 8.0);

      final tNativeC = tNativeA.matmul(tNativeB);
      check(tNativeC.toFlatList()).deepEquals([19.0, 22.0, 43.0, 50.0]);

      final mNative = Matrix<double>.filled(2, 2, 0.0, native: true);
      mNative.set(0, 0, 2.0);
      mNative.set(0, 1, 1.0);
      mNative.set(1, 0, 1.0);
      mNative.set(1, 1, 3.0);
      check(mNative.get(0, 0)).equals(2.0);
      check(mNative.get(1, 1)).equals(3.0);

      final vNative = Vector<double>.filled(3, 0.0, native: true);
      vNative[0] = 10.0;
      vNative[1] = 20.0;
      vNative[2] = 30.0;
      check(vNative.length).equals(3);
      check(vNative[1]).equals(20.0);
    });

    test('automatic native buffer transparent instantiation on supported platforms', () {
      check(NativeBuffer.isSupported).isTrue();
      check(NativeBuffer.isActive).isTrue();

      // Standard Vector.filled and fromList use native buffer automatically
      final vFilled = Vector<double>.filled(5, 0.0);
      check(NativeBuffer.find(vFilled.tensor.data)).isNotNull();

      final vFromList = Vector<double>.fromList([1.0, 2.0, 3.0]);
      check(NativeBuffer.find(vFromList.tensor.data)).isNotNull();

      // Standard Matrix.filled and fromRows use native buffer automatically
      final mFilled = Matrix<double>.filled(2, 2, 0.0);
      check(NativeBuffer.find(mFilled.tensor.data)).isNotNull();

      final mFromRows = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ]);
      check(NativeBuffer.find(mFromRows.tensor.data)).isNotNull();

      // Matrix multiplication result automatically backed by native buffer
      final mResult = mFromRows * mFromRows;
      check(NativeBuffer.find(mResult.tensor.data)).isNotNull();
      check(mResult.get(0, 0)).equals(7.0);
      check(mResult.get(0, 1)).equals(10.0);
      check(mResult.get(1, 0)).equals(15.0);
      check(mResult.get(1, 1)).equals(22.0);

      // Dot product on standard vectors operates zero-copy
      final dotVal = vFromList.dot(vFromList);
      check(dotVal).equals(14.0);
    });

    test('NativeBuffer.isEnabled toggle falls back cleanly to heap', () {
      NativeBuffer.isEnabled = false;
      check(NativeBuffer.isActive).isFalse();

      final vHeap = Vector<double>.filled(4, 1.0);
      check(NativeBuffer.find(vHeap.tensor.data)).isNull();

      NativeBuffer.isEnabled = true;
      check(NativeBuffer.isActive).isTrue();

      final vNative = Vector<double>.filled(4, 1.0);
      check(NativeBuffer.find(vNative.tensor.data)).isNotNull();
    });

    test('NativeBuffer safe zero-length allocation', () {
      final buf0 = NativeBuffer<double>(0, type: DataType.float64);
      check(buf0.length).equals(0);
      check(buf0.data).isEmpty();
      buf0.dispose();
      check(buf0.isDisposed).isTrue();
    });

    test('All integer types support NativeBuffer allocation', () {
      for (final type in [
        DataType.int8,
        DataType.int16,
        DataType.int32,
        DataType.int64,
        DataType.uint8,
        DataType.uint16,
        DataType.uint32,
        DataType.uint64,
      ]) {
        final list = type.newList(4);
        check(NativeBuffer.find(list)).isNotNull();
      }
    });

    test('NativeBuffer.find polymorphic resolution across types', () {
      final buf = NativeBuffer<double>(5, type: DataType.float64);
      // Finding on NativeBuffer itself
      check(NativeBuffer.find(buf)).equals(buf);

      // Finding on Tensor
      final tensor = Tensor<double>.internal(
        type: DataType.float64,
        layout: Layout(shape: [5]),
        data: buf.data,
      );
      check(NativeBuffer.find(tensor)).equals(buf);

      // Finding on Vector and Matrix
      final vec = Vector<double>.filled(3, 1.0);
      check(NativeBuffer.find(vec)).isNotNull();

      final mat = Matrix<double>.filled(2, 2, 1.0);
      check(NativeBuffer.find(mat)).isNotNull();

      // Finding on null or non-buffer
      check(NativeBuffer.find(null)).isNull();
      check(NativeBuffer.find(123)).isNull();
      check(NativeBuffer.find('abc')).isNull();
    });

    test('NativeBuffer typed integer pointer getters', () {
      final i32Buf = NativeBuffer<int>(4, type: DataType.int32);
      check(i32Buf.asInt32Pointer).isNotNull();

      final i64Buf = NativeBuffer<int>(4, type: DataType.int64);
      check(i64Buf.asInt64Pointer).isNotNull();

      final u8Buf = NativeBuffer<int>(4, type: DataType.uint8);
      check(u8Buf.asUint8Pointer).isNotNull();

      i32Buf.dispose();
      check(i32Buf.asInt32Pointer).isNull();
    });

    test(
      'NativeBuffer rejects negative lengths and unsupported data types',
      () {
        check(() => NativeBuffer<double>(-1, type: DataType.float64))
            .throws<RangeError>();

        check(() => NativeBuffer<String>(5, type: DataType.string))
            .throws<ArgumentError>();
      },
    );

    test('Offset subview pointer calculations and dgels zero-copy', () {
      final matA = Matrix<double>.fromRows([
        [1.0, 1.0],
        [1.0, 2.0],
        [1.0, 3.0],
      ]);
      final vecB = Vector<double>.fromList([2.0, 3.0, 4.0]);

      // Both inputs automatically backed by NativeBuffer
      check(NativeBuffer.find(matA)).isNotNull();
      check(NativeBuffer.find(vecB)).isNotNull();

      final solution = leastSquares(matA, vecB);
      check(solution.length).equals(2);
      check(solution[0]).isCloseTo(1.0, 1e-6);
      check(solution[1]).isCloseTo(1.0, 1e-6);

      // Verify subview with non-zero offsetInBytes computes correctly via BLAS
      final buf = NativeBuffer<double>(10, type: DataType.float64);
      for (var i = 0; i < 10; i++) {
        buf.data[i] = i * 1.0;
      }
      final rawList = buf.data as Float64List;
      final subList = rawList.buffer.asFloat64List(24, 5); // starts at index 3
      NativeBuffer.register(subList, buf);

      final ones = Float64List.fromList([1.0, 1.0, 1.0, 1.0, 1.0]);
      final dotVal = AccelerationManager.ddot(
        n: 5,
        x: subList,
        incX: 1,
        y: ones,
        incY: 1,
      );
      check(dotVal).equals(25.0);
    });
  }, testOn: 'vm');

  group('Basic BLAS operations', () {
    accelerationTest('dgemm and sgemm', () {
      // 2x2 double matrix multiply
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final cBuffer = Float64List(4);

      final successD = AccelerationManager.dgemm(
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: cBuffer,
        ldc: 2,
      );
      check(successD).isTrue();
      check(cBuffer[0]).equals(19.0);
      check(cBuffer[1]).equals(22.0);
      check(cBuffer[2]).equals(43.0);
      check(cBuffer[3]).equals(50.0);

      // 2x2 float matrix multiply
      final a32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b32 = Float32List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c32 = Float32List(4);

      final successS = AccelerationManager.sgemm(
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a32,
        lda: 2,
        b: b32,
        ldb: 2,
        beta: 0.0,
        c: c32,
        ldc: 2,
      );
      check(successS).isTrue();
      check(c32[0]).equals(19.0);
      check(c32[1]).equals(22.0);
      check(c32[2]).equals(43.0);
      check(c32[3]).equals(50.0);
    });

    accelerationTest('ddot and dnrm2', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0]);
      final y = Float64List.fromList([4.0, 5.0, 6.0]);

      final dotVal = AccelerationManager.ddot(n: 3, x: x, y: y);
      check(dotVal).isNotNull();
      check(dotVal!).equals(32.0);

      final normVal = AccelerationManager.dnrm2(n: 3, x: x);
      check(normVal).isNotNull();
      check(normVal!).isCloseTo(3.741657, 1e-5);
    });
  });

  group('Transposed layout handling in matmul', () {
    test('transposed A matrix (transA)', () {
      final aOrig = Tensor<double>.fromIterable(
        [1.0, 3.0, 2.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final aTrans = aOrig.transpose(); // shape [2, 2], values [1, 2, 3, 4]
      final b = Tensor<double>.fromIterable(
        [5.0, 6.0, 7.0, 8.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      final result1 = aTrans.matmul(b);
      check(result1.toFlatList()).deepEquals([19.0, 22.0, 43.0, 50.0]);
    });

    test('transposed B matrix (transB)', () {
      final a = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final bOrig = Tensor<double>.fromIterable(
        [5.0, 7.0, 6.0, 8.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final bTrans = bOrig.transpose(); // shape [2, 2], values [5, 6, 7, 8]

      final result2 = a.matmul(bTrans);
      check(result2.toFlatList()).deepEquals([19.0, 22.0, 43.0, 50.0]);
    });

    test('both A and B transposed (transA and transB)', () {
      final aOrig = Tensor<double>.fromIterable(
        [1.0, 3.0, 2.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final aTrans = aOrig.transpose();

      final bOrig = Tensor<double>.fromIterable(
        [5.0, 7.0, 6.0, 8.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final bTrans = bOrig.transpose();

      final result3 = aTrans.matmul(bTrans);
      check(result3.toFlatList()).deepEquals([19.0, 22.0, 43.0, 50.0]);
    });

    accelerationTest('hardware vs fallback parity on matmul', () {
      final t1 = Tensor<double>.fromIterable(
        [1.0, 2.0, 3.0, 4.0],
        shape: [2, 2],
        type: DataType.float64,
      );
      final t2 = Tensor<double>.fromIterable(
        [5.0, 6.0, 7.0, 8.0],
        shape: [2, 2],
        type: DataType.float64,
      );

      final res = t1.matmul(t2);
      check(res.toFlatList()).deepEquals([19.0, 22.0, 43.0, 50.0]);
    });
  });

  group('Symmetric Rank-k update (dsyrk)', () {
    test('Matrix.syrk computes A * A^T and A^T * A', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);

      // A * A^T of size [2 x 2]
      final aAt = a.syrk(transpose: false);
      check(aAt.rowCount).equals(2);
      check(aAt.colCount).equals(2);
      check(aAt.get(0, 0)).equals(14.0); // 1 + 4 + 9
      check(aAt.get(0, 1)).equals(32.0); // 4 + 10 + 18
      check(aAt.get(1, 0)).equals(32.0);
      check(aAt.get(1, 1)).equals(77.0); // 16 + 25 + 36

      // A^T * A of size [3 x 3]
      final atA = a.syrk(transpose: true);
      check(atA.rowCount).equals(3);
      check(atA.colCount).equals(3);
      check(atA.get(0, 0)).equals(17.0); // 1 + 16
      check(atA.get(1, 1)).equals(29.0); // 4 + 25
      check(atA.get(2, 2)).equals(45.0); // 9 + 36
      check(atA.get(0, 1)).equals(22.0); // 2 + 20
      check(atA.get(1, 0)).equals(22.0);
    });

    test('Matrix.syrk natively accelerates already-transposed matrix', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);
      final at = a.transpose(); // shape [3, 2], column-major strides [1, 3]

      // at * at^T should equal A^T * A
      final atAtt = at.syrk(transpose: false);
      check(atAtt.rowCount).equals(3);
      check(atAtt.colCount).equals(3);
      check(atAtt.get(0, 0)).equals(17.0);
      check(atAtt.get(1, 1)).equals(29.0);
      check(atAtt.get(2, 2)).equals(45.0);

      // at^T * at should equal A * A^T
      final attAt = at.syrk(transpose: true);
      check(attAt.rowCount).equals(2);
      check(attAt.colCount).equals(2);
      check(attAt.get(0, 0)).equals(14.0);
      check(attAt.get(1, 1)).equals(77.0);
    });

    test('Matrix.syrk with Float32List', () {
      final a32 = Matrix<double>.fromRows([
        [1.0, 2.0],
        [3.0, 4.0],
      ], type: DataType.float32);

      final res = a32.syrk(transpose: false);
      check(res.get(0, 0)).equals(5.0);
      check(res.get(0, 1)).equals(11.0);
      check(res.get(1, 1)).equals(25.0);
    });

    accelerationTest('covarianceMatrix uses dsyrk acceleration', () {
      final data = Matrix<double>.fromRows([
        [1.0, 10.0],
        [2.0, 20.0],
        [3.0, 30.0],
      ], type: DataType.float64);

      final cov = covarianceMatrix(data);

      check(cov.get(0, 0)).equals(1.0);
      check(cov.get(1, 1)).equals(100.0);
      check(cov.get(0, 1)).isCloseTo(10.0, 1e-12);
      check(cov.get(1, 0)).isCloseTo(10.0, 1e-12);
    });
  });

  group('BLAS Level 1 and 2 routines', () {
    test('Matrix.apply and applyTranspose (dgemv & sgemv)', () {
      final a = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float64);
      final x = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final y = a.apply(x);
      // [1*1 + 2*2 + 3*3, 4*1 + 5*2 + 6*3] = [14, 32]
      check(y.toList()).deepEquals([14.0, 32.0]);

      final yt = Vector<double>.fromList([2.0, 1.0]);
      final xt = a.applyTranspose(yt);
      // [1*2 + 4*1, 2*2 + 5*1, 3*2 + 6*1] = [6, 9, 12]
      check(xt.toList()).deepEquals([6.0, 9.0, 12.0]);

      // Float32 variant
      final a32 = Matrix<double>.fromRows([
        [1.0, 2.0, 3.0],
        [4.0, 5.0, 6.0],
      ], type: DataType.float32);
      final x32 = Vector<double>.fromList([
        1.0,
        2.0,
        3.0,
      ], type: DataType.float32);
      final y32 = a32.apply(x32);
      check(y32.toList()).deepEquals([14.0, 32.0]);
    });

    test('Vector.dot and Vector.norm (ddot, dnrm2, and SIMD)', () {
      final x = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final y = Vector<double>.fromList([4.0, 5.0, 6.0]);
      check(x.dot(y)).equals(32.0);
      // sqrt(1 + 4 + 9) = sqrt(14) ~ 3.74165738677
      check(x.norm()).isCloseTo(3.74165738677, 1e-7);
    });

    test('Vector in-place addScaled (daxpy) and scaleInPlace (dscal)', () {
      final vector = Vector<double>.fromList([1.0, 2.0, 3.0]);
      final other = Vector<double>.fromList([10.0, 20.0, 30.0]);

      vector.addScaled(other, 0.5);
      check(vector.toList()).deepEquals([6.0, 12.0, 18.0]);

      vector.scaleInPlace(2.0);
      check(vector.toList()).deepEquals([12.0, 24.0, 36.0]);
    });

    accelerationTest('AccelerationManager.dsyr2 rank-2 update', () {
      final a = Float64List.fromList([1.0, 0.0, 0.0, 1.0]);
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List.fromList([3.0, 4.0]);

      final ok = AccelerationManager.dsyr2(
        n: 2,
        alpha: 1.0,
        x: x,
        incX: 1,
        y: y,
        incY: 1,
        a: a,
        lda: 2,
      );
      check(ok).isTrue();

      // a[0,0] = 1 + (1*3 + 3*1) = 7
      check(a[0]).equals(7.0);
      // a[0,1] = 0 + (1*4 + 3*2) = 10
      check(a[1]).equals(10.0);
      // a[1,1] = 1 + (2*4 + 4*2) = 17
      check(a[3]).equals(17.0);
    });
  });

  group('LAPACK solvers and Least Squares', () {
    accelerationTest(
      'dgesv solves linear system with hardware and pure Dart fallback parity',
      () {
        // 2x2 system:
        // [2, 1] [x0] = [4]
        // [1, 3] [x1] = [7]
        // solution: x = [1, 2]
        final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
        final b = Float64List.fromList([4.0, 7.0]);

        final success = AccelerationManager.dgesv(
          n: 2,
          nrhs: 1,
          a: a,
          lda: 2,
          b: b,
          ldb: 1,
        );
        check(success).isTrue();
        check(b[0]).isCloseTo(1.0, 1e-9);
        check(b[1]).isCloseTo(2.0, 1e-9);
      },
    );

    accelerationTest(
      'dgesv gracefully fails on singular matrix without corrupting b',
      () {
        final aSingular = Float64List.fromList([1.0, 2.0, 2.0, 4.0]);
        final b = Float64List.fromList([3.0, 6.0]);

        final ok = AccelerationManager.dgesv(
          n: 2,
          nrhs: 1,
          a: aSingular,
          lda: 2,
          b: b,
          ldb: 1,
        );
        check(ok).isFalse();
        check(b[0]).equals(3.0);
        check(b[1]).equals(6.0);
      },
    );

    accelerationTest('dpotrf Cholesky factorization parity', () {
      // Symmetric positive definite matrix:
      // [4, 12, -16]
      // [12, 37, -43]
      // [-16, -43, 98]
      // L = [[2, 0, 0], [6, 1, 0], [-8, 5, 3]]
      final a = Float64List.fromList([
        4.0,
        12.0,
        -16.0,
        12.0,
        37.0,
        -43.0,
        -16.0,
        -43.0,
        98.0,
      ]);

      final ok = AccelerationManager.dpotrf(
        uplo: cblasLower,
        n: 3,
        a: a,
        lda: 3,
      );
      check(ok).isTrue();

      check(a[0]).isCloseTo(2.0, 1e-9);
      check(a[3]).isCloseTo(6.0, 1e-9);
      check(a[4]).isCloseTo(1.0, 1e-9);
      check(a[6]).isCloseTo(-8.0, 1e-9);
      check(a[7]).isCloseTo(5.0, 1e-9);
      check(a[8]).isCloseTo(3.0, 1e-9);
    });

    accelerationTest('leastSquares solves overdetermined system via dgels', () {
      // 3 data points: (1, 6), (2, 5), (3, 7)
      // Fitting y = intercept + slope * x
      final a = Matrix<double>.fromRows([
        [1.0, 1.0],
        [1.0, 2.0],
        [1.0, 3.0],
      ], type: DataType.float64);
      final b = Vector<double>.fromList([6.0, 5.0, 7.0]);

      final sol = leastSquares(a, b);

      check(sol[0]).isCloseTo(5.0, 1e-9);
      check(sol[1]).isCloseTo(0.5, 1e-9);
    });

    test('fitNonlinear parameter estimation', () {
      // Fit y = a * exp(b * x) with true params a = 2.5, b = 1.3
      final xs = [0.1, 0.2, 0.4, 0.7, 1.0];
      final ys = xs
          .map((x) => 2.5 * 1.3 * x + 1.0)
          .toList(); // linear surrogate

      final resultParams = fitNonlinear(
        residualFunction: (Vector<double> params) => Vector<double>.generate(
          xs.length,
          (i) => (params[0] * xs[i] + params[1]) - ys[i],
        ),
        initialParams: Vector<double>.fromList([1.0, 0.5]),
        tolerance: 1e-5,
      );

      check(resultParams[0]).isCloseTo(3.25, 1e-3);
      check(resultParams[1]).isCloseTo(1.0, 1e-3);
    });
  });

  group('AccelerationManager comprehensive fallback & float32 coverage', () {
    test('CblasFfi getters and flags', () {
      check(AccelerationManager.isAccelerated).equals(
        AccelerationManager.isBlasAvailable ||
            AccelerationManager.isVdspAvailable,
      );
      final blas = loadBlas();
      check(blas.isAvailable).equals(AccelerationManager.isBlasAvailable);
      check(blas.hasDgeqrf).isA<bool>();
      check(blas.hasDgesvd).isA<bool>();
    });

    accelerationTest(
      'dgemm and sgemm with transA, transB, offsets, and non-zero beta',
      () {
        // Double precision: C = 2.0 * A^T * B^T + 0.5 * C
        // A is 2x3 (transposed to 3x2), B is 3x2 (transposed to 2x3), C is 3x3
        // Memory has padding offsets
        final a = Float64List.fromList([99.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
        final b = Float64List.fromList([99.0, 7.0, 8.0, 9.0, 10.0, 11.0, 12.0]);
        final cBuffer = Float64List(10);
        cBuffer[1] = 1.0;
        cBuffer[2] = 2.0;
        cBuffer[3] = 3.0;
        cBuffer[4] = 4.0;
        cBuffer[5] = 5.0;
        cBuffer[6] = 6.0;
        cBuffer[7] = 7.0;
        cBuffer[8] = 8.0;
        cBuffer[9] = 9.0;

        final res = AccelerationManager.dgemm(
          transA: cblasTrans,
          transB: cblasTrans,
          m: 3,
          n: 3,
          k: 2,
          alpha: 2.0,
          a: a,
          aOffset: 1,
          lda: 3,
          b: b,
          bOffset: 1,
          ldb: 2,
          beta: 0.5,
          c: cBuffer,
          cOffset: 1,
          ldc: 3,
        );
        check(res).isTrue();

        // Single precision sgemm
        final as = Float32List.fromList([99.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
        final bs = Float32List.fromList([
          99.0,
          7.0,
          8.0,
          9.0,
          10.0,
          11.0,
          12.0,
        ]);
        final cs = Float32List(10);
        cs[1] = 1.0;
        cs[2] = 2.0;
        cs[3] = 3.0;
        cs[4] = 4.0;
        cs[5] = 5.0;
        cs[6] = 6.0;
        cs[7] = 7.0;
        cs[8] = 8.0;
        cs[9] = 9.0;

        final resS = AccelerationManager.sgemm(
          transA: cblasTrans,
          transB: cblasTrans,
          m: 3,
          n: 3,
          k: 2,
          alpha: 2.0,
          a: as,
          aOffset: 1,
          lda: 3,
          b: bs,
          bOffset: 1,
          ldb: 2,
          beta: 0.5,
          c: cs,
          cOffset: 1,
          ldc: 3,
        );
        check(resS).isTrue();
      },
    );

    accelerationTest(
      'dgemv and sgemv with transA, offset, and non-zero beta',
      () {
        // y = 2.0 * A^T * x + 0.5 * y
        // A is 2x3, x is length 2, y is length 3
        final a = Float64List.fromList([0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
        final x = Float64List.fromList([0.0, 1.0, 2.0]);
        final y = Float64List.fromList([0.0, 10.0, 20.0, 30.0]);

        final res = AccelerationManager.dgemv(
          transA: cblasTrans,
          m: 2,
          n: 3,
          alpha: 2.0,
          a: a,
          aOffset: 1,
          lda: 3,
          x: x,
          xOffset: 1,
          incX: 1,
          beta: 0.5,
          y: y,
          yOffset: 1,
          incY: 1,
        );
        check(res).isTrue();

        final as = Float32List.fromList([0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]);
        final xs = Float32List.fromList([0.0, 1.0, 2.0]);
        final ys = Float32List.fromList([0.0, 10.0, 20.0, 30.0]);

        final resS = AccelerationManager.sgemv(
          transA: cblasTrans,
          m: 2,
          n: 3,
          alpha: 2.0,
          a: as,
          aOffset: 1,
          lda: 3,
          x: xs,
          xOffset: 1,
          incX: 1,
          beta: 0.5,
          y: ys,
          yOffset: 1,
          incY: 1,
        );
        check(resS).isTrue();
      },
    );

    accelerationTest('ddot, sdot, dnrm2, snrm2, dasum, daxpy, saxpy, dscal, sscal with strides and offsets', () {
      final x = Float64List.fromList([0.0, 1.0, 0.0, 2.0, 0.0, 3.0]);
      final y = Float64List.fromList([0.0, 4.0, 0.0, 5.0, 0.0, 6.0]);

      final dot = AccelerationManager.ddot(
        n: 3,
        x: x,
        xOffset: 1,
        incX: 2,
        y: y,
        yOffset: 1,
        incY: 2,
      );
      check(dot).equals(1.0 * 4.0 + 2.0 * 5.0 + 3.0 * 6.0);

      final xs = Float32List.fromList([0.0, 1.0, 0.0, 2.0, 0.0, 3.0]);
      final ys = Float32List.fromList([0.0, 4.0, 0.0, 5.0, 0.0, 6.0]);
      final sdot = AccelerationManager.sdot(
        n: 3,
        x: xs,
        xOffset: 1,
        incX: 2,
        y: ys,
        yOffset: 1,
        incY: 2,
      );
      check(sdot).equals(1.0 * 4.0 + 2.0 * 5.0 + 3.0 * 6.0);

      final nrm = AccelerationManager.dnrm2(n: 3, x: x, xOffset: 1, incX: 2);
      check(nrm!).isCloseTo(3.74165738677, 1e-6);

      final snrm = AccelerationManager.snrm2(n: 3, x: xs, xOffset: 1, incX: 2);
      check(snrm!).isCloseTo(3.74165738677, 1e-4);

      AccelerationManager.daxpy(
        n: 3,
        alpha: 2.0,
        x: x,
        xOffset: 1,
        incX: 2,
        y: y,
        yOffset: 1,
        incY: 2,
      );
      check(y[1]).equals(4.0 + 2.0 * 1.0);
      check(y[3]).equals(5.0 + 2.0 * 2.0);
      check(y[5]).equals(6.0 + 2.0 * 3.0);

      AccelerationManager.saxpy(
        n: 3,
        alpha: 2.0,
        x: xs,
        xOffset: 1,
        incX: 2,
        y: ys,
        yOffset: 1,
        incY: 2,
      );
      check(ys[1]).equals(4.0 + 2.0 * 1.0);

      AccelerationManager.dscal(n: 3, alpha: 3.0, x: x, xOffset: 1, incX: 2);
      check(x[1]).equals(3.0);
      check(x[3]).equals(6.0);
      check(x[5]).equals(9.0);

      AccelerationManager.sscal(n: 3, alpha: 3.0, x: xs, xOffset: 1, incX: 2);
      check(xs[1]).equals(3.0);
    });

    accelerationTest(
      'dsyrk, ssyrk, dsyr2, ssyr2 with lower and upper triangular updates',
      () {
        // dsyrk upper and lower
        for (final uplo in [cblasUpper, cblasLower]) {
          final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]); // 2x2
          final cBuffer = Float64List(4);
          final res = AccelerationManager.dsyrk(
            uplo: uplo,
            trans: cblasNoTrans,
            n: 2,
            k: 2,
            alpha: 1.0,
            a: a,
            lda: 2,
            beta: 0.0,
            c: cBuffer,
            ldc: 2,
          );
          check(res).isTrue();

          // With trans = cblasTrans
          final resTrans = AccelerationManager.dsyrk(
            uplo: uplo,
            trans: cblasTrans,
            n: 2,
            k: 2,
            alpha: 1.0,
            a: a,
            lda: 2,
            beta: 0.5,
            c: cBuffer,
            ldc: 2,
          );
          check(resTrans).isTrue();

          // Single precision ssyrk
          final as = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
          final cs = Float32List(4);
          final resS = AccelerationManager.ssyrk(
            uplo: uplo,
            trans: cblasNoTrans,
            n: 2,
            k: 2,
            alpha: 1.0,
            a: as,
            lda: 2,
            beta: 0.0,
            c: cs,
            ldc: 2,
          );
          check(resS).isTrue();
        }

        // dsyr2 and ssyr2
        for (final uplo in [cblasUpper, cblasLower]) {
          final x = Float64List.fromList([0.0, 1.0, 2.0]);
          final y = Float64List.fromList([0.0, 3.0, 4.0]);
          final a = Float64List(4);
          final res = AccelerationManager.dsyr2(
            uplo: uplo,
            n: 2,
            alpha: 1.0,
            x: x,
            xOffset: 1,
            y: y,
            yOffset: 1,
            a: a,
            lda: 2,
          );
          check(res).isTrue();

          final xs = Float32List.fromList([0.0, 1.0, 2.0]);
          final ys = Float32List.fromList([0.0, 3.0, 4.0]);
          final as = Float32List(4);
          final resS = AccelerationManager.ssyr2(
            uplo: uplo,
            n: 2,
            alpha: 1.0,
            x: xs,
            xOffset: 1,
            y: ys,
            yOffset: 1,
            a: as,
            lda: 2,
          );
          check(resS).isTrue();
        }
      },
    );

    accelerationTest('dpotrf fallback and precision with lower triangular', () {
      // Symmetric positive definite 2x2: [[4, 2], [2, 5]]
      final a = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
      final ok = AccelerationManager.dpotrf(
        uplo: cblasLower,
        n: 2,
        a: a,
        lda: 2,
      );
      check(ok).isTrue();
      check(a[0]).isCloseTo(2.0, 1e-6); // sqrt(4) = 2
      check(a[2]).isCloseTo(1.0, 1e-6); // 2/2 = 1
      check(a[3]).isCloseTo(2.0, 1e-6); // sqrt(5 - 1^2) = 2
    });

    accelerationTest('dgesv and dgels fallback and edge cases', () {
      // Singular matrix fails gracefully
      final aSingular = Float64List.fromList([1.0, 2.0, 2.0, 4.0]);
      final bSingular = Float64List.fromList([3.0, 6.0]);
      final okSingular = AccelerationManager.dgesv(
        n: 2,
        nrhs: 1,
        a: aSingular,
        lda: 2,
        b: bSingular,
        ldb: 1,
      );
      check(okSingular).isFalse();

      // dgels 2x2 identity system
      final aGels = Float64List.fromList([2.0, 0.0, 0.0, 2.0]);
      final bGels = Float64List.fromList([4.0, 6.0]);
      final okGels = AccelerationManager.dgels(
        m: 2,
        n: 2,
        nrhs: 1,
        a: aGels,
        lda: 2,
        b: bGels,
        ldb: 1,
      );
      check(okGels).isTrue();
      check(bGels[0]).isCloseTo(2.0, 1e-6);
      check(bGels[1]).isCloseTo(3.0, 1e-6);
    });

    accelerationTest('hardware fallback remaining branches: no-transpose, SIMD dot/nrm2, upper dpotrf', () {
      // dgemm no-trans fallback
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final cBuffer = Float64List(4);
      final okGemm = AccelerationManager.dgemm(
        transA: cblasNoTrans,
        transB: cblasNoTrans,
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: cBuffer,
        ldc: 2,
      );
      check(okGemm).isTrue();
      check(cBuffer[0]).equals(1.0 * 5.0 + 2.0 * 7.0);

      // dgemv no-trans fallback
      final x = Float64List.fromList([2.0, 3.0]);
      final y = Float64List(2);
      final okGemv = AccelerationManager.dgemv(
        transA: cblasNoTrans,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        incX: 1,
        beta: 0.0,
        y: y,
        incY: 1,
      );
      check(okGemv).isTrue();
      check(y[0]).equals(1.0 * 2.0 + 2.0 * 3.0);

      // sdot SIMD fast path (offset 0, inc 1, length == n)
      final xs = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final ys = Float32List.fromList([5.0, 6.0, 7.0, 8.0]);
      final sdotSimd = AccelerationManager.sdot(n: 4, x: xs, y: ys);
      check(sdotSimd).equals(1.0 * 5.0 + 2.0 * 6.0 + 3.0 * 7.0 + 4.0 * 8.0);

      // snrm2 SIMD fast path
      final snrmSimd = AccelerationManager.snrm2(n: 4, x: xs);
      check(snrmSimd!).isCloseTo(math.sqrt(1 + 4 + 9 + 16), 1e-5);

      // dpotrf upper triangular fallback
      final aSym = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
      final okUpper = AccelerationManager.dpotrf(
        uplo: cblasUpper,
        n: 2,
        a: aSym,
        lda: 2,
      );
      check(okUpper).isTrue();
    });

    accelerationTest(
      'native zero-copy float32 and heap-allocated dgesv/dgels acceleration',
      () {
        // Native float32 buffers
        final bufX = NativeBuffer<double>(4, type: DataType.float32);
        final bufY = NativeBuffer<double>(4, type: DataType.float32);
        try {
          final x = bufX.data as Float32List;
          final y = bufY.data as Float32List;
          for (var i = 0; i < 4; i++) {
            x[i] = (i + 1).toDouble();
            y[i] = (i + 2).toDouble();
          }

          final dot = AccelerationManager.sdot(n: 4, x: x, y: y);
          check(dot!).isCloseTo(1 * 2 + 2 * 3 + 3 * 4 + 4 * 5, 1e-4);

          final nrm = AccelerationManager.snrm2(n: 4, x: x);
          check(nrm!).isCloseTo(math.sqrt(1 + 4 + 9 + 16), 1e-4);

          AccelerationManager.saxpy(n: 4, alpha: 2.0, x: x, y: y);
          check(y[0]).isCloseTo(2.0 + 2.0 * 1.0, 1e-4);

          AccelerationManager.sscal(n: 4, alpha: 3.0, x: x);
          check(x[0]).isCloseTo(3.0, 1e-4);

          // Heap-allocated dgesv (copy-to-arena path)
          final aHeap = Float64List.fromList([3.0, 1.0, 1.0, 2.0]);
          final bHeap = Float64List.fromList([9.0, 8.0]);
          final okSolve = AccelerationManager.dgesv(
            n: 2,
            nrhs: 1,
            a: aHeap,
            lda: 2,
            b: bHeap,
            ldb: 1,
          );
          check(okSolve).isTrue();
          check(bHeap[0]).isCloseTo(2.0, 1e-9);
          check(bHeap[1]).isCloseTo(3.0, 1e-9);

          // Heap-allocated dgels (copy-to-arena path)
          final aGelsHeap = Float64List.fromList([
            1.0,
            1.0,
            1.0,
            2.0,
            1.0,
            3.0,
          ]);
          final bGelsHeap = Float64List.fromList([6.0, 5.0, 7.0]);
          final okGels = AccelerationManager.dgels(
            m: 3,
            n: 2,
            nrhs: 1,
            a: aGelsHeap,
            lda: 2,
            b: bGelsHeap,
            ldb: 1,
          );
          check(okGels).isTrue();
          check(bGelsHeap[0]).isCloseTo(5.0, 1e-6);
          check(bGelsHeap[1]).isCloseTo(0.5, 1e-6);
        } finally {
          bufX.dispose();
          bufY.dispose();
        }
      },
    );

    test(
      'SimdEngine constructor & NativeBuffer sgemm, ssyrk, dsyr2, ssyr2 paths',
      () {
        const simd = SimdEngine();
        check(simd).isNotNull();

        // Native sgemm
        final bufA = NativeBuffer<double>(4, type: DataType.float32);
        final bufB = NativeBuffer<double>(4, type: DataType.float32);
        final bufC = NativeBuffer<double>(4, type: DataType.float32);
        bufA.data.setRange(0, 4, [1.0, 2.0, 3.0, 4.0]);
        bufB.data.setRange(0, 4, [5.0, 6.0, 7.0, 8.0]);
        final okSgemm = AccelerationManager.sgemm(
          m: 2,
          n: 2,
          k: 2,
          alpha: 1.0,
          a: bufA.data as Float32List,
          lda: 2,
          b: bufB.data as Float32List,
          ldb: 2,
          beta: 0.0,
          c: bufC.data as Float32List,
          ldc: 2,
        );
        check(okSgemm).isTrue();
        check(bufC.data[0]).isCloseTo(19.0, 1e-4);

        // Heap ssyrk with beta != 0.0
        final aHeapFloat = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
        final cHeapFloat = Float32List.fromList([1.0, 0.0, 0.0, 1.0]);
        final okSsyrk = AccelerationManager.ssyrk(
          n: 2,
          k: 2,
          alpha: 1.0,
          a: aHeapFloat,
          lda: 2,
          beta: 2.0,
          c: cHeapFloat,
          ldc: 2,
        );
        check(okSsyrk).isTrue();

        // Native dsyr2
        final bufX64 = NativeBuffer<double>(2, type: DataType.float64);
        final bufY64 = NativeBuffer<double>(2, type: DataType.float64);
        final bufA64 = NativeBuffer<double>(4, type: DataType.float64);
        bufX64.data.setRange(0, 2, [1.0, 2.0]);
        bufY64.data.setRange(0, 2, [3.0, 4.0]);
        final okDsyr2 = AccelerationManager.dsyr2(
          n: 2,
          alpha: 1.0,
          x: bufX64.data as Float64List,
          incX: 1,
          y: bufY64.data as Float64List,
          incY: 1,
          a: bufA64.data as Float64List,
          lda: 2,
        );
        check(okDsyr2).isTrue();

        // Native ssyr2
        final bufX32 = NativeBuffer<double>(2, type: DataType.float32);
        final bufY32 = NativeBuffer<double>(2, type: DataType.float32);
        final bufA32 = NativeBuffer<double>(4, type: DataType.float32);
        bufX32.data.setRange(0, 2, [1.0, 2.0]);
        bufY32.data.setRange(0, 2, [3.0, 4.0]);
        final okSsyr2 = AccelerationManager.ssyr2(
          n: 2,
          alpha: 1.0,
          x: bufX32.data as Float32List,
          incX: 1,
          y: bufY32.data as Float32List,
          incY: 1,
          a: bufA32.data as Float32List,
          lda: 2,
        );
        check(okSsyr2).isTrue();

        bufA.dispose();
        bufB.dispose();
        bufC.dispose();
        bufX64.dispose();
        bufY64.dispose();
        bufA64.dispose();
        bufX32.dispose();
        bufY32.dispose();
        bufA32.dispose();
      },
    );

    accelerationTest('AccelerationManager transposition branches', () {
      // dgemm with transA == cblasNoTrans and transB == cblasNoTrans
      final a = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b = Float64List.fromList([5.0, 6.0, 7.0, 8.0]);
      final cBuffer = Float64List(4);
      AccelerationManager.dgemm(
        transA: cblasNoTrans,
        transB: cblasNoTrans,
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        b: b,
        ldb: 2,
        beta: 0.0,
        c: cBuffer,
        ldc: 2,
      );
      check(cBuffer[0]).isCloseTo(19.0, 1e-9);

      // dgemm with transA == cblasTrans and transB == cblasTrans
      final aT = Float64List.fromList([1.0, 3.0, 2.0, 4.0]);
      final bT = Float64List.fromList([5.0, 7.0, 6.0, 8.0]);
      final cT = Float64List(4);
      AccelerationManager.dgemm(
        transA: cblasTrans,
        transB: cblasTrans,
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: aT,
        lda: 2,
        b: bT,
        ldb: 2,
        beta: 0.0,
        c: cT,
        ldc: 2,
      );
      check(cT[0]).isCloseTo(19.0, 1e-9);

      // dgemv with transA == cblasNoTrans
      final x = Float64List.fromList([1.0, 2.0]);
      final y = Float64List(2);
      AccelerationManager.dgemv(
        transA: cblasNoTrans,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        incX: 1,
        beta: 0.0,
        y: y,
        incY: 1,
      );
      check(y[0]).isCloseTo(5.0, 1e-9);
      check(y[1]).isCloseTo(11.0, 1e-9);

      // dgemv with transA == cblasTrans
      final yT = Float64List(2);
      AccelerationManager.dgemv(
        transA: cblasTrans,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        x: x,
        incX: 1,
        beta: 0.0,
        y: yT,
        incY: 1,
      );
      check(yT[0]).isCloseTo(7.0, 1e-9);
      check(yT[1]).isCloseTo(10.0, 1e-9);

      // dsyrk with trans == cblasTrans
      final cSyrk = Float64List(4);
      AccelerationManager.dsyrk(
        trans: cblasTrans,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a,
        lda: 2,
        beta: 0.0,
        c: cSyrk,
        ldc: 2,
      );
      // a^T * a: [1*1 + 3*3, 1*2 + 3*4; 2*1 + 4*3, 2*2 + 4*4] = [10, 14; 14,
      // 20]
      check(cSyrk[0]).isCloseTo(10.0, 1e-9);
      check(cSyrk[1]).isCloseTo(14.0, 1e-9);
      check(cSyrk[3]).isCloseTo(20.0, 1e-9);

      // sgemm with transA == cblasNoTrans and transB == cblasNoTrans
      final a32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final b32 = Float32List.fromList([5.0, 6.0, 7.0, 8.0]);
      final c32 = Float32List(4);
      AccelerationManager.sgemm(
        transA: cblasNoTrans,
        transB: cblasNoTrans,
        m: 2,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a32,
        lda: 2,
        b: b32,
        ldb: 2,
        beta: 0.0,
        c: c32,
        ldc: 2,
      );
      check(c32[0]).isCloseTo(19.0, 1e-5);

      // sgemv with transA == cblasNoTrans
      final x32 = Float32List.fromList([1.0, 2.0]);
      final y32 = Float32List(2);
      AccelerationManager.sgemv(
        transA: cblasNoTrans,
        m: 2,
        n: 2,
        alpha: 1.0,
        a: a32,
        lda: 2,
        x: x32,
        incX: 1,
        beta: 0.0,
        y: y32,
        incY: 1,
      );
      check(y32[0]).isCloseTo(5.0, 1e-5);

      // ssyrk with trans == cblasTrans
      final cSyrk32 = Float32List(4);
      AccelerationManager.ssyrk(
        trans: cblasTrans,
        n: 2,
        k: 2,
        alpha: 1.0,
        a: a32,
        lda: 2,
        beta: 0.0,
        c: cSyrk32,
        ldc: 2,
      );
      check(cSyrk32[0]).isCloseTo(10.0, 1e-5);
    });
  });
}
