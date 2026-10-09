// Verify matrix and linear solver functions on a normal magic square:
// http://www.ijmttjournal.org/Volume-3/issue-3/IJMTT-V3I3P501.pdf
import 'dart:io';

import 'package:data/data.dart';
import 'package:more/printer.dart';

/// Generates a magic square test matrix.
Matrix<int> magic(int n) {
  if (n.isOdd) {
    final a = (n + 1) ~/ 2;
    final b = n + 1;
    return Matrix.generate(
      n,
      n,
      (int r, int c) => n * ((r + c + a) % n) + ((r + 2 * c + b) % n) + 1,
      type: DataType.int32,
    );
  } else if (n % 4 == 0) {
    return Matrix.generate(
      n,
      n,
      (int r, int c) => ((r + 1) ~/ 2) % 2 == ((c + 1) ~/ 2) % 2
          ? n * n - n * r - c
          : n * r + c + 1,
      type: DataType.int32,
    );
  } else {
    final rMat = Matrix<int>.filled(n, n, 0, type: DataType.int32);
    final p = n ~/ 2;
    final k = (n - 2) ~/ 4;
    final a = magic(p);
    for (var j = 0; j < p; j++) {
      for (var i = 0; i < p; i++) {
        final aij = a.get(i, j);
        rMat.set(i, j, aij);
        rMat.set(i, j + p, aij + 2 * p * p);
        rMat.set(i + p, j, aij + 3 * p * p);
        rMat.set(i + p, j + p, aij + p * p);
      }
    }
    for (var i = 0; i < p; i++) {
      for (var j = 0; j < k; j++) {
        final t = rMat.get(i, j);
        rMat.set(i, j, rMat.get(i + p, j));
        rMat.set(i + p, j, t);
      }
      for (var j = n - k + 1; j < n; j++) {
        final t = rMat.get(i, j);
        rMat.set(i, j, rMat.get(i + p, j));
        rMat.set(i + p, j, t);
      }
    }
    var t = rMat.get(k, 0);
    rMat.set(k, 0, rMat.get(k + p, 0));
    rMat.set(k + p, 0, t);
    t = rMat.get(k, k);
    rMat.set(k, k, rMat.get(k + p, k));
    rMat.set(k + p, k, t);
    return rMat;
  }
}

/// Printers for console output.
Printer<int> integerPrinter() => FixedNumberPrinter<int>();

Printer<double> doublePrinter(int precision) =>
    FixedNumberPrinter<double>(precision: precision);

Printer<String> alignPrinter(int width) =>
    const StandardPrinter<String>().padLeft(width);

/// Configuration of output printing.
const int columnWidth = 14;
const List<String> columns = ['n', 'trace', 'expected_sum', 'lu_res', 'cg_res'];

void main() {
  stdout.writeln(columns.map(alignPrinter(columnWidth).print).join());
  stdout.writeln();

  for (var n = 3; n <= 32; n++) {
    final m = magic(n);
    final expectedSum = (n * n * n + n) ~/ 2;
    final traceVal = m.trace;
    assert(traceVal == expectedSum, 'invalid magic sum');

    final md = Matrix.generate(
      n,
      n,
      (int r, int c) => m.get(r, c).toDouble(),
      type: DataType.float64,
    );

    // Solve md * x = b using LAPACK LU decomposition / fallback solver
    final b = Vector<double>.filled(n, 1.0, type: DataType.float64);
    final x = md.solve(b);
    final luResidual = (md.apply(x) - b).norm();

    // Solve SPD system (A^T * A) * y = A^T * b using Conjugate Gradient
    final ata = md.transposed * md;
    final atb = md.transposed.apply(b);
    final cgX = conjugateGradient(ata, atb, tolerance: 1e-8);
    final cgResidual = (ata.apply(cgX) - atb).norm();

    final buffer = <String>[
      integerPrinter()(n),
      integerPrinter()(traceVal),
      integerPrinter()(expectedSum),
      doublePrinter(4)(luResidual),
      doublePrinter(4)(cgResidual),
    ];

    stdout.writeln(buffer.map(alignPrinter(columnWidth).print).join());
  }
}
