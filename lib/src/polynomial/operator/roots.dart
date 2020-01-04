library data.polynomial.operator.roots;

import '../../../matrix.dart';
import '../../../type.dart';
import '../../shared/config.dart';
import '../polynomial.dart';

extension RootsExtension<T extends num> on Polynomial<T> {
  ///// Computes the complex roots of a polynomial.
  List<Complex> get roots {
    if (degree <= 0) {
      return [];
    } else if (degree == 1) {
      final a = getUnchecked(1), b = getUnchecked(0);
      return [Complex(-b / a)];
    } else {
      final factor = -1.0 / getUnchecked(degree);
      final matrix =
          Matrix<double>.generate(floatDataType, degree, degree, (r, c) {
        if (r == degree - 1) {
          return factor * getUnchecked(c);
        } else if (r + 1 == c) {
          return 1;
        } else {
          return 0;
        }
      });
      return matrix.eigenvalue.eigenvalues;
    }
  }
}
