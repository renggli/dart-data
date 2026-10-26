import 'package:data/symbolic.dart';

import '../../model/value.dart';
import '../commands.dart';

/// Builds canonical complex analysis commands (`re`, `im`, `conj`, `arg`,
/// `abs`, `polar`, `rect`).
List<Command> buildComplexCommands() => [
  Command(
    name: 're',
    category: CommandCategory.complex,
    signature: 're(z)',
    paramSpecs: const [ParamSpec.expr('z')],
    minArity: 1,
    maxArity: 1,
    doc: 'Extracts the real part Re(z) of a complex expression.',
    examples: const ['re(3 + 4 * i)', 're(exp(i * x))'],
    rpnLabel: 'Re',
    rpnArity: 1,
    appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
    chipLabel: 'Re',
    buildChipCall: (id, _) => 're(r[$id])',
    run: (args, ctx) {
      checkCommandArity('re', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => Re(e).simplify(assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'im',
    category: CommandCategory.complex,
    signature: 'im(z)',
    paramSpecs: const [ParamSpec.expr('z')],
    minArity: 1,
    maxArity: 1,
    doc: 'Extracts the imaginary part Im(z) of a complex expression.',
    examples: const ['im(3 + 4 * i)', 'im(exp(i * x))'],
    rpnLabel: 'Im',
    rpnArity: 1,
    appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
    chipLabel: 'Im',
    buildChipCall: (id, _) => 'im(r[$id])',
    run: (args, ctx) {
      checkCommandArity('im', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => Im(e).simplify(assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'conj',
    category: CommandCategory.complex,
    signature: 'conj(z)',
    paramSpecs: const [ParamSpec.expr('z')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the complex conjugate z* of an expression.',
    examples: const ['conj(3 + 4 * i)', 'conj(a + b * i)'],
    rpnLabel: 'Conj',
    rpnArity: 1,
    appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
    chipLabel: 'conj',
    buildChipCall: (id, _) => 'conj(r[$id])',
    run: (args, ctx) {
      checkCommandArity('conj', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => Conjugate(e).simplify(assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'arg',
    category: CommandCategory.complex,
    signature: 'arg(z)',
    paramSpecs: const [ParamSpec.expr('z')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the complex phase angle arg(z) ∈ (-π, π].',
    examples: const ['arg(1 + i)', 'arg(-1)'],
    rpnLabel: 'Arg',
    rpnArity: 1,
    appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
    chipLabel: 'arg',
    buildChipCall: (id, _) => 'arg(r[$id])',
    run: (args, ctx) {
      checkCommandArity('arg', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => Arg(e).simplify(assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'abs',
    category: CommandCategory.complex,
    signature: 'abs(z)',
    paramSpecs: const [ParamSpec.expr('z')],
    minArity: 1,
    maxArity: 1,
    doc: 'Computes the absolute value or complex modulus |z|.',
    examples: const ['abs(3 + 4 * i)', 'abs(-42)'],
    rpnLabel: 'Abs',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: '|z|',
    buildChipCall: (id, _) => 'abs(r[$id])',
    run: (args, ctx) {
      checkCommandArity('abs', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => Abs(e).simplify(assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'polar',
    category: CommandCategory.complex,
    signature: 'polar(z)',
    paramSpecs: const [ParamSpec.expr('z')],
    minArity: 1,
    maxArity: 1,
    doc: 'Rewrites a complex expression in polar form r * e^(i * θ).',
    examples: const ['polar(1 + i)', 'polar(-2 * i)'],
    rpnLabel: 'Polar',
    rpnArity: 1,
    appliesTo: (v) => v is ExprValue && _hasImaginary(v.expr),
    chipLabel: 'Polar',
    buildChipCall: (id, _) => 'polar(r[$id])',
    run: (args, ctx) {
      checkCommandArity('polar', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => e.toPolar(assumptions: ctx.assumptions),
      );
    },
  ),
  Command(
    name: 'rect',
    category: CommandCategory.complex,
    signature: 'rect(z)',
    paramSpecs: const [ParamSpec.expr('z')],
    minArity: 1,
    maxArity: 1,
    doc: 'Rewrites a complex expression in rectangular form Re(z) + i * Im(z).',
    examples: const ['rect(exp(i * pi / 3))', 'rect((1 + i)^4)'],
    rpnLabel: 'Rect',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'Rect',
    buildChipCall: (id, _) => 'rect(r[$id])',
    run: (args, ctx) {
      checkCommandArity('rect', args, 1, 1);
      return liftUnaryCommand(
        args[0],
        (e) => e.toRectangular(assumptions: ctx.assumptions),
      );
    },
  ),
];

bool _hasImaginary(Expr expr) => expr.anyNode(
  (n) =>
      (n is ComplexNumber && !n.imaginary.isZero) ||
      (n is Constant && !n.isReal),
);
