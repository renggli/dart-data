import 'dart:typed_data';

import '../../../type.dart';
import '../vector.dart';

/// Solves a tridiagonal linear system $A x = d$ in $\mathcal{O}(N)$ time using the Thomas algorithm.
///
/// The tridiagonal system $A x = d$ is defined by:
/// - [sub]: subdiagonal elements $a_0, \dots, a_{N-2}$ of length $N - 1$.
/// - [diag]: main diagonal elements $b_0, \dots, b_{N-1}$ of length $N$.
/// - [sup]: superdiagonal elements $c_0, \dots, c_{N-2}$ of length $N - 1$.
/// - [rhs]: right-hand side vector $d_0, \dots, d_{N-1}$ of length $N$.
///
/// ```dart
/// final sub = Vector<double>.fromList([1.0, 2.0]);
/// final diag = Vector<double>.fromList([2.0, 4.0, 3.0]);
/// final sup = Vector<double>.fromList([1.0, 1.0]);
/// final rhs = Vector<double>.fromList([4.0, 11.0, 11.0]);
/// final x = solveTridiagonal(sub, diag, sup, rhs);
/// print(x); // Vector([1.0588..., 1.8823..., 2.4117...])
/// ```
///
/// Throws an [ArgumentError] if vector lengths are inconsistent, or if the
/// matrix is singular (a zero pivot is encountered during elimination).
Vector<double> solveTridiagonal(
  Vector<num> sub,
  Vector<num> diag,
  Vector<num> sup,
  Vector<num> rhs,
) {
  final n = diag.length;
  if (rhs.length != n) {
    throw ArgumentError(
      'rhs length (${rhs.length}) must match diag length ($n).',
    );
  }
  if (n == 0) {
    return Vector<double>.filled(0, 0.0, type: DataType.float64);
  }
  if (sub.length != n - 1) {
    throw ArgumentError(
      'sub length (${sub.length}) must be ${n - 1} for diag length $n.',
    );
  }
  if (sup.length != n - 1) {
    throw ArgumentError(
      'sup length (${sup.length}) must be ${n - 1} for diag length $n.',
    );
  }

  if (n == 1) {
    final b0 = diag.getUnchecked(0).toDouble();
    if (b0 == 0.0 || b0.isNaN) {
      throw ArgumentError('Matrix is singular (zero pivot at index 0).');
    }
    return Vector<double>.fromList([
      rhs.getUnchecked(0).toDouble() / b0,
    ], type: DataType.float64);
  }

  final cp = Float64List(n - 1);
  final x = Vector<double>.filled(n, 0.0, type: DataType.float64);

  final subTensor = sub.tensor;
  final diagTensor = diag.tensor;
  final supTensor = sup.tensor;
  final rhsTensor = rhs.tensor;

  if (subTensor.isContiguous &&
      diagTensor.isContiguous &&
      supTensor.isContiguous &&
      rhsTensor.isContiguous &&
      x.tensor.isContiguous) {
    final subData = subTensor.data;
    final diagData = diagTensor.data;
    final supData = supTensor.data;
    final rhsData = rhsTensor.data;
    final xData = x.tensor.data;

    final subOff = subTensor.offset;
    final diagOff = diagTensor.offset;
    final supOff = supTensor.offset;
    final rhsOff = rhsTensor.offset;
    final xOff = x.tensor.offset;

    var w = diagData[diagOff].toDouble();
    if (w == 0.0 || w.isNaN) {
      throw ArgumentError('Matrix is singular (zero pivot at index 0).');
    }
    cp[0] = supData[supOff].toDouble() / w;
    xData[xOff] = rhsData[rhsOff].toDouble() / w;

    for (var i = 1; i < n - 1; i++) {
      final ai = subData[subOff + i - 1].toDouble();
      w = diagData[diagOff + i].toDouble() - ai * cp[i - 1];
      if (w == 0.0 || w.isNaN) {
        throw ArgumentError('Matrix is singular (zero pivot at index $i).');
      }
      cp[i] = supData[supOff + i].toDouble() / w;
      xData[xOff + i] =
          (rhsData[rhsOff + i].toDouble() - ai * xData[xOff + i - 1]) / w;
    }

    final an = subData[subOff + n - 2].toDouble();
    w = diagData[diagOff + n - 1].toDouble() - an * cp[n - 2];
    if (w == 0.0 || w.isNaN) {
      throw ArgumentError('Matrix is singular (zero pivot at index ${n - 1}).');
    }
    xData[xOff + n - 1] =
        (rhsData[rhsOff + n - 1].toDouble() - an * xData[xOff + n - 2]) / w;

    for (var i = n - 2; i >= 0; i--) {
      xData[xOff + i] = xData[xOff + i] - cp[i] * xData[xOff + i + 1];
    }

    return x;
  }

  var w = diag.getUnchecked(0).toDouble();
  if (w == 0.0 || w.isNaN) {
    throw ArgumentError('Matrix is singular (zero pivot at index 0).');
  }
  cp[0] = sup.getUnchecked(0).toDouble() / w;
  x.setUnchecked(0, rhs.getUnchecked(0).toDouble() / w);

  for (var i = 1; i < n - 1; i++) {
    final ai = sub.getUnchecked(i - 1).toDouble();
    w = diag.getUnchecked(i).toDouble() - ai * cp[i - 1];
    if (w == 0.0 || w.isNaN) {
      throw ArgumentError('Matrix is singular (zero pivot at index $i).');
    }
    cp[i] = sup.getUnchecked(i).toDouble() / w;
    x.setUnchecked(
      i,
      (rhs.getUnchecked(i).toDouble() - ai * x.getUnchecked(i - 1)) / w,
    );
  }

  final an = sub.getUnchecked(n - 2).toDouble();
  w = diag.getUnchecked(n - 1).toDouble() - an * cp[n - 2];
  if (w == 0.0 || w.isNaN) {
    throw ArgumentError('Matrix is singular (zero pivot at index ${n - 1}).');
  }
  x.setUnchecked(
    n - 1,
    (rhs.getUnchecked(n - 1).toDouble() - an * x.getUnchecked(n - 2)) / w,
  );

  for (var i = n - 2; i >= 0; i--) {
    x.setUnchecked(i, x.getUnchecked(i) - cp[i] * x.getUnchecked(i + 1));
  }

  return x;
}
