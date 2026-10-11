import 'package:meta/meta.dart';

import '../../type.dart';
import 'layout.dart';
import 'operations/operation.dart';

/// Multi-dimensional dense array backed by a flat buffer and strided layout.
///
/// Conceptually, a tensor is an organized multidimensional grid of numbers or
/// values:
/// - Rank 0: a single scalar value
/// - Rank 1: a list of numbers (a vector)
/// - Rank 2: a table or grid of numbers (a matrix)
/// - Rank 3+: a cube or hyper-cube of numbers (e.g. RGB color channels of an
///   image)
///
/// Formally, a tensor represents a multi-linear array over
/// $\mathbb{R}^{d_1 \times \dots \times d_k}$ backed by a contiguous 1D memory
/// array and an affine strided indexing layout
/// $\text{offset} + \sum_{i=0}^{k-1} c_i \cdot s_i$.
///
/// ```dart
/// final t = Tensor<double>.filled(0.0, shape: [2, 3]);
/// t.setValue([0, 1], 42.0);
/// final val = t.getValue([0, 1]); // 42.0
/// ```
class Tensor<T> {
  @internal
  new internal({required this.type, required this.layout, required this.data});

  /// Constructs a [Tensor] with every entry initialized to [value].
  ///
  /// Conceptually, this creates a tensor where every cell contains the
  /// specified [value].
  ///
  /// Formally, this initializes $T \in S^{d_0 \times \dots \times d_{k-1}}$
  /// where $T_{i_0,\dots,i_{k-1}} = \text{value}$ for all indices.
  ///
  /// ```dart
  /// final t = Tensor<int>.filled(7, shape: [2, 3]);
  /// // [[7, 7, 7], [7, 7, 7]]
  /// ```
  factory filled(
    T value, {
    List<int>? shape,
    List<int>? strides,
    DataType<T>? type,
    bool? native,
  }) {
    final effectiveType = type ?? DataType.fromInstance(value);
    final effectiveLayout = Layout(shape: shape, strides: strides);
    final data = effectiveType.newList(
      effectiveLayout.length,
      fillValue: value,
      native: native,
    );
    return Tensor.internal(
      type: effectiveType,
      layout: effectiveLayout,
      data: data,
    );
  }

  /// Constructs a [Tensor] populated by calling [generator] on each coordinate
  /// key.
  ///
  /// Conceptually, this populates each cell by evaluating [generator] with its
  /// multi-dimensional coordinate key.
  ///
  /// Formally, this evaluates a coordinate map
  /// $f: \prod_{j=0}^{k-1} \{0, \dots, d_j - 1\} \to T$.
  ///
  /// ```dart
  /// final t = Tensor<int>.generate(
  ///   (key) => key[0] * 10 + key[1],
  ///   shape: [2, 3],
  /// );
  /// // t.getValue([1, 2]) == 12
  /// ```
  factory generate(
    T Function(List<int> key) generator, {
    required List<int> shape,
    List<int>? strides,
    DataType<T>? type,
    bool? native,
  }) {
    final effectiveLayout = Layout(shape: shape, strides: strides);
    final effectiveType = type ?? DataType.fromType<T>();
    final data = effectiveType.newList(effectiveLayout.length, native: native);
    final tensor = Tensor.internal(
      type: effectiveType,
      layout: effectiveLayout,
      data: data,
    );
    for (final key in effectiveLayout.keys) {
      tensor.setValue(key, generator(key));
    }
    return tensor;
  }

  /// Constructs a [Tensor] by copying elements from a 1D [iterable].
  ///
  /// Conceptually, this takes a flat sequence of values and structures them
  /// into a multi-dimensional tensor of the requested [shape].
  ///
  /// Formally, this reads elements in lexicographical (row-major) order into
  /// the tensor $T \in S^{d_0 \times \dots \times d_{k-1}}$.
  ///
  /// ```dart
  /// final t = Tensor<int>.fromIterable([1, 2, 3, 4, 5, 6], shape: [2, 3]);
  /// // [[1, 2, 3], [4, 5, 6]]
  /// ```
  factory fromIterable(
    Iterable<T> iterable, {
    List<int>? shape,
    List<int>? strides,
    DataType<T>? type,
    bool? native,
  }) {
    final list = iterable.toList(growable: false);
    final effectiveType = type ?? DataType.fromIterable(list);
    final effectiveLayout = shape != null
        ? Layout(shape: shape, strides: strides)
        : Layout(shape: [list.length], strides: strides);
    final data = effectiveType.newList(effectiveLayout.length, native: native);
    for (var i = 0; i < list.length && i < effectiveLayout.length; i++) {
      data[i] = list[i];
    }
    return Tensor.internal(
      type: effectiveType,
      layout: effectiveLayout,
      data: data,
    );
  }

  /// Constructs a [Tensor] from nested Dart lists or scalar objects.
  ///
  /// Conceptually, this constructs a tensor from nested Dart lists or scalar
  /// objects (such as `[[1, 2], [3, 4]]`).
  ///
  /// Formally, this performs recursive isomorphism between nested lists and
  /// multidimensional strided buffers.
  ///
  /// ```dart
  /// final t = Tensor<int>.fromObject([[1, 2, 3], [4, 5, 6]]);
  /// // t.rank == 2, t.shape == [2, 3]
  /// ```
  factory fromObject(dynamic object, {DataType<T>? type, bool? native}) {
    if (object is! Iterable) {
      if (object is T) {
        return Tensor.filled(
          object,
          shape: const [],
          type: type,
          native: native,
        );
      }
      throw ArgumentError.value(object, 'object', 'Expected an Iterable');
    }
    if (object.isEmpty) {
      final effectiveType = type ?? DataType.fromType<T>();
      return Tensor.fromIterable(
        <T>[],
        shape: const [0],
        type: effectiveType,
        native: native,
      );
    }
    final shape = <int>[];
    dynamic current = object;
    while (current is Iterable) {
      shape.add(current.length);
      if (current.isEmpty) break;
      current = current.first;
    }

    final flatList = <T>[];
    void flatten(dynamic item) {
      if (item is Iterable) {
        for (final child in item) {
          flatten(child);
        }
      } else {
        flatList.add(item as T);
      }
    }

    flatten(object);
    return Tensor.fromIterable(
      flatList,
      shape: shape,
      type: type,
      native: native,
    );
  }

  /// The [DataType] defining element storage, operations, and zero-values.
  final DataType<T> type;

  /// The [Layout] governing the strided shape, dimensions, and index mapping.
  final Layout layout;

  /// The underlying flat memory buffer.
  final List<T> data;

  /// Checks whether this tensor shares underlying memory with [other].
  bool sharesMemoryWith(Tensor<dynamic> other) =>
      sharesMemory(data, other.data);

  /// The number of dimensions (axes) in this tensor.
  ///
  /// Rank 0 is a scalar, rank 1 is a vector, rank 2 is a matrix.
  int get rank => layout.rank;

  /// The total count of elements across all dimensions.
  int get length => layout.length;

  /// The dimensions of the tensor along each axis.
  List<int> get shape => layout.shape;

  /// The memory strides (step sizes) along each dimension.
  List<int> get strides => layout.strides;

  /// The starting offset within the flat [data] buffer.
  int get offset => layout.offset;

  /// Whether the elements are stored contiguously in standard row-major order.
  bool get isContiguous => layout.isContiguous;

  /// Returns an iterable over the values in index order.
  Iterable<T> get values => layout.indices.map((idx) => data[idx]);

  /// Returns the flattened elements as a list.
  List<T> toFlatList() => values.toList(growable: false);

  /// Converts the tensor to a nested Dart list structure matching [shape].
  dynamic toNestedList() {
    dynamic build(List<int> prefix, int dim) {
      if (dim == rank) {
        return getValue(prefix);
      }
      final len = shape[dim];
      final res = List<dynamic>.filled(len, null, growable: false);
      for (var i = 0; i < len; i++) {
        prefix.add(i);
        res[i] = build(prefix, dim + 1);
        prefix.removeLast();
      }
      return res;
    }

    return build(<int>[], 0);
  }

  /// Gets the value at the given coordinate key.
  T getValue(List<int> key) => data[layout.toIndex(key)];

  /// Sets the value at the given coordinate key.
  void setValue(List<int> key, T value) => data[layout.toIndex(key)] = value;

  /// Returns the value at [r] and [c] without bounds checks for rank-2 tensors.
  @pragma('vm:prefer-inline')
  T get2D(int r, int c) =>
      data[layout.offset + r * layout.strides[0] + c * layout.strides[1]];

  /// Sets the value at [r] and [c] to [value] without bounds checks for rank-2
  /// tensors.
  @pragma('vm:prefer-inline')
  void set2D(int r, int c, T value) =>
      data[layout.offset + r * layout.strides[0] + c * layout.strides[1]] =
          value;

  /// Returns the value at [index] without bounds checks for rank-1 tensors.
  @pragma('vm:prefer-inline')
  T get1D(int index) => data[layout.offset + index * layout.strides[0]];

  /// Sets the value at [index] to [value] without bounds checks for rank-1
  /// tensors.
  @pragma('vm:prefer-inline')
  void set1D(int index, T value) =>
      data[layout.offset + index * layout.strides[0]] = value;

  /// Slices the first axis at [index].
  Tensor<T> operator [](int index) =>
      Tensor.internal(type: type, layout: layout[index], data: data);

  /// Zero-copy transposition of axes.
  Tensor<T> transpose([List<int>? axes]) =>
      Tensor.internal(type: type, layout: layout.transpose(axes), data: data);

  /// Zero-copy reshape if contiguous, otherwise copies.
  Tensor<T> reshape(List<int> newShape) {
    if (layout.isContiguous) {
      return Tensor.internal(
        type: type,
        layout: layout.reshape(newShape),
        data: data,
      );
    }
    return copy().reshape(newShape);
  }

  /// Zero-copy flip along [axis].
  Tensor<T> flip({int axis = 0}) => Tensor.internal(
    type: type,
    layout: layout.flip(axis: axis),
    data: data,
  );

  /// Slices a range along [axis].
  Tensor<T> getRange({required int axis, int? start, int? end, int step = 1}) =>
      Tensor.internal(
        type: type,
        layout: layout.getRange(axis: axis, start: start, end: end, step: step),
        data: data,
      );

  /// Returns a zero-copy strided multi-axis slice of this tensor.
  Tensor<T> slice(List<Slice> slices) =>
      Tensor<T>.internal(type: type, layout: layout.slice(slices), data: data);

  /// Creates a contiguous deep copy of this tensor.
  Tensor<T> copy({Tensor<T>? target}) {
    if (target != null) {
      return unaryOperation<T>((value) => value, target: target);
    }
    final out = Tensor.filled(
      type.defaultValue,
      shape: layout.shape,
      type: type,
    );
    return unaryOperation<T>((value) => value, target: out);
  }

  @override
  String toString() =>
      'Tensor(type: $type, layout: $layout, values: ${values.take(10).toList()}${length > 10 ? '...' : ''})';
}
