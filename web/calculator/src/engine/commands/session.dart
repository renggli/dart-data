import '../../model/value.dart';
import '../commands.dart';

/// Builds canonical session management commands (`clear`, `clearall`, `vars`,
/// `help`).
List<Command> buildSessionCommands() => [
  Command(
    name: 'clear',
    category: CommandCategory.session,
    signature: 'clear(name, ...)',
    paramSpecs: const [ParamSpec.symbol('name')],
    minArity: 1,
    maxArity: 16,
    doc: 'Unbinds one or more assigned variables or user functions.',
    examples: const ['clear(a)', 'clear(f)'],
    rpnLabel: 'Delete',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'Clear',
    buildChipCall: (id, _) => 'clear(a)',
    run: (args, ctx) {
      checkCommandArity('clear', args, 1, 16);
      final cleared = <String>[];
      for (final arg in args) {
        final name = expectCommandVarName(arg, 'clear');
        ctx.environment.clearSymbol(name);
        cleared.add(name);
        ctx.session.markDependentsStale(changedSymbols: {name});
      }
      return InfoValue('Cleared: ${cleared.join(', ')}');
    },
  ),
  Command(
    name: 'clearall',
    category: CommandCategory.session,
    signature: 'clearall()',
    paramSpecs: const [],
    minArity: 0,
    maxArity: 0,
    doc: 'Unbinds all user variables and functions.',
    examples: const ['clearall()'],
    rpnLabel: 'ClearAll',
    rpnArity: 0,
    appliesTo: (_) => false,
    chipLabel: 'Clear All',
    buildChipCall: (_, _) => 'clearall()',
    run: (args, ctx) {
      final names = {
        ...ctx.environment.variables.keys,
        ...ctx.environment.functions.keys,
      };
      ctx.environment.clearAll();
      if (names.isNotEmpty) {
        ctx.session.markDependentsStale(changedSymbols: names);
      }
      return const InfoValue('All variables and functions cleared.');
    },
  ),
  Command(
    name: 'vars',
    category: CommandCategory.session,
    signature: 'vars()',
    paramSpecs: const [],
    minArity: 0,
    maxArity: 0,
    doc: 'Lists all currently assigned variables and user functions.',
    examples: const ['vars()'],
    rpnLabel: 'Vars',
    rpnArity: 0,
    appliesTo: (_) => false,
    chipLabel: 'Vars',
    buildChipCall: (_, _) => 'vars()',
    run: (args, ctx) {
      final vars = ctx.environment.variables;
      final fns = ctx.environment.functions;
      if (vars.isEmpty && fns.isEmpty) {
        return const InfoValue('No variables or functions defined.');
      }
      final parts = <String>[
        for (final e in vars.entries)
          '${e.key} := ${e.value.toCanonicalText()}',
        for (final f in fns.values) '${f.signature} := ${f.body}',
      ];
      return InfoValue(parts.join('; '), title: 'Environment');
    },
  ),
  Command(
    name: 'help',
    category: CommandCategory.session,
    signature: 'help([command])',
    paramSpecs: const [ParamSpec.symbol('[command]')],
    minArity: 0,
    maxArity: 1,
    doc: 'Displays signature, documentation, and examples for a command.',
    examples: const ['help(integrate)', 'help(solve)'],
    rpnLabel: 'Help',
    rpnArity: 1,
    appliesTo: (_) => false,
    chipLabel: 'Help',
    buildChipCall: (_, _) => 'help()',
    run: (args, ctx) {
      if (args.isEmpty) {
        final names = CommandRegistry.all.map((c) => c.name).join(', ');
        return InfoValue('Available commands: $names', title: 'Help');
      }
      final name = expectCommandVarName(args[0], 'help').toLowerCase();
      final cmd = CommandRegistry.byName[name];
      if (cmd == null) {
        return InfoValue(
          'Unknown command "$name". Type help() to list all commands.',
        );
      }
      final ex = cmd.examples.isNotEmpty
          ? ' | Examples: ${cmd.examples.join(' ; ')}'
          : '';
      return InfoValue('${cmd.signature} — ${cmd.doc}$ex', title: cmd.name);
    },
  ),
];
