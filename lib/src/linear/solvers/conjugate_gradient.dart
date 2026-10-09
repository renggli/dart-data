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

  final f = a.type.field;
  final x =
      x0?.copy() ??
      Vector<T>.filled(b.length, f.additiveIdentity, type: a.type);
  final r = b - a.apply(x);
  final p = r.copy();
  var rsOld = r.dot(r);

  if (f.norm(rsOld) < tolerance * tolerance) {
    return x;
  }

  for (var i = 0; i < maxIterations; i++) {
    final ap = a.apply(p);
    final pap = p.dot(ap);
    if (f.norm(pap) == 0.0) break;
    final alpha = f.div(rsOld, pap);
    x.addScaled(p, alpha);
    r.addScaled(ap, f.neg(alpha));
    final rsNew = r.dot(r);
    if (f.norm(rsNew) < tolerance * tolerance) {
      break;
    }
    final beta = f.div(rsNew, rsOld);
    p.scaleInPlace(beta);
    p.addScaled(r, f.multiplicativeIdentity);
    rsOld = rsNew;
  }

  return x;
}
