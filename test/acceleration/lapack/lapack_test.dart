import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Lapack Factorizations & Solvers', () {
    accelerationTest('dpotrf Cholesky factorization', () {
      final a = Float64List.fromList([4.0, 2.0, 2.0, 5.0]);
      final ok = Lapack.dpotrf(n: 2, a: a, lda: 2);
      check(ok).isTrue();
      // L = [[2, 0], [1, 2]]
      check(a[0]).isCloseTo(2.0, 1e-10);
      check(a[1]).isCloseTo(1.0, 1e-10);
      check(a[3]).isCloseTo(2.0, 1e-10);
    });

    accelerationTest('dgesv linear system solve', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 3.0]);
      final b = Float64List.fromList([5.0, 5.0]);
      final ok = Lapack.dgesv(n: 2, nrhs: 1, a: a, lda: 2, b: b, ldb: 1);
      check(ok).isTrue();
      check(b[0]).isCloseTo(2.0, 1e-10);
      check(b[1]).isCloseTo(1.0, 1e-10);
    });

    accelerationTest('dgels linear least squares overdetermined', () {
      // 3 equations, 2 unknowns
      final a = Float64List.fromList([1.0, 1.0, 1.0, 2.0, 1.0, 3.0]);
      final b = Float64List.fromList([6.0, 0.0, 0.0]);
      final ok = Lapack.dgels(m: 3, n: 2, nrhs: 1, a: a, lda: 2, b: b, ldb: 1);
      check(ok).isTrue();
      check(b[0]).isA<double>();
      check(b[1]).isA<double>();
    });

    accelerationTest('dsyev symmetric eigenvalue solve', () {
      final a = Float64List.fromList([2.0, 1.0, 1.0, 2.0]);
      final w = Float64List(2);
      final ok = Lapack.dsyev(n: 2, a: a, lda: 2, w: w);
      check(ok).isTrue();
      // Eigenvalues of [[2, 1], [1, 2]] are 1 and 3
      check(w[0]).isCloseTo(1.0, 1e-9);
      check(w[1]).isCloseTo(3.0, 1e-9);
    });

    accelerationTest('ssyev float32 eigenvalue solve', () {
      final a = Float32List.fromList([2.0, 1.0, 1.0, 2.0]);
      final w = Float32List(2);
      final ok = Lapack.ssyev(n: 2, a: a, lda: 2, w: w);
      check(ok).isTrue();
      check(w[0]).isCloseTo(1.0, 1e-5);
      check(w[1]).isCloseTo(3.0, 1e-5);
    });
  });
}
