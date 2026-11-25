import '../type/data_type.dart';
import 'vector.dart';

/// Extension methods for orthogonal vector projection and rejection.
extension VectorProjectionExtension<T extends num> on Vector<T> {
  /// Computes the orthogonal projection of this vector onto [onto].
  ///
  /// Computes `(<u, v> / ||v||_2^2) * v` using max-abs scaling to avoid
  /// intermediate overflow or underflow.
  ///
  /// Throws an [ArgumentError] if vector lengths do not match, if [onto] is
  /// empty or the zero vector, or if [onto] contains non-finite elements.
  ///
  /// ```dart
  /// final u = Vector<double>.fromList([3.0, 4.0]);
  /// final v = Vector<double>.fromList([1.0, 0.0]);
  /// final proj = u.project(v);
  /// print(proj); // Vector([3.0, 0.0])
  /// ```
  Vector<double> project<S extends num>(Vector<S> onto) {
    if (length != onto.length) {
      throw ArgumentError(
        'Vector lengths must match: $length vs ${onto.length}',
      );
    }
    if (length == 0) {
      throw ArgumentError('Cannot project onto empty vector.');
    }
    final t1 = tensor;
    final t2 = onto.tensor;
    var maxAbs = 0.0;
    if (t2.isContiguous) {
      final d2 = t2.data;
      final o2 = t2.offset;
      for (var i = 0; i < length; i++) {
        final vi = d2[o2 + i].toDouble();
        if (!vi.isFinite) {
          throw ArgumentError(
            'Cannot project onto non-finite vector element at index $i: $vi',
          );
        }
        final absV = vi.abs();
        if (absV > maxAbs) maxAbs = absV;
      }
    } else {
      for (var i = 0; i < length; i++) {
        final vi = onto.getUnchecked(i).toDouble();
        if (!vi.isFinite) {
          throw ArgumentError(
            'Cannot project onto non-finite vector element at index $i: $vi',
          );
        }
        final absV = vi.abs();
        if (absV > maxAbs) maxAbs = absV;
      }
    }
    if (maxAbs == 0.0) {
      throw ArgumentError('Cannot project onto zero vector.');
    }

    var dotScaled = 0.0;
    var sNormSq = 0.0;
    if (t1.isContiguous && t2.isContiguous) {
      final d1 = t1.data;
      final d2 = t2.data;
      final o1 = t1.offset;
      final o2 = t2.offset;
      for (var i = 0; i < length; i++) {
        final ui = d1[o1 + i].toDouble();
        final si = d2[o2 + i].toDouble() / maxAbs;
        dotScaled += ui * si;
        sNormSq += si * si;
      }
    } else {
      for (var i = 0; i < length; i++) {
        final ui = getUnchecked(i).toDouble();
        final si = onto.getUnchecked(i).toDouble() / maxAbs;
        dotScaled += ui * si;
        sNormSq += si * si;
      }
    }

    var uScale = 1.0;
    if (!dotScaled.isFinite) {
      var maxU = 0.0;
      var allUFinite = true;
      for (var i = 0; i < length; i++) {
        final absU = getUnchecked(i).toDouble().abs();
        if (!absU.isFinite) {
          allUFinite = false;
          break;
        }
        if (absU > maxU) maxU = absU;
      }
      if (allUFinite && maxU > 0.0) {
        uScale = maxU;
        dotScaled = 0.0;
        for (var i = 0; i < length; i++) {
          final ui = getUnchecked(i).toDouble() / maxU;
          final si = onto.getUnchecked(i).toDouble() / maxAbs;
          dotScaled += ui * si;
        }
      }
    }

    final scale = dotScaled / sNormSq;
    final result = Vector<double>.filled(length, 0.0, type: DataType.float64);
    if (t2.isContiguous && result.tensor.isContiguous) {
      final src = t2.data;
      final dst = result.tensor.data;
      final srcOffset = t2.offset;
      final dstOffset = result.tensor.offset;
      for (var i = 0; i < length; i++) {
        dst[dstOffset + i] =
            (scale * (src[srcOffset + i].toDouble() / maxAbs)) * uScale;
      }
    } else {
      for (var i = 0; i < length; i++) {
        result.setUnchecked(
          i,
          (scale * (onto.getUnchecked(i).toDouble() / maxAbs)) * uScale,
        );
      }
    }
    return result;
  }

  /// Computes the orthogonal rejection of this vector from [from]: `u - proj_v(u)`.
  ///
  /// Throws an [ArgumentError] if vector lengths do not match, if [from] is
  /// empty or the zero vector, or if [from] contains non-finite elements.
  ///
  /// ```dart
  /// final u = Vector<double>.fromList([3.0, 4.0]);
  /// final v = Vector<double>.fromList([1.0, 0.0]);
  /// final rej = u.reject(v);
  /// print(rej); // Vector([0.0, 4.0])
  /// ```
  Vector<double> reject<S extends num>(Vector<S> from) {
    final proj = project(from);
    final t1 = tensor;
    final t2 = proj.tensor;
    if (t1.isContiguous && t2.isContiguous) {
      final src = t1.data;
      final dst = t2.data;
      final srcOffset = t1.offset;
      final dstOffset = t2.offset;
      for (var i = 0; i < length; i++) {
        dst[dstOffset + i] = src[srcOffset + i].toDouble() - dst[dstOffset + i];
      }
    } else {
      for (var i = 0; i < length; i++) {
        proj.setUnchecked(i, getUnchecked(i).toDouble() - proj.getUnchecked(i));
      }
    }
    return proj;
  }
}
