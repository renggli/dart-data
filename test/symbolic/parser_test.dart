import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Standard ExprSyntax', () {
    test('parses integers, fractions, scientific notation, and decimals accurately', () {
      final intExpr = Expr.parse('42');
      check(intExpr).isA<IntegerNumber>();
      check(intExpr).equals(IntegerNumber.of(42));

      final bigIntExpr = Expr.parse('123456789012345678901234567890');
      check(bigIntExpr).isA<IntegerNumber>();
      check((bigIntExpr as IntegerNumber).value.isValidInt).isFalse;

      final fracExpr = Expr.parse('3 / 6');
      check(fracExpr).isA<FractionNumber>();
      check(fracExpr).equals(FractionNumber.half);

      final realExpr = Expr.parse('0.5');
      check(realExpr).isA<RealNumber>();
      check(realExpr).equals(const RealNumber(0.5));

      check(Expr.parse('.25')).equals(const RealNumber(0.25));
      check(Expr.parse('1.5e-2')).equals(const RealNumber(0.015));
      check(Expr.parse('2E+3')).equals(const RealNumber(2000.0));
    });

    test('parses built-in constants, functions, OrderTerm, Piecewise, Integral, and case-sensitive identifiers', () {
      check(Expr.parse('pi')).equals(Constant.pi);
      check(Expr.parse('π')).equals(Constant.pi);
      check(Expr.parse('e')).equals(Constant.e);
      check(Expr.parse('i')).equals(ComplexNumber.i);
      check(Expr.parse('infinity')).equals(Constant.infinity);
      check(Expr.parse('∞')).equals(Constant.infinity);
      check(Expr.parse('undefined')).equals(Constant.undefined);

      // Identifiers are strictly case-sensitive; uppercase PI, E, I parse as Variables
      check(Expr.parse('PI')).equals(const Variable('PI'));
      check(Expr.parse('E')).equals(const Variable('E'));
      check(Expr.parse('I')).equals(const Variable('I'));

      // Unicode identifiers (non-whitespace, non-number, non-math-symbol)
      check(Expr.parse('α + β'))
          .equals(const Variable('α') + const Variable('β'));
      check(Expr.parse('ℏ * ω'))
          .equals(const Variable('ℏ') * const Variable('ω'));

      const x = Variable('x');
      check(Expr.parse('sqrt(x)')).equals(Pow.of(x, FractionNumber.half));
      check(Expr.parse('exp(x)')).equals(Pow.of(Constant.e, x));
      check(Expr.parse('ln(x)')).equals(Fn.ln(x));
      check(Expr.parse('log2(x)')).equals(Fn.ln(x) / Fn.ln(IntegerNumber.two));
      check(Expr.parse('log10(x)'))
          .equals(Fn.ln(x) / Fn.ln(IntegerNumber.of(10)));
      check(Expr.parse('sin(x)')).equals(Fn.sin(x));
      check(Expr.parse('sec(x)'))
          .equals(Pow.of(Fn.cos(x), IntegerNumber.negativeOne));
      check(Expr.parse('csc(x)'))
          .equals(Pow.of(Fn.sin(x), IntegerNumber.negativeOne));
      check(Expr.parse('cot(x)')).equals(Fn.cos(x) / Fn.sin(x));
      check(Expr.parse('asec(x)'))
          .equals(Fn.acos(Pow.of(x, IntegerNumber.negativeOne)));
      check(Expr.parse('acsc(x)'))
          .equals(Fn.asin(Pow.of(x, IntegerNumber.negativeOne)));
      check(Expr.parse('acot(x)'))
          .equals(Fn.atan(Pow.of(x, IntegerNumber.negativeOne)));
      check(Expr.parse('sech(x)'))
          .equals(Pow.of(Fn.cosh(x), IntegerNumber.negativeOne));
      check(Expr.parse('csch(x)'))
          .equals(Pow.of(Fn.sinh(x), IntegerNumber.negativeOne));
      check(Expr.parse('coth(x)')).equals(Fn.cosh(x) / Fn.sinh(x));
      check(Expr.parse('asech(x)'))
          .equals(Fn.acosh(Pow.of(x, IntegerNumber.negativeOne)));
      check(Expr.parse('acsch(x)'))
          .equals(Fn.asinh(Pow.of(x, IntegerNumber.negativeOne)));
      check(Expr.parse('acoth(x)'))
          .equals(Fn.atanh(Pow.of(x, IntegerNumber.negativeOne)));
      check(Expr.parse('pow(x, 2)')).equals(Pow.of(x, IntegerNumber.two));
      check(Expr.parse('root(x, 3)'))
          .equals(Pow.of(x, IntegerNumber.one / IntegerNumber.of(3)));
      check(Expr.parse('log(2, x)'))
          .equals(Fn.ln(x) / Fn.ln(IntegerNumber.two));
      check(Expr.parse('lambertW(x, -1)'))
          .equals(Fn.lambertW(x, IntegerNumber.negativeOne));
      check(Expr.parse('lambertW(x, 0)')).equals(Fn.lambertW(x));
      check(Expr.parse('lambertW(x)')).equals(Fn.lambertW(x));

      // Special functions
      check(Expr.parse('zeta(x)')).equals(Fn.zeta(x));
      check(Expr.parse('digamma(x)')).equals(Fn.digamma(x));
      check(Expr.parse('polygamma(1, x)'))
          .equals(Fn.polygamma(IntegerNumber.one, x));
      check(Expr.parse('ellipticK(x)')).equals(Fn.ellipticK(x));
      check(Expr.parse('ellipticE(x)')).equals(Fn.ellipticE(x));
      check(Expr.parse('besselJ(0, x)'))
          .equals(Fn.besselJ(IntegerNumber.zero, x));
      check(Expr.parse('besselY(0, x)'))
          .equals(Fn.besselY(IntegerNumber.zero, x));
      check(Expr.parse('besselI(0, x)'))
          .equals(Fn.besselI(IntegerNumber.zero, x));
      check(Expr.parse('besselK(0, x)'))
          .equals(Fn.besselK(IntegerNumber.zero, x));

      // 2-argument and 4-argument integrate
      check(Expr.parse('integrate(sin(x), x)'))
          .equals(Integral(Fn.sin(x), 'x'));
      check(Expr.parse('integrate(sin(x), x, 0, pi)')).equals(
        Integral(Fn.sin(x), 'x', lower: IntegerNumber.zero, upper: Constant.pi),
      );

      // OrderTerm forms
      check(Expr.parse('O(1)')).equals(OrderTerm('x', 0));
      check(Expr.parse('O(x)')).equals(OrderTerm('x', 1));
      check(Expr.parse('O(x^3)')).equals(OrderTerm('x', 3));
      check(Expr.parse('O(x - 1)'))
          .equals(OrderTerm('x', 1, point: IntegerNumber.one));
      check(Expr.parse('O((x - 1)^3)'))
          .equals(OrderTerm('x', 3, point: IntegerNumber.one));
      check(Expr.parse('O(x, 3)')).equals(OrderTerm('x', 3));
      check(Expr.parse('O(x, 3, 1)'))
          .equals(OrderTerm('x', 3, point: IntegerNumber.one));

      // Relational operators
      check(Expr.parse('x < 1'))
          .equals(Relational.lessThan(x, IntegerNumber.one));
      check(Expr.parse('x <= 1'))
          .equals(Relational.lessEqual(x, IntegerNumber.one));
      check(Expr.parse('x > 1'))
          .equals(Relational.greaterThan(x, IntegerNumber.one));
      check(Expr.parse('x >= 1'))
          .equals(Relational.greaterEqual(x, IntegerNumber.one));
      check(Expr.parse('x == 1'))
          .equals(Relational.equal(x, IntegerNumber.one));
      check(Expr.parse('x = 1')).equals(Relational.equal(x, IntegerNumber.one));
      check(Expr.parse('x != 1'))
          .equals(Relational.notEqual(x, IntegerNumber.one));
    });

    test(
      'precedence of exponentiation, unary + and -, and error diagnostics',
      () {
        const x = Variable('x');
        check(Expr.parse('+x')).equals(x);

        // -x^2 is -(x^2), not (-x)^2
        final negSq = Expr.parse('-x^2');
        check(negSq).equals(
          Mul.of([IntegerNumber.negativeOne, Pow.of(x, IntegerNumber.two)]),
        );
        check(negSq.evaluate({'x': 3.0})).equals(-9.0);

        // (-x)^2 is Pow(-x, 2)
        final parenSq = Expr.parse('(-x)^2');
        check(parenSq.evaluate({'x': 3.0})).equals(9.0);

        // Signed exponent: x^-2 and x^+2
        check(Expr.parse('x^-2')).equals(Pow.of(x, IntegerNumber.of(-2)));
        check(Expr.parse('x^+2')).equals(Pow.of(x, IntegerNumber.two));

        // Right-associative power: 2^3^2 = 2^(3^2) = 512
        final rightAssoc = Expr.parse('2^3^2');
        check(rightAssoc).equals(IntegerNumber.of(512));

        // Double-asterisk exponentiation: x**2, x**-2, 2**3**2
        check(Expr.parse('x**2')).equals(Pow.of(x, IntegerNumber.two));
        check(Expr.parse('x**-2')).equals(Pow.of(x, IntegerNumber.of(-2)));
        check(Expr.parse('2**3**2')).equals(IntegerNumber.of(512));

        // Syntax and function errors (including case sensitivity and arity mismatch)
        final syntax = ExprSyntax.standard;
        check(syntax.parse('SIN(x)'))
            .equals(Fn.symbolic('SIN', const [Variable('x')]));
        check(syntax.parse('unknownUnary(x)'))
            .equals(Fn.symbolic('unknownUnary', const [Variable('x')]));
        check(syntax.parse('unknownBinary(x, y)')).equals(
          Fn.symbolic('unknownBinary', const [Variable('x'), Variable('y')]),
        );
        check(() => syntax.parse('sin(x, y, z)')).throws<FormatException>();
        check(() => syntax.parse('lambertW(x, 2)')).throws<FormatException>();
        check(() => syntax.parse('O(sin(x))')).throws<FormatException>();
        check(() => syntax.parse('O(1, 2)')).throws<FormatException>();
        check(() => syntax.parse('piecewise(x < 0)')).throws<FormatException>();
        check(() => syntax.parse('piecewise(x + 1, 2)'))
            .throws<FormatException>();
        check(() => syntax.parse('integrate(x, 2)')).throws<FormatException>();
        check(() => syntax.parse('integrate(x, y, 0)'))
            .throws<FormatException>();
        check(syntax.parse('diff(x^2, x)'))
            .equals(Derivative(Pow.of(x, IntegerNumber.two), 'x'));
        check(syntax.parse('diff(x^2, i)'))
            .equals(Derivative(Pow.of(x, IntegerNumber.two), 'i'));
        check(syntax.parse('diff(x^2, e)'))
            .equals(Derivative(Pow.of(x, IntegerNumber.two), 'e'));
        check(syntax.parse('diff(x^3, x, 2)'))
            .equals(Derivative(Pow.of(x, IntegerNumber.of(3)), 'x', order: 2));
        check(syntax.parse('sum(2 * i, i, 1, n)')).equals(
          Sum(
            IntegerNumber.two * const Variable('i'),
            'i',
            IntegerNumber.one,
            const Variable('n'),
          ),
        );
        check(syntax.parse('product(i, i, 1, n)')).equals(
          Product(
            const Variable('i'),
            'i',
            IntegerNumber.one,
            const Variable('n'),
          ),
        );
        check(syntax.parse('integrate(exp(e), e)'))
            .equals(Integral(Pow.of(Constant.e, const Variable('e')), 'e'));
        check(syntax.parse('limit(x + i, i, 0)'))
            .equals(Limit(x + const Variable('i'), 'i', IntegerNumber.zero));
        check(() => syntax.parse('diff(x, x, 0)')).throws<FormatException>();
        check(() => syntax.parse('diff(x, 2)')).throws<FormatException>();
        check(() => syntax.parse('diff(x)')).throws<FormatException>();

        check(syntax.parse('limit(x, x, 0)'))
            .equals(Limit(x, 'x', IntegerNumber.zero));
        check(syntax.parse('limit(x, x, 0, both)'))
            .equals(Limit(x, 'x', IntegerNumber.zero));
        check(syntax.parse('limit(x, x, 0, 1)')).equals(
          Limit(
            x,
            'x',
            IntegerNumber.zero,
            direction: LimitDirection.fromAbove,
          ),
        );
        check(syntax.parse('limit(x, x, 0, -1)')).equals(
          Limit(
            x,
            'x',
            IntegerNumber.zero,
            direction: LimitDirection.fromBelow,
          ),
        );
        check(() => syntax.parse('limit(x, x, 0, 2)'))
            .throws<FormatException>();
        check(() => syntax.parse('limit(x, 2, 0)')).throws<FormatException>();
        check(() => syntax.parse('limit(x, x)')).throws<FormatException>();
        check(() => syntax.parse('sum(x, 2, 1, n)')).throws<FormatException>();
        check(() => syntax.parse('sum(x, x, 1)')).throws<FormatException>();
        check(() => syntax.parse('product(x, 2, 1, n)'))
            .throws<FormatException>();
        check(() => syntax.parse('product(x, x, 1)')).throws<FormatException>();

        check(syntax.parse('gcd(12, 18, 24)')).equals(
          Fn.gcd([
            IntegerNumber.of(12),
            IntegerNumber.of(18),
            IntegerNumber.of(24),
          ]),
        );
        check(syntax.parse('gcd(12, 18, 24)').simplify())
            .equals(IntegerNumber.of(6));
        check(syntax.parse('lcm(4, 6, 8)')).equals(
          Fn.lcm([
            IntegerNumber.of(4),
            IntegerNumber.of(6),
            IntegerNumber.of(8),
          ]),
        );
        check(syntax.parse('lcm(4, 6, 8)').simplify())
            .equals(IntegerNumber.of(24));
        check(syntax.parse('gcd(x, 12)'))
            .equals(Fn.gcd([x, IntegerNumber.of(12)]));
        check(syntax.parse('lcm(x, 12)'))
            .equals(Fn.lcm([x, IntegerNumber.of(12)]));
        check(syntax.parse('gcd(12, x, 18)'))
            .equals(Fn.gcd([IntegerNumber.of(12), x, IntegerNumber.of(18)]));
        check(syntax.parse('lcm(12, x, 18)'))
            .equals(Fn.lcm([IntegerNumber.of(12), x, IntegerNumber.of(18)]));
        check(syntax.parse('gcd(x, 12, 18)'))
            .equals(Fn.gcd([x, IntegerNumber.of(12), IntegerNumber.of(18)]));
        check(syntax.parse('lcm(x, 12, 18)'))
            .equals(Fn.lcm([x, IntegerNumber.of(12), IntegerNumber.of(18)]));
        check(syntax.parse('[1, x, 2]'))
            .equals(Fn.tuple([IntegerNumber.one, x, IntegerNumber.two]));
        check(syntax.parse('tuple(1, x)'))
            .equals(Fn.tuple([IntegerNumber.one, x]));

        final vec = syntax.parseVector('[1, x, 2]');
        check(vec.length).equals(3);
        check(syntax.tryParseVector('[1, x]')!.length).equals(2);
        check(syntax.tryParseVector('[1, +]')).isNull;
        check(syntax.tryParseVector('[diff(x)]')).isNull;
        check(() => syntax.parseVector('[1, +]')).throws<FormatException>();

        final mat = syntax.parseMatrix('[[1, 2], [3, 4]]');
        check(mat.rowCount).equals(2);
        check(syntax.tryParseMatrix('[[1, 2], [3, 4]]')!.colCount).equals(2);
        check(syntax.tryParseMatrix('[[1, 2], [3]]')).isNull;
        check(syntax.tryParseMatrix('[1, 2]')).isNull;
        check(() => syntax.parseMatrix('[[1, 2], [3]]'))
            .throws<FormatException>();
        check(() => syntax.parseMatrix('[1, 2]')).throws<FormatException>();

        check(() => syntax.parse('x +')).throws<FormatException>();
        check(syntax.tryParse('x +')).isNull;
        check(syntax.tryParse('diff(x)')).isNull;
      },
    );
  });

  group('Custom ExprSyntax and ExprSyntax.empty', () {
    test('custom constants and empty syntax', () {
      final phi =
          (IntegerNumber.one +
              Pow.of(IntegerNumber.of(5), FractionNumber.half)) /
          IntegerNumber.two;
      final syntax = ExprSyntax(
        constants: {
          'phi': phi,
          'golden': phi,
          'φ': phi,
          'r0': Expr.parse('x^2 + 1'),
        },
      );

      check(syntax.parse('golden')).equals(syntax.parse('phi'));
      check(syntax.parse('φ')).equals(syntax.parse('phi'));
      check(syntax.parse('PHI')).equals(const Variable('PHI'));

      // r0 resolves to bound expression
      final reused = syntax.parse('2 * r0').expand().simplify();
      check(reused.toString()).equals('2 + 2 * x ^ 2');

      final emptySyntax = ExprSyntax.empty();
      check(emptySyntax.parse('pi')).equals(const Variable('pi'));
      check(emptySyntax.parse('e')).equals(const Variable('e'));
      check(emptySyntax.parse('i')).equals(const Variable('i'));
      check(emptySyntax.parse('r0')).equals(const Variable('r0'));
      check(emptySyntax.parse('cos(x)'))
          .equals(Fn.symbolic('cos', const [Variable('x')]));
    });

    test('custom unary, binary, and variadic functions', () {
      final syntax = ExprSyntax(
        unaryFunctions: {
          'doubleIt': (a) => IntegerNumber.two * a,
          'dbl': (a) => IntegerNumber.two * a,
        },
        binaryFunctions: {
          'hypot': (a, b) => Pow.of(
            Pow.of(a, IntegerNumber.two) + Pow.of(b, IntegerNumber.two),
            FractionNumber.half,
          ),
          'pythag': (a, b) => Pow.of(
            Pow.of(a, IntegerNumber.two) + Pow.of(b, IntegerNumber.two),
            FractionNumber.half,
          ),
        },
        variadicFunctions: {
          'fma': (args) => args[0] * args[1] + args[2],
          'sumAll': Add.of,
          'total': Add.of,
        },
      );

      check(syntax.parse('dbl(3)').simplify()).equals(IntegerNumber.of(6));
      check(syntax.parse('pythag(3, 4)').simplify())
          .equals(IntegerNumber.of(5));
      check(syntax.parse('fma(2, 3, 4)').simplify())
          .equals(IntegerNumber.of(10));
      check(syntax.parse('total(1, 2, 3)').simplify())
          .equals(IntegerNumber.of(6));

      // Built-in functions remain available in ExprSyntax(...)
      check(syntax.parse('ln(x)')).equals(Fn.ln(const Variable('x')));
      check(syntax.parse('DBL(3)'))
          .equals(Fn.symbolic('DBL', [IntegerNumber.of(3)]));
    });

    test('implicit multiplication and invalid argument count errors', () {
      final implicit = ExprSyntax(implicitMultiplication: true);
      check(implicit.parse('2x').toString()).equals('2 * x');

      check(() => Expr.parse('integrate(x)')).throws<FormatException>();
      check(() => Expr.parse('limit(x, y)')).throws<FormatException>();

      // Bound variable shadowing of standard constants (i, e, pi)
      check(Expr.parse('sum(i, i, 1, 10)').simplify())
          .equals(IntegerNumber.of(55));
      check(Expr.parse('sum(2 * i, i, 1, 5)').simplify())
          .equals(IntegerNumber.of(30));
      check(Expr.parse('sum(2 * i + 1, i, 1, 3)').simplify())
          .equals(IntegerNumber.of(15));
      check(Expr.parse('sum(3 - i, i, 1, 3)').simplify())
          .equals(IntegerNumber.of(3));
      check(Expr.parse('product(i, i, 1, 4)').simplify())
          .equals(IntegerNumber.of(24));
      check(Expr.parse('product(2 * i, i, 1, 3)').simplify())
          .equals(IntegerNumber.of(48));
      check(Expr.parse('diff(2 * e, e, 1, 3)').simplify())
          .equals(IntegerNumber.two);
      check(Expr.parse('diff(e^2, e, 1, 3)').simplify())
          .equals(IntegerNumber.of(6));
      final parsedDiffE2 = Expr.parse('diff(e^2, e)') as Derivative;
      check(parsedDiffE2.expr)
          .equals(Pow.of(const Variable('e'), IntegerNumber.two));
      check(parsedDiffE2.expr.derivative('e'))
          .equals(IntegerNumber.two * const Variable('e'));

      final parsedDiffExpE = Expr.parse('diff(exp(e), e)') as Derivative;
      check(parsedDiffExpE.expr)
          .equals(Pow.of(Constant.e, const Variable('e')));
      check(parsedDiffExpE.expr.derivative('e'))
          .equals(Pow.of(Constant.e, const Variable('e')));
      check(Expr.parse('integrate(e, e)'))
          .equals(Integral(const Variable('e'), 'e'));
      check(Expr.parse('integrate(exp(x) * e, e)')).equals(
        Integral(
          Pow.of(const Variable('e'), IntegerNumber.one + const Variable('x')),
          'e',
        ),
      );
      check(Expr.parse('integrate(exp(e), e)'))
          .equals(Integral(Pow.of(Constant.e, const Variable('e')), 'e'));
      check(Expr.parse('limit(e + 1, e, 2)')).equals(
        Limit(const Variable('e') + IntegerNumber.one, 'e', IntegerNumber.two),
      );
      check(Expr.parse('limit(exp(x) + e, e, 0)')).equals(
        Limit(
          Pow.of(Constant.e, const Variable('x')) + const Variable('e'),
          'e',
          IntegerNumber.zero,
        ),
      );
      check(Expr.parse('integrate(-i, i, 0, 1)')).isA<Integral>();
      check(Expr.parse('diff(2 * e, e, 2)')).isA<Derivative>();
      check(Expr.parse('limit(e, e, 0, fromAbove)')).isA<Limit>();
      check(Expr.parse('sum(integrate(x, x, 0, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(diff(x^2, x, 1, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(limit(x, x, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(sum(k, k, 1, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(product(k, k, 1, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(integrate(i, i, 0, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(diff(i^2, i, 1, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(limit(i, i, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(sum(i, i, 1, i), i, 1, 3)')).isA<Sum>();
      check(Expr.parse('sum(product(i, i, 1, i), i, 1, 3)')).isA<Sum>();
      check(() => Expr.parse('limit(x)')).throws<FormatException>();
    });
  });

  group('orthogonal polynomials and metadata', () {
    test('parses orthogonal polynomials with integer degree', () {
      check(Expr.parse('chebyshevT(3, x)')).equals(chebyshevT(3));
      check(Expr.parse('chebyshevU(2, x)')).equals(chebyshevU(2));
      check(Expr.parse('legendreP(2, x)')).equals(legendreP(2));
      check(Expr.parse('hermiteH(3, x)')).equals(hermiteH(3));
      check(Expr.parse('hermiteHe(3, x)')).equals(hermiteHe(3));
      check(Expr.parse('laguerreL(2, x)')).equals(laguerreL(2));
      check(Expr.parse('laguerreL(2, x, a)'))
          .equals(laguerreL(2, const Variable('x'), const Variable('a')));
      check(() => Expr.parse('chebyshevT(-1, x)')).throws<FormatException>();
      check(() => Expr.parse('laguerreL(x, x)')).throws<FormatException>();
    });

    test('parses relational operators', () {
      check((Expr.parse('x = 1') as Relational).op).equals(RelOp.equal);
      check((Expr.parse('x != 0') as Relational).op).equals(RelOp.notEqual);
      check((Expr.parse('x < 2') as Relational).op).equals(RelOp.lessThan);
      check((Expr.parse('x <= 2') as Relational).op).equals(RelOp.lessEqual);
      check((Expr.parse('x > 0') as Relational).op).equals(RelOp.greaterThan);
      check((Expr.parse('x >= 0') as Relational).op).equals(RelOp.greaterEqual);
    });

    test('standardFunctions covers built-in functions', () {
      final names = {
        for (final info in ExprSyntax.standardFunctions) info.name,
      };
      check(names).contains('sin');
      check(names).contains('chebyshevT');
      check(names).contains('laguerreL');
      check(names).contains('hypergeometric');
      for (final info in ExprSyntax.standardFunctions) {
        check(info.name).isNotEmpty;
        check(info.doc).isNotEmpty;
      }
    });

    test(
      'parses two-arg special functions, O-terms, and validates binder names',
      () {
        check((Expr.parse('ellipticE(x, 0.5)') as Call).id)
            .equals(FunctionId.ellipticE);
        check((Expr.parse('zeta(2, a)') as Call).id).equals(FunctionId.zeta);
        check(Expr.parse('O(x^3)')).equals(OrderTerm('x', 3));
        check(Expr.parse('O((1 - x)^2)'))
            .equals(OrderTerm('x', 2, point: IntegerNumber.one));
        check(Expr.parse('O((-x + 1)^2)'))
            .equals(OrderTerm('x', 2, point: IntegerNumber.one));
        check(() => Expr.parse('O(-x)')).throws<FormatException>();
        check(() => Expr.parse('integrate(x, 1)')).throws<FormatException>();
        check(() => Expr.parse('diff(x, 1)')).throws<FormatException>();
        check((Expr.parse('ellipticPi(0.5, 0.3)') as Call).id)
            .equals(FunctionId.ellipticPi);
        check((Expr.parse('hypergeometric(1, 2, x)') as Call).id)
            .equals(FunctionId.hypergeometric);
        check(Expr.parse('O(x)')).equals(OrderTerm('x', 1));
        check(() => Expr.parse('lambertW(1, 2, 3)')).throws<FormatException>();
        check(() => Expr.parse('ellipticPi(1)')).throws<FormatException>();
        check(() => Expr.parse('hypergeometric(1, 2)'))
            .throws<FormatException>();
      },
    );
  });
}
