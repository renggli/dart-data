import 'dart:math';

import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Convolution mode, i.e. how the borders are handled.
enum ConvolutionMode {
  full,
  valid,
  same,
}

/// Read-only convolution between two vectors.
class ConvolutionVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  ConvolutionVector(this.dataType, this.vector, this.kernel, this.mode)
      : assert(vector.count > 0, 'Empty vector'),
        assert(kernel.count > 0, 'Empty kernel'),
        vectorCount = vector.count,
        kernelCount = kernel.count;

  final Vector<T> vector;
  final int vectorCount;
  final Vector<T> kernel;
  final int kernelCount;
  final ConvolutionMode mode;

  @override
  final DataType<T> dataType;

  @override
  int get count {
    switch (mode) {
      case ConvolutionMode.full:
        return vectorCount + kernelCount - 1;
      case ConvolutionMode.valid:
        return vectorCount - kernelCount + 1;
      case ConvolutionMode.same:
        return vectorCount;
    }
  }

  @override
  Set<Storage> get storage => {...vector.storage, ...kernel.storage};

  @override
  Vector<T> copy() =>
      ConvolutionVector<T>(dataType, vector.copy(), kernel.copy(), mode);

  @override
  T getUnchecked(int index) {
    final add = dataType.field.add, mul = dataType.field.mul;
    // Compute the offsets
    int v, k;
    switch (mode) {
      case ConvolutionMode.full:
        v = max(index - kernelCount + 1, 0);
        k = index - v;
        break;
      case ConvolutionMode.valid:
        v = index;
        k = kernelCount - 1;
        break;
      case ConvolutionMode.same:
        v = max(index - kernelCount ~/ 2, 0);
        k = index + kernelCount ~/ 2 - v;
        break;
    }
    // Compute the convolution
    var result = dataType.field.additiveIdentity;
    while (v < vectorCount && k >= 0) {
      result = add(
          result,
          mul(
            vector.getUnchecked(v++),
            kernel.getUnchecked(k--),
          ));
    }
    return result;
  }
}

extension ConvolutionVectorExtension<T> on Vector<T> {
  /// Returns a view a convolution between this vector and the given
  /// `kernel`.
  ///
  /// The solution is obtained lazily by straightforward computation, not by
  /// using a FFT.
  ///
  /// See http://en.wikipedia.org/wiki/Convolution.
  Vector<T> convolve(
    Vector<T> kernel, {
    DataType<T>? dataType,
    ConvolutionMode mode = ConvolutionMode.full,
  }) =>
      ConvolutionVector<T>(dataType ?? this.dataType, this, kernel, mode);
}
