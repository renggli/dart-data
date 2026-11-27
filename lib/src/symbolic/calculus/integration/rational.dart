import '../../algebra/expand.dart';
import '../../algebra/helpers.dart';
import '../../algebra/rational.dart';
import '../../algebra/simplify.dart';
import '../../assumptions.dart';
import '../../ast.dart';
import '../../compiler.dart';
import '../../functions/fn.dart';
import '../../oracle/zero_equivalence.dart';
import '../../poly/bridge.dart';
import '../differentiation.dart';
import '../linear_form.dart';
import 'definite.dart';
import 'hermite.dart';
import 'integration.dart';
import 'integration_elementary.dart';
import 'radical.dart';
import 'radical_binomial.dart';
import 'rational_binomial.dart';
import 'rational_partial_fractions.dart';
import 'trigonometric.dart';

/// Attempts quotient and rational-function integration on `left / right` with
/// respect to [variable].
Expr? tryAntiDerivDiv(
  Expr left,
  Expr right,
  String variable, {
  int depth = 0,
  required Assumptions assumptions,
}) {
  // int (c / g(x)) dx
  if (!left.dependsOn(variable)) {
    // int c / (ax + b) dx = (c ln(|ax + b|)) / a
    if (right.matchLinear(variable) case (:final a, b: _)) {
      final num = (left * logAntiderivative(right, assumptions)).simplify(
        assumptions: assumptions,
      );
      return (num / a).simplify(assumptions: assumptions);
    }

    // int c / (ax + b)^n dx = int c * (ax + b)^(-n) dx
    if (right case Pow(:final base, :final exponent)
        when !exponent.dependsOn(variable) &&
            base.matchLinear(variable) != null) {
      final negExp = (-exponent).simplify();
      final powExpr = Pow.of(base, negExp);
      return antiDerivative(
        powExpr,
        variable,
        depth: depth,
        assumptions: assumptions,
      ).scale(left);
    }

    // int c / cosh(ax + b) dx = (c / a) * atan(sinh(ax + b))
    if (right case Call(id: FunctionId.cosh, args: [final inner])) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left * Fn.atan(Fn.sinh(inner))) / a).simplify();
      }
    }

    // int c / sinh(ax + b) dx = (c / a) * (ln|e^(ax+b) - 1| - ln|e^(ax+b) + 1|)
    if (right case Call(id: FunctionId.sinh, args: [final inner])) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        final expU = Pow.of(Constant.e, inner);
        return ((left / a) *
                (logAntiderivative(expU - IntegerNumber.one, assumptions) -
                    logAntiderivative(expU + IntegerNumber.one, assumptions)))
            .simplify(assumptions: assumptions);
      }
    }

    // int c / cos(ax + b) dx = (c / a) * ln| (1 + sin(ax + b)) / cos(ax + b) |
    if (right case Call(id: FunctionId.cos, args: [final inner])) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        final secTan = ((IntegerNumber.one + Fn.sin(inner)) / Fn.cos(inner))
            .simplify();
        return ((left * Fn.ln(Fn.abs(secTan))) / a).simplify();
      }
    }

    // int c / sin(ax + b) dx = -(c / a) * ln| (1 + cos(ax + b)) / sin(ax + b) |
    if (right case Call(id: FunctionId.sin, args: [final inner])) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        final cscCot = ((IntegerNumber.one + Fn.cos(inner)) / Fn.sin(inner))
            .simplify();
        return ((-left * Fn.ln(Fn.abs(cscCot))) / a).simplify();
      }
    }

    // int c / {cos, sin, cosh, sinh}(ax + b)^2 dx
    if (right
        case Pow(base: Call(:final id, args: [final inner]), :final exponent)
        when exponent == IntegerNumber.two ||
            (exponent is RealNumber && exponent.value == 2.0)) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        final antideriv = switch (id) {
          FunctionId.cos => (left * Fn.tan(inner)) / a,
          FunctionId.sin => (-left * Fn.cos(inner)) / (a * Fn.sin(inner)),
          FunctionId.cosh => (left * Fn.tanh(inner)) / a,
          FunctionId.sinh => (-left * Fn.cosh(inner)) / (a * Fn.sinh(inner)),
          _ => null,
        };
        if (antideriv != null) return antideriv.simplify();
      }
    }

    // Higher negative trig/hyperbolic powers: sec^n, csc^n, sech^n, csch^n (3 <= n <= 10)
    if (right case Pow(:final base, exponent: IntegerNumber(asInt: final n?))
        when n >= 3 && n <= 10) {
      final nMinus1 = IntegerNumber.of(n - 1);
      final nMinus2 = IntegerNumber.of(n - 2);
      if (base case Call(id: FunctionId.cos, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (Fn.sin(inner) / (a * nMinus1 * Pow.of(Fn.cos(inner), nMinus1)))
                  .simplify();
          final rem = tryAntiDerivDiv(
            IntegerNumber.one,
            Pow.of(Fn.cos(inner), nMinus2).simplify(),
            variable,
            assumptions: assumptions,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Call(id: FunctionId.sin, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (-Fn.cos(inner) / (a * nMinus1 * Pow.of(Fn.sin(inner), nMinus1)))
                  .simplify();
          final rem = tryAntiDerivDiv(
            IntegerNumber.one,
            Pow.of(Fn.sin(inner), nMinus2).simplify(),
            variable,
            assumptions: assumptions,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Call(id: FunctionId.cosh, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (Fn.sinh(inner) / (a * nMinus1 * Pow.of(Fn.cosh(inner), nMinus1)))
                  .simplify();
          final rem = tryAntiDerivDiv(
            IntegerNumber.one,
            Pow.of(Fn.cosh(inner), nMinus2).simplify(),
            variable,
            assumptions: assumptions,
          );
          if (rem != null) {
            return (left * (term1 + (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
      if (base case Call(id: FunctionId.sinh, args: [final inner])) {
        if (inner.matchLinear(variable) case (:final a, b: _)) {
          final term1 =
              (-Fn.cosh(inner) /
                      (a * nMinus1 * Pow.of(Fn.sinh(inner), nMinus1)))
                  .simplify();
          final rem = tryAntiDerivDiv(
            IntegerNumber.one,
            Pow.of(Fn.sinh(inner), nMinus2).simplify(),
            variable,
            assumptions: assumptions,
          );
          if (rem != null) {
            return (left * (term1 - (nMinus2 / nMinus1) * rem)).simplify();
          }
        }
      }
    }

    // Weierstrass substitution for c / (A + B*sin(u) + C*cos(u))
    if (tryWeierstrassSubstitution(left, right, variable)
        case final weierRes?) {
      return weierRes;
    }

    // Completing the square for quadratic denominator: c / (Ax^2 + Bx + C)
    final coeffs = extractPolynomialCoefficients(right, variable);
    if (coeffs != null && maxPolynomialDegree(coeffs) == 2) {
      final a = coeffs[2] ?? IntegerNumber.zero;
      final b = coeffs[1] ?? IntegerNumber.zero;
      final c = coeffs[0] ?? IntegerNumber.zero;
      final delta = (IntegerNumber.of(4) * a * c - b * b).expand().simplify();
      final twoA = (IntegerNumber.two * a).simplify();
      final twoAxPlusB = (twoA * Variable(variable) + b).simplify();

      Expr atanBranch() {
        final sqrtDelta = Pow.of(delta, FractionNumber.half).simplify();
        return ((IntegerNumber.two * left / sqrtDelta) *
                Fn.atan(twoAxPlusB / sqrtDelta))
            .simplify();
      }

      Expr logAbsBranch() {
        final dPos = (-delta).simplify();
        final sqrtD = Pow.of(dPos, FractionNumber.half).simplify();
        final arg = ((twoAxPlusB - sqrtD) / (twoAxPlusB + sqrtD)).simplify();
        return ((left / sqrtD) * Fn.ln(Fn.abs(arg))).simplify();
      }

      if (delta is Number && delta.isZero) {
        final xPlus = (twoAxPlusB / twoA).simplify();
        return (-left / (a * xPlus)).simplify();
      }
      if (delta.freeVariables.isEmpty && !containsComplexSubexpr(delta)) {
        try {
          final val = delta.evaluate(const {});
          if (val.isFinite && val != 0.0) {
            return val > 0.0 ? atanBranch() : logAbsBranch();
          }
        } on UnsupportedError {
          // Fall through to symbolic check below.
        } on ArgumentError {
          // Fall through to symbolic check below.
        } on StateError {
          // Fall through to symbolic check below.
        }
      }
      if (delta case RealNumeric(:final sign)) {
        if (sign > 0) return atanBranch();
        if (sign < 0) return logAbsBranch();
      }
      if (isSyntacticallyNegative(delta) && !containsComplexSubexpr(delta)) {
        final dPos = (-delta).simplify();
        if (isSymbolicPositive(dPos) || isPositiveCoeffMonomial(dPos)) {
          return logAbsBranch();
        }
      }
      return atanBranch();
    }

    // int c / (d + exp(ax + b)) dx = (c / d) * (x - (1 / a) * ln|d + exp(ax + b)|)
    if (right
        case Add(terms: [final rL, Pow(base: Constant.e, :final exponent)])
        when !rL.dependsOn(variable)) {
      if (exponent.matchLinear(variable) case (:final a, b: _)) {
        final term =
            (Variable(variable) - (logAntiderivative(right, assumptions) / a))
                .simplify(assumptions: assumptions);
        return ((left / rL) * term).simplify(assumptions: assumptions);
      }
    }
  }

  if (tryPowerOverLogPower(left, right, variable, assumptions: assumptions)
      case final logPowRes?) {
    return logPowRes;
  }

  if (tryTrigOrHypOverLinearPower(
        left,
        right,
        variable,
        assumptions: assumptions,
      )
      case final trigHypLinRes?) {
    return trigHypLinRes;
  }
  if (tryExpOverRational(
        left,
        right,
        variable,
        depth: depth,
        assumptions: assumptions,
      )
      case final expRatRes?) {
    return expRatRes;
  }

  // int u'(x) / (a + b * u(x)^2) dx = (1 / sqrt(a * b)) * arctan(sqrt(b / a) * u(x))
  if (right case Add(terms: [final rL, final rR])) {
    if (rL case RationalNumber(isOne: true) || RealNumber(value: 1.0)) {
      if (extractSquareBase(rR) case final u? when u.dependsOn(variable)) {
        final uPrime = u.derivative(variable).simplify();
        if (left.matchScalarMultiple(uPrime, variable) case final k?) {
          return Fn.atan(u).scale(k);
        }
      }
    }
    // General positive constant a + sqTerm
    if (!rL.dependsOn(variable) &&
        rR.dependsOn(variable) &&
        isSymbolicPositive(rL)) {
      if (extractScaledSquareBase((rR / rL).simplify(), variable) case final w?
          when w.dependsOn(variable)) {
        final wPrime = w.derivative(variable).simplify();
        if (left.matchScalarMultiple(wPrime, variable) case final k?) {
          return Fn.atan(w).scale((k / rL).simplify());
        }
      }
    }
  }

  // int u'(x) / sqrt(a - u(x)^2) dx = asin(u(x) / sqrt(a))
  // int u'(x) / sqrt(a + u(x)^2) dx = asinh(u(x) / sqrt(a))
  // int u'(x) / sqrt(u(x)^2 - a) dx = ln|u(x) + sqrt(u(x)^2 - a)|
  if (right case Pow(base: Add(terms: [final t0, final t1]), :final exponent)
      when exponent == FractionNumber.half ||
          (exponent is RealNumber && exponent.value == 0.5)) {
    final aConst = !t0.dependsOn(variable)
        ? t0
        : (!t1.dependsOn(variable) ? t1 : null);
    final varTerm = !t0.dependsOn(variable) ? t1 : t0;
    if (aConst != null) {
      if (isSymbolicPositive(aConst)) {
        final sqrtA = aConst == IntegerNumber.one
            ? IntegerNumber.one
            : Pow.of(aConst, FractionNumber.half).simplify();
        final negTerm = (-varTerm).simplify();
        if (extractScaledSquareBase(negTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Fn.asin(u / sqrtA).scale(k);
          }
        }
        if (extractScaledSquareBase(varTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Fn.asinh(u / sqrtA).scale(k);
          }
        }
      } else if (isSymbolicPositive((-aConst).simplify())) {
        if (extractScaledSquareBase(varTerm, variable) case final u?
            when u.dependsOn(variable)) {
          final uPrime = u.derivative(variable).simplify();
          if (left.matchScalarMultiple(uPrime, variable) case final k?) {
            return Fn.ln(Fn.abs((u + right).simplify())).scale(k);
          }
        }
      }
    }
  }

  // c / ln(ax + b) -> (c / a) * li(ax + b)
  // L / (a + b * ln(c*x + d)) -> (L / (b*c)) * exp(-a/b) * li((c*x + d) * exp(a/b))
  if (!left.dependsOn(variable)) {
    if (right case Call(id: FunctionId.ln, args: [final inner])) {
      if (inner.matchLinear(variable) case (:final a, b: _)) {
        return ((left / a) * Fn.li(inner)).simplify();
      }
    }
    if (matchLinearLog(right, variable) case (
      :final a,
      :final b,
      :final inner,
    )) {
      if (inner.matchLinear(variable) case (a: final c, b: _)) {
        final ratio = (a / b).simplify(assumptions: assumptions);
        return ((left / (b * c)) *
                Pow.of(Constant.e, -ratio) *
                Fn.li(inner * Pow.of(Constant.e, ratio)))
            .simplify(assumptions: assumptions);
      }
    }
  }

  // Split ln(c * x) -> ln(c) + ln(x) when denominator contains ln(x)
  if (depth < 2 &&
      right.anyNode(
        (n) =>
            n is Call &&
            n.id == FunctionId.ln &&
            n.args[0] == Variable(variable),
      ) &&
      left.anyNode((n) => isScaledVarLn(n, variable))) {
    final splitLeft = splitScaledVarLn(
      left,
      variable,
    ).simplify(assumptions: assumptions);
    if (splitLeft != left) {
      final res = antiDerivative(
        (splitLeft / right).simplify(assumptions: assumptions),
        variable,
        depth: depth + 1,
        assumptions: assumptions,
      );
      if (!hasUnevaluatedIntegral(res, variable)) return res;
    }
  }

  // Linear log / atan / atanh / polylog quotients: scale * f(u) / (c + d*x)
  final Expr leftScale;
  final Expr leftFn;
  if (left is Mul) {
    final cList = <Expr>[];
    final vList = <Expr>[];
    for (final f in left.factors) {
      if (f.dependsOn(variable)) {
        vList.add(f);
      } else {
        cList.add(f);
      }
    }
    if (vList.length == 1) {
      leftScale = cList.isEmpty
          ? IntegerNumber.one
          : Mul.of(cList).simplify(assumptions: assumptions);
      leftFn = vList.first;
    } else {
      leftScale = IntegerNumber.one;
      leftFn = left;
    }
  } else {
    leftScale = IntegerNumber.one;
    leftFn = left;
  }

  if (right.matchLinear(variable) case (a: final d, b: final c)) {
    switch (leftFn) {
      case Call(id: FunctionId.ln, args: [final inner]):
        if (inner.matchLinear(variable) case (a: final b, b: final a)) {
          return _integrateLinearLnOverLinear(
            leftScale,
            inner,
            a,
            b,
            right,
            c,
            d,
            variable,
            assumptions,
          );
        }
      case Call(id: FunctionId.atan, args: [final inner]):
        if (inner.matchLinear(variable) case (a: _, b: final a)) {
          if (a is Number && a.isZero && c is Number && c.isZero) {
            return ((leftScale * ComplexNumber.i / (IntegerNumber.two * d)) *
                    (Fn.polylog(IntegerNumber.two, -ComplexNumber.i * inner) -
                        Fn.polylog(IntegerNumber.two, ComplexNumber.i * inner)))
                .simplify(assumptions: assumptions);
          }
          final uPlus = (IntegerNumber.one + ComplexNumber.i * inner).simplify(
            assumptions: assumptions,
          );
          final uMinus = (IntegerNumber.one - ComplexNumber.i * inner).simplify(
            assumptions: assumptions,
          );
          final linP = uPlus.matchLinear(variable);
          final linM = uMinus.matchLinear(variable);
          if (linP != null && linM != null) {
            final lnP = _integrateLinearLnOverLinear(
              IntegerNumber.one,
              uPlus,
              linP.b,
              linP.a,
              right,
              c,
              d,
              variable,
              assumptions,
            );
            final lnM = _integrateLinearLnOverLinear(
              IntegerNumber.one,
              uMinus,
              linM.b,
              linM.a,
              right,
              c,
              d,
              variable,
              assumptions,
            );
            return (leftScale *
                    (lnP - lnM) /
                    (IntegerNumber.two * ComplexNumber.i))
                .simplify(assumptions: assumptions);
          }
        }
        final recip = (inner * Variable(variable)).simplify(
          assumptions: assumptions,
        );
        if (!recip.dependsOn(variable) && c is Number && c.isZero) {
          return ((-leftScale * ComplexNumber.i / (IntegerNumber.two * d)) *
                  (Fn.polylog(IntegerNumber.two, -ComplexNumber.i * inner) -
                      Fn.polylog(IntegerNumber.two, ComplexNumber.i * inner)))
              .simplify(assumptions: assumptions);
        }
      case Call(id: FunctionId.atanh, args: [final inner]):
        if (inner.matchLinear(variable) case (a: _, b: final a)) {
          if (a is Number && a.isZero && c is Number && c.isZero) {
            return ((leftScale / (IntegerNumber.two * d)) *
                    (Fn.polylog(IntegerNumber.two, inner) -
                        Fn.polylog(IntegerNumber.two, -inner)))
                .simplify(assumptions: assumptions);
          }
          final uPlus = (IntegerNumber.one + inner).simplify(
            assumptions: assumptions,
          );
          final uMinus = (IntegerNumber.one - inner).simplify(
            assumptions: assumptions,
          );
          final linP = uPlus.matchLinear(variable);
          final linM = uMinus.matchLinear(variable);
          if (linP != null && linM != null) {
            final lnP = _integrateLinearLnOverLinear(
              IntegerNumber.one,
              uPlus,
              linP.b,
              linP.a,
              right,
              c,
              d,
              variable,
              assumptions,
            );
            final lnM = _integrateLinearLnOverLinear(
              IntegerNumber.one,
              uMinus,
              linM.b,
              linM.a,
              right,
              c,
              d,
              variable,
              assumptions,
            );
            return (leftScale * (lnP - lnM) / IntegerNumber.two).simplify(
              assumptions: assumptions,
            );
          }
        }
        final recip = (inner * Variable(variable)).simplify(
          assumptions: assumptions,
        );
        if (!recip.dependsOn(variable) && c is Number && c.isZero) {
          return ((-leftScale / (IntegerNumber.two * d)) *
                  (Fn.polylog(IntegerNumber.two, inner) -
                      Fn.polylog(IntegerNumber.two, -inner)))
              .simplify(assumptions: assumptions);
        }
      case Call(id: FunctionId.polylog, args: [final order, final arg])
          when !order.dependsOn(variable) && c is Number && c.isZero:
        RationalNumber? monoExp;
        if (arg case Variable(:final name) when name == variable) {
          monoExp = IntegerNumber.one;
        } else if (arg
            case Pow(
              base: Variable(:final name),
              exponent: final RationalNumber m,
            )
            when name == variable && !m.isZero) {
          monoExp = m;
        } else if (arg case Mul(:final factors)) {
          final vfs = [
            for (final mf in factors)
              if (mf.dependsOn(variable)) mf,
          ];
          if (vfs.length == 1) {
            if (vfs.first case Variable(:final name) when name == variable) {
              monoExp = IntegerNumber.one;
            } else if (vfs.first
                case Pow(
                  base: Variable(:final name),
                  exponent: final RationalNumber m,
                )
                when name == variable && !m.isZero) {
              monoExp = m;
            }
          }
        }
        if (monoExp != null) {
          return (leftScale *
                  Fn.polylog(
                    (order + IntegerNumber.one).simplify(
                      assumptions: assumptions,
                    ),
                    arg,
                  ) /
                  (d * monoExp))
              .simplify(assumptions: assumptions);
        }
      default:
        break;
    }
  }

  // c * exp(a*x + b) / (c1*x + d)^k -> Ei reduction (k >= 7)
  if (left case Pow(base: Constant.e, exponent: final expInner)) {
    if (expInner.matchLinear(variable) case (:final a, b: _)) {
      if (right
          case Pow(base: final rBase, exponent: IntegerNumber(asInt: final k?))
          when k >= 7 && k <= 8) {
        if (rBase.matchLinear(variable) case (a: final c1, b: _)) {
          final kMinus1 = IntegerNumber.of(k - 1);
          final term1 = (-left / (c1 * kMinus1 * Pow.of(rBase, kMinus1)))
              .simplify();
          final rem = antiDerivative(
            (a * left / (c1 * kMinus1 * Pow.of(rBase, kMinus1))).simplify(),
            variable,
            depth: 1,
            assumptions: assumptions,
          );
          if (!hasUnevaluatedIntegral(rem, variable)) {
            return (term1 + rem).simplify();
          }
        }
      }
    }
  }

  // c * (sin|cos|sinh|cosh|exp)(a*x + b) / (c1*x + d1)
  if (right.matchLinear(variable) case (a: final c1, b: final d1)) {
    final (:constFactors, :varFactors) = partitionFactors(
      left is Mul ? left.factors : [left],
      variable,
    );
    if (varFactors case [final vf]) {
      final scale = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul.of(constFactors).simplify(),
      };
      Expr? shiftedTrigInt(
        Expr inner,
        Expr Function(Expr) sameFn,
        Expr Function(Expr) crossFn,
        Expr Function(Expr) sameWeight,
        Expr Function(Expr) crossWeight,
        int crossSign,
      ) {
        if (inner.matchLinear(variable) case (:final a, :final b)) {
          final alpha = (a / c1).simplify();
          final u = (alpha * right).simplify();
          final phi = (b - (a * d1) / c1).simplify();
          if (phi is Number && phi.isZero) {
            return (scale * sameFn(u) / c1).simplify();
          }
          final sum = crossSign > 0
              ? sameWeight(phi) * sameFn(u) + crossWeight(phi) * crossFn(u)
              : sameWeight(phi) * sameFn(u) - crossWeight(phi) * crossFn(u);
          return (scale * sum / c1).simplify();
        }
        return null;
      }

      switch (vf) {
        case Call(id: FunctionId.sin, args: [final inner]):
          if (shiftedTrigInt(
                inner,
                Fn.si.call,
                Fn.ci.call,
                Fn.cos.call,
                Fn.sin.call,
                1,
              )
              case final res?) {
            return res;
          }
        case Call(id: FunctionId.cos, args: [final inner]):
          if (shiftedTrigInt(
                inner,
                Fn.ci.call,
                Fn.si.call,
                Fn.cos.call,
                Fn.sin.call,
                -1,
              )
              case final res?) {
            return res;
          }
        case Call(id: FunctionId.sinh, args: [final inner]):
          if (shiftedTrigInt(
                inner,
                Fn.shi.call,
                Fn.chi.call,
                Fn.cosh.call,
                Fn.sinh.call,
                1,
              )
              case final res?) {
            return res;
          }
        case Call(id: FunctionId.cosh, args: [final inner]):
          if (shiftedTrigInt(
                inner,
                Fn.chi.call,
                Fn.shi.call,
                Fn.cosh.call,
                Fn.sinh.call,
                1,
              )
              case final res?) {
            return res;
          }
        default:
          break;
      }
    } else if (varFactors case [final f0, final f1]) {
      final scale = switch (constFactors) {
        [] => IntegerNumber.one,
        [final single] => single,
        _ => Mul.of(constFactors).simplify(),
      };
      final Pow? expNode;
      final Call? trigNode;
      if (f0 is Pow && f0.base == Constant.e && f1 is Call) {
        expNode = f0;
        trigNode = f1;
      } else if (f1 is Pow && f1.base == Constant.e && f0 is Call) {
        expNode = f1;
        trigNode = f0;
      } else {
        expNode = null;
        trigNode = null;
      }
      if (expNode != null &&
          trigNode != null &&
          (trigNode.id == FunctionId.sin || trigNode.id == FunctionId.cos)) {
        final expLin = expNode.exponent.matchLinear(variable);
        final trigLin = trigNode.args[0].matchLinear(variable);
        if (expLin != null && trigLin != null) {
          final shiftVar = (Variable(variable) + d1 / c1).simplify();
          final expConst = Pow.of(
            Constant.e,
            (expLin.b - (expLin.a * d1) / c1).simplify(),
          );
          final phi = (trigLin.b - (trigLin.a * d1) / c1).simplify();
          final iCoeff = ComplexNumber.i;
          final kPlus = (expLin.a + iCoeff * trigLin.a).simplify();
          final kMinus = (expLin.a - iCoeff * trigLin.a).simplify();
          final eiPlus = Fn.ei((kPlus * shiftVar).simplify());
          final eiMinus = Fn.ei((kMinus * shiftVar).simplify());
          final termPlus = (Pow.of(Constant.e, iCoeff * phi) * eiPlus)
              .simplify();
          final termMinus = (Pow.of(Constant.e, -iCoeff * phi) * eiMinus)
              .simplify();
          final trigComb = trigNode.id == FunctionId.sin
              ? (termPlus - termMinus) / (IntegerNumber.two * iCoeff)
              : (termPlus + termMinus) / IntegerNumber.two;
          return (scale * expConst * trigComb / c1).simplify(
            assumptions: assumptions,
          );
        }
      }
    }
  }

  // Quadratic radical denominator: (p*x + q) / (Ax^2 + Bx + C)^(k/2)
  if (right case Pow(:final base, :final exponent)) {
    if (halfIntExponent(exponent) case final halfExp?) {
      final quadRad = tryQuadraticRadical(left, base, -halfExp, variable);
      if (quadRad != null) return quadRad;
    }
  }

  // c / (x * sqrt(A*x^2 + C))
  if (!left.dependsOn(variable)) {
    if (right case Mul(factors: [final f0, final f1])) {
      final Variable? xFactor;
      final Pow? radFactor;
      if (f0 is Variable && f0.name == variable && f1 is Pow) {
        xFactor = f0;
        radFactor = f1;
      } else if (f1 is Variable && f1.name == variable && f0 is Pow) {
        xFactor = f1;
        radFactor = f0;
      } else {
        xFactor = null;
        radFactor = null;
      }
      if (xFactor != null &&
          radFactor != null &&
          halfIntExponent(radFactor.exponent) == 1) {
        final coeffs = extractPolynomialCoefficients(radFactor.base, variable);
        if (coeffs != null &&
            maxPolynomialDegree(coeffs) == 2 &&
            (coeffs[1] == null || coeffs[1] == IntegerNumber.zero)) {
          final cConst = coeffs[0] ?? IntegerNumber.zero;
          if (isSymbolicPositive(cConst)) {
            final sqrtC = Pow.of(cConst, FractionNumber.half).simplify();
            return ((-left / sqrtC) *
                    Fn.ln(Fn.abs((sqrtC + radFactor) / xFactor)))
                .simplify();
          }
          final negC = (-cConst).simplify();
          if (isSymbolicPositive(negC)) {
            final sqrtNegC = Pow.of(negC, FractionNumber.half).simplify();
            return ((left / sqrtNegC) * Fn.atan(radFactor / sqrtNegC))
                .simplify();
          }
        }
      }
    }
  }

  // Chain rule quotient: int u'(x) / u(x) dx = ln(|u(x)|) and u'(x) / u(x)^m dx
  if (right.dependsOn(variable)) {
    final uPrime = right.derivative(variable).simplify();
    var k = left.matchScalarMultiple(uPrime, variable);
    if (k == null) {
      if ((left - uPrime).simplify() == IntegerNumber.zero) {
        k = IntegerNumber.one;
      } else if ((left + uPrime).simplify() == IntegerNumber.zero) {
        k = IntegerNumber.negativeOne;
      }
    }
    if (k != null) {
      return logAntiderivative(
        right,
        assumptions,
      ).simplify(assumptions: assumptions).scale(k);
    }
    if (right
        case Pow(base: final uBase, exponent: IntegerNumber(asInt: final m?))
        when m >= 2 && uBase.dependsOn(variable)) {
      final basePrime = uBase.derivative(variable).simplify();
      var km = left.matchScalarMultiple(basePrime, variable);
      if (km == null) {
        if ((left - basePrime).simplify() == IntegerNumber.zero) {
          km = IntegerNumber.one;
        } else if ((left + basePrime).simplify() == IntegerNumber.zero) {
          km = IntegerNumber.negativeOne;
        }
      }
      if (km != null) {
        final oneMinusM = IntegerNumber.of(1 - m);
        return (km * Pow.of(uBase, oneMinusM) / oneMinusM).simplify(
          assumptions: assumptions,
        );
      }
    }
  }

  // Trigonometric and hyperbolic quotients/powers: sin^p(u)/cos^q(u), sinh^p(u)/cosh^q(u)
  if (tryTrigPowerProduct(left, right, variable) case final trigQuot?) {
    return trigQuot;
  }
  if (tryHypPowerProduct(left, right, variable, assumptions: assumptions)
      case final hypQuot?) {
    return hypQuot;
  }

  // Linear trig quotient: (a1*sin(u) + b1*cos(u) + c1) / (a*sin(u) + b*cos(u) + c)
  if (tryLinearTrigQuotient(left, right, variable) case final linTrigRes?) {
    return linTrigRes;
  }

  // Polynomial / (x^k * sqrt(Q)) or sqrt(Q) / x^k or x^m / sqrt(Q)
  if (tryPolynomialOverSqrtQuadratic(left, right, variable)
      case final polySqrtRes?) {
    return polySqrtRes;
  }

  if (right.dependsOn(variable)) {
    if (tryMonomialDenominator(left, right, variable, assumptions: assumptions)
        case final monoRes?) {
      return monoRes;
    }
    if (tryLinearPowerDenominator(
          left,
          right,
          variable,
          assumptions: assumptions,
        )
        case final linPowRes?) {
      return linPowRes;
    }
    if (tryTwoLinearPowersDenominator(
          left,
          right,
          variable,
          assumptions: assumptions,
        )
        case final twoLinPowRes?) {
      return twoLinPowRes;
    }
    if (tryFactoredBinomialPowersDenominator(
          left,
          right,
          variable,
          depth: depth,
          assumptions: assumptions,
        )
        case final factoredBinomRes?) {
      return factoredBinomRes;
    }
    if (tryMonomialTimesPolyDenominator(
          left,
          right,
          variable,
          depth: depth,
          assumptions: assumptions,
        )
        case final monoPolyRes?) {
      return monoPolyRes;
    }
  }

  // Repeated quadratic denominator: P(x) / (Ax^2 + Bx + C)^m (m >= 2)
  if (right case Pow(base: final quad, exponent: IntegerNumber(asInt: final m?))
      when m >= 2 && m <= 10) {
    if (tryRepeatedQuadratic(left, quad, m, variable) case final repRes?) {
      return repRes;
    }
  }

  // Ostrogradsky reduction for x^k / (a + b*x^n)^m
  if (tryBinomialPowerOstrogradsky(
        left,
        right,
        variable,
        depth: depth,
        assumptions: assumptions,
      )
      case final ostroRes?) {
    return ostroRes;
  }

  // Rationalize P(x) / (c1 * sqrt(A) + c2 * sqrt(B)) denominators when A - B is radical-free
  if (depth < 2 && right is Add && right.terms.length == 2) {
    final conjRes = tryConjugateRadicalDenominator(
      left,
      right.terms[0],
      right.terms[1],
      variable,
      depth: depth,
      assumptions: assumptions,
    );
    if (conjRes != null) return conjRes;

    final sumProdRes = trySumToProductTrigQuotient(
      left,
      right,
      variable,
      depth: depth,
      assumptions: assumptions,
    );
    if (sumProdRes != null) return sumProdRes;
  }

  // Rational functions P(x) / Q(x): polynomial division and partial fractions
  if (right.dependsOn(variable)) {
    final rawDegLeft = polynomialDegree(left, variable);
    final rawDegRight = polynomialDegree(right, variable);
    final paramCount = ({
      ...left.freeVariables,
      ...right.freeVariables,
    }..remove(variable)).length;
    if (rawDegLeft != null && rawDegRight != null && rawDegRight >= 4) {
      if (tryPowerSubstitution(
            left,
            right,
            variable,
            depth: depth,
            assumptions: assumptions,
          )
          case final powSubRes?) {
        return powSubRes;
      }
    }
    if (rawDegLeft != null &&
        rawDegRight != null &&
        rawDegRight >= 1 &&
        (rawDegLeft >= rawDegRight ? rawDegRight <= 24 : rawDegRight <= 12) &&
        !isIntegrationBudgetExhausted() &&
        !exceedsNodeBudget(left, 250) &&
        !exceedsNodeBudget(right, 250)) {
      final leftExp = left.expand().simplify();
      final rightExp = right.expand().simplify();
      final degLeft = polynomialDegree(leftExp, variable);
      final degRight = polynomialDegree(rightExp, variable);
      if (degLeft != null && degRight != null && degRight >= 1) {
        final withinPolyBudget =
            !isIntegrationBudgetExhausted() &&
            !exceedsNodeBudget(leftExp, 300) &&
            !exceedsNodeBudget(rightExp, 300);
        final isDenseMultivariate =
            paramCount >= 5 &&
            degRight >= 6 &&
            rightExp is Add &&
            rightExp.terms.length > 4;
        if (depth < 2 &&
            degLeft <= 12 &&
            degRight <= 12 &&
            withinPolyBudget &&
            !isDenseMultivariate) {
          final canceled = (leftExp / rightExp).cancel(
            assumptions: assumptions,
          );
          final (_, cDen) = splitNumeratorDenominator(canceled);
          final cDegDen = polynomialDegree(cDen.expand().simplify(), variable);
          if (cDegDen != null && cDegDen < degRight) {
            return antiDerivative(
              canceled,
              variable,
              depth: depth + 1,
              assumptions: assumptions,
            );
          }
        }
        if (degLeft >= degRight && degRight <= 24) {
          final (:quotient, :remainder) = leftExp.polynomialDivide(
            rightExp,
            variable,
          );
          final qInt = antiDerivative(
            quotient,
            variable,
            depth: depth,
            assumptions: assumptions,
          );
          if (remainder is Number && remainder.isZero) {
            return qInt;
          }
          final rInt = antiDerivative(
            (remainder / rightExp).simplify(),
            variable,
            depth: depth,
            assumptions: assumptions,
          );
          return (qInt + rInt).simplify();
        }
        if (degRight == 2 && degLeft <= 1) {
          final quadCoeffs = extractPolynomialCoefficients(rightExp, variable)!;
          final numCoeffs = extractPolynomialCoefficients(leftExp, variable)!;
          final a = quadCoeffs[2] ?? IntegerNumber.zero;
          final b = quadCoeffs[1] ?? IntegerNumber.zero;
          final d = numCoeffs[1] ?? IntegerNumber.zero;
          final e = numCoeffs[0] ?? IntegerNumber.zero;
          final quadRes = integrateLinearOverQuad(
            d,
            e,
            rightExp,
            a,
            b,
            variable,
          );
          if (!hasUnevaluatedIntegral(quadRes, variable)) {
            return quadRes;
          }
        }
        if (degRight == 3) {
          if (tryCubicBinomialDenominator(leftExp, rightExp, variable)
              case final cubRes?) {
            return cubRes;
          }
        }
        if (degRight == 4) {
          if (trySophieGermainQuartic(leftExp, rightExp, variable)
              case final quartRes?) {
            return quartRes;
          }
          if (tryBiquadraticDenominator(leftExp, rightExp, variable)
              case final biqRes?) {
            return biqRes;
          }
        }
        if (degRight >= 2) {
          if (tryDistinctLinearPartialFractions(left, right, variable)
              case final pfRes?) {
            return pfRes;
          }
        }
        if (degRight >= 2 && withinPolyBudget && !isDenseMultivariate) {
          if (exprToPolyQ(leftExp, variable) case final numQ?) {
            if (exprToPolyQ(rightExp, variable) case final denQ?
                when denQ.degree >= 2) {
              final hermite = hermiteReduce(
                numQ,
                denQ,
                variable,
                assumptions: assumptions,
              );
              if (hermite.num.isZero) {
                return hermite.rationalPart;
              }
              if (integrateSquareFreeRational(
                    hermite.num,
                    hermite.den,
                    variable,
                    assumptions: assumptions,
                  )
                  case final sfRes?) {
                return (hermite.rationalPart + sfRes).simplify(
                  assumptions: assumptions,
                );
              }
              if (!isZeroExpr(hermite.rationalPart) && depth < 2) {
                final remExpr =
                    (polyQToExpr(hermite.num, variable) /
                            polyQToExpr(hermite.den, variable))
                        .simplify(assumptions: assumptions);
                final remInt = antiDerivative(
                  remExpr,
                  variable,
                  depth: depth + 1,
                  assumptions: assumptions,
                );
                if (!hasUnevaluatedIntegral(remInt, variable)) {
                  return (hermite.rationalPart + remInt).simplify(
                    assumptions: assumptions,
                  );
                }
              }
            }
          }
        }
        if (degRight >= 2 &&
            right is! Pow &&
            withinPolyBudget &&
            !isDenseMultivariate) {
          final sqFree = squareFreeFactorization(rightExp, variable);
          if (sqFree != null && sqFree.any((e) => e.mult > 1)) {
            final rightCoeffs = extractPolynomialCoefficients(
              rightExp,
              variable,
            )!;
            final lead = rightCoeffs[degRight] ?? IntegerNumber.one;
            var factoredDen = lead;
            for (final entry in sqFree) {
              factoredDen =
                  factoredDen *
                  (entry.mult == 1
                      ? entry.factor
                      : Pow.of(entry.factor, IntegerNumber.of(entry.mult)));
            }
            if (sqFree.length == 1) {
              final factor = sqFree.first.factor;
              final mult = sqFree.first.mult;
              final degF = polynomialDegree(factor, variable) ?? 0;
              if (degF == 2) {
                final scaledLeft = (leftExp / lead).simplify(
                  assumptions: assumptions,
                );
                if (tryRepeatedQuadratic(scaledLeft, factor, mult, variable)
                    case final repRes?) {
                  return repRes;
                }
              }
            }
            final factoredRatio = (leftExp / factoredDen).simplify(
              assumptions: assumptions,
            );
            final decomposed = factoredRatio.apart(variable);
            if (decomposed is Add) {
              return Add.of([
                for (final term in decomposed.terms)
                  antiDerivative(
                    term,
                    variable,
                    depth: depth,
                    assumptions: assumptions,
                  ),
              ]).simplify(assumptions: assumptions);
            }
          }
        }
        if (degRight >= 2 &&
            degRight <= 12 &&
            withinPolyBudget &&
            !isDenseMultivariate) {
          final originalRatio = (left / right).simplify();
          final decomposed = originalRatio.apart(variable);
          if (decomposed case Add(:final terms)) {
            return Add.of([
              for (final term in terms)
                antiDerivative(
                  term,
                  variable,
                  depth: depth,
                  assumptions: assumptions,
                ),
            ]).simplify();
          }
          if (decomposed != originalRatio) {
            final (_, newDen) = splitNumeratorDenominator(decomposed);
            final newDeg = polynomialDegree(
              newDen.expand().simplify(),
              variable,
            );
            if ((newDeg != null && newDeg < degRight) ||
                (newDen is Pow &&
                    (newDen.base.matchLinear(variable) != null ||
                        (newDen.exponent is IntegerNumber &&
                            (newDen.exponent as IntegerNumber).value >
                                BigInt.one))) ||
                newDen.matchLinear(variable) != null) {
              return antiDerivative(
                decomposed,
                variable,
                depth: depth,
                assumptions: assumptions,
              );
            }
          }
        }
      }
    }
  }

  return null;
}

Expr _integrateLinearLnOverLinear(
  Expr scale,
  Expr u,
  Expr a,
  Expr b,
  Expr v,
  Expr c,
  Expr d,
  String variable,
  Assumptions assumptions,
) {
  final det = (b * c - a * d).expand().simplify(assumptions: assumptions);
  if (det is Number && det.isZero) {
    return (scale *
            Pow.of(Fn.ln(u), IntegerNumber.two) /
            (IntegerNumber.two * d))
        .simplify(assumptions: assumptions);
  }
  if (c is Number && c.isZero) {
    final ratio = (b * Variable(variable) / a).simplify(
      assumptions: assumptions,
    );
    return ((scale / d) *
            ((Fn.ln(u) - Fn.ln(IntegerNumber.one + ratio)) *
                    logAntiderivative(Variable(variable), assumptions) -
                Fn.polylog(IntegerNumber.two, -ratio)))
        .simplify(assumptions: assumptions);
  }
  final z = (-d * u / det).simplify(assumptions: assumptions);
  final oneMinusZ = (b * v / det).simplify(assumptions: assumptions);
  return ((scale / d) *
          (Fn.ln(u) * Fn.ln(oneMinusZ) + Fn.polylog(IntegerNumber.two, z)))
      .simplify(assumptions: assumptions);
}
