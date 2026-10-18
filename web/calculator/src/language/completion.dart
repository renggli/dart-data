import 'package:data/symbolic.dart';

import '../engine/commands.dart';
import '../model/environment.dart';
import '../model/session.dart';

/// A single completion candidate surfaced in the input bar autocomplete popup.
final class CompletionItem {
  const new({
    required this.label,
    required this.insertText,
    required this.kind,
    required this.detail,
    this.doc,
  });

  /// Display name (`integrate`, `sin`, `r[1]`, `a`).
  final String label;

  /// Text inserted when `Tab` or click accepts the completion.
  final String insertText;

  /// Kind badge (`cmd`, `fn`, `const`, `var`, `res`).
  final String kind;

  /// Short signature or value preview.
  final String detail;

  /// Optional one-line documentation.
  final String? doc;
}

/// Active function/command call signature hint at the current caret position.
final class SignatureHint {
  const new({
    required this.name,
    required this.params,
    required this.activeParamIndex,
    required this.doc,
  });

  final String name;
  final List<String> params;
  final int activeParamIndex;
  final String doc;
}

/// Combined autocomplete result for a given input string and cursor offset.
final class CompletionResult {
  const new({
    required this.prefix,
    required this.replaceStart,
    required this.replaceEnd,
    required this.items,
    this.signatureHint,
  });

  final String prefix;
  final int replaceStart;
  final int replaceEnd;
  final List<CompletionItem> items;
  final SignatureHint? signatureHint;
}

/// Computes prefix completions and active-argument signature hints for the
/// calculator input bar.
abstract final class CalcCompletion {
  static const Map<String, ({List<String> params, String doc})>
  _mathFunctions = {
    'sin': (params: ['x'], doc: 'Sine of x (radians).'),
    'cos': (params: ['x'], doc: 'Cosine of x (radians).'),
    'tan': (params: ['x'], doc: 'Tangent of x (radians).'),
    'sec': (params: ['x'], doc: 'Secant 1 / cos(x).'),
    'csc': (params: ['x'], doc: 'Cosecant 1 / sin(x).'),
    'cot': (params: ['x'], doc: 'Cotangent cos(x) / sin(x).'),
    'asin': (params: ['x'], doc: 'Inverse sine arcsin(x).'),
    'acos': (params: ['x'], doc: 'Inverse cosine arccos(x).'),
    'atan': (params: ['x'], doc: 'Inverse tangent arctan(x).'),
    'sinh': (params: ['x'], doc: 'Hyperbolic sine sinh(x).'),
    'cosh': (params: ['x'], doc: 'Hyperbolic cosine cosh(x).'),
    'tanh': (params: ['x'], doc: 'Hyperbolic tangent tanh(x).'),
    'asinh': (params: ['x'], doc: 'Inverse hyperbolic sine.'),
    'acosh': (params: ['x'], doc: 'Inverse hyperbolic cosine.'),
    'atanh': (params: ['x'], doc: 'Inverse hyperbolic tangent.'),
    'sqrt': (params: ['x'], doc: 'Principal square root √x.'),
    'root': (params: ['x', 'n'], doc: 'Real/principal n-th root x^(1/n).'),
    'exp': (params: ['x'], doc: 'Natural exponential e^x.'),
    'ln': (params: ['x'], doc: 'Natural logarithm ln(x).'),
    'log': (
      params: ['b', 'x'],
      doc: 'Logarithm base b of x (or ln(x) for 1 arg).',
    ),
    'log2': (params: ['x'], doc: 'Base-2 logarithm log₂(x).'),
    'log10': (params: ['x'], doc: 'Base-10 logarithm log₁₀(x).'),
    'erf': (params: ['x'], doc: 'Gauss error function erf(x).'),
    'erfc': (params: ['x'], doc: 'Complementary error function 1 - erf(x).'),
    'gamma': (params: ['z'], doc: 'Euler Gamma function Γ(z).'),
    'beta': (params: ['a', 'b'], doc: 'Euler Beta function B(a, b).'),
    'lambertw': (params: ['z', '[branch]'], doc: 'Lambert W function W_k(z).'),
    'piecewise': (
      params: ['cond1', 'expr1', '[otherwise]'],
      doc: 'Piecewise conditional expression.',
    ),
  };

  /// Computes completions and signature hints at [cursorOffset] in [input].
  static CompletionResult complete(
    String input,
    int cursorOffset, {
    required Environment environment,
    required Session session,
    int maxItems = 8,
  }) {
    final safeCursor = cursorOffset.clamp(0, input.length);
    final sigHint = _findSignatureHint(input, safeCursor, environment);

    // Check if typing a result reference r[...
    final before = input.substring(0, safeCursor);
    if (before.endsWith('r[')) {
      final cells = session.activeCells.reversed.take(maxItems);
      return CompletionResult(
        prefix: 'r[',
        replaceStart: safeCursor - 2,
        replaceEnd: safeCursor,
        items: [
          for (final cell in cells)
            CompletionItem(
              label: 'r[${cell.id}]',
              insertText: 'r[${cell.id}]',
              kind: 'res',
              detail: cell.value.toCanonicalText(),
              doc: cell.input,
            ),
        ],
        signatureHint: sigHint,
      );
    }

    // Extract identifier prefix immediately preceding the cursor
    var start = safeCursor;
    while (start > 0 && _isIdentChar(input.codeUnitAt(start - 1))) {
      start--;
    }
    // Do not complete numbers
    if (start < safeCursor && _isDigit(input.codeUnitAt(start))) {
      return CompletionResult(
        prefix: '',
        replaceStart: safeCursor,
        replaceEnd: safeCursor,
        items: const [],
        signatureHint: sigHint,
      );
    }

    final prefix = input.substring(start, safeCursor);
    if (prefix.isEmpty) {
      return CompletionResult(
        prefix: '',
        replaceStart: safeCursor,
        replaceEnd: safeCursor,
        items: const [],
        signatureHint: sigHint,
      );
    }

    final lowerPrefix = prefix.toLowerCase();
    final candidates = <({int score, CompletionItem item})>[];

    // 1. User variables
    for (final entry in environment.variables.entries) {
      final score = _matchScore(entry.key, lowerPrefix);
      if (score != null) {
        candidates.add((
          score: score,
          item: CompletionItem(
            label: entry.key,
            insertText: entry.key,
            kind: 'var',
            detail: entry.value.toCanonicalText(),
            doc: 'Assigned variable',
          ),
        ));
      }
    }

    // 2. User functions
    for (final fn in environment.functions.values) {
      final score = _matchScore(fn.name, lowerPrefix);
      if (score != null) {
        candidates.add((
          score: score,
          item: CompletionItem(
            label: fn.name,
            insertText: '${fn.name}(',
            kind: 'fn',
            detail: fn.signature,
            doc: 'User function: ${fn.body}',
          ),
        ));
      }
    }

    // 3. Built-in commands
    for (final cmd in CommandRegistry.all) {
      final score = _matchScore(cmd.name, lowerPrefix);
      if (score != null) {
        candidates.add((
          score: score + 1,
          item: CompletionItem(
            label: cmd.name,
            insertText: cmd.params.isEmpty ? '${cmd.name}()' : '${cmd.name}(',
            kind: 'cmd',
            detail: cmd.signature,
            doc: cmd.doc,
          ),
        ));
      }
    }

    // 4. Elementary & special functions
    for (final entry in _mathFunctions.entries) {
      if (CommandRegistry.byName.containsKey(entry.key)) continue;
      final score = _matchScore(entry.key, lowerPrefix);
      if (score != null) {
        final sig = '${entry.key}(${entry.value.params.join(', ')})';
        candidates.add((
          score: score + 2,
          item: CompletionItem(
            label: entry.key,
            insertText: '${entry.key}(',
            kind: 'fn',
            detail: sig,
            doc: entry.value.doc,
          ),
        ));
      }
    }

    // 5. Standard constants
    for (final cName in const ['pi', 'e', 'i', 'infinity']) {
      final score = _matchScore(cName, lowerPrefix);
      if (score != null) {
        final cVal = ExprSyntax.standardConstants[cName]!;
        candidates.add((
          score: score + 3,
          item: CompletionItem(
            label: cName,
            insertText: cName,
            kind: 'const',
            detail: cVal.toString(),
            doc: 'Mathematical constant',
          ),
        ));
      }
    }

    candidates.sort((a, b) {
      final cmp = a.score.compareTo(b.score);
      return cmp != 0 ? cmp : a.item.label.compareTo(b.item.label);
    });

    return CompletionResult(
      prefix: prefix,
      replaceStart: start,
      replaceEnd: safeCursor,
      items: [for (final c in candidates.take(maxItems)) c.item],
      signatureHint: sigHint,
    );
  }

  static SignatureHint? _findSignatureHint(
    String input,
    int cursorOffset,
    Environment env,
  ) {
    // Walk backward from cursorOffset to find the innermost unclosed '('
    var parenDepth = 0;
    var bracketDepth = 0;
    var commaCount = 0;

    for (var i = cursorOffset - 1; i >= 0; i--) {
      final ch = input[i];
      if (ch == ')') {
        parenDepth++;
      } else if (ch == ']') {
        bracketDepth++;
      } else if (ch == '[') {
        if (bracketDepth > 0) bracketDepth--;
      } else if (ch == ',' && parenDepth == 0 && bracketDepth == 0) {
        commaCount++;
      } else if (ch == '(') {
        if (parenDepth > 0) {
          parenDepth--;
        } else {
          // Found the enclosing '('; extract function name before it
          var endName = i;
          while (endName > 0 && input[endName - 1] == ' ') {
            endName--;
          }
          var startName = endName;
          while (startName > 0 &&
              _isIdentChar(input.codeUnitAt(startName - 1))) {
            startName--;
          }
          if (startName < endName) {
            final fnName = input.substring(startName, endName);
            return _lookupSignature(fnName, commaCount, env);
          }
          return null;
        }
      }
    }
    return null;
  }

  static SignatureHint? _lookupSignature(
    String name,
    int commaIndex,
    Environment env,
  ) {
    final userFn = env.getFunction(name);
    if (userFn != null) {
      return SignatureHint(
        name: userFn.name,
        params: userFn.params,
        activeParamIndex: commaIndex.clamp(
          0,
          userFn.params.isEmpty ? 0 : userFn.params.length - 1,
        ),
        doc: 'User function := ${userFn.body}',
      );
    }
    final cmd = CommandRegistry.byName[name];
    if (cmd != null) {
      return SignatureHint(
        name: cmd.name,
        params: cmd.params,
        activeParamIndex: commaIndex.clamp(
          0,
          cmd.params.isEmpty ? 0 : cmd.params.length - 1,
        ),
        doc: cmd.doc,
      );
    }
    final mathFn = _mathFunctions[name];
    if (mathFn != null) {
      return SignatureHint(
        name: name,
        params: mathFn.params,
        activeParamIndex: commaIndex.clamp(
          0,
          mathFn.params.isEmpty ? 0 : mathFn.params.length - 1,
        ),
        doc: mathFn.doc,
      );
    }
    return null;
  }

  static int? _matchScore(String candidate, String lowerPrefix) {
    final lower = candidate.toLowerCase();
    if (lower == lowerPrefix) return 0;
    if (lower.startsWith(lowerPrefix)) return 10 + candidate.length;
    final idx = lower.indexOf(lowerPrefix);
    if (idx != -1) return 50 + idx * 5 + candidate.length;
    return null;
  }

  static bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

  static bool _isIdentChar(int code) =>
      (code >= 0x41 && code <= 0x5A) ||
      (code >= 0x61 && code <= 0x7A) ||
      (code >= 0x30 && code <= 0x39) ||
      code == 0x5F;
}
