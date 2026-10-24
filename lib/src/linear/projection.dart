import '../type/data_type.dart';
import 'vector.dart';

/// Extension methods for orthogonal vector projection and rejection.
extension VectorProjectionExtension<T extends num> on Vector<T> {
  /// Computes the orthogonal projection of this vector onto [onto].
  ///
  /// $$
  /// \operatorname{proj}_{\mathbf{v}}(\mathbf{u}) =
  /// \frac{\langle \mathbf{u}, \mathbf{v} \rangle}{\|\mathbf{v}\|_2^2}
  /// \mathbf{v}
  /// $$
  ///
  /// Throws an [ArgumentError] if vector lengths do not match or if the squared
  /// $L_2$ norm of [onto] is less than $1\text{e-}15$.
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
    var dotProduct = 0.0;
    var vNormSq = 0.0;
    final t1 = tensor;
    final t2 = onto.tensor;
    if (t1.isContiguous && t2.isContiguous) {
      final d1 = t1.data;
      final d2 = t2.data;
      final o1 = t1.offset;
      final o2 = t2.offset;
      for (var i = 0; i < length; i++) {
        final ui = d1[o1 + i].toDouble();
        final vi = d2[o2 + i].toDouble();
        dotProduct += ui * vi;
        vNormSq += vi * vi;
      }
    } else {
      for (var i = 0; i < length; i++) {
        final ui = getUnchecked(i).toDouble();
        final vi = onto.getUnchecked(i).toDouble();
        dotProduct += ui * vi;
        vNormSq += vi * vi;
      }
    }
    if (vNormSq < 1e-15 || !vNormSq.isFinite) {
      throw ArgumentError(
        'Cannot project onto vector with squared norm: $vNormSq',
      );
    }
    final scale = dotProduct / vNormSq;
    final result = Vector<double>.filled(length, 0.0, type: DataType.float64);
    if (t2.isContiguous && result.tensor.isContiguous) {
      final src = t2.data;
      final dst = result.tensor.data;
      final srcOffset = t2.offset;
      final dstOffset = result.tensor.offset;
      for (var i = 0; i < length; i++) {
        dst[dstOffset + i] = scale * src[srcOffset + i].toDouble();
      }
    } else {
      for (var i = 0; i < length; i++) {
        result.setUnchecked(i, scale * onto.getUnchecked(i).toDouble());
      }
    }
    return result;
  }

  /// Computes the orthogonal rejection of this vector from [from].
  ///
  /// The rejection represents the component of this vector orthogonal to
  /// $$
  /// \operatorname{oproj}_{\mathbf{v}}(\mathbf{u})
  ///     = \mathbf{u} - \operatorname{proj}_{\mathbf{v}}(\mathbf{u})
  /// $$
  ///
  /// Throws an [ArgumentError] if vector lengths do not match or if the squared
  /// $L_2$ norm of [from] is less than $1\text{e-}15$.
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
