import 'dart:math' as math;
import 'dart:typed_data';

import '../../type.dart';
import '../hardware/hardware.dart';
import '../tensor/operations/operation.dart';
import '../tensor/tensor.dart';
import 'matrix.dart';

/// 1-dimensional mathematical vector backed by a 1D [Tensor].
class Vector<T> {
  new(this.tensor)
    : assert(tensor.rank == 1, 'Tensor must have rank 1, got ${tensor.rank}');

  /// Constructs a vector filled with [value].
  factory filled(int length, T value, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromInstance(value);
    final tensor = Tensor<T>.filled(
      value,
      shape: [length],
      type: effectiveType,
    );
    return Vector(tensor);
  }

  /// Constructs a vector with [length] elements backed by off-heap native memory.
  factory native(int length, {DataType<T>? type}) =>
      Vector(Tensor<T>.native(shape: [length], type: type));

  /// Constructs a vector populated by [generator].
  factory generate(
    int length,
    T Function(int index) generator, {
    DataType<T>? type,
  }) {
    final effectiveType = type ?? DataType.fromType<T>();
    final tensor = Tensor<T>.generate(
      (key) => generator(key[0]),
      shape: [length],
      type: effectiveType,
    );
    return Vector(tensor);
  }

  /// Constructs a vector from a list of elements.
  factory fromList(List<T> list, {DataType<T>? type}) {
    final effectiveType = type ?? DataType.fromIterable(list);
    final tensor = Tensor<T>.fromIterable(
      list,
      shape: [list.length],
      type: effectiveType,
    );
    return Vector(tensor);
  }

  /// Constructs a vector from an iterable of elements.
  factory fromIterable(Iterable<T> iterable, {DataType<T>? type}) =>
      Vector.fromList(iterable.toList(growable: false), type: type);

  /// The underlying 1D tensor.
  final Tensor<T> tensor;

  /// The number of elements in this vector.
  int get length => tensor.length;

  /// The data type of the elements.
  DataType<T> get type => tensor.type;

  /// Gets the element at [index].
  T operator [](int index) => tensor.data[tensor.layout.toIndex([index])];

  /// Sets the element at [index] to [value].
  void operator []=(int index, T value) {
    tensor.data[tensor.layout.toIndex([index])] = value;
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
        sum = field.add(sum, field.mul(field.conjugate(this[i]), other[i]));
      }
    }
    return sum;
  }

  /// Computes the outer product with [other], producing an [M x N] matrix.
  Matrix<T> outer(Vector<T> other) {
    final rows = length;
    final cols = other.length;
    final field = type.field;
    final res = Matrix<T>.filled(rows, cols, type.defaultValue, type: type);
    for (var i = 0; i < rows; i++) {
      final xi = this[i];
      for (var j = 0; j < cols; j++) {
        res.set(i, j, field.mul(xi, other[j]));
      }
    }
    return res;
  }

  /// Computes the $L_p$ norm of this vector.
  double norm([num pNorm = 2]) {
    final field = type.field;
    if (pNorm == double.infinity) {
      var maxVal = 0.0;
      for (var i = 0; i < length; i++) {
        final val = field.norm(this[i]);
        if (val > maxVal) maxVal = val;
      }
      return maxVal;
    }
    if (pNorm == 1) {
      var sum = 0.0;
      for (var i = 0; i < length; i++) {
        sum += field.norm(this[i]);
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
        final val = field.norm(this[i]);
        sumSq += val * val;
      }
      return math.sqrt(sumSq);
    }
    var sumP = 0.0;
    for (var i = 0; i < length; i++) {
      sumP += math.pow(field.norm(this[i]), pNorm);
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
      this[i] = field.add(this[i], field.mul(alpha, other[i]));
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
      this[i] = field.mul(this[i], scalar);
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

  /// Converts this vector into a matrix (as column [N x 1] or row [1 x N]).
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
      acc = field.add(acc, this[i]);
    }
    return acc;
  }

  /// Returns a flat list of elements.
  List<T> toList() => tensor.toFlatList();

  @override
  String toString() => 'Vector(${toList()})';
}
