import 'package:data/symbolic.dart';

import '../language/signature.dart';
import '../model/environment.dart';
import '../model/value.dart';
import 'commands/algebra.dart';
import 'commands/calculus.dart';
import 'commands/complex.dart';
import 'commands/interactive.dart';
import 'commands/linear.dart';
import 'commands/numbers.dart';
import 'commands/numeric.dart';
import 'commands/plot.dart';
import 'commands/session.dart';

/// Category of a notebook command for grouping in help and autocomplete.
enum CommandCategory {
  algebra('Algebra'),
  calculus('Calculus'),
  plot('Plotting'),
  interactive('Interactive'),
  numeric('Numeric'),
  linear('Linear Algebra'),
  complex('Complex'),
  numbers('Numbers'),
  session('Session');

  new(this.label);

  final String label;
}

/// Execution context passed to every command handler.
abstract interface class EvaluatorContext {
  Environment get env;
  Assumptions get assumptions;
  CommandRegistry get registry;
}

/// Declarative definition of a notebook command.
final class Command {
  const new({
    required this.name,
    required this.category,
    required this.signature,
    required this.doc,
    required this.run,
    this.aliases = const [],
    this.examples = const [],
    this.preserveForm = false,
    this.chipLabel,
    this.appliesTo,
    this.buildChipCall,
  });

  final String name;
  final CommandCategory category;
  final FunctionSignature signature;
  final String doc;
  final CalcValue Function(BoundArgs args, EvaluatorContext ctx) run;
  final List<String> aliases;
  final List<String> examples;
  final bool preserveForm;
  final String? chipLabel;
  final bool Function(CalcValue value)? appliesTo;
  final String Function(String input, CalcValue value)? buildChipCall;
}

/// Registry of all built-in notebook commands.
final class CommandRegistry {
  new() {
    for (final cmd in [
      ...algebraCommands,
      ...calculusCommands,
      ...plotCommands,
      ...interactiveCommands,
      ...numericCommands,
      ...linearCommands,
      ...complexCommands,
      ...numbersCommands,
      ...sessionCommands,
    ]) {
      _byName[cmd.name] = cmd;
      _canonical.add(cmd);
      for (final alias in cmd.aliases) {
        _byName[alias] = cmd;
      }
    }
  }

  final Map<String, Command> _byName = {};
  final List<Command> _canonical = [];

  List<Command> get all => List.unmodifiable(_canonical);

  Set<String> get allNames => Set.unmodifiable(_byName.keys);

  Command? lookup(String name) => _byName[name];
}

/// Helper to infer the primary free variable of [expr], defaulting to `'x'`.
String inferVariable(Expr expr, [String? explicit]) {
  if (explicit != null) return explicit;
  final vars = expr.freeVariables;
  if (vars.isEmpty) return 'x';
  if (vars.contains('x')) return 'x';
  if (vars.contains('t')) return 't';
  if (vars.contains('z')) return 'z';
  final sorted = vars.toList()..sort();
  return sorted.first;
}

/// Parses a [VariableDomain] string for `assume` and `domain:` options.
VariableDomain parseDomainName(String name) => switch (name.toLowerCase()) {
  'unknown' => VariableDomain.unknown,
  'complex' => VariableDomain.complex,
  'real' => VariableDomain.real,
  'positive' => VariableDomain.positive,
  'integer' => VariableDomain.integer,
  _ => throw ArgumentBindingException(
    "Unknown domain '$name'. Expected: unknown, complex, real, positive, integer",
  ),
};
