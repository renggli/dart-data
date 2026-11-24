import 'package:data/symbolic.dart';

import '../language/ast.dart';
import '../language/grammar.dart';
import '../language/signature.dart';
import 'serialization.dart';
import 'value.dart';

/// How complex numbers are formatted in the notebook.
enum ComplexDisplayMode { rectangular, polar }

/// Persistent notebook evaluation and display settings.
final class NotebookSettings {
  const new({
    this.autoSimplify = true,
    this.implicitMultiplication = true,
    this.approxMode = false,
    this.digits = 10,
    this.complexDisplay = ComplexDisplayMode.rectangular,
    this.domain = VariableDomain.complex,
    this.variableDomains = const {},
    this.theme = 'light',
    this.timeoutMs = 5000,
  });

  factory fromJson(Map<String, Object?> json) {
    final rawDomains =
        json['variableDomains'] as Map<String, Object?>? ?? const {};
    return NotebookSettings(
      autoSimplify: json['autoSimplify'] as bool? ?? true,
      implicitMultiplication: json['implicitMultiplication'] as bool? ?? true,
      approxMode: json['approxMode'] as bool? ?? false,
      digits: (json['digits'] as num?)?.toInt() ?? 10,
      complexDisplay: ComplexDisplayMode.values.firstWhere(
        (m) => m.name == json['complexDisplay'],
        orElse: () => ComplexDisplayMode.rectangular,
      ),
      domain: VariableDomain.values.firstWhere(
        (d) => d.name == json['domain'],
        orElse: () => VariableDomain.complex,
      ),
      variableDomains: {
        for (final entry in rawDomains.entries)
          entry.key: VariableDomain.values.firstWhere(
            (d) => d.name == entry.value,
            orElse: () => VariableDomain.complex,
          ),
      },
      theme: json['theme'] as String? ?? 'light',
      timeoutMs: (json['timeoutMs'] as num?)?.toInt() ?? 5000,
    );
  }

  final bool autoSimplify;
  final bool implicitMultiplication;
  final bool approxMode;
  final int digits;
  final ComplexDisplayMode complexDisplay;
  final VariableDomain domain;
  final Map<String, VariableDomain> variableDomains;
  final String theme;
  final int timeoutMs;

  Assumptions toAssumptions() =>
      Assumptions(domains: variableDomains, defaultDomain: domain);

  NotebookSettings copyWith({
    bool? autoSimplify,
    bool? implicitMultiplication,
    bool? approxMode,
    int? digits,
    ComplexDisplayMode? complexDisplay,
    VariableDomain? domain,
    Map<String, VariableDomain>? variableDomains,
    String? theme,
    int? timeoutMs,
  }) => NotebookSettings(
    autoSimplify: autoSimplify ?? this.autoSimplify,
    implicitMultiplication:
        implicitMultiplication ?? this.implicitMultiplication,
    approxMode: approxMode ?? this.approxMode,
    digits: digits ?? this.digits,
    complexDisplay: complexDisplay ?? this.complexDisplay,
    domain: domain ?? this.domain,
    variableDomains: variableDomains ?? this.variableDomains,
    theme: theme ?? this.theme,
    timeoutMs: timeoutMs ?? this.timeoutMs,
  );

  Map<String, Object?> toJson() => {
    'autoSimplify': autoSimplify,
    'implicitMultiplication': implicitMultiplication,
    'approxMode': approxMode,
    'digits': digits,
    'complexDisplay': complexDisplay.name,
    'domain': domain.name,
    'variableDomains': {
      for (final entry in variableDomains.entries) entry.key: entry.value.name,
    },
    'theme': theme,
    'timeoutMs': timeoutMs,
  };
}

/// User-defined function with optional positional and named parameters.
final class UserFunction {
  const new({
    required this.name,
    required this.params,
    required this.body,
    required this.source,
  });

  factory fromJson(Map<String, Object?> json) {
    final source = json['source']! as String;
    final stmt = CalcGrammar().parse(source) as FunctionDefStatement;
    return UserFunction(
      name: stmt.name,
      params: stmt.params,
      body: stmt.body,
      source: source,
    );
  }

  final String name;
  final List<ParamDef> params;
  final CalcNode body;
  final String source;

  /// Builds a [FunctionSignature] for [ArgumentBinder] and autocomplete hints.
  FunctionSignature toSignature(CalcValue Function(CalcNode node) evalDefault) {
    final positional = <ParamSpec>[];
    final named = <ParamSpec>[];
    for (final p in params) {
      final defVal = p.defaultExpr == null ? null : evalDefault(p.defaultExpr!);
      if (p.isNamed) {
        named.add(
          ParamSpec.named(
            p.name,
            type: ParamType.any,
            required: defVal == null,
            defaultValue: defVal,
          ),
        );
      } else if (p.isOptionalPositional) {
        positional.add(
          ParamSpec.optional(p.name, type: ParamType.any, defaultValue: defVal),
        );
      } else {
        positional.add(ParamSpec.positional(p.name, type: ParamType.any));
      }
    }
    return FunctionSignature(positional: positional, named: named);
  }

  String formatSignature() => '$name(${params.join(', ')})';

  Map<String, Object?> toJson() => {'name': name, 'source': source};
}

/// Mutable evaluation environment holding bound variables, user functions, and
/// [NotebookSettings].
final class Environment {
  new({
    Map<String, CalcValue>? variables,
    Map<String, UserFunction>? functions,
    NotebookSettings? settings,
  }) : variables = variables ?? {},
       functions = functions ?? {},
       settings = settings ?? const NotebookSettings();

  factory fromJson(Map<String, Object?> json) {
    final rawVars = json['variables'] as Map<String, Object?>? ?? const {};
    final rawFuncs = json['functions'] as Map<String, Object?>? ?? const {};
    final rawSettings = json['settings'] as Map<String, Object?>?;
    return Environment(
      variables: {
        for (final entry in rawVars.entries)
          entry.key: valueFromJson(entry.value! as Map<String, Object?>),
      },
      functions: {
        for (final entry in rawFuncs.entries)
          entry.key: UserFunction.fromJson(
            entry.value! as Map<String, Object?>,
          ),
      },
      settings: rawSettings == null
          ? const NotebookSettings()
          : NotebookSettings.fromJson(rawSettings),
    );
  }

  final Map<String, CalcValue> variables;
  final Map<String, UserFunction> functions;
  NotebookSettings settings;

  void clear() {
    variables.clear();
    functions.clear();
    settings = settings.copyWith(variableDomains: const {});
  }

  List<String> clearNames(Iterable<String> names) {
    final removed = <String>[];
    final nextDomains = Map<String, VariableDomain>.of(
      settings.variableDomains,
    );
    for (final name in names) {
      var hit = false;
      if (variables.remove(name) != null) hit = true;
      if (functions.remove(name) != null) hit = true;
      if (nextDomains.remove(name) != null) hit = true;
      if (hit) removed.add(name);
    }
    settings = settings.copyWith(variableDomains: nextDomains);
    return removed;
  }

  Environment clone() => Environment(
    variables: Map<String, CalcValue>.of(variables),
    functions: Map<String, UserFunction>.of(functions),
    settings: settings,
  );

  Map<String, Object?> toJson() => {
    'variables': {
      for (final entry in variables.entries)
        entry.key: valueToJson(entry.value),
    },
    'functions': {
      for (final entry in functions.entries) entry.key: entry.value.toJson(),
    },
    'settings': settings.toJson(),
  };
}
