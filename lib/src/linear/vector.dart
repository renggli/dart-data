import 'dart:math' as math;
import 'dart:typed_data';

import '../../type.dart';
import '../hardware/hardware.dart';
import '../tensor/layout.dart';
import '../tensor/operations/operation.dart';
import '../tensor/tensor.dart';
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
  factory filled(int length, T value, {DataType<T>? type, bool? native}) {
    final effectiveType = type ?? DataType.fromInstance(value);
    final tensor = Tensor<T>.filled(
      value,
      shape: [length],
      type: effectiveType,
      native: native,
    );
    return Vector(tensor);
  }

  /// Constructs a [Vector] populated by [generator].
  factory generate(
    int length,
    T Function(int index) generator, {
    DataType<T>? type,
    bool? native,
  }) {
    final effectiveType = type ?? DataType.fromType<T>();
    final data = effectiveType.newList(length, native: native);
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
  factory fromList(List<T> list, {DataType<T>? type, bool? native}) {
    final effectiveType = type ?? DataType.fromIterable(list);
    final tensor = Tensor<T>.fromIterable(
      list,
      shape: [list.length],
      type: effectiveType,
      native: native,
    );
    return Vector(tensor);
  }

  /// Constructs a [Vector] from an iterable of elements.
  factory fromIterable(
    Iterable<T> iterable, {
    DataType<T>? type,
    bool? native,
  }) => Vector.fromList(
    iterable.toList(growable: false),
    type: type,
    native: native,
  );

  /// Constructs a [Vector] with a sequence of [count] evenly spaced values over
  /// the interval `[start, stop]`.
  ///
  /// Conceptually, this partitions the continuous interval between [start] and
  /// [stop] into equal increments.
  ///
  /// When [endpoint] is `true` (the default), [stop] is included as the final
  /// value. When [endpoint] is `false`, the interval is divided into [count]
  /// sub-intervals and [stop] is excluded.
  ///
  /// ```dart
  /// final v = Vector.linspace(0.0, 1.0, count: 5);
  /// print(v); // [0.0, 0.25, 0.5, 0.75, 1.0]
  /// ```
  factory linspace(
    double start,
    double stop, {
    int count = 50,
    bool endpoint = true,
    DataType<T>? type,
    bool? native,
  }) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Count must be non-negative.');
    }
    final effectiveType = type ?? (DataType.float64 as DataType<T>);
    final data = effectiveType.newList(count, native: native);
    if (count == 1) {
      data[0] = start as T;
    } else if (count > 1) {
      final divisor = endpoint ? count - 1 : count;
      for (var i = 0; i < count; i++) {
        if (i == 0) {
          data[i] = start as T;
        } else if (endpoint && i == count - 1) {
          data[i] = stop as T;
        } else {
          final t = i / divisor;
          data[i] = (start * (1.0 - t) + stop * t) as T;
        }
      }
    }
    return Vector(
      Tensor.internal(
        type: effectiveType,
        layout: Layout(shape: [count]),
        data: data,
      ),
    );
  }

  /// Constructs a [Vector] with a sequence of [count] evenly spaced values on a
  /// logarithmic scale over `[base^start, base^stop]`.
  ///
  /// Conceptually, this evaluates [base] raised to powers that are linearly
  /// spaced from [start] to [stop].
  ///
  /// ```dart
  /// final v = Vector.logspace(0.0, 3.0, count: 4);
  /// print(v); // [1.0, 10.0, 100.0, 1000.0]
  /// ```
  factory logspace(
    double start,
    double stop, {
    int count = 50,
    double base = 10.0,
    bool endpoint = true,
    DataType<T>? type,
    bool? native,
  }) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Count must be non-negative.');
    }
    if (base <= 0.0) {
      throw ArgumentError.value(base, 'base', 'Base must be positive.');
    }
    final effectiveType = type ?? (DataType.float64 as DataType<T>);
    final data = effectiveType.newList(count, native: native);
    if (count == 1) {
      data[0] = math.pow(base, start).toDouble() as T;
    } else if (count > 1) {
      final divisor = endpoint ? count - 1 : count;
      for (var i = 0; i < count; i++) {
        if (i == 0) {
          data[i] = math.pow(base, start).toDouble() as T;
        } else if (endpoint && i == count - 1) {
          data[i] = math.pow(base, stop).toDouble() as T;
        } else {
          final t = i / divisor;
          final exp = start * (1.0 - t) + stop * t;
          data[i] = math.pow(base, exp).toDouble() as T;
        }
      }
    }
    return Vector(
      Tensor.internal(
        type: effectiveType,
        layout: Layout(shape: [count]),
        data: data,
      ),
    );
  }

  /// Constructs a [Vector] with a sequence of [count] geometrically spaced
  /// values over the interval `[start, stop]`.
  ///
  /// Both [start] and [stop] must be non-zero and share the same sign. Values
  /// are spaced evenly on a logarithmic scale such that each step has a
  /// constant multiplicative ratio.
  ///
  /// ```dart
  /// final v = Vector.geomspace(1.0, 1000.0, count: 4);
  /// print(v); // [1.0, 10.0, 100.0, 1000.0]
  /// ```
  factory geomspace(
    double start,
    double stop, {
    int count = 50,
    bool endpoint = true,
    DataType<T>? type,
    bool? native,
  }) {
    if (count < 0) {
      throw ArgumentError.value(count, 'count', 'Count must be non-negative.');
    }
    if (start == 0.0) {
      throw ArgumentError.value(
        start,
        'start',
        'Geometric spacing requires non-zero start.',
      );
    }
    if (stop == 0.0) {
      throw ArgumentError.value(
        stop,
        'stop',
        'Geometric spacing requires non-zero stop.',
      );
    }
    if ((start > 0) != (stop > 0)) {
      throw ArgumentError(
        'Geometric spacing requires start and stop to have the same sign.',
      );
    }
    final isNegative = start < 0.0;
    final effectiveStart = isNegative ? -start : start;
    final effectiveStop = isNegative ? -stop : stop;
    final logStart = math.log(effectiveStart);
    final logStop = math.log(effectiveStop);
    final effectiveType = type ?? (DataType.float64 as DataType<T>);
    final data = effectiveType.newList(count, native: native);
    if (count == 1) {
      data[0] = start as T;
    } else if (count > 1) {
      final divisor = endpoint ? count - 1 : count;
      for (var i = 0; i < count; i++) {
        if (i == 0) {
          data[i] = start as T;
        } else if (endpoint && i == count - 1) {
          data[i] = stop as T;
        } else {
          final t = i / divisor;
          final logVal = logStart * (1.0 - t) + logStop * t;
          final val = math.exp(logVal);
          data[i] = (isNegative ? -val : val) as T;
        }
      }
    }
    return Vector(
      Tensor.internal(
        type: effectiveType,
        layout: Layout(shape: [count]),
        data: data,
      ),
    );
  }

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
    return Vector(tensor.unaryOperation((val) => field.mul(val, scalar)));
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
      final res = HardwareManager.ddot(
        n: length,
        x: tensor.data as Float64List,
        xOffset: tensor.offset,
        incX: tensor.strides[0],
        y: other.tensor.data as Float64List,
        yOffset: other.tensor.offset,
        incY: other.tensor.strides[0],
      );
      if (res != null) return res as T;
    } else if (T == double &&
        tensor.strides[0] > 0 &&
        other.tensor.strides[0] > 0 &&
        tensor.data is Float32List &&
        other.tensor.data is Float32List) {
      final res = HardwareManager.sdot(
        n: length,
        x: tensor.data as Float32List,
        xOffset: tensor.offset,
        incX: tensor.strides[0],
        y: other.tensor.data as Float32List,
        yOffset: other.tensor.offset,
        incY: other.tensor.strides[0],
      );
      if (res != null) return res as T;
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
    final field = type.field;
    if (pNorm == double.infinity) {
      var maxVal = 0.0;
      for (var i = 0; i < length; i++) {
        final val = field.norm(getUnchecked(i));
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
        final res = HardwareManager.dnrm2(
          n: length,
          x: tensor.data as Float64List,
          xOffset: tensor.offset,
          incX: tensor.strides[0],
        );
        if (res != null) return res;
      } else if (T == double &&
          tensor.strides[0] > 0 &&
          tensor.data is Float32List) {
        final res = HardwareManager.snrm2(
          n: length,
          x: tensor.data as Float32List,
          xOffset: tensor.offset,
          incX: tensor.strides[0],
        );
        if (res != null) return res;
      }

      var sumSq = 0.0;
      for (var i = 0; i < length; i++) {
        final val = field.norm(getUnchecked(i));
        sumSq += val * val;
      }
      return math.sqrt(sumSq);
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
      final success = HardwareManager.daxpy(
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
      final success = HardwareManager.saxpy(
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
      final success = HardwareManager.dscal(
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
      final success = HardwareManager.sscal(
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
  Vector<T> copy() => Vector(tensor.copy());

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
    final field = type.field;
    final srcTensor = effectiveSource.tensor;
    final dstTensor = result.tensor;
    if (srcTensor.isContiguous && dstTensor.isContiguous) {
      final src = srcTensor.data;
      final dst = dstTensor.data;
      final srcOffset = srcTensor.offset;
      final dstOffset = dstTensor.offset;
      var acc = field.additiveIdentity;
      for (var i = 0; i < length; i++) {
        acc = field.add(acc, src[srcOffset + i]);
        dst[dstOffset + i] = acc;
      }
      return result;
    }
    var acc = field.additiveIdentity;
    for (var i = 0; i < length; i++) {
      acc = field.add(acc, effectiveSource.getUnchecked(i));
      result.setUnchecked(i, acc);
    }
    return result;
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
    final field = type.field;
    final srcTensor = effectiveSource.tensor;
    final dstTensor = result.tensor;
    if (srcTensor.isContiguous && dstTensor.isContiguous) {
      final src = srcTensor.data;
      final dst = dstTensor.data;
      final srcOffset = srcTensor.offset;
      final dstOffset = dstTensor.offset;
      var acc = field.multiplicativeIdentity;
      for (var i = 0; i < length; i++) {
        acc = field.mul(acc, src[srcOffset + i]);
        dst[dstOffset + i] = acc;
      }
      return result;
    }
    var acc = field.multiplicativeIdentity;
    for (var i = 0; i < length; i++) {
      acc = field.mul(acc, effectiveSource.getUnchecked(i));
      result.setUnchecked(i, acc);
    }
    return result;
  }

  /// Returns a flat list of elements.
  List<T> toList() => tensor.toFlatList();

  @override
  String toString() => 'Vector(${toList()})';
}
