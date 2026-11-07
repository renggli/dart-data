import '../../linear/matrix.dart';
import '../algebra/expand.dart';
import '../algebra/simplify.dart';
import '../algebra/term_accumulator.dart';
import '../ast.dart';
import '../linear/bareiss.dart';
import '../type/expr_data_type.dart';
import 'univariate.dart';

/// Sylvester resultant solver for bivariate polynomial systems.
class SylvesterResultantSolver {
  /// Constructs the Sylvester resultant matrix $S_x(f, g)$ eliminating [elimVariable].
  static Matrix<Expr> sylvesterMatrix(Expr f, Expr g, String elimVariable) {
    final expF = f.expand().simplify();
    final expG = g.expand().simplify();
    final fCoeffs =
        extractPolynomialCoefficients(expF, elimVariable) ??
        (throw ArgumentError(
          'Expression f is not polynomial in $elimVariable: $f',
        ));
    final gCoeffs =
        extractPolynomialCoefficients(expG, elimVariable) ??
        (throw ArgumentError(
          'Expression g is not polynomial in $elimVariable: $g',
        ));

    var degF = 0;
    for (final p in fCoeffs.keys) {
      if (p > degF && !isZeroExpr(fCoeffs[p]!)) degF = p;
    }
    var degG = 0;
    for (final p in gCoeffs.keys) {
      if (p > degG && !isZeroExpr(gCoeffs[p]!)) degG = p;
    }

    if (degF == 0 && degG == 0) {
      final mat = Matrix<Expr>.filled(
        1,
        1,
        IntegerNumber.one,
        type: exprDataType,
      );
      return mat;
    }
    if (degF == 0) {
      final mat = Matrix<Expr>.filled(
        degG,
        degG,
        IntegerNumber.zero,
        type: exprDataType,
      );
      final cF = fCoeffs[0] ?? IntegerNumber.zero;
      for (var i = 0; i < degG; i++) {
        mat.setUnchecked(i, i, cF);
      }
      return mat;
    }
    if (degG == 0) {
      final mat = Matrix<Expr>.filled(
        degF,
        degF,
        IntegerNumber.zero,
        type: exprDataType,
      );
      final cG = gCoeffs[0] ?? IntegerNumber.zero;
      for (var i = 0; i < degF; i++) {
        mat.setUnchecked(i, i, cG);
      }
      return mat;
    }

    final dim = degF + degG;
    final mat = Matrix<Expr>.filled(
      dim,
      dim,
      IntegerNumber.zero,
      type: exprDataType,
    );

    // Rows for f (degG rows)
    for (var i = 0; i < degG; i++) {
      for (var p = degF; p >= 0; p--) {
        final coeff = fCoeffs[p] ?? IntegerNumber.zero;
        final col = (degF - p) + i;
        if (col < dim) {
          mat.setUnchecked(i, col, coeff);
        }
      }
    }

    // Rows for g (degF rows)
    for (var j = 0; j < degF; j++) {
      for (var p = degG; p >= 0; p--) {
        final coeff = gCoeffs[p] ?? IntegerNumber.zero;
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
    return const BareissEngine().determinant(mat).expand().simplify();
  }

  /// Solves a bivariate polynomial system `f = 0, g = 0` for [variables] via Sylvester resultant elimination.
  static List<Map<String, Expr>> solve(Expr f, Expr g, List<String> variables) {
    final String xVar;
    final String yVar;
    if (variables case [final x, final y]) {
      xVar = x;
      yVar = y;
    } else {
      throw ArgumentError(
        'Sylvester resultant solver requires exactly 2 variables, got ${variables.length}',
      );
    }

    final expF = f.expand().simplify();
    final expG = g.expand().simplify();
    final resY = resultant(expF, expG, xVar);
    final yRoots = solveEquation(resY, yVar);

    final solutions = <Map<String, Expr>>[];
    final seen = <String>{};

    for (final y0 in yRoots) {
      final fAtY = expF.substitute(yVar, y0).expand().simplify();
      final gAtY = expG.substitute(yVar, y0).expand().simplify();

      if (!fAtY.dependsOn(xVar) && !isZeroExpr(fAtY)) continue;
      if (!gAtY.dependsOn(xVar) && !isZeroExpr(gAtY)) continue;

      final xCandidates = <Expr>[
        if (fAtY.dependsOn(xVar)) ...solveEquation(fAtY, xVar),
        if (gAtY.dependsOn(xVar)) ...solveEquation(gAtY, xVar),
      ];
      for (final x0 in deduplicateRoots(xCandidates)) {
        final fVal = fAtY.substitute(xVar, x0).expand().simplify();
        final gVal = gAtY.substitute(xVar, x0).expand().simplify();
        if (isZeroExpr(fVal) && isZeroExpr(gVal)) {
          final key = '${x0.simplify()}|${y0.simplify()}';
          if (seen.add(key)) {
            solutions.add({xVar: x0.simplify(), yVar: y0.simplify()});
          }
        }
      }
    }

    return solutions;
  }
}
