import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../type/data_type.dart';
import 'layout.dart';
import 'operations/operation.dart';
import 'tensor.dart';

/// Zero-cost extension type wrapping [Tensor] with direct [Float64List] buffer
/// access.
///
/// Conceptually, this is an $N$-dimensional grid of decimal numbers optimized
/// for speed and direct memory access.
///
/// Formally, provides an unboxed multi-dimensional array over
/// $\mathbb{R}^{d_1 \times \dots \times d_k}$ backed by flat IEEE 754
/// double-precision buffers with strided index layouts.
///
/// ```dart
/// final t = Float64Tensor.filled(0.0, shape: [2, 3]);
/// print(t.rank); // 2
/// ```
extension type Float64Tensor._(Tensor<double> _tensor)
    implements Tensor<double> {
  /// Constructs a [Float64Tensor] wrapping [tensor].
  ///
  /// Throws an [ArgumentError] if `tensor.data` is not a [Float64List].
  factory(Tensor<double> tensor) {
    if (tensor.data is! Float64List) {
      throw ArgumentError.value(
        tensor,
        'tensor',
        'Float64Tensor requires underlying data to be Float64List, got ${tensor.data.runtimeType}',
      );
    }
    return Float64Tensor._(tensor);
  }

  /// Constructs a [Float64Tensor] from any [Tensor<double>], copying elements
  /// to a [Float64List] if not already backed by one.
  factory fromDoubleTensor(Tensor<double> tensor) {
    if (tensor.data is Float64List) {
      return Float64Tensor._(tensor);
    }
    final len = tensor.length;
    final copy = Float64List(len);
    if (tensor.isContiguous) {
      final data = tensor.data;
      final off = tensor.offset;
      for (var i = 0; i < len; i++) {
        copy[i] = data[off + i];
      }
    } else {
      var i = 0;
      for (final val in tensor.values) {
        copy[i++] = val;
      }
    }
    return Float64Tensor._(
      Tensor.internal(
        type: DataType.float64,
        layout: Layout(shape: tensor.shape),
        data: copy,
      ),
    );
  }

  /// Constructs a [Float64Tensor] filled with [value].
  factory filled(double value, {List<int>? shape}) => Float64Tensor._(
    Tensor<double>.filled(value, shape: shape, type: DataType.float64),
  );

  /// Constructs a [Float64Tensor] using [generator] for each coordinate key.
  factory generate(
    double Function(List<int> key) generator, {
    required List<int> shape,
  }) => Float64Tensor._(
    Tensor<double>.generate(generator, shape: shape, type: DataType.float64),
  );

  /// Constructs a [Float64Tensor] from an iterable.
  factory fromIterable(Iterable<double> iterable, {List<int>? shape}) =>
      Float64Tensor._(
        Tensor<double>.fromIterable(
          iterable,
          shape: shape,
          type: DataType.float64,
        ),
      );

  /// Constructs a [Float64Tensor] from nested Dart lists or scalar objects.
  factory fromObject(Object? object) => Float64Tensor._(
    Tensor<double>.fromObject(object, type: DataType.float64),
  );

  /// Direct zero-copy access to the underlying [Float64List] buffer.
  Float64List get asTypedList => _tensor.data as Float64List;

  /// Fast element access for 1D tensors.
  @pragma('vm:prefer-inline')
  @redeclare
  double get1D(int index) => asTypedList[offset + index * strides[0]];

  /// Fast element mutation for 1D tensors.
  @pragma('vm:prefer-inline')
  @redeclare
  void set1D(int index, double value) =>
      asTypedList[offset + index * strides[0]] = value;

  /// Fast element access for 2D tensors.
  @pragma('vm:prefer-inline')
  @redeclare
  double get2D(int row, int col) =>
      asTypedList[offset + row * strides[0] + col * strides[1]];

  /// Fast element mutation for 2D tensors.
  @pragma('vm:prefer-inline')
  @redeclare
  void set2D(int row, int col, double value) =>
      asTypedList[offset + row * strides[0] + col * strides[1]] = value;

  /// Slices the first axis at [index] as [Float64Tensor].
  @redeclare
  Float64Tensor operator [](int index) => Float64Tensor._(_tensor[index]);

  /// Returns a reshaped view as [Float64Tensor].
  @redeclare
  Float64Tensor reshape(List<int> newShape) =>
      Float64Tensor._(_tensor.reshape(newShape));

  /// Returns a transposed view as [Float64Tensor].
  @redeclare
  Float64Tensor transpose([List<int>? permutation]) =>
      Float64Tensor._(_tensor.transpose(permutation));

  /// Returns a flipped view along [axis] as [Float64Tensor].
  @redeclare
  Float64Tensor flip({int axis = 0}) =>
      Float64Tensor._(_tensor.flip(axis: axis));

  /// Slices a range along [axis] as [Float64Tensor].
  @redeclare
  Float64Tensor getRange({
    required int axis,
    int? start,
    int? end,
    int step = 1,
  }) => Float64Tensor._(
    _tensor.getRange(axis: axis, start: start, end: end, step: step),
  );

  /// Returns a zero-copy strided multi-axis slice as [Float64Tensor].
  @redeclare
  Float64Tensor slice(List<Slice> slices) =>
      Float64Tensor._(_tensor.slice(slices));

  /// Creates a contiguous deep copy of this tensor as [Float64Tensor].
  @redeclare
  Float64Tensor copy({Float64Tensor? target}) {
    if (target != null) {
      _tensor.copy(target: target._tensor);
      return target;
    }
    return Float64Tensor._(_tensor.copy());
  }

  /// Inlined contiguous element-wise addition.
  Float64Tensor operator +(Tensor<double> other) {
    if (isContiguous &&
        other.isContiguous &&
        areShapesEqual(shape, other.shape)) {
      final a = asTypedList;
      final b = other.data;
      final out = Float64List(length);
      final aOff = offset;
      final bOff = other.offset;
      if (b is Float64List) {
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] + b[bOff + i];
        }
      } else {
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] + b[bOff + i];
        }
      }
      return Float64Tensor._(
        Tensor.internal(
          type: DataType.float64,
          layout: Layout(shape: shape),
          data: out,
        ),
      );
    }
    return Float64Tensor._(_tensor + other);
  }

  /// Inlined contiguous element-wise subtraction.
  Float64Tensor operator -(Tensor<double> other) {
    if (isContiguous &&
        other.isContiguous &&
        areShapesEqual(shape, other.shape)) {
      final a = asTypedList;
      final b = other.data;
      final out = Float64List(length);
      final aOff = offset;
      final bOff = other.offset;
      if (b is Float64List) {
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] - b[bOff + i];
        }
      } else {
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] - b[bOff + i];
        }
      }
      return Float64Tensor._(
        Tensor.internal(
          type: DataType.float64,
          layout: Layout(shape: shape),
          data: out,
        ),
      );
    }
    return Float64Tensor._(_tensor - other);
  }

  /// Inlined contiguous element-wise multiplication.
  Float64Tensor operator *(Tensor<double> other) {
    if (isContiguous &&
        other.isContiguous &&
        areShapesEqual(shape, other.shape)) {
      final a = asTypedList;
      final b = other.data;
      final out = Float64List(length);
      final aOff = offset;
      final bOff = other.offset;
      if (b is Float64List) {
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] * b[bOff + i];
        }
      } else {
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] * b[bOff + i];
        }
      }
      return Float64Tensor._(
        Tensor.internal(
          type: DataType.float64,
          layout: Layout(shape: shape),
          data: out,
        ),
      );
    }
    return Float64Tensor._(_tensor * other);
  }

  /// Inlined contiguous element-wise division.
  Float64Tensor operator /(Tensor<double> other) {
    if (isContiguous &&
        other.isContiguous &&
        areShapesEqual(shape, other.shape)) {
      final a = asTypedList;
      final b = other.data;
      final out = Float64List(length);
      final aOff = offset;
      final bOff = other.offset;
      if (b is Float64List) {
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] / b[bOff + i];
        }
      } else {
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] / b[bOff + i];
        }
      }
      return Float64Tensor._(
        Tensor.internal(
          type: DataType.float64,
          layout: Layout(shape: shape),
          data: out,
        ),
      );
    }
    return Float64Tensor._(_tensor / other);
  }

  /// Inlined unary negation.
  Float64Tensor operator -() {
    if (isContiguous) {
      final a = asTypedList;
      final out = Float64List(length);
      final aOff = offset;
      for (var i = 0; i < length; i++) {
        out[i] = -a[aOff + i];
      }
      return Float64Tensor._(
        Tensor.internal(
          type: DataType.float64,
          layout: Layout(shape: shape),
          data: out,
        ),
      );
    }
    return Float64Tensor._(-_tensor);
  }

  /// Scales all elements by [scalar].
  Float64Tensor scale(double scalar) {
    if (isContiguous) {
      final a = asTypedList;
      final out = Float64List(length);
      final aOff = offset;
      for (var i = 0; i < length; i++) {
        out[i] = a[aOff + i] * scalar;
      }
      return Float64Tensor._(
        Tensor.internal(
          type: DataType.float64,
          layout: Layout(shape: shape),
          data: out,
        ),
      );
    }
    return Float64Tensor._(_tensor.unaryOperation((val) => val * scalar));
  }
}
