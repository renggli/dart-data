import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('AST Node Hashing & Equality', () {
    test('distinct unary expressions with identical Variable argument have distinct hash codes', () {
      const x = Variable('x');
      const uSin = Sin(x);
      const uCos = Cos(x);
      const uNeg = Neg(x);
      const uExp = Exp(x);
      const uLn = Ln(x);

      final unaries = <UnaryExpr>[uSin, uCos, uNeg, uExp, uLn];

      final hashCodes = unaries.map((e) => e.hashCode).toSet();
      check(hashCodes.length).equals(5);

      for (var i = 0; i < unaries.length; i++) {
        for (var j = 0; j < unaries.length; j++) {
          if (i == j) {
            check(unaries[i] == unaries[j]).isTrue();
          } else {
            check(unaries[i] == unaries[j]).isFalse();
            check(unaries[i].hashCode == unaries[j].hashCode).isFalse();
          }
        }
      }
    });

    test('distinct unary expressions with numeric argument have distinct hash codes', () {
      const num = RationalNumber(42, 5);
      const uSin = Sin(num);
      const uCos = Cos(num);
      const uNeg = Neg(num);
      const uExp = Exp(num);
      const uLn = Ln(num);

      final unaries = <UnaryExpr>[uSin, uCos, uNeg, uExp, uLn];
      final hashCodes = unaries.map((e) => e.hashCode).toSet();
      check(hashCodes.length).equals(5);

      for (var i = 0; i < unaries.length; i++) {
        for (var j = 0; j < unaries.length; j++) {
          if (i != j) {
            check(unaries[i] == unaries[j]).isFalse();
            check(unaries[i].hashCode == unaries[j].hashCode).isFalse();
          }
        }
      }
    });

    test('distinct binary expressions with identical arguments have distinct hash codes', () {
      const x = Variable('x');
      const y = Variable('y');

      const bAdd = Add(x, y);
      const bSub = Sub(x, y);
      const bMul = Mul(x, y);
      const bDiv = Div(x, y);
      const bPow = Pow(x, y);

      final binaries = <BinaryExpr>[bAdd, bSub, bMul, bDiv, bPow];

      final hashCodes = binaries.map((e) => e.hashCode).toSet();
      check(hashCodes.length).equals(5);

      for (var i = 0; i < binaries.length; i++) {
        for (var j = 0; j < binaries.length; j++) {
          if (i == j) {
            check(binaries[i] == binaries[j]).isTrue();
          } else {
            check(binaries[i] == binaries[j]).isFalse();
            check(binaries[i].hashCode == binaries[j].hashCode).isFalse();
          }
        }
      }
    });

    test('binary expressions with identical left and right operands have distinct hash codes', () {
      const x = Variable('x');

      const bAdd = Add(x, x);
      const bSub = Sub(x, x);
      const bMul = Mul(x, x);
      const bDiv = Div(x, x);
      const bPow = Pow(x, x);

      final binaries = <BinaryExpr>[bAdd, bSub, bMul, bDiv, bPow];
      final hashCodes = binaries.map((e) => e.hashCode).toSet();
      check(hashCodes.length).equals(5);

      for (var i = 0; i < binaries.length; i++) {
        for (var j = 0; j < binaries.length; j++) {
          if (i != j) {
            check(binaries[i] == binaries[j]).isFalse();
            check(binaries[i].hashCode == binaries[j].hashCode).isFalse();
          }
        }
      }
    });

    test('cross-family non-collision and structural equality invariants', () {
      const x = Variable('x');
      const y = Variable('y');

      check((const Sin(x) as Expr) == const Add(x, x)).isFalse();
      check((const Neg(x) as Expr) == const Sub(x, x)).isFalse();

      const sub1 = Sub(x, y);
      const sub2 = Sub(y, x);
      check(sub1 == sub2).isFalse();
      check(sub1.hashCode == sub2.hashCode).isFalse();

      const add1 = Add(x, y);
      const add2 = Add(y, x);
      check(add1 == add2).isFalse();
      check(add1.hashCode == add2.hashCode).isFalse();

      const p = Pow(x, y);
      check(p.base).equals(x);
      check(p.exponent).equals(y);
      check(p.left).equals(x);
      check(p.right).equals(y);
    });

    test('hash distribution across composite AST nodes', () {
      const vars = [Variable('a'), Variable('b'), Variable('c')];
      final nodes = <Expr>[];

      for (final v in vars) {
        nodes.add(Sin(v));
        nodes.add(Cos(v));
        nodes.add(Neg(v));
        nodes.add(Exp(v));
        nodes.add(Ln(v));
      }

      for (var i = 0; i < vars.length; i++) {
        for (var j = 0; j < vars.length; j++) {
          nodes.add(Add(vars[i], vars[j]));
          nodes.add(Sub(vars[i], vars[j]));
          nodes.add(Mul(vars[i], vars[j]));
          nodes.add(Div(vars[i], vars[j]));
          nodes.add(Pow(vars[i], vars[j]));
        }
      }

      check(nodes.length).equals(60);
      final uniqueHashCodes = nodes.map((e) => e.hashCode).toSet();
      check(uniqueHashCodes.length).equals(60);
    });
  });

  group('Free Variables Correctness & Tree Traversal Stress', () {
    test('bushy tree with hundreds of variables collects all variables without stack overflow', () {
      const depth = 14;
      const numDistinctVars = 512;

      Expr buildBushyTree(int currentDepth, int index) {
        if (currentDepth == depth) {
          final varIdx = index % numDistinctVars;
          return Variable('var_$varIdx');
        }
        final left = buildBushyTree(currentDepth + 1, index * 2);
        final right = buildBushyTree(currentDepth + 1, index * 2 + 1);
        return switch (currentDepth % 4) {
          0 => Add(left, right),
          1 => Mul(left, right),
          2 => Sub(left, right),
          _ => Add(Sin(left), Cos(right)),
        };
      }

      final bushyTree = buildBushyTree(0, 0);

      final collected = <String>{};
      bushyTree.collectFreeVariables(collected);

      check(collected.length).equals(numDistinctVars);
      for (var i = 0; i < numDistinctVars; i++) {
        check(collected.contains('var_$i')).isTrue();
      }

      final fromGetter = bushyTree.freeVariables;
      check(fromGetter.length).equals(numDistinctVars);
      check(fromGetter).unorderedEquals(collected);

      check(bushyTree.dependsOn('var_0')).isTrue();
      check(bushyTree.dependsOn('var_255')).isTrue();
      check(bushyTree.dependsOn('var_511')).isTrue();
      check(bushyTree.dependsOn('var_9999')).isFalse();
    });

    test('deep linear chain of 1000 binary nodes collects all variables accurately', () {
      const chainDepth = 1000;
      Expr linearTree = const Variable('x_0');
      for (var i = 1; i < chainDepth; i++) {
        linearTree = Add(linearTree, Variable('x_$i'));
      }

      final target = <String>{};
      linearTree.collectFreeVariables(target);

      check(target.length).equals(chainDepth);
      for (var i = 0; i < chainDepth; i++) {
        check(target.contains('x_$i')).isTrue();
      }

      final fromGetter = linearTree.freeVariables;
      check(fromGetter.length).equals(chainDepth);
      check(fromGetter).unorderedEquals(target);
    });

    test('deep unary chain of 500 alternating transcendental nodes executes without stack overflow', () {
      const chainDepth = 500;
      Expr unaryTree = const Variable('root');
      for (var i = 0; i < chainDepth; i++) {
        unaryTree = switch (i % 5) {
          0 => Sin(unaryTree),
          1 => Cos(unaryTree),
          2 => Neg(unaryTree),
          3 => Exp(unaryTree),
          _ => Ln(unaryTree),
        };
      }

      final target = <String>{};
      unaryTree.collectFreeVariables(target);

      check(target).unorderedEquals({'root'});
      check(unaryTree.freeVariables).unorderedEquals({'root'});
      check(unaryTree.dependsOn('root')).isTrue();
      check(unaryTree.dependsOn('other')).isFalse();
    });
  });

  group('Canonical Pow & Radical AST Representation', () {
    const x = Variable('x');

    test('Pow(base, RationalNumber(1, 2)) canonical properties', () {
      const pow1 = Pow(x, RationalNumber(1, 2));
      const pow2 = Pow(x, RationalNumber(1, 2));
      const powOther = Pow(x, RationalNumber(1, 3));

      check(pow1 == pow2).isTrue();
      check(pow1.hashCode == pow2.hashCode).isTrue();
      check(pow1 == powOther).isFalse();

      check(pow1.freeVariables).unorderedEquals({'x'});

      final substituted = pow1.substitute('x', const RationalNumber(9));
      check(substituted)
          .equals(const Pow(RationalNumber(9), RationalNumber(1, 2)));
      check(substituted.evaluate({})).equals(3.0);
    });

    test('sqrt and pow parse canonically to Pow AST node', () {
      final sqrtExpr = Expr.parse('sqrt(x)');
      check(sqrtExpr).isA<Pow>();
      final powNode = sqrtExpr as Pow;
      check(powNode.base).equals(const Variable('x'));
      check(powNode.exponent).equals(const RationalNumber(1, 2));

      final powExpr = Expr.parse('pow(x, 3)');
      check(powExpr).isA<Pow>();
      final powNode2 = powExpr as Pow;
      check(powNode2.base).equals(const Variable('x'));
      check(powNode2.exponent).equals(const RationalNumber(3));

      final nestedSqrt = Expr.parse('sqrt(x^2 + 1)');
      check(nestedSqrt).isA<Pow>();
      check((nestedSqrt as Pow).exponent).equals(const RationalNumber(1, 2));
    });

    test('direct evaluate on square roots and powers', () {
      // sqrt(4) = 2
      const sqrt4 = Pow(RationalNumber(4), RationalNumber(1, 2));
      check(sqrt4.evaluate({})).equals(2.0);

      // sqrt(0) = 0
      const sqrt0 = Pow(RationalNumber(0), RationalNumber(1, 2));
      check(sqrt0.evaluate({})).equals(0.0);

      // sqrt(-1) = NaN
      const sqrtNeg = Pow(RationalNumber(-1), RationalNumber(1, 2));
      check(sqrtNeg.evaluate({}).isNaN).isTrue();

      // sqrt(x^2) for positive and negative numbers
      const sqrtX2 = Pow(Pow(x, RationalNumber(2)), RationalNumber(1, 2));
      check(sqrtX2.evaluate({'x': 5.0})).equals(5.0);
      check(sqrtX2.evaluate({'x': -5.0})).equals(5.0);

      // pow(x, -2) for x = 4
      const xPowNeg2 = Pow(x, RationalNumber(-2));
      check(xPowNeg2.evaluate({'x': 4.0})).equals(0.0625);

      // pow(0, -1) = Infinity
      const div0 = Pow(RationalNumber(0), RationalNumber(-1));
      check(div0.evaluate({})).equals(double.infinity);

      // odd rational root of negative number: (-8)^(1/3) = -2.0
      const cbrtNeg8 = Pow(RationalNumber(-8), RationalNumber(1, 3));
      check(cbrtNeg8.evaluate({})).isCloseTo(-2.0, 1e-12);
      const cbrtNeg8Squared = Pow(RationalNumber(-8), RationalNumber(2, 3));
      check(cbrtNeg8Squared.evaluate({})).isCloseTo(4.0, 1e-12);
    });

    test('RealNumber(double.nan) reflexivity and stable inverse hyperbolic evaluation', () {
      const nan1 = RealNumber(double.nan);
      const nan2 = RealNumber(double.nan);
      check(nan1 == nan2).isTrue();
      check(nan1.hashCode).equals(nan2.hashCode);

      // Asinh for large negative argument does not underflow to -Infinity
      const largeNegAsinh = Asinh(RealNumber(-1e8));
      final val = largeNegAsinh.evaluate({});
      check(val.isFinite).isTrue();
      check(val).isCloseTo(-19.11382792451231, 1e-10);
    });
  });
}
