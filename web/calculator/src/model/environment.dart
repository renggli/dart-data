import 'package:data/symbolic.dart';

import 'value.dart';

/// Angle measurement unit for numeric evaluation and plotting.
enum AngleMode { rad, deg }

/// Display format for complex results (`a + b * i` vs `r * e^(i * theta)`).
enum ComplexDisplayMode { rect, polar }

/// Active calculator interaction mode.
enum CalcMode { scroll, rpn }

/// Immutable user-configurable calculator settings.
final class CalcSettings {
  const new({
    this.autoSimplify = true,
    this.implicitMultiplication = true,
    this.approxMode = false,
    this.digits = 10,
    this.angleMode = AngleMode.rad,
    this.complexDisplay = ComplexDisplayMode.rect,
    this.domain = VariableDomain.unknown,
    this.keypadVisible = false,
    this.haptics = true,
    this.timeoutMs = 10000,
  });

  final bool autoSimplify;
  final bool implicitMultiplication;
  final bool approxMode;
  final int digits;
  final AngleMode angleMode;
  final ComplexDisplayMode complexDisplay;
  final VariableDomain domain;
  final bool keypadVisible;
  final bool haptics;
  final int timeoutMs;

  Assumptions get assumptions => domain == VariableDomain.unknown
      ? Assumptions.none
      : Assumptions(defaultDomain: domain);

  CalcSettings copyWith({
    bool? autoSimplify,
    bool? implicitMultiplication,
    bool? approxMode,
    int? digits,
    AngleMode? angleMode,
    ComplexDisplayMode? complexDisplay,
    VariableDomain? domain,
    bool? keypadVisible,
    bool? haptics,
    int? timeoutMs,
  }) => CalcSettings(
    autoSimplify: autoSimplify ?? this.autoSimplify,
    implicitMultiplication:
        implicitMultiplication ?? this.implicitMultiplication,
    approxMode: approxMode ?? this.approxMode,
    digits: digits ?? this.digits,
    angleMode: angleMode ?? this.angleMode,
    complexDisplay: complexDisplay ?? this.complexDisplay,
    domain: domain ?? this.domain,
    keypadVisible: keypadVisible ?? this.keypadVisible,
    haptics: haptics ?? this.haptics,
    timeoutMs: timeoutMs ?? this.timeoutMs,
  );

  Map<String, Object?> toJson() => {
    'autoSimplify': autoSimplify,
    'implicitMultiplication': implicitMultiplication,
    'approxMode': approxMode,
    'digits': digits,
    'angleMode': angleMode.name,
    'complexDisplay': complexDisplay.name,
    'domain': domain.name,
    'keypadVisible': keypadVisible,
    'haptics': haptics,
    'timeoutMs': timeoutMs,
  };

  factory fromJson(Map<String, Object?> json) => CalcSettings(
    autoSimplify: json['autoSimplify'] as bool? ?? true,
    implicitMultiplication: json['implicitMultiplication'] as bool? ?? true,
    approxMode: json['approxMode'] as bool? ?? false,
    digits: ((json['digits'] as num?)?.toInt() ?? 10).clamp(4, 15),
    angleMode: AngleMode.values.firstWhere(
      (e) => e.name == json['angleMode'],
      orElse: () => AngleMode.rad,
    ),
    complexDisplay: ComplexDisplayMode.values.firstWhere(
      (e) => e.name == json['complexDisplay'],
      orElse: () => ComplexDisplayMode.rect,
    ),
    domain: VariableDomain.values.firstWhere(
      (e) => e.name == json['domain'],
      orElse: () => VariableDomain.unknown,
    ),
    keypadVisible: json['keypadVisible'] as bool? ?? false,
    haptics: json['haptics'] as bool? ?? true,
    timeoutMs: (json['timeoutMs'] as num?)?.toInt() ?? 10000,
  );
}

/// User-defined symbolic function `f(x1, x2, ...) := body`.
final class UserFunction {
  const new({
    required this.name,
    required this.params,
    required this.body,
    required this.sourceText,
  });

  final String name;
  final List<String> params;
  final Expr body;
  final String sourceText;

  String get signature => '$name(${params.join(', ')})';

  Expr apply(List<Expr> args) {
    if (args.length != params.length) {
      throw ArgumentError(
        'Function $name expects ${params.length} argument(s), got ${args.length}.',
      );
    }
    var result = body;
    for (var i = 0; i < params.length; i++) {
      result = result.substitute(params[i], Variable('\$param_$i'));
    }
    for (var i = 0; i < params.length; i++) {
      result = result.substitute('\$param_$i', args[i]);
    }
    return result;
  }

  Map<String, Object?> toJson() => {
    'name': name,
    'params': params,
    'body': body.toString(),
    'sourceText': sourceText,
  };

  factory fromJson(Map<String, Object?> json) => UserFunction(
    name: json['name']! as String,
    params: (json['params']! as List<Object?>).cast<String>(),
    body: Expr.parse(json['body']! as String),
    sourceText: json['sourceText'] as String? ?? (json['body']! as String),
  );
}

/// Shared execution environment storing assigned variables, user functions,
/// and active [CalcSettings].
final class Environment {
  new({
    Map<String, CalcValue>? variables,
    Map<String, UserFunction>? functions,
    this.settings = const CalcSettings(),
  }) : _variables = {...?variables},
       _functions = {...?functions};

  final Map<String, CalcValue> _variables;
  final Map<String, UserFunction> _functions;
  CalcSettings settings;

  Map<String, CalcValue> get variables => Map.unmodifiable(_variables);
  Map<String, UserFunction> get functions => Map.unmodifiable(_functions);

  CalcValue? getVariable(String name) => _variables[name];

  void setVariable(String name, CalcValue value) {
    _variables[name] = value;
  }

  bool removeVariable(String name) => _variables.remove(name) != null;

  UserFunction? getFunction(String name) => _functions[name];

  void setFunction(UserFunction fn) {
    _functions[fn.name] = fn;
  }

  bool removeFunction(String name) => _functions.remove(name) != null;

  bool clearSymbol(String name) {
    final removedVar = removeVariable(name);
    final removedFn = removeFunction(name);
    return removedVar || removedFn;
  }

  void clearAll() {
    _variables.clear();
    _functions.clear();
  }

  Environment clone() => Environment(
    variables: _variables,
    functions: _functions,
    settings: settings,
  );
}
