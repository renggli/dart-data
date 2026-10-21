import 'acceleration_mode.dart';
import 'blas/blas.dart';
import 'fft/fft.dart';
import 'lapack/lapack.dart';
import 'vforce/vforce.dart';

/// Central acceleration coordinator controlling execution [mode].
///
/// Mathematical operations are organized into dedicated domain modules:
/// - [Blas]: Vector-vector (Level 1), matrix-vector (Level 2), and matrix-matrix
///   (Level 3) basic linear algebra subprograms.
/// - [Lapack]: Linear system solvers, matrix factorizations (Cholesky, LU, QR),
///   and eigenvalue/eigenvector decompositions.
/// - [Fft]: In-place 1D and 2D complex and real Fast Fourier Transforms.
/// - [Vforce]: Vectorized transcendental functions, reductions, and 1D signal
///   operations.
class AccelerationManager {
  new _(); // coverage:ignore-line

  /// The active acceleration mode across all mathematical modules. Defaults to
  /// [AccelerationMode.auto].
  static AccelerationMode mode = AccelerationMode.auto;

  /// Whether hardware acceleration is currently active.
  static bool get isAccelerated =>
      mode != AccelerationMode.dart &&
      (Blas.isAvailable ||
          Lapack.isAvailable ||
          Fft.isAvailable ||
          Vforce.isAvailable);
}
