/// Execution mode for numerical backend acceleration.
enum AccelerationMode {
  /// Automatically selects the fastest available approach on current platform (default).
  ///
  /// Uses native BLAS/LAPACK or SIMD acceleration when available, falling back gracefully
  /// to pure Dart software algorithms if unavailable or if input size is below threshold.
  auto,

  /// Forces the use of native accelerated hardware backends (BLAS/LAPACK/SIMD).
  ///
  /// Explicitly throws [StateError] if native acceleration is unavailable on the platform
  /// or encounters an execution failure (no silent fallback to software).
  accelerated,

  /// Forces the use of pure Dart software algorithms.
  ///
  /// Useful for cross-platform portability testing, debugging, and benchmarking.
  dart,
}
