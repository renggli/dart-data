import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

final List<Command> numbersCommands = [
  Command(
    name: 'approx',
    aliases: ['N'],
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
      named: [ParamSpec.named('digits', type: ParamType.integer)],
    ),
    doc: 'Evaluates an expression numerically to floating-point precision.',
    examples: ['approx(pi)', 'approx(sqrt(2))'],
    chipLabel: 'Approx',
    appliesTo: (v) => v is ExprValue && v.isExact,
    buildChipCall: (input, _) => 'approx($input)',
    run: (args, _) => ExprValue(args.expr('expr').approximate()),
  ),
  Command(
    name: 'exact',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Converts floating-point numbers in an expression to exact rationals.',
    examples: ['exact(0.75)', 'exact(1.25 * x)'],
    run: (args, ctx) => ExprValue(
      args.expr('expr').rationalize().simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'gcd',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('a')],
      variadic: true,
      variadicType: ParamType.expr,
    ),
    doc: 'Computes the greatest common divisor.',
    examples: ['gcd(48, 180)'],
    run: (args, ctx) => ExprValue(
      Fn.gcd([args.expr('a'), ...args.rest.cast<Expr>()])
          .simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'lcm',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('a')],
      variadic: true,
      variadicType: ParamType.expr,
    ),
    doc: 'Computes the least common multiple.',
    examples: ['lcm(12, 18)'],
    run: (args, ctx) => ExprValue(
      Fn.lcm([args.expr('a'), ...args.rest.cast<Expr>()])
          .simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'min',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('a')],
      variadic: true,
      variadicType: ParamType.expr,
    ),
    doc: 'Computes the minimum of expressions.',
    examples: ['min(3, -1, 7)'],
    run: (args, ctx) => ExprValue(
      Fn.min([args.expr('a'), ...args.rest.cast<Expr>()])
          .simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'max',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('a')],
      variadic: true,
      variadicType: ParamType.expr,
    ),
    doc: 'Computes the maximum of expressions.',
    examples: ['max(3, -1, 7)'],
    run: (args, ctx) => ExprValue(
      Fn.max([args.expr('a'), ...args.rest.cast<Expr>()])
          .simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'mod',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('a'), ParamSpec.positional('b')],
    ),
    doc: 'Computes the modulo remainder a mod b.',
    examples: ['mod(17, 5)'],
    run: (args, ctx) => ExprValue(
      Fn.mod(
        args.expr('a'),
        args.expr('b'),
      ).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'isprime',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('n', type: ParamType.integer)],
    ),
    doc: 'Tests whether an integer is prime.',
    examples: ['isprime(97)', 'isprime(91)'],
    run: (args, _) => BoolValue(_isPrime(args.intVal('n'))),
  ),
  Command(
    name: 'factorial',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(positional: [ParamSpec.positional('n')]),
    doc: 'Computes the factorial n!.',
    examples: ['factorial(10)'],
    run: (args, ctx) => ExprValue(
      Fn.factorial(args.expr('n')).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'binomial',
    aliases: ['nCr'],
    category: CommandCategory.numbers,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('n'), ParamSpec.positional('k')],
    ),
    doc: 'Computes the binomial coefficient C(n, k).',
    examples: ['binomial(10, 3)'],
    run: (args, ctx) => ExprValue(
      Fn.binomial(
        args.expr('n'),
        args.expr('k'),
      ).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'floor',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(positional: [ParamSpec.positional('x')]),
    doc: 'Computes the floor (greatest integer <= x).',
    examples: ['floor(3.7)'],
    run: (args, ctx) => ExprValue(
      Fn.floor(args.expr('x')).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'ceil',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(positional: [ParamSpec.positional('x')]),
    doc: 'Computes the ceiling (smallest integer >= x).',
    examples: ['ceil(3.2)'],
    run: (args, ctx) => ExprValue(
      Fn.ceil(args.expr('x')).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'round',
    category: CommandCategory.numbers,
    signature: const FunctionSignature(positional: [ParamSpec.positional('x')]),
    doc: 'Rounds to the nearest integer.',
    examples: ['round(3.6)'],
    run: (args, ctx) => ExprValue(
      Fn.round(args.expr('x')).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'sign',
    aliases: ['sgn'],
    category: CommandCategory.numbers,
    signature: const FunctionSignature(positional: [ParamSpec.positional('x')]),
    doc: 'Computes the signum (-1, 0, or 1).',
    examples: ['sign(-42)'],
    run: (args, ctx) => ExprValue(
      Fn.sign(args.expr('x')).simplify(assumptions: ctx.assumptions),
    ),
  ),
];

bool _isPrime(int n) {
  if (n < 2) return false;
  if (n < 4) return true;
  if (n.isEven || n % 3 == 0) return false;
  for (var i = 5; i * i <= n; i += 6) {
    if (n % i == 0 || n % (i + 2) == 0) return false;
  }
  return true;
}
