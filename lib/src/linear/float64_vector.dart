import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';

import '../acceleration/blas/blas.dart';
import '../tensor/layout.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';
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
extension type Float64Vector._(Vector<double> _vector)
    implements Vector<double> {
  /// Constructs a [Float64Vector] wrapping [vector].
  ///
  /// Throws an [ArgumentError] if `vector.tensor.data` is not a [Float64List].
  factory(Vector<double> vector) {
    if (vector.tensor.data is! Float64List) {
      throw ArgumentError.value(
        vector,
        'vector',
        'Float64Vector requires underlying data to be Float64List, got ${vector.tensor.data.runtimeType}',
      );
    }
    return Float64Vector._(vector);
  }

  /// Constructs a [Float64Vector] from any [Vector<double>], copying elements
  /// to a [Float64List] if not already backed by one.
  factory fromDoubleVector(Vector<double> vector) {
    if (vector.tensor.data is Float64List) {
      return Float64Vector._(vector);
    }
    return Float64Vector._(
      Vector<double>.generate(
        vector.length,
        (i) => vector[i],
        type: DataType.float64,
      ),
    );
  }

  /// Constructs a [Float64Vector] filled with [value].
  factory filled(int length, double value) => Float64Vector._(
    Vector<double>.filled(length, value, type: DataType.float64),
  );

  /// Constructs a [Float64Vector] populated by [generator].
  factory generate(int length, double Function(int index) generator) =>
      Float64Vector._(
        Vector<double>.generate(length, generator, type: DataType.float64),
      );

  /// Constructs a [Float64Vector] from a list of elements.
  factory fromList(List<double> list) =>
      Float64Vector._(Vector<double>.fromList(list, type: DataType.float64));

  /// Constructs a [Float64Vector] from an iterable of elements.
  factory fromIterable(Iterable<double> iterable) => Float64Vector._(
    Vector<double>.fromIterable(iterable, type: DataType.float64),
  );

  /// Direct zero-copy access to the underlying [Float64List] buffer.
  Float64List get asTypedList => _vector.tensor.data as Float64List;

  /// Fast element access at [index] without bounds checking.
  @pragma('vm:prefer-inline')
  @redeclare
  double getUnchecked(int index) {
    final t = _vector.tensor;
    return asTypedList[t.offset + index * t.strides[0]];
  }

  /// Fast element mutation at [index] without bounds checking.
  @pragma('vm:prefer-inline')
  @redeclare
  void setUnchecked(int index, double value) {
    final t = _vector.tensor;
    asTypedList[t.offset + index * t.strides[0]] = value;
  }

  /// Fast element access at [index].
  @pragma('vm:prefer-inline')
  @redeclare
  double operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return getUnchecked(index);
  }

  /// Fast element mutation at [index].
  @pragma('vm:prefer-inline')
  @redeclare
  void operator []=(int index, double value) {
    RangeError.checkValidIndex(index, this, 'index', length);
    setUnchecked(index, value);
  }

  /// Returns a zero-copy subvector view from [start] to [end] as [Float64Vector].
  @redeclare
  Float64Vector subVector(int start, [int? end]) =>
      Float64Vector._(_vector.subVector(start, end));

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
    final bData = tB.data is Float64List
        ? tB.data as Float64List
        : Float64List.fromList(tB.data);
    if (tA.strides[0] > 0 && tB.strides[0] > 0) {
      return Blas.ddot(
        n: length,
        x: asTypedList,
        xOffset: tA.offset,
        incX: tA.strides[0],
        y: bData,
        yOffset: tB.offset,
        incY: tB.strides[0],
      );
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

  /// Computes the $p$-norm of this vector.
  ///
  /// For $p = 2$ (default Euclidean norm), routes directly to BLAS `dnrm2`.
  @redeclare
  double norm([num pNorm = 2]) {
    if (pNorm == 2) {
      final t = _vector.tensor;
      if (t.strides[0] > 0) {
        return Blas.dnrm2(
          n: length,
          x: asTypedList,
          xOffset: t.offset,
          incX: t.strides[0],
        );
      }
      return math.sqrt(dot(this));
    }
    return _vector.norm(pNorm);
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
    if (tA.isContiguous && tB.isContiguous) {
      final out = Float64List(length);
      final a = asTypedList;
      final aOff = tA.offset;
      final bOff = tB.offset;
      if (tB.data is Float64List) {
        final b = tB.data as Float64List;
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] + b[bOff + i];
        }
      } else {
        final b = tB.data;
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] + b[bOff + i];
        }
      }
      return Float64Vector._(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector._(_vector + other);
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
    if (tA.isContiguous && tB.isContiguous) {
      final out = Float64List(length);
      final a = asTypedList;
      final aOff = tA.offset;
      final bOff = tB.offset;
      if (tB.data is Float64List) {
        final b = tB.data as Float64List;
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] - b[bOff + i];
        }
      } else {
        final b = tB.data;
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] - b[bOff + i];
        }
      }
      return Float64Vector._(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector._(_vector - other);
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
    if (tA.isContiguous && tB.isContiguous) {
      final out = Float64List(length);
      final a = asTypedList;
      final aOff = tA.offset;
      final bOff = tB.offset;
      if (tB.data is Float64List) {
        final b = tB.data as Float64List;
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] * b[bOff + i];
        }
      } else {
        final b = tB.data;
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] * b[bOff + i];
        }
      }
      return Float64Vector._(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector._(_vector * other);
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
    if (tA.isContiguous && tB.isContiguous) {
      final out = Float64List(length);
      final a = asTypedList;
      final aOff = tA.offset;
      final bOff = tB.offset;
      if (tB.data is Float64List) {
        final b = tB.data as Float64List;
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] / b[bOff + i];
        }
      } else {
        final b = tB.data;
        for (var i = 0; i < length; i++) {
          out[i] = a[aOff + i] / b[bOff + i];
        }
      }
      return Float64Vector._(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector._(_vector / other);
  }

  /// Inlined vector negation.
  @redeclare
  Float64Vector operator -() {
    final t = _vector.tensor;
    if (t.isContiguous) {
      final out = Float64List(length);
      final a = asTypedList;
      final aOff = t.offset;
      for (var i = 0; i < length; i++) {
        out[i] = -a[aOff + i];
      }
      return Float64Vector._(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector._(-_vector);
  }

  /// Inlined vector scaling.
  @redeclare
  Float64Vector scale(double scalar) {
    final t = _vector.tensor;
    if (t.isContiguous) {
      final out = Float64List(length);
      final a = asTypedList;
      final aOff = t.offset;
      for (var i = 0; i < length; i++) {
        out[i] = a[aOff + i] * scalar;
      }
      return Float64Vector._(
        Vector(
          Tensor.internal(
            type: DataType.float64,
            layout: Layout(shape: [length]),
            data: out,
          ),
        ),
      );
    }
    return Float64Vector._(_vector.scale(scalar));
  }

  /// Returns the unit vector in the same direction as [Float64Vector].
  @redeclare
  Float64Vector normalized() => Float64Vector._(_vector.normalized());

  /// Creates a deep contiguous copy of this vector as [Float64Vector].
  @redeclare
  Float64Vector copy({Float64Vector? target}) {
    if (target != null) {
      _vector.copy(target: target._vector);
      return target;
    }
    return Float64Vector._(_vector.copy());
  }

  /// Computes the cumulative sum (prefix sum) along this vector.
  @redeclare
  Float64Vector cumsum({Float64Vector? target}) {
    if (target != null) {
      _vector.cumsum(target: target._vector);
      return target;
    }
    return Float64Vector._(_vector.cumsum());
  }

  /// Computes the cumulative product (prefix product) along this vector.
  @redeclare
  Float64Vector cumprod({Float64Vector? target}) {
    if (target != null) {
      _vector.cumprod(target: target._vector);
      return target;
    }
    return Float64Vector._(_vector.cumprod());
  }
}
