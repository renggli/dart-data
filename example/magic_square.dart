// Verify some of the library functions on a normal magic square:
// http://www.ijmttjournal.org/Volume-3/issue-3/IJMTT-V3I3P501.pdf
import 'dart:io';
import 'dart:math' as math;

import 'package:data/data.dart';
import 'package:more/printer.dart';

/// Generates a magic square test matrix.
Matrix<int> magic(int n) {
  if (n.isOdd) {
    final a = (n + 1) ~/ 2;
    final b = n + 1;
    return Matrix.generate(
      DataType.int64,
      n,
      n,
      (r, c) => n * ((r + c + a) % n) + ((r + 2 * c + b) % n) + 1,
    );
  } else if (n % 4 == 0) {
    return Matrix.generate(
      DataType.int64,
      n,
      n,
      (r, c) => ((r + 1) ~/ 2) % 2 == ((c + 1) ~/ 2) % 2
          ? n * n - n * r - c
          : n * r + c + 1,
    );
  } else {
    final R = Matrix(DataType.int64, n, n);
    final p = n ~/ 2;
    final k = (n - 2) ~/ 4;
    final A = magic(p);
    for (var j = 0; j < p; j++) {
      for (var i = 0; i < p; i++) {
        final aij = A.get(i, j);
        R.set(i, j, aij);
        R.set(i, j + p, aij + 2 * p * p);
        R.set(i + p, j, aij + 3 * p * p);
        R.set(i + p, j + p, aij + p * p);
      }
    }
    for (var i = 0; i < p; i++) {
      for (var j = 0; j < k; j++) {
        final t = R.get(i, j);
        R.set(i, j, R.get(i + p, j));
        R.set(i + p, j, t);
      }
      for (var j = n - k + 1; j < n; j++) {
        final t = R.get(i, j);
        R.set(i, j, R.get(i + p, j));
        R.set(i + p, j, t);
      }
    }
    var t = R.get(k, 0);
    R.set(k, 0, R.get(k + p, 0));
    R.set(k + p, 0, t);
    t = R.get(k, k);
    R.set(k, k, R.get(k + p, k));
    R.set(k + p, k, t);
    return R;
  }
}

/// Printers for console output.
Printer<int> integerPrinter() => FixedNumberPrinter<int>();

Printer<double> doublePrinter(int precision) =>
    FixedNumberPrinter<double>(precision: precision);

Printer<String> alignPrinter(int width) =>
    const StandardPrinter<String>().padLeft(width);

/// Configuration of output printing.
const int width = 14;
const List<String> columns = [
  'n',
  'trace',
  'max_eig',
  'rank',
  'cond',
  'lu_res',
  'qr_res',
];

void main() {
  final eps = math.pow(2.0, -52.0);

  stdout.writeln(columns.map(alignPrinter(width).print).join());
  stdout.writeln();

  for (var n = 3; n <= 128; n++) {
    final m = magic(n);
    final md = m.map((row, col, value) => value.toDouble(), DataType.float64);

    final buffer = <String>[];

    // Order of magic square.
    buffer.add(integerPrinter()(n));

    // Diagonal sum, should be the magic sum, (n^3 + n) / 2.
    {
      final t = m.diagonal().sum;
      buffer.add(integerPrinter()(t));
      assert(t == (n * n * n + n) / 2, 'invalid magic sum');
    }

    // Maximum eigenvalue of (A + A') / 2, should equal trace.
    {
      final e = ((md + md.transposed) * 0.5).eigenvalue;
      buffer.add(doublePrinter(3)(e.realEigenvalues.last));
      assert(
        (e.realEigenvalues.last - m.diagonal().sum).abs() < 0.0001,
        'invalid eigenvalue',
      );
    }

    // Linear algebraic rank, should equal n if n is odd, be less than n if n
    // is even.
    {
      final r = m.rank;
      buffer.add(integerPrinter()(r));
      assert(
        n % 4 == 0
            ? r == 3
            : n.isOdd
            ? r == n
            : r == (n ~/ 2) + 2,
        'invalid rank',
      );
    }

    // L_2 condition number, ratio of singular values.
    {
      final c = m.cond;
      final cn = c < 1 / eps ? c : double.infinity;
      buffer.add(doublePrinter(3)(cn));
      assert(
        n == 3
            ? cn.round() == 4
            : n.isOdd
            ? cn.round() == n
            : cn == double.infinity,
      );
    }

    // Test of LU factorization, norm1(L*U-A(p,:))/(n*eps).
    {
      final lu = md.lu;
      final l = lu.lower;
      final u = lu.upper;
      final p = lu.pivot;
      final r = l * u - md.rowIndex(p);
      final res = r.norm1 / (n * eps);
      buffer.add(doublePrinter(3)(res));
      assert(r.normFrobenius < 1e-8, 'inaccurate LU factorization');
    }

    // Test of QR factorization, norm1(Q*R-A)/(n*eps).
    {
      final qr = md.qr;
      final q = qr.orthogonal;
      final r = qr.upper;
      final R = q * r - m.cast(DataType.float64);
      final res = R.norm1 / (n * eps);
      buffer.add(doublePrinter(3)(res));
      assert(R.normFrobenius < 1e-8, 'inaccurate QR factorization');
    }

    // Trace of inverse, should be the inverse of the magic sum.
    if (n.isOdd) {
      final t = 1 / md.inverse.trace;
      assert(t.round() == (n * n * n + n) / 2, 'invalid inverse magic sum');
    }

    stdout.writeln(buffer.map(alignPrinter(width).print).join());
  }
}
