library data.shared.math;

import 'dart:math' as math;

/// sqrt(a^2 + b^2) without under/overflow. **/
double hypot(double a, double b) {
  if (a.abs() > b.abs()) {
    final r = b / a;
    return a.abs() * math.sqrt(1 + r * r);
  } else if (b != 0) {
    final r = a / b;
    return b.abs() * math.sqrt(1 + r * r);
  } else {
    return 0.0;
  }
}
