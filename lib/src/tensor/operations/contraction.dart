import '../tensor.dart';
import 'matmul.dart';

/// Extension providing generalized tensor contraction and products on [Tensor].
extension ContractionTensorExtension<T> on Tensor<T> {
  /// Computes the tensor dot product (contraction) along specified [axes].
  ///
  /// - If [axes] is an integer $N$, contracts the last $N$ axes of `this`
  ///   with the first $N$ axes of [other].
  /// - If [axes] is a tuple `(axesA, axesB)`, contracts the listed axes of `this`
  ///   with the corresponding listed axes of [other].
  ///
  /// Maps to 2D matrix multiplication (`matmul`), leveraging hardware BLAS
  /// acceleration when available.
  Tensor<T> tensordot(Tensor<T> other, {dynamic axes = 2}) =>
      tensorDot(this, other, axes: axes);

  /// Computes the tensor inner product (Frobenius / full contraction) with [other].
  ///
  /// Contracts all corresponding axes, resulting in a rank-0 scalar tensor.
  Tensor<T> innerProduct(Tensor<T> other) => tensorDot(
    this,
    other,
    axes: (
      List<int>.generate(rank, (i) => i),
      List<int>.generate(other.rank, (i) => i),
    ),
  );

  /// Computes the tensor outer product with [other].
  ///
  /// No axes are contracted, producing a tensor of rank `this.rank + other.rank`.
  Tensor<T> outerProduct(Tensor<T> other) => tensorDot(this, other, axes: 0);
}

/// Computes the tensor dot product (contraction) of [a] and [b] along specified [axes].
///
/// Top-level function for [ContractionTensorExtension.tensordot].
Tensor<T> tensorDot<T>(Tensor<T> a, Tensor<T> b, {dynamic axes = 2}) {
  final (axesA, axesB) = _parseAxes(a.rank, b.rank, axes);
  if (axesA.length != axesB.length) {
    throw ArgumentError(
      'Number of contracted axes must match: ${axesA.length} != ${axesB.length}',
    );
  }
  for (var i = 0; i < axesA.length; i++) {
    if (a.shape[axesA[i]] != b.shape[axesB[i]]) {
      throw ArgumentError(
        'Contracted axis sizes must match: a.shape[${axesA[i]}]=${a.shape[axesA[i]]} != b.shape[${axesB[i]}]=${b.shape[axesB[i]]}',
      );
    }
  }

  final freeA = <int>[];
  for (var i = 0; i < a.rank; i++) {
    if (!axesA.contains(i)) freeA.add(i);
  }
  final freeB = <int>[];
  for (var i = 0; i < b.rank; i++) {
    if (!axesB.contains(i)) freeB.add(i);
  }

  final permA = [...freeA, ...axesA];
  final permB = [...axesB, ...freeB];

  final shapeFreeA = freeA.map((i) => a.shape[i]).toList();
  final shapeFreeB = freeB.map((i) => b.shape[i]).toList();

  final sizeFreeA = shapeFreeA.fold(1, (prod, dim) => prod * dim);
  final sizeContracted = axesA.fold(1, (prod, ax) => prod * a.shape[ax]);
  final sizeFreeB = shapeFreeB.fold(1, (prod, dim) => prod * dim);

  final transA = permA.isEmpty || _isIdentityPermutation(permA)
      ? a
      : a.transpose(permA);
  final transB = permB.isEmpty || _isIdentityPermutation(permB)
      ? b
      : b.transpose(permB);

  final matA = transA.reshape([sizeFreeA, sizeContracted]);
  final matB = transB.reshape([sizeContracted, sizeFreeB]);

  final prodMat = matA.matmul(matB);
  final outShape = [...shapeFreeA, ...shapeFreeB];
  return prodMat.reshape(outShape);
}

/// Computes the full inner product of two tensors.
Tensor<T> innerProduct<T>(Tensor<T> a, Tensor<T> b) => a.innerProduct(b);

/// Computes the outer product of two tensors.
Tensor<T> outerProduct<T>(Tensor<T> a, Tensor<T> b) => a.outerProduct(b);

(List<int>, List<int>) _parseAxes(int rankA, int rankB, dynamic axes) {
  if (axes is int) {
    if (axes < 0) {
      throw ArgumentError.value(
        axes,
        'axes',
        'Number of axes must be non-negative',
      );
    }
    if (axes > rankA || axes > rankB) {
      throw ArgumentError(
        'Number of axes ($axes) exceeds tensor rank ($rankA, $rankB)',
      );
    }
    final axesA = List<int>.generate(axes, (i) => rankA - axes + i);
    final axesB = List<int>.generate(axes, (i) => i);
    return (axesA, axesB);
  } else if (axes is (List<int>, List<int>)) {
    final (aAxes, bAxes) = axes;
    return (_normalizeAxes(rankA, aAxes), _normalizeAxes(rankB, bAxes));
  } else if (axes is (int, int)) {
    final (aAxis, bAxis) = axes;
    return (_normalizeAxes(rankA, [aAxis]), _normalizeAxes(rankB, [bAxis]));
  } else if (axes is List && axes.length == 2) {
    final aList = axes[0] is int
        ? [axes[0] as int]
        : (axes[0] as Iterable).cast<int>().toList();
    final bList = axes[1] is int
        ? [axes[1] as int]
        : (axes[1] as Iterable).cast<int>().toList();
    return (_normalizeAxes(rankA, aList), _normalizeAxes(rankB, bList));
  } else {
    throw ArgumentError.value(
      axes,
      'axes',
      'Invalid axes specification for tensordot: expected int, (List<int>, List<int>), or (int, int)',
    );
  }
}

List<int> _normalizeAxes(int rank, List<int> axes) {
  final result = <int>[];
  for (final axis in axes) {
    final norm = axis < 0 ? axis + rank : axis;
    if (norm < 0 || norm >= rank) {
      throw RangeError.value(axis, 'axis', 'Axis out of bounds [0, $rank)');
    }
    if (result.contains(norm)) {
      throw ArgumentError('Duplicate axis in contraction list: $axis');
    }
    result.add(norm);
  }
  return result;
}

bool _isIdentityPermutation(List<int> perm) {
  for (var i = 0; i < perm.length; i++) {
    if (perm[i] != i) return false;
  }
  return true;
}
