/// 1D Brent minimization combining golden section search and parabolic
/// interpolation.
({double point, double value, int iterations}) brentMinimize(
  double Function(double) fn, {
  required double a,
  required double b,
  double tolerance = 1e-8,
  int maxIterations = 100,
}) {
  const goldenRatio = 0.38196601125010515179541316563436; // (3 - sqrt(5)) / 2

  var xA = a < b ? a : b;
  var xB = a < b ? b : a;
  var x = xA + goldenRatio * (xB - xA);
  var wVal = x;
  var vVal = wVal;
  var fx = fn(x);
  var fw = fx;
  var fv = fw;
  var dStep = 0.0;
  var eStep = 0.0;

  var iter = 0;
  for (; iter < maxIterations; iter++) {
    final xm = 0.5 * (xA + xB);
    final tol1 = 1e-10 * x.abs() + tolerance;
    final tol2 = 2.0 * tol1;

    if ((x - xm).abs() <= (tol2 - 0.5 * (xB - xA))) {
      break;
    }

    var pVal = 0.0;
    var qVal = 0.0;
    var rVal = 0.0;

    if (eStep.abs() > tol1) {
      rVal = (x - wVal) * (fx - fv);
      qVal = (x - vVal) * (fx - fw);
      pVal = (x - vVal) * qVal - (x - wVal) * rVal;
      qVal = 2.0 * (qVal - rVal);
      if (qVal > 0.0) pVal = -pVal;
      qVal = qVal.abs();
      final rTemp = eStep;
      eStep = dStep;
      if (pVal.abs() < (0.5 * qVal * rTemp).abs() &&
          pVal > qVal * (xA - x) &&
          pVal < qVal * (xB - x)) {
        dStep = pVal / qVal;
        final uVal = x + dStep;
        if (uVal - xA < tol2 || xB - uVal < tol2) {
          dStep = xm - x >= 0 ? tol1 : -tol1;
        }
      } else {
        eStep = x >= xm ? xA - x : xB - x;
        dStep = goldenRatio * eStep;
      }
    } else {
      eStep = x >= xm ? xA - x : xB - x;
      dStep = goldenRatio * eStep;
    }

    final uVal = dStep.abs() >= tol1
        ? x + dStep
        : x + (dStep > 0 ? tol1 : -tol1);
    final fu = fn(uVal);

    if (fu <= fx) {
      if (uVal >= x) {
        xA = x;
      } else {
        xB = x;
      }
      vVal = wVal;
      fv = fw;
      wVal = x;
      fw = fx;
      x = uVal;
      fx = fu;
    } else {
      if (uVal < x) {
        xA = uVal;
      } else {
        xB = uVal;
      }
      if (fu <= fw || wVal == x) {
        vVal = wVal;
        fv = fw;
        wVal = uVal;
        fw = fu;
      } else if (fu <= fv || vVal == x || vVal == wVal) {
        vVal = uVal;
        fv = fu;
      }
    }
  }

  return (point: x, value: fx, iterations: iter);
}
