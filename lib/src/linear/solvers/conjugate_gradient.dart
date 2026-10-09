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
  var x =
      x0?.copy() ??
      Vector<T>.filled(b.length, f.additiveIdentity, type: a.type);
  var r = b - a.apply(x);
  var p = r.copy();
  var rsOld = r.dot(r);

  if (f.norm(rsOld) < tolerance * tolerance) {
    return x;
  }

  for (var i = 0; i < maxIterations; i++) {
    final ap = a.apply(p);
    final pap = p.dot(ap);
    if (f.norm(pap) == 0.0) break;
    final alpha = f.div(rsOld, pap);
    x = x + p.scale(alpha);
    r = r - ap.scale(alpha);
    final rsNew = r.dot(r);
    if (f.norm(rsNew) < tolerance * tolerance) {
      break;
    }
    final beta = f.div(rsNew, rsOld);
    p = r + p.scale(beta);
    rsOld = rsNew;
  }

  return x;
}
