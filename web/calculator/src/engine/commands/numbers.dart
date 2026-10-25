import 'package:data/symbolic.dart';

import '../../model/value.dart';
import '../commands.dart';

/// Builds canonical number theory & rounding commands (`approx`, `exact`,
/// `gcd`, `lcm`, `mod`, `isprime`, `factorial`, `binomial`, `floor`, `ceil`,
/// `round`).
List<Command> buildNumbersCommands() => [
  Command(
    name: 'approx',
    category: CommandCategory.numbers,
    signature: 'approx(expr, [digits])',
    paramSpecs: const [
      ParamSpec.expr('expr'),
      ParamSpec.optionalInt('[digits]'),
    ],
    minArity: 1,
    maxArity: 2,
    doc: 'Evaluates closed constant subexpressions to floating-point numbers.',
    examples: const ['approx(sqrt(2) + pi)', 'approx(sin(1), 8)'],
    rpnLabel: 'Approx',
    rpnArity: 1,
    appliesTo: (v) => v.isExact && !(v is ExprValue && v.expr is IntegerNumber),
    chipLabel: '≈',
    buildChipCall: (id, _) => 'approx(r[$id])',
    run: (args, ctx) {
      checkCommandArity('approx', args, 1, 2);
      return liftUnaryCommand(
        args[0],
        (e) => e.approximate(),
        onMatrix: (m) => m.approximate(),
        onVector: (v) => v.approximate(),
      );
    },
  ),
  Command(
    name: 'exact',
    category: CommandCategory.numbers,
    signature: 'exact(expr)',
    paramSpecs: const [ParamSpec.expr('expr')],
    minArity: 1,
    maxArity: 1,
    doc: 'Reconstructs exact rationals from floating-point numbers via continued fractions.',
    examples: const ['exact(0.333333333333)', 'exact(0.75 * x + 0.125)'],
    rpnLabel: 'Exact',
    rpnArity: 1,
    appliesTo: (v) => !v.isExact,
    chipLabel: 'Exact',
    buildChipCall: (id, _) => 'exact(r[$id])',
    run: (args, ctx) {
      checkCommandArity('exact', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => e.rationalize(),
        onMatrix: (m) => m.rationalize(),
        onVector: (v) => v.rationalize(),
      );
    },
  ),
  Command(
    name: 'gcd',
    category: CommandCategory.numbers,
    signature: 'gcd(a, b, ...)',
    paramSpecs: const [ParamSpec.expr('a'), ParamSpec.expr('b')],
    minArity: 2,
    maxArity: 16,
    doc: 'Computes the greatest common divisor of integers or rationals.',
    examples: const ['gcd(84, 126)', 'gcd(12, 18, 30)'],
    rpnLabel: 'GCD',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'gcd',
    buildChipCall: (id, _) => 'gcd(r[$id], 1)',
    run: (args, ctx) {
      checkCommandArity('gcd', args, 2, 16);
      final exprArgs = [for (final a in args) expectCommandExpr(a, 'gcd')];
      return ExprValue(
        ExprSyntax.standardVariadicFunctions['gcd']!(exprArgs).simplify(),
      );
    },
  ),
  Command(
    name: 'lcm',
    category: CommandCategory.numbers,
    signature: 'lcm(a, b, ...)',
    paramSpecs: const [ParamSpec.expr('a'), ParamSpec.expr('b')],
    minArity: 2,
    maxArity: 16,
    doc: 'Computes the least common multiple of integers or rationals.',
    examples: const ['lcm(12, 18)', 'lcm(4, 6, 15)'],
    rpnLabel: 'LCM',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'lcm',
    buildChipCall: (id, _) => 'lcm(r[$id], 1)',
    run: (args, ctx) {
      checkCommandArity('lcm', args, 2, 16);
      final exprArgs = [for (final a in args) expectCommandExpr(a, 'lcm')];
      return ExprValue(
        ExprSyntax.standardVariadicFunctions['lcm']!(exprArgs).simplify(),
      );
    },
  ),
  Command(
    name: 'mod',
    category: CommandCategory.numbers,
    signature: 'mod(a, b)',
    paramSpecs: const [ParamSpec.expr('a'), ParamSpec.expr('b')],
    minArity: 2,
    maxArity: 2,
    doc: 'Computes the modulo remainder a mod b.',
    examples: const ['mod(17, 5)', 'mod(-7, 3)'],
    rpnLabel: 'MOD',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'mod',
    buildChipCall: (id, _) => 'mod(r[$id], 2)',
    run: (args, ctx) {
      checkCommandArity('mod', args, 2, 2);
      final a = expectCommandExpr(args[0], 'mod');
      final b = expectCommandExpr(args[1], 'mod');
      return ExprValue(Mod(a, b).simplify());
    },
  ),
  Command(
    name: 'isprime',
    category: CommandCategory.numbers,
    signature: 'isprime(n)',
    paramSpecs: const [ParamSpec.expr('n')],
    minArity: 1,
    maxArity: 1,
    doc: 'Tests whether integer n is prime (returns 1 if prime, 0 otherwise).',
    examples: const ['isprime(97)', 'isprime(100)'],
    rpnLabel: 'IsPrime',
    rpnArity: 1,
    appliesTo: (v) => v is ExprValue && v.expr is IntegerNumber,
    chipLabel: 'Prime?',
    buildChipCall: (id, _) => 'isprime(r[$id])',
    run: (args, ctx) {
      checkCommandArity('isprime', args, 1, 1);
      final e = expectCommandExpr(args[0], 'isprime').simplify();
      if (e is IntegerNumber) {
        return ExprValue(e.isPrime ? IntegerNumber.one : IntegerNumber.zero);
      }
      throw ArgumentError('isprime expects an integer argument, got: $e');
    },
  ),
  Command(
    name: 'factorial',
    category: CommandCategory.numbers,
    signature: 'factorial(n)',
    paramSpecs: const [ParamSpec.expr('n')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the exact factorial n!.',
    examples: const ['factorial(30)', '25!'],
    rpnLabel: 'n!',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'n!',
    buildChipCall: (id, _) => 'factorial(r[$id])',
    run: (args, ctx) {
      checkCommandArity('factorial', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => Factorial(e).simplify());
    },
  ),
  Command(
    name: 'binomial',
    category: CommandCategory.numbers,
    signature: 'binomial(n, k)',
    paramSpecs: const [ParamSpec.expr('n'), ParamSpec.expr('k')],
    minArity: 2,
    maxArity: 2,
    doc: 'Computes the binomial coefficient C(n, k).',
    examples: const ['binomial(10, 3)', 'binomial(n, 2)'],
    rpnLabel: 'nCr',
    rpnArity: 2,
    appliesTo: (_) => false,
    chipLabel: 'nCr',
    buildChipCall: (id, _) => 'binomial(r[$id], 2)',
    run: (args, ctx) {
      checkCommandArity('binomial', args, 2, 2);
      final a = expectCommandExpr(args[0], 'binomial');
      final b = expectCommandExpr(args[1], 'binomial');
      return ExprValue(Binomial(a, b).simplify());
    },
  ),
  Command(
    name: 'floor',
    category: CommandCategory.numbers,
    signature: 'floor(x)',
    paramSpecs: const [ParamSpec.expr('x')],
    minArity: 1,
    maxArity: 1,
    doc: 'Rounds down to the greatest integer ≤ x.',
    examples: const ['floor(7 / 3)', 'floor(pi)'],
    rpnLabel: 'Floor',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'floor',
    buildChipCall: (id, _) => 'floor(r[$id])',
    run: (args, ctx) {
      checkCommandArity('floor', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => Floor(e).simplify());
    },
  ),
  Command(
    name: 'ceil',
    category: CommandCategory.numbers,
    signature: 'ceil(x)',
    paramSpecs: const [ParamSpec.expr('x')],
    minArity: 1,
    maxArity: 1,
    doc: 'Rounds up to the least integer ≥ x.',
    examples: const ['ceil(7 / 3)', 'ceil(pi)'],
    rpnLabel: 'Ceil',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'ceil',
    buildChipCall: (id, _) => 'ceil(r[$id])',
    run: (args, ctx) {
      checkCommandArity('ceil', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => Ceil(e).simplify());
    },
  ),
  Command(
    name: 'round',
    category: CommandCategory.numbers,
    signature: 'round(x)',
    paramSpecs: const [ParamSpec.expr('x')],
    minArity: 1,
    maxArity: 1,
    doc: 'Rounds to the nearest integer.',
    examples: const ['round(7 / 3)', 'round(pi)'],
    rpnLabel: 'Round',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'round',
    buildChipCall: (id, _) => 'round(r[$id])',
    run: (args, ctx) {
      checkCommandArity('round', args, 1, 1);
      return liftUnaryCommand(args[0], (e) => Round(e).simplify());
    },
  ),
];
