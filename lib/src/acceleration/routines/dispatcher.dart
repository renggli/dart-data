import '../acceleration_error.dart';
import '../acceleration_manager.dart';
import '../acceleration_mode.dart';

/// Dispatches an accelerated routine returning a value [T], with transparent
/// fallback to pure Dart.
///
/// In [AccelerationMode.dart], invokes [fallback] directly.
/// In [AccelerationMode.accelerated], asserts [isAvailable] and invokes [accelerate].
/// If [accelerate] returns `null`, throws [AccelerationFailedError].
/// In [AccelerationMode.auto], invokes [accelerate] if [isAvailable] and [canAccelerate]
/// is `true`. If [accelerate] returns `null`, falls back to [fallback].
T executeAccelerated<T>({
  required String feature,
  required String operation,
  required bool isAvailable,
  bool canAccelerate = true,
  required T? Function() accelerate,
  required T Function() fallback,
}) {
  final mode = AccelerationManager.mode;
  if (mode == AccelerationMode.accelerated) {
    if (!isAvailable) {
      throw AccelerationError.unavailable(feature);
    }
    final result = accelerate();
    if (result == null) {
      throw AccelerationError.failed(operation);
    }
    return result;
  }
  if (mode == AccelerationMode.auto && isAvailable && canAccelerate) {
    final result = accelerate();
    if (result != null) return result;
  }
  return fallback();
}

/// Dispatches an accelerated operation returning a boolean success status,
/// with transparent fallback to pure Dart.
///
/// In [AccelerationMode.dart], invokes [fallback] directly.
/// In [AccelerationMode.accelerated], asserts [isAvailable] and invokes [accelerate].
/// If [accelerate] returns `false` and [failOnError] is `true`, throws [AccelerationFailedError].
/// In [AccelerationMode.auto], invokes [accelerate] if [isAvailable] and [canAccelerate]
/// is `true`. If [accelerate] returns `true`, returns `true`. Otherwise falls back to [fallback].
bool executeAcceleratedOperation({
  required String feature,
  required String operation,
  required bool isAvailable,
  bool canAccelerate = true,
  bool failOnError = true,
  required bool Function() accelerate,
  required bool Function() fallback,
}) {
  final mode = AccelerationManager.mode;
  if (mode == AccelerationMode.accelerated) {
    if (!isAvailable) {
      throw AccelerationError.unavailable(feature);
    }
    final success = accelerate();
    if (!success && failOnError) {
      throw AccelerationError.failed(operation);
    }
    return success;
  }
  if (mode == AccelerationMode.auto && isAvailable && canAccelerate) {
    final success = accelerate();
    if (success) return true;
  }
  return fallback();
}
