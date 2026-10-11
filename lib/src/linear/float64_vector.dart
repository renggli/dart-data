import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../../type.dart';
import '../acceleration/acceleration_manager.dart';
import '../tensor/layout.dart';
import '../tensor/tensor.dart';
import 'vector.dart';

/// Zero-cost extension type wrapping [Vector<double>] with direct [Float64List]
/// buffer access.
///
/// This provides a 1D vector optimized to store 64-bit floating-point numbers
/// in contiguous memory for high-speed mathematical operations. Formally, it
/// provides an unboxed vector representation over $\mathbb{R}^n$ backed by flat
/// IEEE 754 double-precision arrays compatible with BLAS level 1 and 2
/// operations.
///
/// ```dart
/// final v = Float64Vector.filled(3, 2.5);
/// print(v.length); // 3
/// ```
extension type Float64Vector(Vector<double> _vector) implements Vector<double> {
  /// Constructs a [Float64Vector] filled with [value].
  factory filled(int length, double value, {bool? native}) => Float64Vector(
    Vector<double>.filled(
      length,
      value,
      type: DataType.float64,
      native: native,
    ),
  );

  /// Constructs a [Float64Vector] populated by [generator].
  factory generate(
    int length,
    double Function(int index) generator, {
    bool? native,
  }) => Float64Vector(
    Vector<double>.generate(
      length,
      generator,
      type: DataType.float64,
      native: native,
    ),
  );

  /// Constructs a [Float64Vector] from a list of elements.
  factory fromList(List<double> list, {bool? native}) => Float64Vector(
    Vector<double>.fromList(list, type: DataType.float64, native: native),
  );

  /// Constructs a [Float64Vector] from an iterable of elements.
  factory fromIterable(Iterable<double> iterable, {bool? native}) =>
      Float64Vector(
        Vector<double>.fromIterable(
          iterable,
          type: DataType.float64,
          native: native,
        ),
      );

  /// Constructs a [Float64Vector] with a sequence of [count] evenly spaced
  /// values over the interval `[start, stop]`.
  factory linspace(
    double start,
    double stop, {
    int count = 50,
    bool endpoint = true,
    bool? native,
  }) => Float64Vector(
    Vector<double>.linspace(
      start,
      stop,
      count: count,
      endpoint: endpoint,
      type: DataType.float64,
      native: native,
    ),
  );

  /// Constructs a [Float64Vector] with a sequence of [count] evenly spaced
  /// values on a logarithmic scale over `[base^start, base^stop]`.
  factory logspace(
    double start,
    double stop, {
    int count = 50,
    double base = 10.0,
    bool endpoint = true,
    bool? native,
  }) => Float64Vector(
    Vector<double>.logspace(
      start,
      stop,
      count: count,
      base: base,
      endpoint: endpoint,
      type: DataType.float64,
      native: native,
    ),
  );

  /// Constructs a [Float64Vector] with a sequence of [count] geometrically
  /// spaced values over the interval `[start, stop]`.
  factory geomspace(
    double start,
    double stop, {
    int count = 50,
    bool endpoint = true,
    bool? native,
  }) => Float64Vector(
    Vector<double>.geomspace(
      start,
      stop,
      count: count,
      endpoint: endpoint,
      type: DataType.float64,
      native: native,
    ),
  );

  /// Direct zero-copy access to the underlying [Float64List] buffer.
  Float64List get asTypedList => _vector.tensor.data is Float64List
      ? _vector.tensor.data as Float64List
      : Float64List.fromList(_vector.tensor.data);

  /// Fast element access at [index].
  @pragma('vm:prefer-inline')
  @redeclare
  double operator [](int index) {
    final t = _vector.tensor;
    return asTypedList[t.offset + index * t.strides[0]];
  }

  /// Fast element mutation at [index].
  @pragma('vm:prefer-inline')
  @redeclare
  void operator []=(int index, double value) {
    final t = _vector.tensor;
    asTypedList[t.offset + index * t.strides[0]] = value;
  }

  /// Algebraic inner dot product routing directly to BLAS `ddot`.
  @redeclare
  double dot(Vector<double> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${other.length}',
      );
    }
    final tA = _vector.tensor;
    final tB = other.tensor;
    final bData = other is Float64Vector
        ? other.asTypedList
        : (tB.data is Float64List
              ? tB.data as Float64List
              : Float64List.fromList(tB.data));
    if (tA.strides[0] > 0 && tB.strides[0] > 0) {
      final res = AccelerationManager.ddot(
        n: length,
        x: asTypedList,
        xOffset: tA.offset,
        incX: tA.strides[0],
        y: bData,
        yOffset: tB.offset,
        incY: tB.strides[0],
      );
      if (res != null) return res;
    }
    // Fallback inlined loop
    final a = asTypedList;
    final aOff = tA.offset;
    final bOff = tB.offset;
    final aStr = tA.strides[0];
    final bStr = tB.strides[0];
    var sum = 0.0;
    for (var i = 0; i < length; i++) {
      sum += a[aOff + i * aStr] * bData[bOff + i * bStr];
    }
    return sum;
  }

  /// Euclidean L2 norm routing directly to BLAS `dnrm2`.
  double norm2() {
    final t = _vector.tensor;
    if (t.strides[0] > 0) {
      final res = AccelerationManager.dnrm2(
        n: length,
        x: asTypedList,
        xOffset: t.offset,
        incX: t.strides[0],
      );
      if (res != null) return res;
    }
    return math.sqrt(dot(this));
  }

  /// Inlined vector addition.
  @redeclare
  Float64Vector operator +(Vector<double> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${other.length}',
      );
    }
    final tA = _vector.tensor;
    final tB = other.tensor;
    if (tA.isContiguous &&
        tB.isContiguous &&
        tA.offset == 0 &&
        tB.offset == 0) {
      final out = Float64List(length);
      final a = asTypedList;
      final b = other is Float64Vector
          ? other.asTypedList
          : (tB.data is Float64List
                ? tB.data as Float64List
                : Float64List.fromList(tB.data));
      for (var i = 0; i < length; i++) {
        out[i] = a[i] + b[i];
      }
      return Float64Vector(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector(_vector + other);
  }

  /// Inlined vector subtraction.
  @redeclare
  Float64Vector operator -(Vector<double> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${other.length}',
      );
    }
    final tA = _vector.tensor;
    final tB = other.tensor;
    if (tA.isContiguous &&
        tB.isContiguous &&
        tA.offset == 0 &&
        tB.offset == 0) {
      final out = Float64List(length);
      final a = asTypedList;
      final b = other is Float64Vector
          ? other.asTypedList
          : (tB.data is Float64List
                ? tB.data as Float64List
                : Float64List.fromList(tB.data));
      for (var i = 0; i < length; i++) {
        out[i] = a[i] - b[i];
      }
      return Float64Vector(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector(_vector - other);
  }

  /// Inlined Hadamard (element-wise) multiplication.
  @redeclare
  Float64Vector operator *(Vector<double> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${other.length}',
      );
    }
    final tA = _vector.tensor;
    final tB = other.tensor;
    if (tA.isContiguous &&
        tB.isContiguous &&
        tA.offset == 0 &&
        tB.offset == 0) {
      final out = Float64List(length);
      final a = asTypedList;
      final b = other is Float64Vector
          ? other.asTypedList
          : (tB.data is Float64List
                ? tB.data as Float64List
                : Float64List.fromList(tB.data));
      for (var i = 0; i < length; i++) {
        out[i] = a[i] * b[i];
      }
      return Float64Vector(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector(_vector * other);
  }

  /// Inlined element-wise division.
  @redeclare
  Float64Vector operator /(Vector<double> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${other.length}',
      );
    }
    final tA = _vector.tensor;
    final tB = other.tensor;
    if (tA.isContiguous &&
        tB.isContiguous &&
        tA.offset == 0 &&
        tB.offset == 0) {
      final out = Float64List(length);
      final a = asTypedList;
      final b = other is Float64Vector
          ? other.asTypedList
          : (tB.data is Float64List
                ? tB.data as Float64List
                : Float64List.fromList(tB.data));
      for (var i = 0; i < length; i++) {
        out[i] = a[i] / b[i];
      }
      return Float64Vector(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector(_vector / other);
  }

  /// Inlined vector negation.
  @redeclare
  Float64Vector operator -() {
    final t = _vector.tensor;
    if (t.isContiguous && t.offset == 0) {
      final out = Float64List(length);
      final a = asTypedList;
      for (var i = 0; i < length; i++) {
        out[i] = -a[i];
      }
      return Float64Vector(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector(-_vector);
  }

  /// Inlined vector scaling.
  @redeclare
  Float64Vector scale(double scalar) {
    final t = _vector.tensor;
    if (t.isContiguous && t.offset == 0) {
      final out = Float64List(length);
      final a = asTypedList;
      for (var i = 0; i < length; i++) {
        out[i] = a[i] * scalar;
      }
      return Float64Vector(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector(_vector.scale(scalar));
  }
}
