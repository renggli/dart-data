import '../layout.dart';
import '../tensor.dart';

extension ManipulationTensorExtension<T> on Tensor<T> {
  /// Concatenates this tensor with [other] along [axis].
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
  Tensor<T> tile(List<int> reps) {
    if (reps.length < rank) {
      throw ArgumentError(
        'reps length (${reps.length}) must be >= rank ($rank)',
      );
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
  Tensor<T> pad(List<List<int>> padding, {T? fillValue}) {
    if (padding.length != rank) {
      throw ArgumentError('padding length must match rank $rank');
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
}
