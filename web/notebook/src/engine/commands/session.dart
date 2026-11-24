import 'package:data/symbolic.dart';

import '../../language/signature.dart';
import '../../model/value.dart';
import '../commands.dart';

final List<Command> sessionCommands = [
  Command(
    name: 'clear',
    category: CommandCategory.session,
    signature: const FunctionSignature(
      variadic: true,
      variadicType: ParamType.symbol,
    ),
    doc: 'Clears one or more bound variables, user functions, or assumptions.',
    examples: ['clear(a, b)'],
    run: (args, ctx) {
      final names = args.rest.cast<String>();
      if (names.isEmpty) {
        return const InfoValue('Specify variable or function names to clear.');
      }
      final removed = ctx.env.clearNames(names);
      return InfoValue(
        removed.isEmpty ? 'Nothing cleared.' : 'Cleared: ${removed.join(', ')}',
      );
    },
  ),
  Command(
    name: 'clearall',
    category: CommandCategory.session,
    signature: const FunctionSignature(),
    doc: 'Clears all variables, user functions, and variable assumptions.',
    examples: ['clearall()'],
    run: (_, ctx) {
      ctx.env.clear();
      return const InfoValue(
        'Cleared all variables, functions, and assumptions.',
      );
    },
  ),
  Command(
    name: 'vars',
    category: CommandCategory.session,
    signature: const FunctionSignature(),
    doc: 'Lists all bound variables, user functions, and assumptions.',
    examples: ['vars()'],
    run: (_, ctx) {
      final buf = StringBuffer();
      if (ctx.env.variables.isNotEmpty) {
        buf.writeln('Variables:');
        for (final entry in ctx.env.variables.entries) {
          buf.writeln('  ${entry.key} := ${entry.value.toCanonicalText()}');
        }
      }
      if (ctx.env.functions.isNotEmpty) {
        buf.writeln('Functions:');
        for (final fn in ctx.env.functions.values) {
          buf.writeln('  ${fn.source}');
        }
      }
      if (ctx.env.settings.variableDomains.isNotEmpty) {
        buf.writeln('Assumptions:');
        for (final entry in ctx.env.settings.variableDomains.entries) {
          buf.writeln('  ${entry.key}: ${entry.value.name}');
        }
      }
      if (buf.isEmpty) {
        return const InfoValue(
          'No variables, functions, or assumptions defined.',
        );
      }
      return InfoValue(buf.toString().trimRight(), title: 'Session State');
    },
  ),
  Command(
    name: 'assume',
    category: CommandCategory.session,
    signature: const FunctionSignature(
      positional: [
        ParamSpec.positional('var', type: ParamType.symbol),
        ParamSpec.positional(
          'domain',
          type: ParamType.string,
          enumValues: ['unknown', 'complex', 'real', 'positive', 'integer'],
        ),
      ],
    ),
    doc: 'Sets a domain assumption for a variable.',
    examples: ["assume(x, 'positive')", "assume(n, 'integer')"],
    run: (args, ctx) {
      final v = args.symbol('var');
      final domStr = args.stringVal('domain');
      final dom = parseDomainName(domStr);
      final next = Map<String, VariableDomain>.of(
        ctx.env.settings.variableDomains,
      )..[v] = dom;
      ctx.env.settings = ctx.env.settings.copyWith(variableDomains: next);
      return InfoValue('Assumed $v is $domStr.');
    },
  ),
  Command(
    name: 'help',
    category: CommandCategory.session,
    signature: const FunctionSignature(
      positional: [ParamSpec.optional('command', type: ParamType.string)],
    ),
    doc: 'Displays documentation for a command or lists all commands.',
    examples: ['help()', "help('integrate')"],
    run: (args, ctx) {
      final name = args.stringOrNull('command');
      if (name != null) {
        final cmd = ctx.registry.lookup(name);
        if (cmd == null) {
          return ErrorValue("Unknown command '$name'");
        }
        final buf = StringBuffer()
          ..writeln(cmd.signature.format(cmd.name))
          ..writeln(cmd.doc);
        if (cmd.examples.isNotEmpty) {
          buf.writeln('Examples: ${cmd.examples.join(' | ')}');
        }
        return InfoValue(buf.toString().trimRight(), title: cmd.name);
      }
      final grouped = <CommandCategory, List<String>>{};
      for (final cmd in ctx.registry.all) {
        grouped.putIfAbsent(cmd.category, () => []).add(cmd.name);
      }
      final buf = StringBuffer();
      for (final entry in grouped.entries) {
        buf.writeln('${entry.key.label}: ${entry.value.join(', ')}');
      }
      return InfoValue(buf.toString().trimRight(), title: 'Commands');
    },
  ),
];
