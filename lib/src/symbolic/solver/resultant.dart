import '../../linear/matrix.dart';
import '../algebra/simplify.dart';
import '../ast.dart';
import '../linear/bareiss.dart';
import '../type/expr_data_type.dart';
import 'polynomial.dart';
import 'univariate.dart';

/// Sylvester resultant solver for bivariate polynomial systems.
class SylvesterResultantSolver {
  /// Constructs the Sylvester resultant matrix $S_x(f, g)$ eliminating [elimVariable].
  static Matrix<Expr> sylvesterMatrix(Expr f, Expr g, String elimVariable) {
    final fCoeffs =
        extractMonomialCoefficients(f, elimVariable) ??
        (throw ArgumentError(
          'Expression f is not polynomial in $elimVariable: $f',
        ));
    final gCoeffs =
        extractMonomialCoefficients(g, elimVariable) ??
        (throw ArgumentError(
          'Expression g is not polynomial in $elimVariable: $g',
        ));

    var degF = 0;
    for (final p in fCoeffs.keys) {
      if (p > degF && !_isZeroCoeff(fCoeffs[p]!)) degF = p;
    }
    var degG = 0;
    for (final p in gCoeffs.keys) {
      if (p > degG && !_isZeroCoeff(gCoeffs[p]!)) degG = p;
    }

    if (degF == 0 && degG == 0) {
      final mat = Matrix<Expr>.filled(
        1,
        1,
        RationalNumber.one,
        type: exprDataType,
      );
      return mat;
    }
    if (degF == 0) {
      final mat = Matrix<Expr>.filled(
        degG,
        degG,
        RationalNumber.zero,
        type: exprDataType,
      );
      final cF = fCoeffs[0] ?? RationalNumber.zero;
      for (var i = 0; i < degG; i++) {
        mat.setUnchecked(i, i, cF);
      }
      return mat;
    }
    if (degG == 0) {
      final mat = Matrix<Expr>.filled(
        degF,
        degF,
        RationalNumber.zero,
        type: exprDataType,
      );
      final cG = gCoeffs[0] ?? RationalNumber.zero;
      for (var i = 0; i < degF; i++) {
        mat.setUnchecked(i, i, cG);
      }
      return mat;
    }

    final dim = degF + degG;
    final mat = Matrix<Expr>.filled(
      dim,
      dim,
      RationalNumber.zero,
      type: exprDataType,
    );

    // Rows for f (degG rows)
    for (var i = 0; i < degG; i++) {
      for (var p = degF; p >= 0; p--) {
        final coeff = fCoeffs[p] ?? RationalNumber.zero;
        final col = (degF - p) + i;
        if (col < dim) {
          mat.setUnchecked(i, col, coeff);
        }
      }
    }

    // Rows for g (degF rows)
    for (var j = 0; j < degF; j++) {
      for (var p = degG; p >= 0; p--) {
        final coeff = gCoeffs[p] ?? RationalNumber.zero;
        final col = (degG - p) + j;
        if (col < dim) {
          mat.setUnchecked(degG + j, col, coeff);
        }
      }
    }

    return mat;
  }

  /// Computes the resultant Res_x(f, g) by evaluating the determinant of the Sylvester matrix.
  static Expr resultant(Expr f, Expr g, String elimVariable) {
    final mat = sylvesterMatrix(f, g, elimVariable);
    return const BareissEngine().determinant(mat).simplify();
  }

  /// Solves a bivariate polynomial system `f = 0, g = 0` for [variables] via Sylvester resultant elimination.
  static List<Map<String, Expr>> solve(Expr f, Expr g, List<String> variables) {
    if (variables.length != 2) {
      throw ArgumentError(
        'Sylvester resultant solver requires exactly 2 variables, got ${variables.length}',
      );
    }
    final xVar = variables[0];
    final yVar = variables[1];

    final resY = resultant(f, g, xVar);
    final yRoots = solveEquation(resY, yVar);

    final solutions = <Map<String, Expr>>[];
    final seen = <String>{};

    for (final y0 in yRoots) {
      final fAtY = f.substitute(yVar, y0).simplify();
      final gAtY = g.substitute(yVar, y0).simplify();

      final xEq = fAtY.dependsOn(xVar) ? fAtY : gAtY;
      final checkEq = fAtY.dependsOn(xVar) ? gAtY : fAtY;
      final xRoots = solveEquation(xEq, xVar);
      for (final x0 in xRoots) {
        final checkVal = checkEq.substitute(xVar, x0).simplify();
        if (isZeroExpr(checkVal)) {
          final key = '${x0.simplify()}|${y0.simplify()}';
          if (seen.add(key)) {
            solutions.add({xVar: x0.simplify(), yVar: y0.simplify()});
          }
        }
      }
    }

    return solutions;
  }

  static bool _isZeroCoeff(Expr expr) => switch (expr) {
    RationalNumber(isZero: true) => true,
    RealNumber(value: 0.0) => true,
    ComplexNumber(real: 0.0, imaginary: 0.0) => true,
    _ => false,
  };
}
