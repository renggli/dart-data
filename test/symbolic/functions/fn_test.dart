import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Fn canonical namespace', () {
    test('exposes canonical non-symbolic specs matching standardFunctions', () {
      final standardNames = {
        for (final info in ExprSyntax.standardFunctions) info.name,
      };
      final specs = <FunctionSpec>[
        Fn.sin,
        Fn.cos,
        Fn.tan,
        Fn.asin,
        Fn.acos,
        Fn.atan,
        Fn.atan2,
        Fn.sinh,
        Fn.cosh,
        Fn.tanh,
        Fn.asinh,
        Fn.acosh,
        Fn.atanh,
        Fn.abs,
        Fn.ln,
        Fn.re,
        Fn.im,
        Fn.arg,
        Fn.conj,
        Fn.factorial,
        Fn.binomial,
        Fn.floor,
        Fn.ceil,
        Fn.round,
        Fn.sign,
        Fn.mod,
        Fn.min,
        Fn.max,
        Fn.gcd,
        Fn.lcm,
        Fn.tuple,
        Fn.erf,
        Fn.erfc,
        Fn.erfi,
        Fn.fresnelS,
        Fn.fresnelC,
        Fn.ei,
        Fn.expIntegralE,
        Fn.li,
        Fn.si,
        Fn.ci,
        Fn.shi,
        Fn.chi,
        Fn.gamma,
        Fn.upperGamma,
        Fn.lowerGamma,
        Fn.logGamma,
        Fn.digamma,
        Fn.polygamma,
        Fn.zeta,
        Fn.beta,
        Fn.polylog,
        Fn.besselJ,
        Fn.besselY,
        Fn.besselI,
        Fn.besselK,
        Fn.ellipticK,
        Fn.ellipticE,
        Fn.ellipticF,
        Fn.ellipticPi,
        Fn.hypergeometric,
        Fn.appellF1,
        Fn.lambertW,
      ];

      final ids = <FunctionId>{};
      for (final spec in specs) {
        check(spec.id == FunctionId.symbolic).isFalse;
        check(ids.add(spec.id)).isTrue;
        check(standardNames.contains(spec.name)).isTrue;
      }
      // Every built-in FunctionId except symbolic is represented in Fn.
      check(ids.length).equals(FunctionId.values.length - 1);
    });
  });
}
