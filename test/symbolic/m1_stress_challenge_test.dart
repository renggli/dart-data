import 'dart:math' as math;
import 'dart:typed_data';

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

void main() {
  group('Empirical Challenge 1: AST Node Hashing & Equality', () {
    test('distinct unary expressions with identical Variable argument have distinct hash codes', () {
      const x = Variable('x');
      const uSin = Sin(x);
      const uCos = Cos(x);
      const uNeg = Neg(x);
      const uExp = Exp(x);
      const uLn = Ln(x);

      final unaries = <UnaryExpr>[uSin, uCos, uNeg, uExp, uLn];

      // Mutually distinct hash codes
      final hashCodes = unaries.map((e) => e.hashCode).toSet();
      check(hashCodes.length).equals(5);

      // Mutually non-equal
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

      // Mutually distinct hash codes
      final hashCodes = binaries.map((e) => e.hashCode).toSet();
      check(hashCodes.length).equals(5);

      // Mutually non-equal
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

      // Unary vs Binary
      check((const Sin(x) as Expr) == const Add(x, x)).isFalse();
      check((const Neg(x) as Expr) == const Sub(x, x)).isFalse();

      // Reversed operands in non-commutative and commutative syntax
      const sub1 = Sub(x, y);
      const sub2 = Sub(y, x);
      check(sub1 == sub2).isFalse();
      check(sub1.hashCode == sub2.hashCode).isFalse();

      const add1 = Add(x, y);
      const add2 = Add(y, x);
      check(add1 == add2).isFalse(); // AST nodes are structurally ordered
      check(add1.hashCode == add2.hashCode).isFalse();

      // Pow accessors
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

      // Total nodes: 3 * 5 + 9 * 5 = 15 + 45 = 60 nodes
      check(nodes.length).equals(60);
      final uniqueHashCodes = nodes.map((e) => e.hashCode).toSet();
      // Hash collisions among 60 small AST expressions should be 0 with Object.hash
      check(uniqueHashCodes.length).equals(60);
    });
  });

  group(
    'Empirical Challenge 2: Tensor Kernel Zero-Allocation & Performance',
    () {
      test('10,000 iterations tight loop execution with memory and numerical stability', () {
        const x = Variable('x');
        const y = Variable('y');
        const z = Variable('z');

        // Multi-operation transcendental and rational formula
        // f(x, y, z) = sin(x) * cos(y) + exp(x - y) - ln(z) + (x * y) / (z + 1)
        final expr =
            (const Sin(x) * const Cos(y)) +
            Exp(x - y) -
            const Ln(z) +
            ((x * y) / (z + const RationalNumber(1)));

        final kernel = expr.compileTensorKernel(['x', 'y', 'z']);

        const bufferLen = 64;
        final xBuf = Float64List(bufferLen);
        final yBuf = Float64List(bufferLen);
        final zBuf = Float64List(bufferLen);
        final outBuf = Float64List(bufferLen);
        final expectedBuf = Float64List(bufferLen);

        for (var i = 0; i < bufferLen; i++) {
          final xVal = (i + 1) * 0.05;
          final yVal = (i + 1) * 0.03;
          final zVal =
              (i + 1) * 0.1 + 1.0; // keep z > 1 so ln(z) > 0 and z + 1 != 0
          xBuf[i] = xVal;
          yBuf[i] = yVal;
          zBuf[i] = zVal;

          expectedBuf[i] =
              math.sin(xVal) * math.cos(yVal) +
              math.exp(xVal - yVal) -
              math.log(zVal) +
              (xVal * yVal) / (zVal + 1.0);
        }

        final stopwatch = Stopwatch()..start();

        // Phase A: Execute 10,000 times with static buffers to test stability
        const iterations = 10000;
        for (var iter = 0; iter < iterations; iter++) {
          kernel([xBuf, yBuf, zBuf], outBuf);
        }

        stopwatch.stop();

        // Output correctness check across the full buffer
        for (var i = 0; i < bufferLen; i++) {
          check(outBuf[i]).isCloseTo(expectedBuf[i], 1e-12);
        }

        // Performance check: 10,000 iterations over 64 elements = 640,000 vector evaluations
        // Must complete within 2000ms
        check(stopwatch.elapsedMilliseconds).isLessThan(2000);

        // Phase B: Execute 1,000 iterations with dynamically mutating inputs to verify no state residue
        for (var iter = 0; iter < 1000; iter++) {
          final factor = (iter % 100 + 1) * 0.01;
          xBuf[0] = factor;
          yBuf[0] = factor * 0.5;
          zBuf[0] = factor + 1.5;

          kernel([xBuf, yBuf, zBuf], outBuf);

          final expected =
              math.sin(xBuf[0]) * math.cos(yBuf[0]) +
              math.exp(xBuf[0] - yBuf[0]) -
              math.log(zBuf[0]) +
              (xBuf[0] * yBuf[0]) / (zBuf[0] + 1.0);
          check(outBuf[0]).isCloseTo(expected, 1e-12);
        }
      });

      test(
        'kernel execution with deeply nested unary and stack operations',
        () {
          const x = Variable('x');
          // Expression testing heavy stack reuse:
          // f(x) = exp(-(-(-sin(cos(sin(x)))))) + x^2 - x^3 + x^4
          final expr =
              const Exp(Neg(Neg(Neg(Sin(Cos(Sin(x))))))) +
              x.pow(const RationalNumber(2)) -
              x.pow(const RationalNumber(3)) +
              x.pow(const RationalNumber(4));

          final kernel = expr.compileTensorKernel(['x']);

          final xBuf = Float64List.fromList([0.1, 0.5, 1.0, 1.5, 2.0]);
          final outBuf = Float64List(5);

          for (var iter = 0; iter < 1000; iter++) {
            kernel([xBuf], outBuf);
          }

          for (var i = 0; i < 5; i++) {
            final xVal = xBuf[i];
            final inner = -math.sin(math.cos(math.sin(xVal)));
            final expected =
                math.exp(inner) +
                math.pow(xVal, 2) -
                math.pow(xVal, 3) +
                math.pow(xVal, 4);
            check(outBuf[i]).isCloseTo(expected, 1e-12);
          }
        },
      );
    },
  );

  group('Empirical Challenge 3: Free Variables Correctness & Tree Stress', () {
    test('bushy tree with hundreds of variables collects all variables without stack overflow', () {
      // Build a balanced binary tree of depth 14 with 16,384 leaves (32,767 total nodes)
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

      // Verify collectFreeVariables with a reused target set
      final collected = <String>{};
      bushyTree.collectFreeVariables(collected);

      check(collected.length).equals(numDistinctVars);
      for (var i = 0; i < numDistinctVars; i++) {
        check(collected.contains('var_$i')).isTrue();
      }

      // Verify freeVariables getter produces identical results
      final fromGetter = bushyTree.freeVariables;
      check(fromGetter.length).equals(numDistinctVars);
      check(fromGetter).unorderedEquals(collected);

      // Verify dependsOn consistency
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
}
