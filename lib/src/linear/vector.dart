import 'dart:math' as math;
import 'dart:typed_data';

import '../acceleration/blas/blas.dart';
import '../tensor/layout.dart';
import '../tensor/operations/operation.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';
import 'matrix.dart';

/// 1-dimensional mathematical vector backed by a 1D [Tensor].
///
/// Conceptually, a vector is an ordered list of numbers with a magnitude
/// (length) and direction, like a geometric arrow $(x, y, z)$. Mathematically,
/// a vector represents an element of a finite-dimensional vector space
/// $V \cong T^n$ over the scalar field $T$.
///
/// ```dart
/// final v = Vector<double>.fromList([1.0, 2.0, 3.0]);
/// final len = v.length; // 3
/// ```
class Vector<T> {
  /// Creates a [Vector] wrapping a 1-dimensional [tensor].
  ///
  /// ```dart
  /// final t = Tensor<int>.fromIterable([1, 2, 3]);
  /// final v = Vector<int>(t);
  /// ```
  new(this.tensor)
    : assert(tensor.rank == 1, 'Tensor must have rank 1, got ${tensor.rank}');

  /// Constructs a [Vector] filled with [value].
  factory filled(int length, T value, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromInstance(value);
    final tensor = Tensor<T>.filled(
      value,
      shape: [length],
      type: effectiveType,
    );
    return Vector(tensor);
  }

  /// Constructs a [Vector] populated by [generator].
  factory generate(
    int length,
    T Function(int index) generator, {
    DataType<T>? type,
  }) {
    final effectiveType = type ?? DataType.fromType<T>();
    final data = effectiveType.newList(length);
    for (var i = 0; i < length; i++) {
      data[i] = generator(i);
    }
    return Vector(
      Tensor.internal(
        type: effectiveType,
        layout: Layout(shape: [length]),
        data: data,
      ),
    );
  }

  /// Constructs a [Vector] from a list of elements.
  factory fromList(List<T> list, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromIterable(list);
    final tensor = Tensor<T>.fromIterable(
      list,
      shape: [list.length],
      type: effectiveType,
    );
    return Vector(tensor);
  }

  /// Constructs a [Vector] from an iterable of elements.
  factory fromIterable(Iterable<T> iterable, {DataType<T>? type}) =>
      Vector.fromList(iterable.toList(growable: false), type: type);

  /// The underlying 1D [Tensor].
  final Tensor<T> tensor;

  /// The number of elements in this vector.
  int get length => tensor.length;

  /// The data type of the elements.
  DataType<T> get type => tensor.type;

  /// Gets the element at [index] without bounds checks.
  @pragma('vm:prefer-inline')
  T getUnchecked(int index) => tensor.get1D(index);

  /// Sets the element at [index] to [value] without bounds checks.
  @pragma('vm:prefer-inline')
  void setUnchecked(int index, T value) => tensor.set1D(index, value);

  /// Gets the element at [index].
  T operator [](int index) {
    RangeError.checkValidIndex(index, this, 'index', length);
    return getUnchecked(index);
  }

  /// Sets the element at [index] to [value].
  void operator []=(int index, T value) {
    RangeError.checkValidIndex(index, this, 'index', length);
    setUnchecked(index, value);
  }

  /// Element-wise vector addition.
  Vector<T> operator +(Vector<T> other) => Vector(tensor + other.tensor);

  /// Element-wise vector subtraction.
  Vector<T> operator -(Vector<T> other) => Vector(tensor - other.tensor);

  /// Element-wise Hadamard product.
  Vector<T> operator *(Vector<T> other) => Vector(tensor * other.tensor);

  /// Element-wise division.
  Vector<T> operator /(Vector<T> other) => Vector(tensor / other.tensor);

  /// Unary negation.
  Vector<T> operator -() => Vector(-tensor);

  /// Multiplies every element by [scalar].
  Vector<T> scale(T scalar) {
    final field = type.field;
    return Vector(
      tensor.unaryOperation((val) => field.mul(val, scalar), type: type),
    );
  }

  /// Computes the algebraic inner product (dot product) with [other].
  ///
  /// Conceptually, the dot product multiplies corresponding components and sums
  /// them: $u \cdot v = u_1 v_1 + u_2 v_2 + \dots$. If the dot product is zero,
  /// the vectors are orthogonal (perpendicular). More formally, this calculates
  /// the standard Hermitian inner product
  /// $\langle u, v \rangle = \sum_{i=1}^n \bar{u}_i v_i$, using conjugate
  /// multiplication for complex fields and hardware BLAS acceleration when
  /// available.
  ///
  /// ```dart
  /// final a = Vector<double>.fromList([1.0, 2.0, 3.0]);
  /// final b = Vector<double>.fromList([4.0, 5.0, 6.0]);
  /// final d = a.dot(b); // 32.0
  /// ```
  T dot(Vector<T> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${other.length}',
      );
    }
    if (T == double &&
        tensor.strides[0] > 0 &&
        other.tensor.strides[0] > 0 &&
        tensor.data is Float64List &&
        other.tensor.data is Float64List) {
      final res = Blas.ddot(
        n: length,
        x: tensor.data as Float64List,
        xOffset: tensor.offset,
        incX: tensor.strides[0],
        y: other.tensor.data as Float64List,
        yOffset: other.tensor.offset,
        incY: other.tensor.strides[0],
      );
      return res as T;
    } else if (T == double &&
        tensor.strides[0] > 0 &&
        other.tensor.strides[0] > 0 &&
        tensor.data is Float32List &&
        other.tensor.data is Float32List) {
      final res = Blas.sdot(
        n: length,
        x: tensor.data as Float32List,
        xOffset: tensor.offset,
        incX: tensor.strides[0],
        y: other.tensor.data as Float32List,
        yOffset: other.tensor.offset,
        incY: other.tensor.strides[0],
      );
      return res as T;
    }

    final field = type.field;
    var sum = field.additiveIdentity;
    final t1 = tensor;
    final t2 = other.tensor;
    if (t1.isContiguous && t2.isContiguous) {
      final d1 = t1.data, d2 = t2.data;
      final o1 = t1.offset, o2 = t2.offset;
      for (var i = 0; i < length; i++) {
        sum = field.add(
          sum,
          field.mul(field.conjugate(d1[o1 + i]), d2[o2 + i]),
        );
      }
    } else {
      for (var i = 0; i < length; i++) {
        sum = field.add(
          sum,
          field.mul(field.conjugate(getUnchecked(i)), other.getUnchecked(i)),
        );
      }
    }
    return sum;
  }

  /// Computes the outer product with [other], producing an $M \times N$ matrix.
  ///
  /// Conceptually, this multiplies each element of the first vector by each
  /// element of the second vector, producing a full rank-2 [Matrix]. Formally,
  /// this calculates the rank-1 tensor product
  /// $u \otimes v = u v^T \in T^{M \times N}$.
  ///
  /// ```dart
  /// final a = Vector<int>.fromList([1, 2]);
  /// final b = Vector<int>.fromList([3, 4, 5]);
  /// final m = a.outer(b); // 2x3 matrix
  /// ```
  Matrix<T> outer(Vector<T> other) {
    final rows = length;
    final cols = other.length;
    final field = type.field;
    final res = Matrix<T>.filled(rows, cols, type.defaultValue, type: type);
    for (var i = 0; i < rows; i++) {
      final xi = getUnchecked(i);
      for (var j = 0; j < cols; j++) {
        res.setUnchecked(i, j, field.mul(xi, other.getUnchecked(j)));
      }
    }
    return res;
  }

  /// Computes the 3-dimensional vector cross product $u \times v$ with [other].
  ///
  /// Conceptually, the cross product produces a vector perpendicular to both
  /// input vectors in 3-dimensional space. Formally:
  ///
  /// $$u \times v = (u_2 v_3 - u_3 v_2,\, u_3 v_1 - u_1 v_3,\, u_1 v_2 - u_2 v_1)$$
  ///
  /// Throws an [ArgumentError] if either vector does not have length 3.
  ///
  /// ```dart
  /// final u = Vector<double>.fromList([1.0, 0.0, 0.0]);
  /// final v = Vector<double>.fromList([0.0, 1.0, 0.0]);
  /// final w = u.cross(v); // [0.0, 0.0, 1.0]
  /// ```
  Vector<T> cross(Vector<T> other) {
    if (length != 3 || other.length != 3) {
      throw ArgumentError(
        'Cross product is only defined for 3D vectors, got $length and ${other.length}.',
      );
    }
    final field = type.field;
    final u0 = getUnchecked(0);
    final u1 = getUnchecked(1);
    final u2 = getUnchecked(2);
    final v0 = other.getUnchecked(0);
    final v1 = other.getUnchecked(1);
    final v2 = other.getUnchecked(2);
    return Vector<T>.fromList([
      field.sub(field.mul(u1, v2), field.mul(u2, v1)),
      field.sub(field.mul(u2, v0), field.mul(u0, v2)),
      field.sub(field.mul(u0, v1), field.mul(u1, v0)),
    ], type: type);
  }

  /// Computes the $L_p$ norm (length or magnitude) of this vector.
  ///
  /// Conceptually, the default norm ($p=2$) is the standard Euclidean length
  /// calculated via the Pythagorean theorem: $\sqrt{x^2 + y^2 + \dots}$.
  /// Formally, this calculates the $L_p$ metric
  /// $\|v\|_p = \left( \sum_{i=1}^n |v_i|^p \right)^{1/p}$, supporting $p=1$
  /// (Manhattan norm), $p=2$ (Euclidean norm), and $p=\infty$ (Chebyshev norm).
  ///
  /// ```dart
  /// final v = Vector<double>.fromList([3.0, 4.0]);
  /// final length = v.norm(); // 5.0
  /// ```
  double norm([num pNorm = 2]) {
    if (pNorm.isNaN || pNorm < 1) {
      throw ArgumentError.value(pNorm, 'pNorm', 'pNorm must be >= 1');
    }
    final field = type.field;
    if (pNorm == double.infinity) {
      var maxVal = 0.0;
      for (var i = 0; i < length; i++) {
        final val = field.norm(getUnchecked(i));
        if (val.isNaN) return double.nan;
        if (val > maxVal) maxVal = val;
      }
      return maxVal;
    }
    if (pNorm == 1) {
      var sum = 0.0;
      for (var i = 0; i < length; i++) {
        sum += field.norm(getUnchecked(i));
      }
      return sum;
    }
    if (pNorm == 2) {
      if (T == double && tensor.strides[0] > 0 && tensor.data is Float64List) {
        return Blas.dnrm2(
          n: length,
          x: tensor.data as Float64List,
          xOffset: tensor.offset,
          incX: tensor.strides[0],
        );
      } else if (T == double &&
          tensor.strides[0] > 0 &&
          tensor.data is Float32List) {
        return Blas.snrm2(
          n: length,
          x: tensor.data as Float32List,
          xOffset: tensor.offset,
          incX: tensor.strides[0],
        );
      }

      var scale = 0.0;
      var sumsq = 1.0;
      for (var i = 0; i < length; i++) {
        final absVal = field.norm(getUnchecked(i));
        if (absVal != 0.0) {
          if (absVal.isNaN) return double.nan;
          if (absVal.isInfinite) {
            scale = double.infinity;
          } else if (scale < absVal) {
            sumsq = 1.0 + sumsq * (scale / absVal) * (scale / absVal);
            scale = absVal;
          } else if (scale.isFinite) {
            sumsq += (absVal / scale) * (absVal / scale);
          }
        }
      }
      return scale * math.sqrt(sumsq);
    }
    var sumP = 0.0;
    for (var i = 0; i < length; i++) {
      sumP += math.pow(field.norm(getUnchecked(i)), pNorm);
    }
    return math.pow(sumP, 1.0 / pNorm).toDouble();
  }

  /// Adds scaled [other] vector in-place: $y \leftarrow y + \alpha \cdot x$.
  void addScaled(Vector<T> other, T alpha) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${other.length}',
      );
    }
    if (T == double &&
        alpha is num &&
        tensor.strides[0] > 0 &&
        other.tensor.strides[0] > 0 &&
        tensor.data is Float64List &&
        other.tensor.data is Float64List) {
      final success = Blas.daxpy(
        n: length,
        alpha: alpha.toDouble(),
        x: other.tensor.data as Float64List,
        xOffset: other.tensor.offset,
        incX: other.tensor.strides[0],
        y: tensor.data as Float64List,
        yOffset: tensor.offset,
        incY: tensor.strides[0],
      );
      if (success) return;
    } else if (T == double &&
        alpha is num &&
        tensor.strides[0] > 0 &&
        other.tensor.strides[0] > 0 &&
        tensor.data is Float32List &&
        other.tensor.data is Float32List) {
      final success = Blas.saxpy(
        n: length,
        alpha: alpha.toDouble(),
        x: other.tensor.data as Float32List,
        xOffset: other.tensor.offset,
        incX: other.tensor.strides[0],
        y: tensor.data as Float32List,
        yOffset: tensor.offset,
        incY: tensor.strides[0],
      );
      if (success) return;
    }
    final field = type.field;
    for (var i = 0; i < length; i++) {
      setUnchecked(
        i,
        field.add(getUnchecked(i), field.mul(alpha, other.getUnchecked(i))),
      );
    }
  }

  /// Scales every element in-place by [scalar]: $x \leftarrow \alpha \cdot x$.
  void scaleInPlace(T scalar) {
    if (T == double &&
        scalar is num &&
        tensor.strides[0] > 0 &&
        tensor.data is Float64List) {
      final success = Blas.dscal(
        n: length,
        alpha: scalar.toDouble(),
        x: tensor.data as Float64List,
        xOffset: tensor.offset,
        incX: tensor.strides[0],
      );
      if (success) return;
    } else if (T == double &&
        scalar is num &&
        tensor.strides[0] > 0 &&
        tensor.data is Float32List) {
      final success = Blas.sscal(
        n: length,
        alpha: scalar.toDouble(),
        x: tensor.data as Float32List,
        xOffset: tensor.offset,
        incX: tensor.strides[0],
      );
      if (success) return;
    }
    final field = type.field;
    for (var i = 0; i < length; i++) {
      setUnchecked(i, field.mul(getUnchecked(i), scalar));
    }
  }

  /// Returns the unit vector in the same direction.
  Vector<T> normalized() {
    final normVal = norm();
    if (normVal == 0.0) throw StateError('Cannot normalize zero vector');
    final field = type.field;
    final inv = field.div(
      field.multiplicativeIdentity,
      field.scale(field.multiplicativeIdentity, normVal),
    );
    return scale(inv);
  }

  /// Converts this vector into a matrix (as column $N \times 1$ or row
  /// $1 \times N$).
  Matrix<T> toMatrix({bool asColumn = true}) {
    final shape = asColumn ? [length, 1] : [1, length];
    return Matrix(tensor.reshape(shape));
  }

  /// Slices a subvector from [start] to [end].
  Vector<T> subVector(int start, [int? end]) {
    final actualEnd = end ?? length;
    final slicedLayout = tensor.layout.getRange(
      axis: 0,
      start: start,
      end: actualEnd,
    );
    return Vector(
      Tensor.internal(type: type, layout: slicedLayout, data: tensor.data),
    );
  }

  /// Creates a deep contiguous copy of this vector.
  Vector<T> copy({Vector<T>? target}) {
    if (target != null) {
      tensor.copy(target: target.tensor);
      return target;
    }
    return Vector(tensor.copy());
  }

  /// Sum of all elements in this vector.
  T get sum {
    final field = type.field;
    var acc = field.additiveIdentity;
    for (var i = 0; i < length; i++) {
      acc = field.add(acc, getUnchecked(i));
    }
    return acc;
  }

  /// Computes the cumulative sum (prefix sum) along this vector.
  ///
  /// Each element at index $i$ in the resulting vector is the sum of all
  /// elements from index $0$ to $i$.
  ///
  /// If [target] is provided, writes the result into [target] (which may be
  /// `this` for in-place computation) and returns it.
  ///
  /// ```dart
  /// final v = Vector<int>.fromList([1, 2, 3, 4]);
  /// final result = v.cumsum();
  /// print(result); // Vector([1, 3, 6, 10])
  /// ```
  Vector<T> cumsum({Vector<T>? target}) {
    final field = type.field;
    return _scan(field.additiveIdentity, field.add, target: target);
  }

  /// Computes the cumulative product (prefix product) along this vector.
  ///
  /// Each element at index $i$ in the resulting vector is the product of all
  /// elements from index $0$ to $i$.
  ///
  /// If [target] is provided, writes the result into [target] (which may be
  /// `this` for in-place computation) and returns it.
  ///
  /// ```dart
  /// final v = Vector<int>.fromList([1, 2, 3, 4]);
  /// final result = v.cumprod();
  /// print(result); // Vector([1, 2, 6, 24])
  /// ```
  Vector<T> cumprod({Vector<T>? target}) {
    final field = type.field;
    return _scan(field.multiplicativeIdentity, field.mul, target: target);
  }

  /// Returns a flat list of elements.
  List<T> toList() => tensor.toFlatList();

  @override
  String toString() => 'Vector(${toList()})';

  Vector<T> _scan(
    T initial,
    T Function(T acc, T value) combine, {
    Vector<T>? target,
  }) {
    if (target != null && target.length != length) {
      throw ArgumentError(
        'Target vector length must match: $length vs ${target.length}',
      );
    }
    final result =
        target ?? Vector<T>.filled(length, type.defaultValue, type: type);
    if (length == 0) return result;
    final Vector<T> effectiveSource;
    if (target != null &&
        !identical(this, target) &&
        identical(tensor.data, target.tensor.data)) {
      effectiveSource = copy();
    } else {
      effectiveSource = this;
    }
    final srcTensor = effectiveSource.tensor;
    final dstTensor = result.tensor;
    if (srcTensor.isContiguous && dstTensor.isContiguous) {
      final src = srcTensor.data;
      final dst = dstTensor.data;
      final srcOffset = srcTensor.offset;
      final dstOffset = dstTensor.offset;
      var acc = initial;
      for (var i = 0; i < length; i++) {
        acc = combine(acc, src[srcOffset + i]);
        dst[dstOffset + i] = acc;
      }
      return result;
    }
    var acc = initial;
    for (var i = 0; i < length; i++) {
      acc = combine(acc, effectiveSource.getUnchecked(i));
      result.setUnchecked(i, acc);
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Vector && other.tensor == tensor;

  @override
  int get hashCode => tensor.hashCode;
}
