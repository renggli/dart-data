import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/src/acceleration/blas/cblas.dart';
import 'package:data/src/acceleration/fallback/pure_dart_blas1.dart';
import 'package:data/src/acceleration/fallback/pure_dart_blas2.dart';
import 'package:data/src/acceleration/fallback/pure_dart_blas3.dart';
import 'package:data/src/acceleration/fallback/pure_dart_vforce.dart';
import 'package:test/test.dart';

void main() {
  group('PureDartBlas1', () {
    test('ddot and sdot', () {
      final x64 = Float64List.fromList([1.0, 2.0, 3.0]);
      final y64 = Float64List.fromList([4.0, 5.0, 6.0]);
      check(PureDartBlas1.ddot(n: 3, x: x64, y: y64)).equals(32.0);

      final x32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final y32 = Float32List.fromList([2.0, 3.0, 4.0, 5.0]);
      check(PureDartBlas1.sdot(n: 4, x: x32, y: y32)).equals(40.0);
    });

    test('dnrm2 and snrm2', () {
      final x64 = Float64List.fromList([3.0, 4.0]);
      check(PureDartBlas1.dnrm2(n: 2, x: x64)).equals(5.0);

      final x32 = Float32List.fromList([3.0, 4.0, 0.0, 0.0]);
      check(PureDartBlas1.snrm2(n: 4, x: x32)).equals(5.0);
    });

    test('daxpy and saxpy', () {
      final x64 = Float64List.fromList([1.0, 2.0]);
      final y64 = Float64List.fromList([3.0, 4.0]);
      check(PureDartBlas1.daxpy(n: 2, alpha: 2.0, x: x64, y: y64)).isTrue();
      check(y64[0]).equals(5.0);
      check(y64[1]).equals(8.0);

      final x32 = Float32List.fromList([1.0, 2.0]);
      final y32 = Float32List.fromList([3.0, 4.0]);
      check(PureDartBlas1.saxpy(n: 2, alpha: 2.0, x: x32, y: y32)).isTrue();
      check(y32[0]).equals(5.0);
      check(y32[1]).equals(8.0);
    });

    test('dscal and sscal', () {
      final x64 = Float64List.fromList([2.0, 3.0]);
      check(PureDartBlas1.dscal(n: 2, alpha: 3.0, x: x64)).isTrue();
      check(x64[0]).equals(6.0);
      check(x64[1]).equals(9.0);

      final x32 = Float32List.fromList([2.0, 3.0]);
      check(PureDartBlas1.sscal(n: 2, alpha: 3.0, x: x32)).isTrue();
      check(x32[0]).equals(6.0);
      check(x32[1]).equals(9.0);
    });
  });

  group('PureDartBlas2', () {
    test('dgemv and sgemv', () {
      final a64 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x64 = Float64List.fromList([1.0, 2.0]);
      final y64 = Float64List(2);
      check(
        PureDartBlas2.dgemv(
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a64,
          lda: 2,
          x: x64,
          incX: 1,
          beta: 0.0,
          y: y64,
          incY: 1,
        ),
      ).isTrue();
      check(y64[0]).equals(5.0);
      check(y64[1]).equals(11.0);

      final a32 = Float32List.fromList([1.0, 2.0, 3.0, 4.0]);
      final x32 = Float32List.fromList([1.0, 2.0]);
      final y32 = Float32List(2);
      check(
        PureDartBlas2.sgemv(
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
        ),
      ).isTrue();
      check(y32[0]).equals(5.0);
      check(y32[1]).equals(11.0);
    });

    test('dsyr2 and ssyr2', () {
      final a64 = Float64List(4);
      final x64 = Float64List.fromList([1.0, 2.0]);
      final y64 = Float64List.fromList([3.0, 4.0]);
      check(
        PureDartBlas2.dsyr2(n: 2, alpha: 1.0, x: x64, y: y64, a: a64, lda: 2),
      ).isTrue();
      // x * y^T + y * x^T:
      // [1*3+3*1, 1*4+3*2] = [6, 10]
      // [2*3+4*1, 2*4+4*2] = [10, 16]
      check(a64[0]).equals(6.0);
      check(a64[1]).equals(10.0);
      check(a64[2]).equals(10.0);
      check(a64[3]).equals(16.0);
    });

    test('dtrmv and strmv', () {
      final a64 = Float64List.fromList([2.0, 3.0, 0.0, 4.0]);
      final x64 = Float64List.fromList([1.0, 2.0]);
      check(PureDartBlas2.dtrmv(uplo: cblasUpper, n: 2, a: a64, lda: 2, x: x64))
          .isTrue();
      // Upper triangular: [2*1 + 3*2, 4*2] = [8, 8]
      check(x64[0]).equals(8.0);
      check(x64[1]).equals(8.0);
    });
  });

  group('PureDartBlas3', () {
    test('dsyrk and ssyrk', () {
      final a64 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final c64 = Float64List(4);
      check(
        PureDartBlas3.dsyrk(
          n: 2,
          k: 2,
          alpha: 1.0,
          a: a64,
          lda: 2,
          beta: 0.0,
          c: c64,
          ldc: 2,
        ),
      ).isTrue();
      // A * A^T:
      // [1*1 + 2*2, 1*3 + 2*4] = [5, 11]
      // [3*1 + 4*2, 3*3 + 4*4] = [11, 25]
      check(c64[0]).equals(5.0);
      check(c64[1]).equals(11.0);
      check(c64[2]).equals(11.0);
      check(c64[3]).equals(25.0);
    });

    test('dsymm and ssymm', () {
      // A symmetric: [2, 1; 1, 3]
      final a64 = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b64 = Float64List.fromList([1.0, 0.0, 0.0, 1.0]);
      final c64 = Float64List(4);
      check(
        PureDartBlas3.dsymm(
          side: cblasLeft,
          uplo: cblasUpper,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a64,
          lda: 2,
          b: b64,
          ldb: 2,
          beta: 0.0,
          c: c64,
          ldc: 2,
        ),
      ).isTrue();
      check(c64[0]).equals(2.0);
      check(c64[1]).equals(1.0);
      check(c64[2]).equals(1.0);
      check(c64[3]).equals(3.0);
    });

    test('dtrmm and strmm', () {
      // A upper: [2, 1; 0, 3]
      final a64 = Float64List.fromList([2.0, 1.0, 0.0, 3.0]);
      final b64 = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(
        PureDartBlas3.dtrmm(
          side: cblasLeft,
          uplo: cblasUpper,
          m: 2,
          n: 2,
          alpha: 1.0,
          a: a64,
          lda: 2,
          b: b64,
          ldb: 2,
        ),
      ).isTrue();
      // B = A * B = [2*1 + 1*3, 2*2 + 1*4; 3*3, 3*4] = [5, 8; 9, 12]
      check(b64[0]).equals(5.0);
      check(b64[1]).equals(8.0);
      check(b64[2]).equals(9.0);
      check(b64[3]).equals(12.0);
    });
  });

  group('PureDartVforce', () {
    test('transcendental functions', () {
      final input = Float64List.fromList([0.0, 1.0]);
      final sinOut = PureDartVforce.vsin(input);
      check(sinOut[0]).equals(0.0);

      final cosOut = PureDartVforce.vcos(input);
      check(cosOut[0]).equals(1.0);

      final expOut = PureDartVforce.vexp(input);
      check(expOut[0]).equals(1.0);

      final logOut = PureDartVforce.vlog(Float64List.fromList([1.0]));
      check(logOut[0]).equals(0.0);

      final sqrtOut = PureDartVforce.vsqrt(Float64List.fromList([4.0]));
      check(sqrtOut[0]).equals(2.0);

      final powOut = PureDartVforce.vpow(
        Float64List.fromList([2.0]),
        Float64List.fromList([3.0]),
      );
      check(powOut[0]).equals(8.0);
    });

    test('reductions and signal processing', () {
      final x = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      check(PureDartVforce.sum(x)).equals(10.0);
      check(PureDartVforce.mean(x)).equals(2.5);
      check(PureDartVforce.variance(x)).isCloseTo(1.6666666666666667, 1e-10);

      final signal = Float64List.fromList([1.0, 2.0, 3.0, 4.0]);
      final filter = Float64List.fromList([1.0, 0.5]);
      final conv = PureDartVforce.convolve(signal, filter);
      check(conv.length).equals(3);

      final corr = PureDartVforce.correlate(signal, filter);
      check(corr.length).equals(3);
    });
  });
}
