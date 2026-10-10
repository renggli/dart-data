import '../operator.dart';
import '../vector.dart';

/// Solves the symmetric positive-definite linear system A * x = b using Conjugate Gradient.
Vector<T> conjugateGradient<T>(
  LinearOperator<T> a,
  Vector<T> b, {
  Vector<T>? x0,
  double tolerance = 1e-10,
  int maxIterations = 1000,
}) {
  if (a.rowCount != a.colCount) {
    throw ArgumentError(
      'Matrix A must be square, got ${a.rowCount} x ${a.colCount}',
    );
  }
  if (a.rowCount != b.length) {
    throw ArgumentError(
      'Matrix rowCount (${a.rowCount}) must match vector b length (${b.length})',
    );
  }

  final field = a.type.field;
  final x =
      x0?.copy() ??
      Vector<T>.filled(b.length, field.additiveIdentity, type: a.type);
  final residual = b - a.apply(x);
  final direction = residual.copy();
  var rsOld = residual.dot(residual);

  if (field.norm(rsOld) < tolerance * tolerance) {
    return x;
  }

  for (var i = 0; i < maxIterations; i++) {
    final ap = a.apply(direction);
    final pap = direction.dot(ap);
    if (field.norm(pap) == 0.0) break;
    final alpha = field.div(rsOld, pap);
    x.addScaled(direction, alpha);
    residual.addScaled(ap, field.neg(alpha));
    final rsNew = residual.dot(residual);
    if (field.norm(rsNew) < tolerance * tolerance) {
      break;
    }
    final beta = field.div(rsNew, rsOld);
    direction.scaleInPlace(beta);
    direction.addScaled(residual, field.multiplicativeIdentity);
    rsOld = rsNew;
  }

  return x;
}
