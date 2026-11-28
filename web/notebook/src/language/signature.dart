import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/symbolic.dart';

import '../model/value.dart';
import 'ast.dart';

/// Expected parameter type for declarative command & function binding.
enum ParamType {
  any,
  expr,
  symbol,
  equation,
  number,
  integer,
  string,
  boolean,
  range,
  vector,
  matrix,
  exprList,
  symbolList,
  rangeList,
}

/// Specification of a single positional or named parameter.
final class ParamSpec {
  const new positional(
    this.name, {
    this.type = ParamType.expr,
    this.enumValues,
    this.doc = '',
  }) : isPositional = true,
       isRequired = true,
       defaultValue = null;

  const new optional(
    this.name, {
    this.type = ParamType.expr,
    this.defaultValue,
    this.doc = '',
  }) : isPositional = true,
       isRequired = false,
       enumValues = null;

  const new named(
    this.name, {
    this.type = ParamType.any,
    bool required = false,
    this.defaultValue,
    this.enumValues,
    this.doc = '',
  }) : isPositional = false,
       isRequired = required;

  final String name;
  final ParamType type;
  final bool isPositional;
  final bool isRequired;
  final Object? defaultValue;
  final List<String>? enumValues;
  final String doc;
}

/// Declarative signature for a command or function.
final class FunctionSignature {
  const new({
    this.positional = const [],
    this.named = const [],
    this.variadic = false,
    this.variadicType = ParamType.any,
  });

  final List<ParamSpec> positional;
  final List<ParamSpec> named;
  final bool variadic;
  final ParamType variadicType;

  /// Formats a human-readable signature string such as
  /// `plot(expr, [var], {from: -5, to: 5})`.
  String format(String name) {
    final parts = <String>[];
    for (final p in positional) {
      parts.add(p.isRequired ? p.name : '[${p.name}]');
    }
    if (variadic) {
      parts.add('...');
    }
    if (named.isNotEmpty) {
      final namedParts = [
        for (final n in named)
          if (n.defaultValue != null)
            '${n.name}: ${_formatDefault(n.defaultValue!)}'
          else
            n.name,
      ];
      parts.add('{${namedParts.join(', ')}}');
    }
    return '$name(${parts.join(', ')})';
  }

  static String _formatDefault(Object value) {
    if (value is NumericRange) {
      return value.toString();
    }
    if (value is double &&
        value.isFinite &&
        value == value.truncateToDouble()) {
      return value.toInt().toString();
    }
    return value.toString();
  }
}

/// Error thrown when arguments fail signature validation.
final class ArgumentBindingException implements Exception {
  const new(this.message, {this.offset, this.suggestion});

  final String message;
  final int? offset;
  final String? suggestion;

  @override
  String toString() => 'ArgumentBindingException: $message';
}

/// Typed view over bound positional, named, and variadic arguments.
final class BoundArgs {
  const new(this._values, this.rest);

  final Map<String, Object?> _values;
  final List<Object?> rest;

  bool has(String name) => _values[name] != null;

  Object? raw(String name) => _values[name];

  Expr expr(String name) {
    final v = _values[name];
    if (v is Expr) return v;
    if (v is ExprValue) return v.expr;
    throw ArgumentBindingException("Expected expression for '$name'");
  }

  Expr? exprOrNull(String name) {
    final v = _values[name];
    if (v == null) return null;
    if (v is Expr) return v;
    if (v is ExprValue) return v.expr;
    throw ArgumentBindingException("Expected expression for '$name'");
  }

  String symbol(String name) {
    final v = _values[name];
    if (v is String) return v;
    throw ArgumentBindingException("Expected symbol name for '$name'");
  }

  String? symbolOrNull(String name) {
    final v = _values[name];
    if (v == null) return null;
    if (v is String) return v;
    throw ArgumentBindingException("Expected symbol name for '$name'");
  }

  double doubleVal(String name) {
    final v = _values[name];
    if (v is double) return v;
    if (v is int) return v.toDouble();
    throw ArgumentBindingException("Expected number for '$name'");
  }

  double? doubleOrNull(String name) {
    final v = _values[name];
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    throw ArgumentBindingException("Expected number for '$name'");
  }

  int intVal(String name) {
    final v = _values[name];
    if (v is int) return v;
    if (v is double && v % 1 == 0) return v.toInt();
    throw ArgumentBindingException("Expected integer for '$name'");
  }

  int? intOrNull(String name) {
    final v = _values[name];
    if (v == null) return null;
    if (v is int) return v;
    if (v is double && v % 1 == 0) return v.toInt();
    throw ArgumentBindingException("Expected integer for '$name'");
  }

  String stringVal(String name) {
    final v = _values[name];
    if (v is String) return v;
    throw ArgumentBindingException("Expected string for '$name'");
  }

  String? stringOrNull(String name) {
    final v = _values[name];
    if (v == null) return null;
    if (v is String) return v;
    throw ArgumentBindingException("Expected string for '$name'");
  }

  bool boolVal(String name, {bool fallback = false}) {
    final v = _values[name];
    if (v == null) return fallback;
    if (v is bool) return v;
    throw ArgumentBindingException("Expected boolean for '$name'");
  }

  Matrix<Expr> matrix(String name) {
    final v = _values[name];
    if (v is Matrix<Expr>) return v;
    if (v is MatrixValue) return v.matrix;
    throw ArgumentBindingException("Expected matrix for '$name'");
  }

  Vector<Expr> vector(String name) {
    final v = _values[name];
    if (v is Vector<Expr>) return v;
    if (v is VectorValue) return v.vector;
    throw ArgumentBindingException("Expected vector for '$name'");
  }

  List<Expr> exprList(String name) {
    final v = _values[name];
    if (v is List<Expr>) return v;
    throw ArgumentBindingException("Expected list of expressions for '$name'");
  }

  List<String> symbolList(String name) {
    final v = _values[name];
    if (v is List<String>) return v;
    throw ArgumentBindingException("Expected list of symbols for '$name'");
  }

  RangeValue range(String name) {
    final r = rangeOrNull(name);
    if (r == null) {
      throw ArgumentBindingException("Expected range for '$name'");
    }
    return r;
  }

  RangeValue? rangeOrNull(String name) {
    final v = _values[name];
    if (v == null) return null;
    if (v is RangeValue) return v;
    if (v is NumericRange) {
      return RangeValue(
        RealNumber.fromDouble(v.start),
        RealNumber.fromDouble(v.end),
      );
    }
    throw ArgumentBindingException("Expected range for '$name'");
  }

  ({double start, double end}) numericRange(
    String name, {
    bool allowInfinite = false,
    bool requireOrdered = true,
  }) {
    final bounds = numericRangeOrNull(
      name,
      allowInfinite: allowInfinite,
      requireOrdered: requireOrdered,
    );
    if (bounds == null) {
      throw ArgumentBindingException("Expected numeric range for '$name'");
    }
    return bounds;
  }

  ({double start, double end})? numericRangeOrNull(
    String name, {
    bool allowInfinite = false,
    bool requireOrdered = true,
  }) {
    final v = _values[name];
    if (v == null) return null;
    final ({double start, double end}) bounds;
    if (v is NumericRange) {
      if (!allowInfinite && (!v.start.isFinite || !v.end.isFinite)) {
        throw ArgumentBindingException(
          "Range endpoints for '$name' must be finite",
        );
      }
      bounds = (start: v.start, end: v.end);
    } else if (v is RangeValue) {
      final converted = v.toNumericBounds(allowInfinite: allowInfinite);
      if (converted == null) {
        throw ArgumentBindingException(
          "Range endpoints for '$name' must be real numbers",
        );
      }
      bounds = converted;
    } else {
      throw ArgumentBindingException("Expected numeric range for '$name'");
    }
    if (requireOrdered && bounds.start >= bounds.end) {
      throw ArgumentBindingException(
        "Range '$name' must have start < end (got ${PlotValue.fmtBound(bounds.start)}..${PlotValue.fmtBound(bounds.end)})",
      );
    }
    return bounds;
  }

  List<RangeValue> rangeList(String name) {
    final v = _values[name];
    if (v is List<RangeValue>) return v;
    throw ArgumentBindingException("Expected list of ranges for '$name'");
  }

  List<RangeValue>? rangeListOrNull(String name) {
    final v = _values[name];
    if (v == null) return null;
    if (v is List<RangeValue>) return v;
    throw ArgumentBindingException("Expected list of ranges for '$name'");
  }
}

/// Callback used by [ArgumentBinder] to evaluate an argument AST node.
typedef NodeEvaluator = CalcValue Function(
  CalcNode node, {
  Set<String> boundSymbols,
});

/// Binds raw [CallNode] positional & named arguments against a
/// [FunctionSignature].
final class ArgumentBinder {
  const new _();

  static BoundArgs bind(
    String callName,
    FunctionSignature sig,
    List<CalcNode> positionalArgs,
    List<NamedArg> namedArgs,
    NodeEvaluator eval, {
    int? callOffset,
  }) {
    final minPos = sig.positional.where((p) => p.isRequired).length;
    final maxPos = sig.positional.length;

    if (positionalArgs.length < minPos) {
      throw ArgumentBindingException(
        '$callName expects at least $minPos positional argument(s), '
        'got ${positionalArgs.length}. Signature: ${sig.format(callName)}',
        offset: callOffset,
      );
    }
    if (!sig.variadic && positionalArgs.length > maxPos) {
      throw ArgumentBindingException(
        '$callName expects at most $maxPos positional argument(s), '
        'got ${positionalArgs.length}. Signature: ${sig.format(callName)}',
        offset: positionalArgs[maxPos].offset,
      );
    }

    // Collect symbol names from positional symbol/symbolList arguments so
    // earlier `expr` args can treat them as free variables (e.g. diff(x^2, x)).
    final scopedSymbols = <String>{};
    for (
      var i = 0;
      i < positionalArgs.length && i < sig.positional.length;
      i++
    ) {
      final spec = sig.positional[i];
      final node = positionalArgs[i];
      if (spec.type == ParamType.symbol && node is SymbolNode) {
        scopedSymbols.add(node.name);
      } else if (spec.type == ParamType.symbolList &&
          node is VectorLiteralNode) {
        for (final el in node.elements) {
          if (el is SymbolNode) scopedSymbols.add(el.name);
        }
      }
    }

    final bound = <String, Object?>{};
    final rest = <Object?>[];

    for (var i = 0; i < positionalArgs.length; i++) {
      final node = positionalArgs[i];
      if (i < sig.positional.length) {
        final spec = sig.positional[i];
        bound[spec.name] = _convertArg(
          spec.name,
          spec.type,
          node,
          eval,
          scopedSymbols,
          enumValues: spec.enumValues,
        );
      } else {
        rest.add(
          _convertArg(
            'arg${i + 1}',
            sig.variadicType,
            node,
            eval,
            scopedSymbols,
          ),
        );
      }
    }

    // Fill omitted optional positional defaults
    for (var i = positionalArgs.length; i < sig.positional.length; i++) {
      final spec = sig.positional[i];
      bound[spec.name] = spec.defaultValue;
    }

    // Bind named arguments
    final namedMap = {for (final n in sig.named) n.name: n};
    for (final arg in namedArgs) {
      final spec = namedMap[arg.name];
      if (spec == null) {
        final suggestion = _closestMatch(arg.name, namedMap.keys);
        final hint = suggestion != null ? " Did you mean '$suggestion'?" : '';
        throw ArgumentBindingException(
          "Unknown named argument '${arg.name}' for $callName.$hint",
          offset: arg.offset,
          suggestion: suggestion,
        );
      }
      bound[spec.name] = _convertArg(
        spec.name,
        spec.type,
        arg.value,
        eval,
        scopedSymbols,
        enumValues: spec.enumValues,
      );
    }

    // Check required named args and fill defaults
    for (final spec in sig.named) {
      if (!bound.containsKey(spec.name)) {
        if (spec.isRequired) {
          throw ArgumentBindingException(
            "Missing required named argument '${spec.name}' for $callName",
            offset: callOffset,
          );
        }
        bound[spec.name] = spec.defaultValue;
      }
    }

    return BoundArgs(bound, rest);
  }

  static Object? _convertArg(
    String name,
    ParamType type,
    CalcNode node,
    NodeEvaluator eval,
    Set<String> scopedSymbols, {
    List<String>? enumValues,
  }) {
    switch (type) {
      case ParamType.symbol:
        if (node is SymbolNode) return node.name;
        if (node is ExprLeafNode && node.expr is Variable) {
          return (node.expr as Variable).name;
        }
        // Allow constants like `e` or `i` if used as dummy variable
        if (node is ExprLeafNode) {
          if (node.expr == Constant.e) return 'e';
          if (node.expr == ComplexNumber.i) return 'i';
        }
        throw ArgumentBindingException(
          "Argument '$name' must be a variable symbol",
          offset: node.offset,
        );

      case ParamType.symbolList:
        if (node is SymbolNode) return <String>[node.name];
        if (node is VectorLiteralNode) {
          return [
            for (final el in node.elements)
              if (el is SymbolNode)
                el.name
              else
                throw ArgumentBindingException(
                  "All elements of '$name' must be variable symbols",
                  offset: el.offset,
                ),
          ];
        }
        throw ArgumentBindingException(
          "Argument '$name' must be a symbol or list of symbols",
          offset: node.offset,
        );

      case ParamType.equation:
        // Keep equation LHS/RHS evaluated with scoped symbols
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is ExprValue) return val.expr;
        throw ArgumentBindingException(
          "Argument '$name' must be an equation or expression",
          offset: node.offset,
        );

      case ParamType.expr:
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is ExprValue) return val.expr;
        if (val is SeriesValue) return val.exprWithOrder;
        throw ArgumentBindingException(
          "Argument '$name' must be a symbolic expression (got ${val.kind})",
          offset: node.offset,
        );

      case ParamType.exprList:
        if (node is VectorLiteralNode) {
          final out = <Expr>[];
          for (final el in node.elements) {
            final val = eval(el, boundSymbols: scopedSymbols);
            if (val is ExprValue) {
              out.add(val.expr);
            } else {
              throw ArgumentBindingException(
                "All elements of '$name' must be expressions",
                offset: el.offset,
              );
            }
          }
          return out;
        }
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is ExprValue) return <Expr>[val.expr];
        if (val is VectorValue) {
          return [
            for (var i = 0; i < val.vector.length; i++)
              val.vector.getUnchecked(i),
          ];
        }
        if (val is ListValue) {
          return [
            for (final el in val.elements)
              if (el is ExprValue)
                el.expr
              else
                throw ArgumentBindingException(
                  "All elements of '$name' must be expressions",
                  offset: node.offset,
                ),
          ];
        }
        throw ArgumentBindingException(
          "Argument '$name' must be an expression or list of expressions",
          offset: node.offset,
        );

      case ParamType.number:
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is ExprValue) {
          final approx = val.expr.approximate();
          if (approx is RealNumber && approx.value.isFinite) {
            return approx.value;
          }
          if (approx is IntegerNumber) return approx.value.toDouble();
          if (approx is FractionNumber) {
            return approx.numerator.toDouble() / approx.denominator.toDouble();
          }
          if (approx == Constant.infinity) return double.infinity;
          if (approx == -Constant.infinity) return double.negativeInfinity;
        }
        throw ArgumentBindingException(
          "Argument '$name' must evaluate to a real number",
          offset: node.offset,
        );

      case ParamType.integer:
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is ExprValue) {
          if (val.expr case IntegerNumber(:final asInt?)) return asInt;
        }
        throw ArgumentBindingException(
          "Argument '$name' must be an integer",
          offset: node.offset,
        );

      case ParamType.string:
        final val = eval(node, boundSymbols: scopedSymbols);
        final String s;
        if (val is StringValue) {
          s = val.value;
        } else if (node is SymbolNode) {
          s = node.name;
        } else {
          throw ArgumentBindingException(
            "Argument '$name' must be a string",
            offset: node.offset,
          );
        }
        if (enumValues != null && !enumValues.contains(s)) {
          final suggestion = _closestMatch(s, enumValues);
          final hint = suggestion != null ? " Did you mean '$suggestion'?" : '';
          throw ArgumentBindingException(
            "Invalid value '$s' for '$name'. Expected one of: ${enumValues.join(', ')}.$hint",
            offset: node.offset,
            suggestion: suggestion,
          );
        }
        return s;

      case ParamType.boolean:
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is BoolValue) return val.value;
        throw ArgumentBindingException(
          "Argument '$name' must be a boolean (true or false)",
          offset: node.offset,
        );

      case ParamType.vector:
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is VectorValue) return val.vector;
        throw ArgumentBindingException(
          "Argument '$name' must be a vector",
          offset: node.offset,
        );

      case ParamType.matrix:
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is MatrixValue) return val.matrix;
        throw ArgumentBindingException(
          "Argument '$name' must be a matrix",
          offset: node.offset,
        );

      case ParamType.range:
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is RangeValue) return val;
        throw ArgumentBindingException(
          "Argument '$name' must be a range (e.g. -2..2)",
          offset: node.offset,
        );

      case ParamType.rangeList:
        if (node is VectorLiteralNode) {
          final out = <RangeValue>[];
          for (final el in node.elements) {
            final val = eval(el, boundSymbols: scopedSymbols);
            if (val is RangeValue) {
              out.add(val);
            } else {
              throw ArgumentBindingException(
                "All elements of '$name' must be ranges (e.g. 0..1)",
                offset: el.offset,
              );
            }
          }
          return out;
        }
        final val = eval(node, boundSymbols: scopedSymbols);
        if (val is RangeValue) return <RangeValue>[val];
        if (val is ListValue) {
          return [
            for (final el in val.elements)
              if (el is RangeValue)
                el
              else
                throw ArgumentBindingException(
                  "All elements of '$name' must be ranges (e.g. 0..1)",
                  offset: node.offset,
                ),
          ];
        }
        throw ArgumentBindingException(
          "Argument '$name' must be a range or list of ranges",
          offset: node.offset,
        );

      case ParamType.any:
        return eval(node, boundSymbols: scopedSymbols);
    }
  }

  static String? _closestMatch(String input, Iterable<String> candidates) {
    String? best;
    var bestDist = 3; // Max edit distance threshold
    for (final c in candidates) {
      final d = _levenshtein(input.toLowerCase(), c.toLowerCase());
      if (d < bestDist) {
        bestDist = d;
        best = c;
      }
    }
    return best;
  }

  static int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    var prev = List<int>.generate(b.length + 1, (j) => j);
    var curr = List<int>.filled(b.length + 1, 0);
    for (var i = 0; i < a.length; i++) {
      curr[0] = i + 1;
      for (var j = 0; j < b.length; j++) {
        final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
        curr[j + 1] = math.min(
          math.min(curr[j] + 1, prev[j + 1] + 1),
          prev[j] + cost,
        );
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[b.length];
  }
}
