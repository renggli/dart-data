import 'dart:math';

import 'package:meta/meta.dart';

import '../../../type.dart';
import '../../shared/storage.dart';
import '../mixin/unmodifiable_vector.dart';
import '../vector.dart';

/// Read-only convolution between two vectors.
abstract class ConvolutionVector<T> with Vector<T>, UnmodifiableVectorMixin<T> {
  ConvolutionVector(this.dataType, this.vector, this.kernel)
      : assert(vector.count > 0, 'Empty vector'),
        assert(kernel.count > 0, 'Empty kernel');

  final Vector<T> vector;
  final Vector<T> kernel;

  @override
  final DataType<T> dataType;

  @override
  Set<Storage> get storage => {...vector.storage, ...kernel.storage};

  @internal
  T convolution(int vs, int ke) {
    final add = dataType.field.add, mul = dataType.field.mul;
    var result = dataType.field.additiveIdentity;
    for (var v = vs, k = ke; v < vector.count && k >= 0; v++, k--) {
      result = add(result, mul(vector.getUnchecked(v), kernel.getUnchecked(k)));
    }
    return result;
  }
}

class FullConvolutionVector<T> extends ConvolutionVector<T> {
  FullConvolutionVector(super.dataType, super.vector, super.kernel)
      : count = vector.count + kernel.count - 1;

  @override
  final int count;

  @override
  T getUnchecked(int index) {
    final v = max(index - kernel.count + 1, 0);
    return convolution(v, index - v);
  }
}

class ValidConvolutionVector<T> extends ConvolutionVector<T> {
  ValidConvolutionVector(super.dataType, super.vector, super.kernel)
      : count = vector.count - kernel.count + 1;

  @override
  final int count;

  @override
  T getUnchecked(int index) => convolution(index, kernel.count - 1);
}

class SameConvolutionVector<T> extends ConvolutionVector<T> {
  SameConvolutionVector(super.dataType, super.vector, super.kernel)
      : count = vector.count;

  @override
  final int count;

  @override
  T getUnchecked(int index) {
    final k2 = kernel.count ~/ 2, v = max(index - k2, 0);
    return convolution(v, index + k2 - v);
  }
}

/// Convolution mode on a [Vector], i.e. how the borders are handled.
enum VectorConvolution {
  full,
  valid,
  same,
}

extension ConvolutionVectorExtension<T> on Vector<T> {
  /// Returns a view of the convolution between this vector and the given
  /// [kernel]. The solution is obtained lazily by straightforward computation,
  /// not by using a FFT.
  ///
  /// See http://en.wikipedia.org/wiki/Convolution.
  Vector<T> convolve(
    Vector<T> kernel, {
    DataType<T>? dataType,
    VectorConvolution mode = VectorConvolution.full,
  }) =>
      switch (mode) {
        VectorConvolution.full =>
          FullConvolutionVector<T>(dataType ?? this.dataType, this, kernel),
        VectorConvolution.valid =>
          ValidConvolutionVector<T>(dataType ?? this.dataType, this, kernel),
        VectorConvolution.same =>
          SameConvolutionVector<T>(dataType ?? this.dataType, this, kernel)
      };
}
