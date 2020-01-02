library data.test.tutorial;

import 'package:data/matrix.dart';
import 'package:data/type.dart';
import 'package:data/vector.dart';
import 'package:more/printer.dart';
import 'package:test/test.dart';

void main() {
  test('solve a linear equation', () {
    final a = Matrix<double>.fromRows(DataType.float64, [
      [2, 1, 1],
      [1, 3, 2],
      [1, 0, 0],
    ]);
    final b = Vector.builder.withType(DataType.float64).fromList([4, 5, 6]);
    final x = a.solve(b.columnMatrix).column(0);
    expect(x.format(valuePrinter: Printer.fixed()), '6 15 -23');
  });
  test('find eigenvalues', () {
    final a = Matrix<double>.fromRows(DataType.float64, [
      [1, 0, 0, -1],
      [0, -1, 0, 0],
      [0, 0, 1, -1],
      [-1, 0, -1, 0],
    ]);
    final decomposition = a.eigenvalue;
    final eigenvalues = Vector.builder
        .withType(DataType.float64)
        .fromList(decomposition.realEigenvalues);
    expect(eigenvalues.format(valuePrinter: Printer.fixed(precision: 1)),
        '-1.0 -1.0 1.0 2.0');
  });
}
