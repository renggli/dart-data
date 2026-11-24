import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

const List<String> _domainEnum = [
  'unknown',
  'complex',
  'real',
  'positive',
  'integer',
];

final List<Command> algebraCommands = [
  Command(
    name: 'simplify',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
      named: [
        ParamSpec.named(
          'domain',
          type: ParamType.string,
          enumValues: _domainEnum,
        ),
      ],
    ),
    doc: 'Simplifies an expression algebraically under optional domain assumptions.',
    examples: [
      'simplify((x^2 - 1)/(x - 1))',
      "simplify(sqrt(x^2), domain: 'positive')",
    ],
    chipLabel: 'Simplify',
    appliesTo: (v) => v is ExprValue,
    buildChipCall: (input, _) => 'simplify($input)',
    run: (args, ctx) {
      final domName = args.stringOrNull('domain');
      final assumptions = domName == null
          ? ctx.assumptions
          : Assumptions(defaultDomain: parseDomainName(domName));
      return ExprValue(args.expr('expr').simplify(assumptions: assumptions));
    },
  ),
  Command(
    name: 'expand',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Expands products and integer powers in an expression.',
    examples: ['expand((x + 1)^4)'],
    preserveForm: true,
    chipLabel: 'Expand',
    appliesTo: (v) => v is ExprValue,
    buildChipCall: (input, _) => 'expand($input)',
    run: (args, _) => ExprValue(args.expr('expr').expand()),
  ),
  Command(
    name: 'factor',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Factors a polynomial over the integers/rationals.',
    examples: ['factor(x^3 - 1)', 'factor(x^2 - 5*x + 6)'],
    preserveForm: true,
    chipLabel: 'Factor',
    appliesTo: (v) => v is ExprValue,
    buildChipCall: (input, _) => 'factor($input)',
    run: (args, _) => ExprValue(args.expr('expr').factor()),
  ),
  Command(
    name: 'solve',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('eq', type: ParamType.equation),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
      named: [
        ParamSpec.named(
          'domain',
          type: ParamType.string,
          enumValues: _domainEnum,
        ),
      ],
    ),
    doc: 'Solves an equation (or expression = 0) symbolically.',
    examples: ['solve(x^2 - 5*x + 6 = 0, x)', 'solve(sin(x) = 1/2, x)'],
    chipLabel: 'Solve',
    appliesTo: (v) => v is ExprValue && v.expr.freeVariables.isNotEmpty,
    buildChipCall: (input, v) {
      final ev = v as ExprValue;
      final vName = inferVariable(ev.expr);
      return 'solve($input, $vName)';
    },
    run: (args, ctx) {
      final eq = args.expr('eq');
      final v = inferVariable(eq, args.symbolOrNull('var'));
      final domName = args.stringOrNull('domain');
      final assumptions = domName == null
          ? ctx.assumptions
          : Assumptions(defaultDomain: parseDomainName(domName));
      final solutions = eq.solve(v, assumptions: assumptions);
      if (solutions.length == 1) return ExprValue(solutions.first);
      return ListValue([for (final s in solutions) ExprValue(s)]);
    },
  ),
  Command(
    name: 'subs',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
      variadic: true,
      variadicType: ParamType.equation,
    ),
    doc: 'Substitutes variables using `var = value` equations.',
    examples: ['subs(x^2 + y, x = 3, y = 1)'],
    run: (args, _) {
      var expr = args.expr('expr');
      for (final item in args.rest) {
        if (item is Equal) {
          if (item.left case Variable(:final name)) {
            expr = expr.substitute(name, item.right);
            continue;
          }
        }
        throw const ArgumentBindingException(
          'subs replacements must have the form variable = value',
        );
      }
      return ExprValue(expr.simplify());
    },
  ),
  Command(
    name: 'apart',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.optional('var', type: ParamType.symbol),
      ],
    ),
    doc:
        'Computes the partial fraction decomposition of a rational expression.',
    examples: ['apart(1 / (x^2 - 1), x)'],
    preserveForm: true,
    run: (args, _) {
      final expr = args.expr('expr');
      final v = inferVariable(expr, args.symbolOrNull('var'));
      return ExprValue(expr.apart(v));
    },
  ),
  Command(
    name: 'together',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Combines sums of fractions over a common denominator.',
    examples: ['together(1/x + 1/(x + 1))'],
    preserveForm: true,
    run: (args, _) => ExprValue(args.expr('expr').together()),
  ),
  Command(
    name: 'cancel',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Cancels common polynomial factors in numerator and denominator.',
    examples: ['cancel((x^2 - 4)/(x - 2))'],
    run: (args, _) => ExprValue(args.expr('expr').cancel()),
  ),
  Command(
    name: 'collect',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('expr'),
        ParamSpec.positional('var', type: ParamType.symbol),
      ],
    ),
    doc: 'Collects terms by powers of a variable.',
    examples: ['collect(a*x^2 + b*x + c*x^2, x)'],
    preserveForm: true,
    run: (args, _) => ExprValue(args.expr('expr').collect(args.symbol('var'))),
  ),
  Command(
    name: 'numer',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Extracts the numerator of a rational expression.',
    examples: ['numer((x + 1)/(x - 2))'],
    run: (args, _) => ExprValue(args.expr('expr').numerator),
  ),
  Command(
    name: 'denom',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Extracts the denominator of a rational expression.',
    examples: ['denom((x + 1)/(x - 2))'],
    run: (args, _) => ExprValue(args.expr('expr').denominator),
  ),
  Command(
    name: 'trigexpand',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Expands trigonometric functions of sums and multiples.',
    examples: ['trigexpand(sin(2*x))'],
    preserveForm: true,
    run: (args, _) => ExprValue(args.expr('expr').expandTrig()),
  ),
  Command(
    name: 'trigsimplify',
    category: CommandCategory.algebra,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('expr')],
    ),
    doc: 'Simplifies trigonometric expressions using Pythagorean and angle identities.',
    examples: ['trigsimplify(sin(x)^2 + cos(x)^2)'],
    run: (args, _) => ExprValue(args.expr('expr').simplifyTrig()),
  ),
];
