import '../type/data_type.dart';
import '../type/memory_buffer.dart';
import 'layout.dart';
import 'operations/operation.dart';

/// Multi-dimensional dense array backed by a flat buffer and strided layout.
class Tensor<T> {
  new internal({required this.type, required this.layout, required this.data})
    : buffer = MemoryBuffer<T>(data);

  /// Constructs a tensor filled with [value].
  factory filled(
    T value, {
    List<int>? shape,
    List<int>? strides,
    DataType<T>? type,
  }) {
    final effectiveType = type ?? DataType.fromInstance(value);
    final effectiveLayout = Layout(shape: shape, strides: strides);
    final data = effectiveType.newList(
      effectiveLayout.length,
      fillValue: value,
    );
    return Tensor.internal(
      type: effectiveType,
      layout: effectiveLayout,
      data: data,
    );
  }

  /// Constructs a tensor populated by calling [generator] on each coordinate key.
  factory generate(
    T Function(List<int> key) generator, {
    required List<int> shape,
    List<int>? strides,
    DataType<T>? type,
  }) {
    final effectiveLayout = Layout(shape: shape, strides: strides);
    final effectiveType = type ?? DataType.fromType<T>();
    final data = effectiveType.newList(effectiveLayout.length);
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

  /// Constructs a tensor from a 1D iterable.
  factory fromIterable(
    Iterable<T> iterable, {
    List<int>? shape,
    List<int>? strides,
    DataType<T>? type,
  }) {
    final list = iterable.toList(growable: false);
    final effectiveType = type ?? DataType.fromIterable(list);
    final effectiveLayout = shape != null
        ? Layout(shape: shape, strides: strides)
        : Layout(shape: [list.length], strides: strides);
    final data = effectiveType.newList(effectiveLayout.length);
    for (var i = 0; i < list.length && i < effectiveLayout.length; i++) {
      data[i] = list[i];
    }
    return Tensor.internal(
      type: effectiveType,
      layout: effectiveLayout,
      data: data,
    );
  }

  /// Constructs a tensor from nested Dart lists / objects.
  factory fromObject(dynamic object, {DataType<T>? type}) {
    if (object is! Iterable) {
      if (object is T) {
        return Tensor.filled(object, shape: const [], type: type);
      }
      throw ArgumentError.value(object, 'object', 'Expected an Iterable');
    }
    if (object.isEmpty) {
      final effectiveType = type ?? DataType.fromType<T>();
      return Tensor.fromIterable(<T>[], shape: const [0], type: effectiveType);
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
    return Tensor.fromIterable(flatList, shape: shape, type: type);
  }

  final DataType<T> type;
  final Layout layout;
  final List<T> data;
  final MemoryBuffer<T> buffer;

  int get rank => layout.rank;
  int get length => layout.length;
  List<int> get shape => layout.shape;
  List<int> get strides => layout.strides;
  int get offset => layout.offset;
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

  /// Creates a contiguous deep copy of this tensor.
  Tensor<T> copy({Tensor<T>? target}) {
    if (target != null) {
      return unaryOperation<T>((v) => v, target: target);
    }
    final out = Tensor.filled(
      type.defaultValue,
      shape: layout.shape,
      type: type,
    );
    return unaryOperation<T>((v) => v, target: out);
  }

  @override
  String toString() =>
      'Tensor(type: $type, layout: $layout, values: ${values.take(10).toList()}${length > 10 ? '...' : ''})';
}
