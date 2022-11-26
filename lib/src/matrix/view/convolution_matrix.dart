import 'dart:math';

import 'package:meta/meta.dart';

import '../../../type.dart';
import '../../shared/convolution.dart';
import '../../shared/storage.dart';
import '../matrix.dart';
import '../mixin/unmodifiable_matrix.dart';

/// Read-only convolution between two matrices.
abstract class ConvolutionMatrix<T> with Matrix<T>, UnmodifiableMatrixMixin<T> {
  ConvolutionMatrix(this.dataType, this.matrix, this.kernel)
      : assert(matrix.rowCount > 0 && matrix.colCount > 0, 'Empty matrix'),
        assert(kernel.rowCount > 0 && kernel.colCount > 0, 'Empty kernel');

  final Matrix<T> matrix;
  final Matrix<T> kernel;

  @override
  final DataType<T> dataType;

  @override
  Set<Storage> get storage => {...matrix.storage, ...kernel.storage};

  @internal
  T convolution(int mrs, int mcs, int kre, int kce) {
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var vr = mrs, kr = kre; vr < matrix.rowCount && kr >= 0; vr++, kr--) {
      for (var vc = mcs, kc = kce;
          vc < matrix.colCount && kc >= 0;
          vc++, kc--) {
        result = add(
            result,
            mul(
              matrix.getUnchecked(vr, vc),
              kernel.getUnchecked(kr, kc),
            ));
      }
    }
    return result;
  }
}

class FullConvolutionMatrix<T> extends ConvolutionMatrix<T> {
  FullConvolutionMatrix(super.dataType, super.matrix, super.kernel)
      : rowCount = matrix.rowCount + kernel.rowCount - 1,
        colCount = matrix.colCount + kernel.colCount - 1;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  T getUnchecked(int row, int col) {
    final vr = max(row - kernel.rowCount + 1, 0);
    final vc = max(col - kernel.colCount + 1, 0);
    return convolution(vr, vc, row - vr, col - vc);
  }
}

class ValidConvolutionMatrix<T> extends ConvolutionMatrix<T> {
  ValidConvolutionMatrix(super.dataType, super.matrix, super.kernel)
      : rowCount = matrix.rowCount - kernel.rowCount + 1,
        colCount = matrix.colCount - kernel.colCount + 1;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  T getUnchecked(int row, int col) =>
      convolution(row, col, kernel.rowCount - 1, kernel.colCount - 1);
}

class SameConvolutionMatrix<T> extends ConvolutionMatrix<T> {
  SameConvolutionMatrix(super.dataType, super.matrix, super.kernel)
      : rowCount = matrix.rowCount,
        colCount = matrix.colCount;

  @override
  final int rowCount;

  @override
  final int colCount;

  @override
  T getUnchecked(int row, int col) {
    final kr2 = kernel.rowCount ~/ 2, vr = max(row - kr2, 0);
    final kc2 = kernel.colCount ~/ 2, vc = max(col - kc2, 0);
    return convolution(vr, vc, row + kr2 - vr, col + kc2 - vc);
  }
}

extension ConvolutionMatrixExtension<T> on Matrix<T> {
  /// Returns a view of the convolution between this matrix and the given
  /// `kernel`. The solution is obtained lazily by straightforward computation,
  /// not by using a FFT.
  ///
  /// See http://en.wikipedia.org/wiki/Convolution.
  Matrix<T> convolve(
    Matrix<T> kernel, {
    DataType<T>? dataType,
    ConvolutionMode mode = ConvolutionMode.full,
  }) {
    switch (mode) {
      case ConvolutionMode.full:
        return FullConvolutionMatrix<T>(
            dataType ?? this.dataType, this, kernel);
      case ConvolutionMode.valid:
        return ValidConvolutionMatrix<T>(
            dataType ?? this.dataType, this, kernel);
      case ConvolutionMode.same:
        return SameConvolutionMatrix<T>(
            dataType ?? this.dataType, this, kernel);
    }
  }
}
