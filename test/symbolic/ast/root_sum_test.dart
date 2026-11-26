import 'package:checks/checks.dart';
import 'package:data/data.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('RootSum AST properties', () {
    test('freeVariables, anyNode, equality, and hashCode', () {
      const t = Variable('t');
      const x = Variable('x');
      final rs1 = RootSum(t.pow(3) - t - x, 't', Ln(x - t));
      final rs2 = RootSum(t.pow(3) - t - x, 't', Ln(x - t));
      final rsDiffVar = RootSum(
        const Variable('u').pow(3) - const Variable('u') - x,
        'u',
        Ln(x - const Variable('u')),
      );

      check(rs1.freeVariables).deepEquals({'x'});
      check(rs1.anyNode((n) => n is Ln)).isTrue;
      check(rs1.anyNode((n) => n is Sin)).isFalse;
      check(rs1).equals(rs2);
      check(rs1.hashCode).equals(rs2.hashCode);
      check(rs1 == rsDiffVar).isFalse;
    });

    test('mapChildren and capture-avoiding substitution', () {
      const t = Variable('t');
      const x = Variable('x');
      const y = Variable('y');
      final rs = RootSum(t.pow(2) - x, 't', x + t);

      // Identical transform preserves instance.
      check(identical(rs.mapChildren((e) => e), rs)).isTrue;

      // Shadowed bound variable is not substituted.
      check(rs.substitute('t', IntegerNumber.of(5))).equals(rs);

      // Free variable substitution preserves alpha-equivalence without capture.
      final replaced = rs.substitute('x', t + y) as RootSum;
      check(replaced.variable == 't').isFalse;
      check(replaced.freeVariables).deepEquals({'t', 'y'});
      check(replaced.evaluate({'t': 1.0, 'y': 3.0})).isCloseTo(8.0, 1e-9);
    });

    test('structural ordering handles RootSum deterministically', () {
      final a = Expr.parse('rootsum(t^2 - 1, t, t)');
      final b = Expr.parse('rootsum(t^2 - 2, t, t)');
      check(a + b).isA<Add>();
    });
  });

  group('RootSum parsing and formatting', () {
    test('parses rootsum and handles bound constants', () {
      final parsed = Expr.parse('rootsum(t^3 - 2, t, ln(x - t))');
      check(parsed).isA<RootSum>();
      check(parsed.toString()).equals('rootsum(t ^ 3 - 2, t, ln(x - t))');
      final simplified = parsed.simplify();
      check(simplified.toString()).equals('rootsum(-2 + t ^ 3, t, ln(-t + x))');
      check(simplified.toLatex())
          .equals(r'\sum_{t : -2 + {t}^{3} = 0} \ln(-t + x)');
      check(simplified.toMathMl()).contains('<munder>');

      final unboundE = Expr.parse('rootsum(e^2 - 1, e, e)');
      check(unboundE.freeVariables).isEmpty;
      check(unboundE.evaluate()).isCloseTo(0.0, 1e-12);
    });

    test('throws FormatException for malformed rootsum', () {
      check(() => Expr.parse('rootsum(t^2 - 1, t)')).throws<FormatException>();
      check(() => Expr.parse('rootsum(t^2 - 1, 2, t)'))
          .throws<FormatException>();
    });
  });

  group('RootSum simplification and differentiation', () {
    test('simplifies trivial constant, linear, and zero cases', () {
      check(Expr.parse('rootsum(t^3 - 1, t, 0)').simplify())
          .equals(IntegerNumber.zero);
      check(Expr.parse('rootsum(5, t, t)').simplify())
          .equals(IntegerNumber.zero);
      check(Expr.parse('rootsum(t - 3, t, t^2 + 1)').simplify())
          .equals(IntegerNumber.of(10));
      check(Expr.parse('rootsum(t^4 + t + 1, t, x)').simplify())
          .equals(Expr.parse('4 * x').simplify());
      check(Expr.parse('rootsum(t^3 - 2, t, t)').simplify()).isA<RootSum>();
    });

    test('differentiates parametric and Blake-style algebraic RootSum', () {
      final param = Expr.parse('rootsum(t^2 - x, t, t^3)');
      final dParam = param.derivative('x');
      check(dParam.evaluate({'x': 4.0})).isCloseTo(0.0, 1e-9);

      // Shadowed derivative returns zero.
      check(Expr.parse('rootsum(x^2 - 2, x, x)').derivative('x'))
          .equals(IntegerNumber.zero);

      // Blake problem #585 integral & integrand.
      final blakeIntegral = Expr.parse(
        '1/8*rootsum(_Z1^8 - 4*_Z1^4 + 2, _Z1, (-ln(x) + ln((x^4 + 1)^(1/2) - x*_Z1))/_Z1)',
      );
      final blakeIntegrand = Expr.parse(
        '(x^16 - 1) / (x^4 + 1)^(1/2) / (x^16 + 1)',
      );
      final deriv = blakeIntegral.derivative('x').evaluateComplex({
        'x': const Complex(1.3),
      });
      final expected = blakeIntegrand.evaluateComplex({
        'x': const Complex(1.3),
      });
      check(deriv.a).isCloseTo(expected.a, 1e-8);
      check(deriv.b).isCloseTo(expected.b, 1e-8);
    });
  });

  group('RootSum numerical evaluation and approximation', () {
    test('evaluates real, complex-conjugate, and parametric root sums', () {
      // Roots of t^2 - 5t + 6 = 0 are 2 and 3 => sum of t^2 is 4 + 9 = 13.
      final realRoots = Expr.parse('rootsum(t^2 - 5*t + 6, t, t^2)');
      check(realRoots.evaluate()).isCloseTo(13.0, 1e-9);
      final approxReal = realRoots.approximate() as RealNumber;
      check(approxReal.value).isCloseTo(13.0, 1e-9);

      // Complex conjugate roots of t^2 + 1 = 0 sum to real result for t^2 -> -2.
      final conjRoots = Expr.parse('rootsum(t^2 + 1, t, t^2)');
      check(conjRoots.evaluate()).isCloseTo(-2.0, 1e-9);

      // Parametric polynomial t^3 - a*t - 1, sum t^2 = -2 * coeff(t) / 1 = 2*a.
      final vieta = Expr.parse('rootsum(t^3 - a*t - 1, t, t^2)');
      check(vieta.evaluate({'a': 3.5})).isCloseTo(7.0, 1e-9);

      // Complex-coefficient cubic t^3 - i: roots satisfy t^3 = i => sum(t^3) = 3*i.
      final complexCubic = Expr.parse('rootsum(t^3 - i, t, t^3)');
      final val = complexCubic.evaluateComplex();
      check(val.a).isCloseTo(0.0, 1e-9);
      check(val.b).isCloseTo(3.0, 1e-9);
    });
  });
}
