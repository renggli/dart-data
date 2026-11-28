import 'dart:math' as math;

import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

final List<Command> interactiveCommands = [
  Command(
    name: 'slider',
    category: CommandCategory.interactive,
    signature: const FunctionSignature(
      positional: [ParamSpec.positional('range', type: ParamType.range)],
      named: [
        ParamSpec.named('default', type: ParamType.number),
        ParamSpec.named('step', type: ParamType.number),
        ParamSpec.named('label', type: ParamType.string),
      ],
    ),
    doc: 'Creates an interactive numeric slider over `min..max` whose value updates dependent cells and plots live.',
    examples: [
      "a := slider(-1..1, default: 0, label: 'value a')",
      "n := slider(1..10, default: 3, step: 1, label: 'order')",
    ],
    run: (args, _) {
      final range = args.numericRange('range');
      final minVal = range.start;
      final maxVal = range.end;
      if (!minVal.isFinite || !maxVal.isFinite || minVal >= maxVal) {
        throw const ArgumentBindingException(
          'slider requires a finite ascending range min..max with min < max',
        );
      }
      final rawDefault = args.doubleOrNull('default');
      final defaultVal = (rawDefault ?? 0.5 * (minVal + maxVal)).clamp(
        minVal,
        maxVal,
      );
      final rawStep = args.doubleOrNull('step');
      final step = rawStep != null && rawStep.isFinite && rawStep > 0
          ? rawStep
          : _niceStep(minVal, maxVal);
      return SliderValue(
        key: '',
        min: minVal,
        max: maxVal,
        step: step,
        defaultValue: defaultVal,
        value: defaultVal,
        label: args.stringOrNull('label'),
      );
    },
  ),
  Command(
    name: 'input',
    category: CommandCategory.interactive,
    signature: const FunctionSignature(
      positional: [ParamSpec.optional('default', type: ParamType.any)],
      named: [ParamSpec.named('label', type: ParamType.string)],
    ),
    preserveForm: true,
    doc: 'Creates an interactive formula input box whose parsed expression or numeric value updates dependent cells live.',
    examples: [
      "b := input(pi, label: 'value: b')",
      "f := input(sin(x), label: 'formula')",
    ],
    run: (args, ctx) {
      final rawDefault = args.raw('default');
      final CalcValue defaultEval;
      if (rawDefault == null) {
        defaultEval = ExprValue(IntegerNumber.zero);
      } else if (rawDefault is CalcValue) {
        defaultEval = switch (rawDefault) {
          SliderValue(:final unwrapped) => unwrapped,
          InputValue(:final unwrapped) => unwrapped,
          ControlGroupValue() => ExprValue(IntegerNumber.zero),
          _ => rawDefault,
        };
      } else {
        defaultEval = ExprValue(IntegerNumber.zero);
      }
      final simplified =
          (ctx.env.settings.autoSimplify &&
              defaultEval is ExprValue &&
              defaultEval.expr is! Relational)
          ? ExprValue(defaultEval.expr.simplify(assumptions: ctx.assumptions))
          : defaultEval;
      final defaultSrc = defaultEval.toCanonicalText();
      return InputValue(
        key: '',
        defaultSource: defaultSrc,
        source: defaultSrc,
        evaluated: simplified,
        label: args.stringOrNull('label'),
      );
    },
  ),
];

double _niceStep(double min, double max) {
  final span = (max - min).abs();
  if (span == 0) return 0.01;
  final raw = span / 200.0;
  final exp = (math.log(raw) / math.ln10).floor();
  final pow10 = math.pow(10.0, exp).toDouble();
  final mant = raw / pow10;
  final nice = mant <= 1.5
      ? 1.0
      : mant <= 3.5
      ? 2.0
      : mant <= 7.5
      ? 5.0
      : 10.0;
  return nice * pow10;
}
