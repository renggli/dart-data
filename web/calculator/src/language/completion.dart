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

/// Metadata describing a built-in mathematical or special function for
/// autocomplete, the command palette, and the help panel.
final class MathFunctionInfo {
  const new({
    required this.name,
    required this.params,
    required this.doc,
    this.examples = const [],
  });

  /// Canonical function identifier.
  final String name;

  /// Parameter names shown in signatures and argument hints.
  final List<String> params;

  /// Short description of the function.
  final String doc;

  /// Click-to-run example expressions shown in the help panel.
  final List<String> examples;

  /// Formatted call signature.
  String get signature => '$name(${params.join(', ')})';
}

/// Computes prefix completions and active-argument signature hints for the
/// calculator input bar.
abstract final class CalcCompletion {
  /// All built-in elementary and special functions exposed in completion, the
  /// command palette, and the help panel.
  static const List<MathFunctionInfo> mathFunctions = [
    MathFunctionInfo(
      name: 'sin',
      params: ['x'],
      doc: 'Sine of x (radians).',
      examples: ['sin(pi / 6)'],
    ),
    MathFunctionInfo(
      name: 'cos',
      params: ['x'],
      doc: 'Cosine of x (radians).',
      examples: ['cos(pi / 3)'],
    ),
    MathFunctionInfo(
      name: 'tan',
      params: ['x'],
      doc: 'Tangent of x (radians).',
      examples: ['tan(pi / 4)'],
    ),
    MathFunctionInfo(
      name: 'sec',
      params: ['x'],
      doc: 'Secant 1 / cos(x).',
      examples: ['sec(pi / 3)'],
    ),
    MathFunctionInfo(
      name: 'csc',
      params: ['x'],
      doc: 'Cosecant 1 / sin(x).',
      examples: ['csc(pi / 6)'],
    ),
    MathFunctionInfo(
      name: 'cot',
      params: ['x'],
      doc: 'Cotangent cos(x) / sin(x).',
      examples: ['cot(pi / 4)'],
    ),
    MathFunctionInfo(
      name: 'asin',
      params: ['x'],
      doc: 'Inverse sine arcsin(x).',
      examples: ['asin(1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'acos',
      params: ['x'],
      doc: 'Inverse cosine arccos(x).',
      examples: ['acos(1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'atan',
      params: ['x'],
      doc: 'Inverse tangent arctan(x).',
      examples: ['atan(1)'],
    ),
    MathFunctionInfo(
      name: 'asec',
      params: ['x'],
      doc: 'Inverse secant arcsec(x).',
      examples: ['asec(2)'],
    ),
    MathFunctionInfo(
      name: 'acsc',
      params: ['x'],
      doc: 'Inverse cosecant arccsc(x).',
      examples: ['acsc(2)'],
    ),
    MathFunctionInfo(
      name: 'acot',
      params: ['x'],
      doc: 'Inverse cotangent arccot(x).',
      examples: ['acot(1)'],
    ),
    MathFunctionInfo(
      name: 'sinh',
      params: ['x'],
      doc: 'Hyperbolic sine sinh(x).',
      examples: ['sinh(1)'],
    ),
    MathFunctionInfo(
      name: 'cosh',
      params: ['x'],
      doc: 'Hyperbolic cosine cosh(x).',
      examples: ['cosh(1)'],
    ),
    MathFunctionInfo(
      name: 'tanh',
      params: ['x'],
      doc: 'Hyperbolic tangent tanh(x).',
      examples: ['tanh(1)'],
    ),
    MathFunctionInfo(
      name: 'sech',
      params: ['x'],
      doc: 'Hyperbolic secant 1 / cosh(x).',
      examples: ['sech(0)'],
    ),
    MathFunctionInfo(
      name: 'csch',
      params: ['x'],
      doc: 'Hyperbolic cosecant 1 / sinh(x).',
      examples: ['csch(1)'],
    ),
    MathFunctionInfo(
      name: 'coth',
      params: ['x'],
      doc: 'Hyperbolic cotangent cosh(x) / sinh(x).',
      examples: ['coth(1)'],
    ),
    MathFunctionInfo(
      name: 'asinh',
      params: ['x'],
      doc: 'Inverse hyperbolic sine.',
      examples: ['asinh(1)'],
    ),
    MathFunctionInfo(
      name: 'acosh',
      params: ['x'],
      doc: 'Inverse hyperbolic cosine.',
      examples: ['acosh(2)'],
    ),
    MathFunctionInfo(
      name: 'atanh',
      params: ['x'],
      doc: 'Inverse hyperbolic tangent.',
      examples: ['atanh(1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'asech',
      params: ['x'],
      doc: 'Inverse hyperbolic secant.',
      examples: ['asech(1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'acsch',
      params: ['x'],
      doc: 'Inverse hyperbolic cosecant.',
      examples: ['acsch(1)'],
    ),
    MathFunctionInfo(
      name: 'acoth',
      params: ['x'],
      doc: 'Inverse hyperbolic cotangent.',
      examples: ['acoth(2)'],
    ),
    MathFunctionInfo(
      name: 'sqrt',
      params: ['x'],
      doc: 'Principal square root √x.',
      examples: ['sqrt(12)'],
    ),
    MathFunctionInfo(
      name: 'root',
      params: ['x', 'n'],
      doc: 'Real/principal n-th root x^(1/n).',
      examples: ['root(27, 3)'],
    ),
    MathFunctionInfo(
      name: 'exp',
      params: ['x'],
      doc: 'Natural exponential e^x.',
      examples: ['exp(1)'],
    ),
    MathFunctionInfo(
      name: 'ln',
      params: ['x'],
      doc: 'Natural logarithm ln(x).',
      examples: ['ln(e^3)'],
    ),
    MathFunctionInfo(
      name: 'log',
      params: ['b', 'x'],
      doc: 'Logarithm base b of x (or ln(x) for 1 arg).',
      examples: ['log(2, 32)'],
    ),
    MathFunctionInfo(
      name: 'log2',
      params: ['x'],
      doc: 'Base-2 logarithm log₂(x).',
      examples: ['log2(1024)'],
    ),
    MathFunctionInfo(
      name: 'log10',
      params: ['x'],
      doc: 'Base-10 logarithm log₁₀(x).',
      examples: ['log10(1000)'],
    ),
    MathFunctionInfo(
      name: 'erf',
      params: ['x'],
      doc: 'Gauss error function erf(x).',
      examples: ['erf(1)'],
    ),
    MathFunctionInfo(
      name: 'erfc',
      params: ['x'],
      doc: 'Complementary error function 1 - erf(x).',
      examples: ['erfc(1)'],
    ),
    MathFunctionInfo(
      name: 'erfi',
      params: ['x'],
      doc: 'Imaginary error function erfi(x).',
      examples: ['erfi(1)'],
    ),
    MathFunctionInfo(
      name: 'fresnels',
      params: ['x'],
      doc: 'Fresnel sine integral S(x).',
      examples: ['fresnels(1)'],
    ),
    MathFunctionInfo(
      name: 'fresnelc',
      params: ['x'],
      doc: 'Fresnel cosine integral C(x).',
      examples: ['fresnelc(1)'],
    ),
    MathFunctionInfo(
      name: 'Ei',
      params: ['x'],
      doc: 'Exponential integral Ei(x).',
      examples: ['Ei(1)'],
    ),
    MathFunctionInfo(
      name: 'li',
      params: ['x'],
      doc: 'Logarithmic integral li(x).',
      examples: ['li(2)'],
    ),
    MathFunctionInfo(
      name: 'Si',
      params: ['x'],
      doc: 'Sine integral Si(x).',
      examples: ['Si(1)'],
    ),
    MathFunctionInfo(
      name: 'Ci',
      params: ['x'],
      doc: 'Cosine integral Ci(x).',
      examples: ['Ci(1)'],
    ),
    MathFunctionInfo(
      name: 'Shi',
      params: ['x'],
      doc: 'Hyperbolic sine integral Shi(x).',
      examples: ['Shi(1)'],
    ),
    MathFunctionInfo(
      name: 'Chi',
      params: ['x'],
      doc: 'Hyperbolic cosine integral Chi(x).',
      examples: ['Chi(1)'],
    ),
    MathFunctionInfo(
      name: 'gamma',
      params: ['z'],
      doc: 'Euler Gamma function Γ(z).',
      examples: ['gamma(5)', 'gamma(1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'uppergamma',
      params: ['a', 'x'],
      doc: 'Upper incomplete Gamma function Γ(a, x).',
      examples: ['uppergamma(2, 1)'],
    ),
    MathFunctionInfo(
      name: 'lowergamma',
      params: ['a', 'x'],
      doc: 'Lower incomplete Gamma function γ(a, x).',
      examples: ['lowergamma(2, 1)'],
    ),
    MathFunctionInfo(
      name: 'digamma',
      params: ['z'],
      doc: 'Digamma function ψ(z).',
      examples: ['digamma(1)'],
    ),
    MathFunctionInfo(
      name: 'polygamma',
      params: ['n', 'z'],
      doc: 'Polygamma function ψ^(n)(z).',
      examples: ['polygamma(1, 1)'],
    ),
    MathFunctionInfo(
      name: 'zeta',
      params: ['s'],
      doc: 'Riemann zeta function ζ(s).',
      examples: ['zeta(2)'],
    ),
    MathFunctionInfo(
      name: 'polylog',
      params: ['s', 'z'],
      doc: 'Polylogarithm Li_s(z).',
      examples: ['polylog(2, 1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'beta',
      params: ['a', 'b'],
      doc: 'Euler Beta function B(a, b).',
      examples: ['beta(2, 3)'],
    ),
    MathFunctionInfo(
      name: 'elliptick',
      params: ['m'],
      doc: 'Complete elliptic integral of the first kind K(m).',
      examples: ['elliptick(1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'elliptice',
      params: ['m'],
      doc: 'Complete elliptic integral of the second kind E(m).',
      examples: ['elliptice(1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'elliptic_f',
      params: ['phi', 'm'],
      doc: 'Incomplete elliptic integral of the first kind F(φ, m).',
      examples: ['elliptic_f(pi / 3, 1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'elliptic_e',
      params: ['phi', 'm'],
      doc: 'Incomplete elliptic integral of the second kind E(φ, m).',
      examples: ['elliptic_e(pi / 3, 1 / 2)'],
    ),
    MathFunctionInfo(
      name: 'besselj',
      params: ['nu', 'x'],
      doc: 'Bessel function of the first kind J_ν(x).',
      examples: ['besselj(0, 1)'],
    ),
    MathFunctionInfo(
      name: 'bessely',
      params: ['nu', 'x'],
      doc: 'Bessel function of the second kind Y_ν(x).',
      examples: ['bessely(0, 1)'],
    ),
    MathFunctionInfo(
      name: 'besseli',
      params: ['nu', 'x'],
      doc: 'Modified Bessel function of the first kind I_ν(x).',
      examples: ['besseli(0, 1)'],
    ),
    MathFunctionInfo(
      name: 'besselk',
      params: ['nu', 'x'],
      doc: 'Modified Bessel function of the second kind K_ν(x).',
      examples: ['besselk(0, 1)'],
    ),
    MathFunctionInfo(
      name: 'lambertw',
      params: ['z', '[branch]'],
      doc: 'Lambert W function W_k(z).',
      examples: ['lambertw(1)'],
    ),
    MathFunctionInfo(
      name: 'piecewise',
      params: ['cond1', 'expr1', '[otherwise]'],
      doc: 'Piecewise conditional expression.',
      examples: ['piecewise(x > 0, x, -x)'],
    ),
  ];

  /// Lookup map from lowercase function name to [MathFunctionInfo].
  static final Map<String, MathFunctionInfo> mathFunctionByName = {
    for (final fn in mathFunctions) fn.name.toLowerCase(): fn,
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
    for (final fn in mathFunctions) {
      if (CommandRegistry.byName.containsKey(fn.name)) continue;
      final score = _matchScore(fn.name, lowerPrefix);
      if (score != null) {
        candidates.add((
          score: score + 2,
          item: CompletionItem(
            label: fn.name,
            insertText: '${fn.name}(',
            kind: 'fn',
            detail: fn.signature,
            doc: fn.doc,
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
    final mathFn = mathFunctionByName[name.toLowerCase()];
    if (mathFn != null) {
      return SignatureHint(
        name: mathFn.name,
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
