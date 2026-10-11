/// Multi-dimensional array (Tensor) engine with arbitrary ranks, generalized
/// stride layouts, and tensor contractions.
///
/// Generalizes 1D vectors and 2D matrices to $N$-dimensional arrays. Provides
/// zero-copy views (reshaping, slicing, transposing, broadcasting) backed by
/// flat contiguous memory buffers and arbitrary stride arithmetic.
///
/// ## Key Capabilities
///
/// - **Arbitrary Rank & Shape**: [Tensor] supports rank-0 (scalars), rank-1
///   (vectors), rank-2 (matrices), and higher-dimensional tensors.
/// - **Generalized Stride Layouts ([Layout])**: Strided indexing mapping
///   $N$-dimensional coordinates $\mathbf{k} = (k_0, \dots, k_{r-1})$ to flat
///   buffer offsets in $\mathcal{O}(1)$ time.
/// - **Zero-Copy Views**: [Tensor.reshape], [Tensor.transpose], and
///   [Tensor.slice] manipulate stride metadata without copying data.
/// - **Broadcasting & Operations**: [OperationTensorExtension] handles
///   element-wise operations and automatic broadcasting following NumPy
///   semantics across matching or singleton axes.
/// - **Manipulations**: [ManipulationTensorExtension] provides concatenation,
///   stacking, tiling, padding, and splitting.
/// - **Contractions & Einstein Summation**: [einsum],
///   [ContractionTensorExtension.tensordot],
///   [ContractionTensorExtension.innerProduct], and
///   [ContractionTensorExtension.outerProduct] perform multi-tensor
///   contractions specified by index strings or axis indices.
/// - **Hardware-Accelerated Math**: Fast batch matrix multiplication
///   ([MatmulTensorExtension.matmul]), [Float64Tensor] unboxed buffers, and
///   reductions ([ReductionTensorExtension.sum],
///   [ReductionTensorExtension.mean], [ReductionTensorExtension.min],
///   [ReductionTensorExtension.max]) across specified axes.
///
/// ## Example
///
/// ```dart
/// import 'package:data/tensor.dart';
///
/// void main() {
///   // Create a 2x3 tensor filled with 1.0
///   final t = Tensor<double>.filled(1.0, shape: [2, 3]);
///   print('Shape: ${t.shape}, Rank: ${t.rank}');
///
///   // Matrix multiplication via Einstein summation: C_ik = A_ij * B_jk
///   final a = Tensor<double>.fromIterable(
///     [1.0, 2.0, 3.0, 4.0],
///     shape: [2, 2],
///   );
///   final b = Tensor<double>.fromIterable(
///     [5.0, 6.0, 7.0, 8.0],
///     shape: [2, 2],
///   );
///   final c = einsum('ij,jk->ik', [a, b]);
///   print('Einsum result:\n$c');
/// }
/// ```
library;

import 'src/tensor/float64_tensor.dart';
import 'src/tensor/layout.dart';
import 'src/tensor/operations/contraction.dart';
import 'src/tensor/operations/einsum.dart';
import 'src/tensor/operations/manipulation.dart';
import 'src/tensor/operations/matmul.dart';
import 'src/tensor/operations/operation.dart';
import 'src/tensor/operations/reduction.dart';
import 'src/tensor/tensor.dart';

export 'src/tensor/float64_tensor.dart';
export 'src/tensor/layout.dart';
export 'src/tensor/operations/contraction.dart';
export 'src/tensor/operations/einsum.dart';
export 'src/tensor/operations/manipulation.dart';
export 'src/tensor/operations/matmul.dart';
export 'src/tensor/operations/operation.dart';
export 'src/tensor/operations/reduction.dart';
export 'src/tensor/tensor.dart';
