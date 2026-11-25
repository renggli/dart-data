import '../tensor.dart';
import 'matmul.dart';

/// Extension providing generalized tensor contraction and products on [Tensor].
extension ContractionTensorExtension<T> on Tensor<T> {
  /// Computes the tensor dot product (contraction) along specified [axes] or
  /// [contractAxes].
  ///
  /// Conceptually, this generalizes matrix multiplication and dot products to
  /// multidimensional tensors along chosen axes.
  ///
  /// Formally, this calculates the tensor contraction:
  /// `C[i_1,...,i_m, j_1,...,j_n] = ∑_{k_1,...,k_p} A[i_1,...,i_m, k_1,...,k_p] * B[k_1,...,k_p, j_1,...,j_n]`.
  ///
  /// - When [contractAxes] is omitted, contracts the last [axes] axes of
  ///   `this` with the first [axes] axes of [other].
  /// - When [contractAxes] is provided, contracts the listed axes in
  ///   `contractAxes.self` with `contractAxes.other`.
  ///
  /// Maps to 2D matrix multiplication ([matmul]), leveraging hardware BLAS
  /// acceleration when available.
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([[1, 2], [3, 4]]);
  /// final b = Tensor<int>.fromObject([[5, 6], [7, 8]]);
  /// final c = a.tensordot(b, axes: 1);
  /// // c has shape [2, 2] and values [[19, 22], [43, 50]]
  /// ```
  Tensor<T> tensordot(
    Tensor<T> other, {
    int axes = 2,
    ({List<int> self, List<int> other})? contractAxes,
  }) => _tensorDot(this, other, axes: axes, contractAxes: contractAxes);

  /// Computes the tensor inner product (Frobenius / full contraction) with
  /// [other].
  ///
  /// Conceptually, this multiplies all corresponding entries pairwise and sums
  /// them into a single scalar value.
  ///
  /// Formally, this calculates the Frobenius inner product
  /// `<A, B>_F = ∑ A[i_1,...,i_k] * B[i_1,...,i_k]`.
  ///
  /// Contracts all corresponding axes, resulting in a rank-0 scalar tensor.
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([1, 2, 3]);
  /// final b = Tensor<int>.fromObject([4, 5, 6]);
  /// final ip = a.innerProduct(b).toFlatList().first; // 32
  /// ```
  Tensor<T> innerProduct(Tensor<T> other) => _tensorDot(
    this,
    other,
    contractAxes: (
      self: List<int>.generate(rank, (i) => i),
      other: List<int>.generate(other.rank, (i) => i),
    ),
  );

  /// Computes the tensor outer product with [other].
  ///
  /// Conceptually, this multiplies every entry of the first tensor by every
  /// entry of the second, creating a higher-dimensional tensor of products.
  ///
  /// Formally, this computes the tensor product `A ⊗ B` with
  /// `(A ⊗ B)[i_1,...,i_m, j_1,...,j_n] = A[i_1,...,i_m] * B[j_1,...,j_n]`.
  ///
  /// No axes are contracted, producing a tensor of rank
  /// `this.rank + other.rank`.
  ///
  /// ```dart
  /// final a = Tensor<int>.fromObject([1, 2]);
  /// final b = Tensor<int>.fromObject([3, 4]);
  /// final op = a.outerProduct(b); // shape [2, 2]
  /// ```
  Tensor<T> outerProduct(Tensor<T> other) => _tensorDot(this, other, axes: 0);
}

/// Returns `true` if [perm] is the identity permutation `[0, 1, ..., n - 1]`.
bool isIdentityPermutation(List<int> perm) {
  for (var i = 0; i < perm.length; i++) {
    if (perm[i] != i) return false;
  }
  return true;
}

Tensor<T> _tensorDot<T>(
  Tensor<T> a,
  Tensor<T> b, {
  int axes = 2,
  ({List<int> self, List<int> other})? contractAxes,
}) {
  final parsed = _parseAxes(a.rank, b.rank, axes, contractAxes);
  final axesA = parsed.self;
  final axesB = parsed.other;
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

  final transA = permA.isEmpty || isIdentityPermutation(permA)
      ? a
      : a.transpose(permA);
  final transB = permB.isEmpty || isIdentityPermutation(permB)
      ? b
      : b.transpose(permB);

  final matA = transA.reshape([sizeFreeA, sizeContracted]);
  final matB = transB.reshape([sizeContracted, sizeFreeB]);

  final prodMat = matA.matmul(matB);
  final outShape = [...shapeFreeA, ...shapeFreeB];
  return prodMat.reshape(outShape);
}

({List<int> self, List<int> other}) _parseAxes(
  int rankA,
  int rankB,
  int axes,
  ({List<int> self, List<int> other})? contractAxes,
) {
  if (contractAxes != null) {
    return (
      self: _normalizeAxes(rankA, contractAxes.self),
      other: _normalizeAxes(rankB, contractAxes.other),
    );
  }
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
  return (self: axesA, other: axesB);
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
