import '../../linear/matrix.dart';
import '../algebra/expand.dart';
import '../algebra/helpers.dart';
import '../algebra/simplify.dart';
import '../assumptions.dart';
import '../ast.dart';
import '../linear/bareiss.dart';
import '../poly/bridge.dart';
import '../poly/univariate.dart';
import '../type/expr_data_type.dart';
import 'univariate.dart';

/// Sylvester resultant solver for bivariate polynomial systems.
class SylvesterResultantSolver {
  /// Constructs the Sylvester resultant matrix `S_x(f, g)` eliminating [elimVariable].
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
    for (final MapEntry(key: p, value: c) in fCoeffs.entries) {
      if (p > degF && !isZeroExpr(c)) degF = p;
    }
    var degG = 0;
    for (final MapEntry(key: p, value: c) in gCoeffs.entries) {
      if (p > degG && !isZeroExpr(c)) degG = p;
    }

    if (degF == 0 && degG == 0) {
      final cF = fCoeffs[0] ?? IntegerNumber.zero;
      final cG = gCoeffs[0] ?? IntegerNumber.zero;
      final val = (isZeroExpr(cF) || isZeroExpr(cG))
          ? IntegerNumber.zero
          : IntegerNumber.one;
      return Matrix<Expr>.filled(1, 1, val, type: exprDataType);
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

  /// Computes the resultant Res_x(f, g) by evaluating the determinant of the Sylvester matrix,
  /// using exact rational [PolyQ.resultant] when both operands are univariate polynomials over Q.
  static Expr resultant(Expr f, Expr g, String elimVariable) {
    final pF = exprToPolyQ(f, elimVariable);
    final pG = exprToPolyQ(g, elimVariable);
    if (pF != null && pG != null) {
      return pF.resultant(pG);
    }
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
    final yRoots = solveEquation(resY, yVar, assumptions: Assumptions.none);

    final solutions = <Map<String, Expr>>[];
    final seen = <({Expr x, Expr y})>{};

    for (final y0 in yRoots) {
      final fAtY = expF.substitute(yVar, y0).expand().simplify();
      final gAtY = expG.substitute(yVar, y0).expand().simplify();

      if (!fAtY.dependsOn(xVar) && !isZeroExpr(fAtY)) continue;
      if (!gAtY.dependsOn(xVar) && !isZeroExpr(gAtY)) continue;

      final xCandidates = <Expr>[
        if (fAtY.dependsOn(xVar))
          ...solveEquation(fAtY, xVar, assumptions: Assumptions.none),
        if (gAtY.dependsOn(xVar))
          ...solveEquation(gAtY, xVar, assumptions: Assumptions.none),
      ];
      for (final x0 in deduplicateRoots(xCandidates)) {
        final fVal = fAtY.substitute(xVar, x0).expand().simplify();
        final gVal = gAtY.substitute(xVar, x0).expand().simplify();
        if (isZeroExpr(fVal) && isZeroExpr(gVal)) {
          final xSimp = x0.simplify();
          final ySimp = y0.simplify();
          if (seen.add((x: xSimp, y: ySimp))) {
            solutions.add({xVar: xSimp, yVar: ySimp});
          }
        }
      }
    }

    return solutions;
  }
}
