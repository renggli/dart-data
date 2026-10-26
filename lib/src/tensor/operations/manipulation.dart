import '../layout.dart';
import '../tensor.dart';

extension ManipulationTensorExtension<T> on Tensor<T> {
  /// Concatenates this tensor with [other] along [axis].
  ///
  /// Conceptually, this joins two tensors side-by-side or end-to-end along
  /// [axis].
  ///
  /// Formally, this forms a direct concatenation along coordinate axis $k$.
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([[1, 2]]);
  /// final b = Tensor<int>.fromObject([[3, 4]]);
  /// final c = a.concatenate(b, axis: 0);
  /// // c has shape [2, 2] and values [[1, 2], [3, 4]]
  /// ```
  Tensor<T> concatenate(Tensor<T> other, {int axis = 0}) =>
      concatenateAll([this, other], axis: axis);

  /// Concatenates a list of [tensors] along the specified [axis].
  static Tensor<E> concatenateAll<E>(List<Tensor<E>> tensors, {int axis = 0}) {
    if (tensors.isEmpty) throw ArgumentError('Tensors list cannot be empty');
    final first = tensors.first;
    final rank = first.rank;
    final normalizedAxis = axis < 0 ? axis + rank : axis;
    if (normalizedAxis < 0 || normalizedAxis >= rank) {
      throw RangeError.value(axis, 'axis', 'Axis out of bounds [0, $rank)');
    }

    var axisTotal = 0;
    for (final tensor in tensors) {
      if (tensor.rank != rank) {
        throw ArgumentError(
          'All tensors must have rank $rank, got ${tensor.rank}',
        );
      }
      for (var i = 0; i < rank; i++) {
        if (i != normalizedAxis &&
            tensor.layout.shape[i] != first.layout.shape[i]) {
          throw ArgumentError(
            'Mismatched shape along non-concatenation axis $i',
          );
        }
      }
      axisTotal += tensor.layout.shape[normalizedAxis];
    }

    final outShape = List<int>.from(first.layout.shape);
    outShape[normalizedAxis] = axisTotal;

    final result = Tensor<E>.filled(
      first.type.defaultValue,
      shape: outShape,
      type: first.type,
    );
    var axisOffset = 0;
    for (final tensor in tensors) {
      final tLen = tensor.layout.shape[normalizedAxis];
      for (final key in tensor.layout.keys) {
        final outKey = List<int>.from(key);
        outKey[normalizedAxis] += axisOffset;
        result.setValue(outKey, tensor.getValue(key));
      }
      axisOffset += tLen;
    }
    return result;
  }

  /// Stacks this tensor with [other] along a new [axis].
  ///
  /// Conceptually, this aligns tensors of identical shape along a newly created
  /// dimension [axis].
  ///
  /// Formally, this embeds the tensors into a new dimension axis.
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([1, 2]);
  /// final b = Tensor<int>.fromObject([3, 4]);
  /// final c = a.stack(b, axis: 0);
  /// // c has shape [2, 2] and values [[1, 2], [3, 4]]
  /// ```
  Tensor<T> stack(Tensor<T> other, {int axis = 0}) =>
      stackAll([this, other], axis: axis);

  /// Stacks a list of [tensors] along a new [axis].
  static Tensor<E> stackAll<E>(List<Tensor<E>> tensors, {int axis = 0}) {
    if (tensors.isEmpty) throw ArgumentError('Tensors list cannot be empty');
    final first = tensors.first;
    final rank = first.rank;
    final newRank = rank + 1;
    final normalizedAxis = axis < 0 ? axis + newRank : axis;
    if (normalizedAxis < 0 || normalizedAxis >= newRank) {
      throw RangeError.value(axis, 'axis', 'Axis out of bounds [0, $newRank)');
    }

    for (final tensor in tensors) {
      if (!areShapesEqual(tensor.layout.shape, first.layout.shape)) {
        throw ArgumentError(
          'All tensors must have matching shape ${first.layout.shape}, got ${tensor.layout.shape}',
        );
      }
    }

    final outShape = List<int>.from(first.layout.shape);
    outShape.insert(normalizedAxis, tensors.length);

    final result = Tensor<E>.filled(
      first.type.defaultValue,
      shape: outShape,
      type: first.type,
    );
    for (var i = 0; i < tensors.length; i++) {
      final tensor = tensors[i];
      for (final key in tensor.layout.keys) {
        final outKey = List<int>.from(key);
        outKey.insert(normalizedAxis, i);
        result.setValue(outKey, tensor.getValue(key));
      }
    }
    return result;
  }

  /// Repeats this tensor along each axis according to [reps].
  ///
  /// Conceptually, this replicates the tensor repeatedly along each axis
  /// according to [reps].
  ///
  /// Formally, this computes the periodic extension along axes by [reps].
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([1, 2]);
  /// final b = a.tile([2]);
  /// // b has shape [4] and values [1, 2, 1, 2]
  /// ```
  Tensor<T> tile(List<int> reps) {
    if (reps.length < rank) {
      throw ArgumentError(
        'reps length (${reps.length}) must be >= rank ($rank)',
      );
    }
    for (final rep in reps) {
      if (rep < 0) {
        throw ArgumentError.value(reps, 'reps', 'Repetitions must be >= 0');
      }
    }
    final paddedShape = [
      ...List<int>.filled(reps.length - rank, 1),
      ...layout.shape,
    ];
    final outShape = List<int>.generate(
      reps.length,
      (i) => paddedShape[i] * reps[i],
    );
    final result = Tensor<T>.filled(
      type.defaultValue,
      shape: outShape,
      type: type,
    );
    final outLayout = Layout(shape: outShape);

    for (final outKey in outLayout.keys) {
      final inKey = List<int>.generate(rank, (i) {
        final repIdx = i + (reps.length - rank);
        return outKey[repIdx] % layout.shape[i];
      });
      result.setValue(outKey, getValue(inKey));
    }
    return result;
  }

  /// Pads this tensor with [fillValue] according to [padding] per dimension.
  ///
  /// Conceptually, this expands the boundaries of the tensor by padding with
  /// [fillValue].
  ///
  /// Formally, this embeds the tensor into an enlarged index domain with
  /// constant boundary conditions.
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([1, 2]);
  /// final b = a.pad([[1, 1]], fillValue: 0);
  /// // b has shape [4] and values [0, 1, 2, 0]
  /// ```
  Tensor<T> pad(List<List<int>> padding, {T? fillValue}) {
    if (padding.length != rank) {
      throw ArgumentError('padding length must match rank $rank');
    }
    for (var i = 0; i < rank; i++) {
      final p = padding[i];
      if (p.length != 2 || p[0] < 0 || p[1] < 0) {
        throw ArgumentError.value(
          padding,
          'padding',
          'Each axis padding must be [before, after] with non-negative values',
        );
      }
    }
    final padVal = fillValue ?? type.defaultValue;
    final outShape = List<int>.generate(
      rank,
      (i) => layout.shape[i] + padding[i][0] + padding[i][1],
    );
    final result = Tensor<T>.filled(padVal, shape: outShape, type: type);

    for (final key in layout.keys) {
      final outKey = List<int>.generate(rank, (i) => key[i] + padding[i][0]);
      result.setValue(outKey, getValue(key));
    }
    return result;
  }

  /// Splits this tensor into [parts] equal chunks along [axis].
  ///
  /// Conceptually, this partitions the tensor into [parts] equally sized slices
  /// along [axis].
  ///
  /// Formally, this partitions the index domain along axis $k$ into $p$ equal
  /// subdomains.
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([1, 2, 3, 4]);
  /// final parts = a.split(2);
  /// // parts has 2 tensors: [1, 2] and [3, 4]
  /// ```
  ///
  /// Throws [ArgumentError] if [parts] is not positive or if the dimension
  /// along [axis] is not evenly divisible by [parts].
  List<Tensor<T>> split(int parts, {int axis = 0}) {
    if (parts <= 0) {
      throw ArgumentError.value(
        parts,
        'parts',
        'Number of parts must be positive',
      );
    }
    final normAxis = axis < 0 ? axis + rank : axis;
    if (normAxis < 0 || normAxis >= rank) {
      throw RangeError.value(axis, 'axis', 'Axis out of bounds [0, $rank)');
    }
    final dim = shape[normAxis];
    if (dim % parts != 0) {
      throw ArgumentError(
        'Dimension size ($dim) along axis $axis must be divisible by parts ($parts)',
      );
    }
    final partSize = dim ~/ parts;
    return List<Tensor<T>>.generate(parts, (i) {
      final start = i * partSize;
      return getRange(axis: normAxis, start: start, end: start + partSize);
    });
  }

  /// Splits this tensor into chunks along [axis] with lengths given by
  /// [splitSizes].
  ///
  /// Conceptually, this partitions the tensor into slices along [axis] with
  /// lengths given by [splitSizes].
  ///
  /// Formally, this partitions the index domain along axis $k$ according to the
  /// integer partition [splitSizes].
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([1, 2, 3, 4, 5]);
  /// final parts = a.splitWithSizes([2, 3]);
  /// // parts has 2 tensors: [1, 2] and [3, 4, 5]
  /// ```
  ///
  /// Throws [ArgumentError] if any size in [splitSizes] is negative or if the
  /// sum of [splitSizes] does not match the dimension length along [axis].
  List<Tensor<T>> splitWithSizes(List<int> splitSizes, {int axis = 0}) {
    final normAxis = axis < 0 ? axis + rank : axis;
    if (normAxis < 0 || normAxis >= rank) {
      throw RangeError.value(axis, 'axis', 'Axis out of bounds [0, $rank)');
    }
    var sum = 0;
    for (final size in splitSizes) {
      if (size < 0) {
        throw ArgumentError.value(
          size,
          'splitSizes',
          'Split sizes must be non-negative',
        );
      }
      sum += size;
    }
    final dim = shape[normAxis];
    if (sum != dim) {
      throw ArgumentError(
        'Sum of splitSizes ($sum) must equal dimension size ($dim) along axis $axis',
      );
    }
    final result = <Tensor<T>>[];
    var currentOffset = 0;
    for (final size in splitSizes) {
      result.add(
        getRange(
          axis: normAxis,
          start: currentOffset,
          end: currentOffset + size,
        ),
      );
      currentOffset += size;
    }
    return result;
  }
}
