import 'acceleration_mode.dart';

/// Base class for errors thrown by the acceleration subsystem.
abstract class AccelerationError extends StateError {
  new(super.message);

  /// Constructs an [AccelerationUnavailableError] indicating that native
  /// acceleration for [feature] is unavailable on the current platform.
  factory unavailable(String feature) => AccelerationUnavailableError(feature);

  /// Constructs an [AccelerationFailedError] indicating that native execution of
  /// [operation] failed.
  factory failed(String operation) => AccelerationFailedError(operation);
}

/// Error thrown when hardware acceleration is requested in
/// [AccelerationMode.accelerated] but is unsupported or unavailable on the
/// current platform.
class AccelerationUnavailableError extends AccelerationError {
  /// Creates an error indicating that [feature] acceleration is unavailable.
  new(this.feature) : super('Native $feature acceleration is unavailable.');

  /// The requested feature that is unavailable (e.g. `'BLAS'`, `'LAPACK'`).
  final String feature;
}

/// Error thrown when native hardware execution of an accelerated operation fails.
class AccelerationFailedError extends AccelerationError {
  /// Creates an error indicating that native execution of [operation] failed.
  new(this.operation) : super('Native $operation execution failed.');

  /// The operation that failed during native execution.
  final String operation;
}
