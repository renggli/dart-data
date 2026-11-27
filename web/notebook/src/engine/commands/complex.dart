import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

final List<Command> complexCommands = [
  Command(
    name: 're',
    category: CommandCategory.complex,
    signature: const FunctionSignature(positional: [ParamSpec.positional('z')]),
    doc: 'Extracts the real part of a complex expression.',
    examples: ['re(3 + 4*i)', 're(exp(i*x))'],
    run: (args, ctx) =>
        ExprValue(Fn.re(args.expr('z')).simplify(assumptions: ctx.assumptions)),
  ),
  Command(
    name: 'im',
    category: CommandCategory.complex,
    signature: const FunctionSignature(positional: [ParamSpec.positional('z')]),
    doc: 'Extracts the imaginary part of a complex expression.',
    examples: ['im(3 + 4*i)'],
    run: (args, ctx) =>
        ExprValue(Fn.im(args.expr('z')).simplify(assumptions: ctx.assumptions)),
  ),
  Command(
    name: 'conj',
    aliases: ['conjugate'],
    category: CommandCategory.complex,
    signature: const FunctionSignature(positional: [ParamSpec.positional('z')]),
    doc: 'Computes the complex conjugate.',
    examples: ['conj(3 + 4*i)'],
    run: (args, ctx) => ExprValue(
      Fn.conj(args.expr('z')).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'arg',
    category: CommandCategory.complex,
    signature: const FunctionSignature(positional: [ParamSpec.positional('z')]),
    doc: 'Computes the principal argument (phase angle) in (-pi, pi].',
    examples: ['arg(1 + i)'],
    run: (args, ctx) => ExprValue(
      Fn.arg(args.expr('z')).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'abs',
    category: CommandCategory.complex,
    signature: const FunctionSignature(positional: [ParamSpec.positional('z')]),
    doc: 'Computes the absolute value or complex modulus.',
    examples: ['abs(3 + 4*i)'],
    run: (args, ctx) => ExprValue(
      Fn.abs(args.expr('z')).simplify(assumptions: ctx.assumptions),
    ),
  ),
  Command(
    name: 'polar',
    category: CommandCategory.complex,
    signature: const FunctionSignature(positional: [ParamSpec.positional('z')]),
    doc: 'Converts a complex expression into polar form [r, theta].',
    examples: ['polar(1 + i)'],
    run: (args, ctx) {
      final z = args.expr('z');
      final r = Fn.abs(z).simplify(assumptions: ctx.assumptions);
      final theta = Fn.arg(z).simplify(assumptions: ctx.assumptions);
      return ListValue([ExprValue(r), ExprValue(theta)]);
    },
  ),
  Command(
    name: 'rect',
    category: CommandCategory.complex,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('r'), ParamSpec.positional('theta')],
    ),
    doc: 'Converts polar coordinates (r, theta) to rectangular form a + b*i.',
    examples: ['rect(sqrt(2), pi/4)'],
    run: (args, ctx) {
      final r = args.expr('r');
      final theta = args.expr('theta');
      final expr = r * (Fn.cos(theta) + ComplexNumber.i * Fn.sin(theta));
      return ExprValue(expr.simplify(assumptions: ctx.assumptions));
    },
  ),
];
