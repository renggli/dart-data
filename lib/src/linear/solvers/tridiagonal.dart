import 'dart:typed_data';

import '../../tensor/layout.dart';
import '../../tensor/tensor.dart';
import '../../type/data_type.dart';
import '../vector.dart';

/// Solves a tridiagonal linear system $A x = d$ in $\mathcal{O}(N)$ time using
/// the Thomas algorithm.
///
/// Conceptually, a tridiagonal matrix only has non-zero entries along the main
/// diagonal and its two immediate neighboring diagonals. The Thomas algorithm
/// sweeps through the system in a single forward and backward pass, solving for
/// all unknowns in linear time. More formally, it computes specialized Gaussian
/// elimination without pivoting for tridiagonal systems, executing in
/// $\mathcal{O}(N)$ arithmetic operations.
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

  final subData = _asFloat64List(sub);
  final diagData = _asFloat64List(diag);
  final supData = _asFloat64List(sup);
  final rhsData = _asFloat64List(rhs);

  final cp = Float64List(n - 1);
  final xData = Float64List(n);

  var w = diagData[0];
  if (w == 0.0 || w.isNaN) {
    throw ArgumentError('Matrix is singular (zero pivot at index 0).');
  }
  cp[0] = supData[0] / w;
  xData[0] = rhsData[0] / w;

  for (var i = 1; i < n - 1; i++) {
    final ai = subData[i - 1];
    w = diagData[i] - ai * cp[i - 1];
    if (w == 0.0 || w.isNaN) {
      throw ArgumentError('Matrix is singular (zero pivot at index $i).');
    }
    cp[i] = supData[i] / w;
    xData[i] = (rhsData[i] - ai * xData[i - 1]) / w;
  }

  final an = subData[n - 2];
  w = diagData[n - 1] - an * cp[n - 2];
  if (w == 0.0 || w.isNaN) {
    throw ArgumentError('Matrix is singular (zero pivot at index ${n - 1}).');
  }
  xData[n - 1] = (rhsData[n - 1] - an * xData[n - 2]) / w;

  for (var i = n - 2; i >= 0; i--) {
    xData[i] -= cp[i] * xData[i + 1];
  }

  return Vector(
    Tensor<double>.internal(
      type: DataType.float64,
      layout: Layout(shape: [n]),
      data: xData,
    ),
  );
}

Float64List _asFloat64List(Vector<num> v) {
  final tensor = v.tensor;
  final data = tensor.data;
  if (data is Float64List && tensor.isContiguous) {
    if (tensor.offset == 0 && tensor.length == data.length) {
      return data;
    }
    return Float64List.sublistView(
      data,
      tensor.offset,
      tensor.offset + tensor.length,
    );
  }
  final result = Float64List(v.length);
  for (var i = 0; i < v.length; i++) {
    result[i] = v.getUnchecked(i).toDouble();
  }
  return result;
}
