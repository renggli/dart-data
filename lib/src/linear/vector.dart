import 'dart:math' as math;

import '../tensor/operations/operation.dart';
import '../tensor/tensor.dart';
import '../type/data_type.dart';
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
    final f = type.field;
    return Vector(tensor.unaryOperation((v) => f.mul(v, scalar)));
  }

  /// Computes the algebraic inner product (dot product) with [other].
  T dot(Vector<T> other) {
    if (length != other.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${other.length}',
      );
    }
    final f = type.field;
    var sum = f.additiveIdentity;
    final t1 = tensor;
    final t2 = other.tensor;
    if (t1.isContiguous && t2.isContiguous) {
      final d1 = t1.data, d2 = t2.data;
      final o1 = t1.offset, o2 = t2.offset;
      for (var i = 0; i < length; i++) {
        sum = f.add(sum, f.mul(f.conjugate(d1[o1 + i]), d2[o2 + i]));
      }
    } else {
      for (var i = 0; i < length; i++) {
        sum = f.add(sum, f.mul(f.conjugate(this[i]), other[i]));
      }
    }
    return sum;
  }

  /// Computes the outer product with [other], producing an [M x N] matrix.
  Matrix<T> outer(Vector<T> other) {
    final m = length;
    final n = other.length;
    final f = type.field;
    final res = Matrix<T>.filled(m, n, type.defaultValue, type: type);
    for (var i = 0; i < m; i++) {
      final xi = this[i];
      for (var j = 0; j < n; j++) {
        res.set(i, j, f.mul(xi, other[j]));
      }
    }
    return res;
  }

  /// Computes the $L_p$ norm of this vector.
  double norm([num p = 2]) {
    final f = type.field;
    if (p == double.infinity) {
      var maxVal = 0.0;
      for (var i = 0; i < length; i++) {
        final val = f.norm(this[i]);
        if (val > maxVal) maxVal = val;
      }
      return maxVal;
    }
    if (p == 1) {
      var sum = 0.0;
      for (var i = 0; i < length; i++) {
        sum += f.norm(this[i]);
      }
      return sum;
    }
    if (p == 2) {
      var sumSq = 0.0;
      for (var i = 0; i < length; i++) {
        final val = f.norm(this[i]);
        sumSq += val * val;
      }
      return math.sqrt(sumSq);
    }
    var sumP = 0.0;
    for (var i = 0; i < length; i++) {
      sumP += math.pow(f.norm(this[i]), p);
    }
    return math.pow(sumP, 1.0 / p).toDouble();
  }

  /// Returns the unit vector in the same direction.
  Vector<T> normalized() {
    final n = norm();
    if (n == 0.0) throw StateError('Cannot normalize zero vector');
    final f = type.field;
    final inv = f.div(
      f.multiplicativeIdentity,
      f.scale(f.multiplicativeIdentity, n),
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
    final f = type.field;
    var acc = f.additiveIdentity;
    for (var i = 0; i < length; i++) {
      acc = f.add(acc, this[i]);
    }
    return acc;
  }

  /// Returns a flat list of elements.
  List<T> toList() => tensor.toFlatList();

  @override
  String toString() => 'Vector(${toList()})';
}
