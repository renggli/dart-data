import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Assumptions with positive domain', () {
    test(
      'simplifies radicals, abs, sign, and arg under positive assumptions',
      () {
        const posX = Assumptions(domains: {'x': VariableDomain.positive});
        final sqrtSq = Expr.parse('sqrt(x^2)');
        check(sqrtSq.simplify().toString()).equals('sqrt(x ^ 2)');

        final simplified = sqrtSq.simplify(assumptions: posX);
        check(simplified).equals(const Variable('x'));

        // Re-simplifying an already-simplified Abs(x) with positive assumptions
        final absX = Expr.parse('abs(x)').simplify();
        check(absX.simplify(assumptions: posX)).equals(const Variable('x'));

        check(Expr.parse('sign(x)').simplify(assumptions: posX))
            .equals(IntegerNumber.one);

        check(Expr.parse('arg(x)').simplify(assumptions: posX))
            .equals(IntegerNumber.zero);

        check(Expr.parse('(x^y)^z').simplify(assumptions: posX).toString())
            .equals('(x ^ y) ^ z');
        const realYZPosX = Assumptions(
          domains: {
            'x': VariableDomain.positive,
            'y': VariableDomain.real,
            'z': VariableDomain.real,
          },
        );
        check(
          Expr.parse('(x^y)^z').simplify(assumptions: realYZPosX).toString(),
        ).equals('x ^ (y * z)');
      },
    );
  });

  group('Assumptions with real and complex domains and copyWith chaining', () {
    test(
      'controls conjugate, re, im, radical reductions, and parent chaining',
      () {
        const z = Variable('z');
        const complexZ = Assumptions(domains: {'z': VariableDomain.complex});
        check(Fn.conj(z).simplify(assumptions: complexZ)).equals(Fn.conj(z));
        check(Fn.re(z).simplify(assumptions: complexZ)).equals(Fn.re(z));
        check(Fn.im(z).simplify(assumptions: complexZ)).equals(Fn.im(z));

        // For complex z, sqrt(z^2) does not collapse to abs(z)
        check(
          Expr.parse('sqrt(z^2)').simplify(assumptions: complexZ).toString(),
        ).equals('sqrt(z ^ 2)');

        // Chained assumptions via copyWith overriding parent defaultDomain
        check(Assumptions.none.isEmpty).isTrue;
        check(Assumptions.complex.isEmpty).isFalse;
        check(Fn.conj(z).simplify(assumptions: Assumptions.complex))
            .equals(Fn.conj(z));
        final chained = Assumptions.complex.copyWith(
          domains: {'z': VariableDomain.real},
        );
        check(chained.isEmpty).isFalse;
        check(chained.domainOf('z')).equals(VariableDomain.real);

        // copyWith merges domains while preserving existing ones
        const posX = Assumptions(domains: {'x': VariableDomain.positive});
        final assumed = posX.copyWith(domains: {'y': VariableDomain.real});
        check(assumed.domainOf('x')).equals(VariableDomain.positive);
        check(assumed.domainOf('y')).equals(VariableDomain.real);
        check(assumed.domains['x']).equals(VariableDomain.positive);
        check(assumed.domains['y']).equals(VariableDomain.real);
        check(chained.domainOf('w')).equals(VariableDomain.complex);
        check(Fn.conj(z).simplify(assumptions: chained)).equals(z);

        final positiveDefault = Assumptions.none.copyWith(
          defaultDomain: VariableDomain.positive,
        );
        check(positiveDefault.domainOf('x')).equals(VariableDomain.positive);
        check(Expr.parse('sqrt(x^2)').simplify(assumptions: positiveDefault))
            .equals(const Variable('x'));

        final mixedReal = Assumptions.real.copyWith(
          domains: {'n': VariableDomain.integer},
        );
        check(mixedReal.domainOf('n')).equals(VariableDomain.integer);
        check(mixedReal.domainOf('x')).equals(VariableDomain.real);
      },
    );
  });

  group('Assumptions with integer domain', () {
    test('simplifies rounding, modulo, and integer multiples of pi', () {
      const intN = Assumptions(domains: {'n': VariableDomain.integer});
      check(Expr.parse('floor(n)').simplify(assumptions: intN))
          .equals(const Variable('n'));
      check(
        Expr.parse('ceil(2 * n + 1)').simplify(assumptions: intN).toString(),
      ).equals('1 + 2 * n');
      check(Expr.parse('round(n^2)').simplify(assumptions: intN).toString())
          .equals('n ^ 2');
      check(Expr.parse('mod(n, 1)').simplify(assumptions: intN))
          .equals(IntegerNumber.zero);
      check(Expr.parse('sin(n * pi)').simplify(assumptions: intN))
          .equals(IntegerNumber.zero);
      check(Expr.parse('tan(n * pi)').simplify(assumptions: intN))
          .equals(IntegerNumber.zero);
      check(Expr.parse('cos(2 * n * pi)').simplify(assumptions: intN))
          .equals(IntegerNumber.one);
      check(Expr.parse('cos(n * pi)').simplify(assumptions: intN).toString())
          .equals('(-1) ^ n');
      check(Expr.parse('(-1)^(2 * n)').simplify(assumptions: intN))
          .equals(IntegerNumber.one);
    });
  });

  group('Assumptions with equation solver', () {
    test('filters equation roots according to passed domain assumptions', () {
      final eq1 = Expr.parse('x^2 - 4');
      check(eq1.solve('x', assumptions: Assumptions.positive))
          .deepEquals([IntegerNumber.two]);

      final eq2 = Expr.parse('x^2 + 1');
      check(eq2.solve('x', assumptions: Assumptions.real)).isEmpty;

      final eq3 = Expr.parse('(2 * x - 1) * (x - 3)');
      check(
        eq3.solve(
          'x',
          assumptions: const Assumptions(
            domains: {'x': VariableDomain.integer},
          ),
        ),
      ).deepEquals([IntegerNumber.of(3)]);
    });

    test('implements value equality and hashCode', () {
      const a1 = Assumptions(domains: {'x': VariableDomain.positive});
      final a2 = Assumptions.none.copyWith(
        domains: {'x': VariableDomain.positive},
      );
      const a3 = Assumptions(
        domains: {'x': VariableDomain.positive},
        defaultDomain: VariableDomain.real,
      );
      check(a1).equals(a2);
      check(a1.hashCode).equals(a2.hashCode);
      check(a1 == a3).isFalse;
    });
  });

  group('Assumptions v2 composable properties and relations', () {
    test(
      'tracks negative, nonNegative, integer parity, and relational bounds',
      () {
        const x = Variable('x');
        const y = Variable('y');

        final negX = Assumptions.none.withNegative('x');
        check(negX.isNegative('x')).isTrue;
        check(negX.isNonPositive('x')).isTrue;
        check(negX.isNonZero('x')).isTrue;
        check(negX.isReal('x')).isTrue;
        check(Expr.parse('sqrt(x^2)').simplify(assumptions: negX)).equals(-x);
        check(Expr.parse('abs(x)').simplify(assumptions: negX)).equals(-x);
        check(Expr.parse('sign(x)').simplify(assumptions: negX))
            .equals(IntegerNumber.negativeOne);
        check(Expr.parse('arg(x)').simplify(assumptions: negX))
            .equals(Constant.pi);

        final nonNegX = Assumptions.none.withNonNegative('x');
        check(nonNegX.isNonNegative('x')).isTrue;
        check(nonNegX.isReal('x')).isTrue;
        check(nonNegX.isPositive('x')).isFalse;
        check(Expr.parse('sqrt(x^2)').simplify(assumptions: nonNegX)).equals(x);
        check(Expr.parse('abs(x)').simplify(assumptions: nonNegX)).equals(x);

        final oddN = Assumptions.none.withOdd('n');
        check(oddN.isOdd('n')).isTrue;
        check(oddN.isInteger('n')).isTrue;
        check(oddN.isNonZero('n')).isTrue;
        check(Expr.parse('(-1)^n').simplify(assumptions: oddN))
            .equals(IntegerNumber.negativeOne);

        final evenN = Assumptions.none.withEven('n');
        check(evenN.isEven('n')).isTrue;
        check(Expr.parse('(-1)^n').simplify(assumptions: evenN))
            .equals(IntegerNumber.one);

        final relAssump = Assumptions.none
            .withRelation(Relational.greaterThan(x, IntegerNumber.zero))
            .withRelation(Relational.greaterThan(x, y));
        check(relAssump.isPositive('x')).isTrue;
        check(
          Relational.greaterThan(
            x,
            IntegerNumber.zero,
          ).simplify(assumptions: relAssump),
        ).equals(IntegerNumber.one);
        check(Relational.greaterThan(x, y).simplify(assumptions: relAssump))
            .equals(IntegerNumber.one);
        check(Relational.lessEqual(x, y).simplify(assumptions: relAssump))
            .equals(IntegerNumber.zero);

        final bounded = Assumptions.none.withBounds(
          'x',
          lower: IntegerNumber.one,
          lowerInclusive: false,
          upper: IntegerNumber.of(4),
          upperInclusive: true,
        );
        check(bounded.isEmpty).isFalse;
        check(bounded.domainOf('x')).equals(VariableDomain.positive);
        check(bounded.boundsOf('x')).equals(
          VariableBounds(
            lower: IntegerNumber.one,
            upper: IntegerNumber.of(4),
            upperInclusive: true,
          ),
        );
        check(bounded.boundsOf('y').isUnbounded).isTrue;
        check(Assumptions.none.withComplex('z').domainOf('z'))
            .equals(VariableDomain.complex);
        check(Assumptions.none.withInteger('n').domainOf('n'))
            .equals(VariableDomain.integer);

        final nonPos = Assumptions.none.withNonPositive('u');
        check(nonPos.isNonPositive('u')).isTrue;
        check(nonPos.isReal('u')).isTrue;

        final nz = Assumptions.none.withNonZero('v');
        check(nz.isNonZero('v')).isTrue;

        final zeroRels = Assumptions.none
            .withRelation(Relational.lessThan(IntegerNumber.zero, x))
            .withRelation(Relational.lessEqual(IntegerNumber.zero, y))
            .withRelation(
              Relational.greaterThan(IntegerNumber.zero, const Variable('a')),
            )
            .withRelation(
              Relational.greaterEqual(IntegerNumber.zero, const Variable('b')),
            )
            .withRelation(
              Relational.notEqual(IntegerNumber.zero, const Variable('c')),
            )
            .withRelation(
              Relational.equal(IntegerNumber.zero, const Variable('d')),
            )
            .withRelation(
              Relational.lessThan(const Variable('p'), IntegerNumber.one),
            );
        check(zeroRels.isPositive('x')).isTrue;
        check(zeroRels.isNonNegative('y')).isTrue;
        check(zeroRels.isNegative('a')).isTrue;
        check(zeroRels.isNonPositive('b')).isTrue;
        check(zeroRels.isNonZero('c')).isTrue;
        check(zeroRels.isReal('d')).isFalse;
        check(zeroRels.isReal('p')).isTrue;

        final copyRel = Assumptions.none.copyWith(
          relations: [
            Relational.lessEqual(x, IntegerNumber.zero),
            Relational.notEqual(y, IntegerNumber.zero),
            Relational.greaterEqual(IntegerNumber.zero, const Variable('q')),
            Relational.notEqual(IntegerNumber.zero, const Variable('r')),
            Relational.lessThan(IntegerNumber.one, const Variable('s')),
          ],
        );
        check(copyRel.isNonPositive('x')).isTrue;
        check(copyRel.isNonZero('y')).isTrue;
        check(copyRel.isNonPositive('q')).isTrue;
        check(copyRel.isNonZero('r')).isTrue;
        check(copyRel.isReal('s')).isTrue;

        check(bounded == bounded).isTrue;
        check(bounded.hashCode).equals(bounded.hashCode);
        check(bounded.boundsOf('x') == bounded.boundsOf('x')).isTrue;
      },
    );
  });
}
