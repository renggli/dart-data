import 'package:data/symbolic.dart';

import '../engine/commands.dart';
import '../model/environment.dart';
import 'lexer.dart';

/// Kind of completion candidate shown in the autocomplete popup.
enum CompletionKind {
  command,
  mathFunc,
  userFunc,
  variable,
  constant,
  paramLabel,
  enumValue,
}

/// Single autocomplete suggestion item.
final class CompletionItem {
  const new({
    required this.label,
    required this.insertText,
    required this.kind,
    required this.detail,
    this.doc = '',
  });

  final String label;
  final String insertText;
  final CompletionKind kind;
  final String detail;
  final String doc;
}

/// Active parameter signature hint when the cursor is inside `fn(...)`.
final class SignatureHint {
  const new({
    required this.functionName,
    required this.signatureText,
    required this.activeParamName,
    required this.doc,
  });

  final String functionName;
  final String signatureText;
  final String? activeParamName;
  final String doc;
}

/// Result of querying [NotebookCompletion.suggest] at a cursor offset.
final class CompletionResult {
  const new({
    required this.replaceStart,
    required this.replaceEnd,
    required this.items,
    this.signatureHint,
  });

  final int replaceStart;
  final int replaceEnd;
  final List<CompletionItem> items;
  final SignatureHint? signatureHint;
}

/// Metadata-driven autocomplete & active-parameter signature engine.
final class NotebookCompletion {
  const new _();

  static final List<({String name, String doc})> _constants = [
    (name: 'pi', doc: 'Archimedes constant 3.14159...'),
    (name: 'e', doc: 'Euler number 2.71828...'),
    (name: 'i', doc: 'Imaginary unit sqrt(-1)'),
    (name: 'infinity', doc: 'Positive infinity'),
    (name: 'true', doc: 'Boolean true'),
    (name: 'false', doc: 'Boolean false'),
  ];

  /// Computes completion suggestions and an optional [SignatureHint] for
  /// [source] at [cursor].
  static CompletionResult suggest(
    String source,
    int cursor, {
    required CommandRegistry registry,
    required Environment env,
  }) {
    final pos = cursor.clamp(0, source.length);
    final callCtx = _findEnclosingCall(source, pos);
    final sigHint = callCtx == null
        ? null
        : _buildSignatureHint(callCtx, registry, env);

    // 1. After `paramName:` inside a command call -> suggest enumValues
    if (callCtx != null && callCtx.activeNamedParam != null) {
      final cmd = registry.lookup(callCtx.name);
      if (cmd != null) {
        final spec = cmd.signature.named
            .where((n) => n.name == callCtx.activeNamedParam)
            .firstOrNull;
        final enumVals = spec?.enumValues;
        if (enumVals != null && enumVals.isNotEmpty) {
          final prefixInfo = _scanQuotedOrWordPrefix(source, pos);
          final q = prefixInfo.prefix.toLowerCase();
          final items = [
            for (final v in enumVals)
              if (v.toLowerCase().startsWith(q))
                CompletionItem(
                  label: "'$v'",
                  insertText: prefixInfo.inQuotes ? v : "'$v'",
                  kind: CompletionKind.enumValue,
                  detail: '${spec!.name} option',
                  doc: spec.doc,
                ),
          ];
          return CompletionResult(
            replaceStart: prefixInfo.start,
            replaceEnd: pos,
            items: items,
            signatureHint: sigHint,
          );
        }
      }
    }

    // Scan identifier prefix at cursor
    var start = pos;
    while (start > 0 && _isIdentChar(source.codeUnitAt(start - 1))) {
      start--;
    }
    final prefix = source.substring(start, pos);
    final q = prefix.toLowerCase();

    final items = <CompletionItem>[];

    // 2. Inside `fn(...)` -> suggest unused named parameter labels
    if (callCtx != null) {
      final cmd = registry.lookup(callCtx.name);
      if (cmd != null) {
        for (final n in cmd.signature.named) {
          if (callCtx.usedNamedArgs.contains(n.name)) continue;
          if (q.isEmpty || n.name.toLowerCase().startsWith(q)) {
            items.add(
              CompletionItem(
                label: '${n.name}:',
                insertText: '${n.name}: ',
                kind: CompletionKind.paramLabel,
                detail: n.defaultValue != null
                    ? 'default: ${n.defaultValue}'
                    : (n.isRequired ? 'required' : 'optional'),
                doc: n.doc,
              ),
            );
          }
        }
      } else if (env.functions[callCtx.name] case final userFn?) {
        for (final p in userFn.params) {
          if (!p.isNamed || callCtx.usedNamedArgs.contains(p.name)) continue;
          if (q.isEmpty || p.name.toLowerCase().startsWith(q)) {
            items.add(
              CompletionItem(
                label: '${p.name}:',
                insertText: '${p.name}: ',
                kind: CompletionKind.paramLabel,
                detail: p.defaultExpr != null
                    ? 'default: ${p.defaultExpr}'
                    : 'required',
              ),
            );
          }
        }
      }
    }

    // Only suggest global symbols/commands if prefix is non-empty or we have
    // named parameters to show.
    if (q.isEmpty) {
      return CompletionResult(
        replaceStart: start,
        replaceEnd: pos,
        items: items,
        signatureHint: sigHint,
      );
    }

    // 3. Bound variables & user functions
    for (final v in env.variables.keys) {
      if (v.toLowerCase().startsWith(q)) {
        items.add(
          CompletionItem(
            label: v,
            insertText: v,
            kind: CompletionKind.variable,
            detail: env.variables[v]!.kind,
          ),
        );
      }
    }
    for (final fn in env.functions.values) {
      if (fn.name.toLowerCase().startsWith(q)) {
        items.add(
          CompletionItem(
            label: fn.name,
            insertText: '${fn.name}(',
            kind: CompletionKind.userFunc,
            detail: fn.formatSignature(),
          ),
        );
      }
    }

    // 4. Commands from CommandRegistry.all
    for (final cmd in registry.all) {
      if (cmd.name.toLowerCase().startsWith(q)) {
        items.add(
          CompletionItem(
            label: cmd.name,
            insertText: '${cmd.name}(',
            kind: CompletionKind.command,
            detail: cmd.signature.format(cmd.name),
            doc: cmd.doc,
          ),
        );
      }
    }

    // 5. Built-in math functions from ExprSyntax.standardFunctions
    for (final info in ExprSyntax.standardFunctions) {
      if (info.name.toLowerCase().startsWith(q)) {
        items.add(
          CompletionItem(
            label: info.name,
            insertText: '${info.name}(',
            kind: CompletionKind.mathFunc,
            detail: '${info.name}(${info.params.join(', ')})',
            doc: info.doc,
          ),
        );
      }
    }

    // 6. Constants
    for (final c in _constants) {
      if (c.name.toLowerCase().startsWith(q)) {
        items.add(
          CompletionItem(
            label: c.name,
            insertText: c.name,
            kind: CompletionKind.constant,
            detail: 'constant',
            doc: c.doc,
          ),
        );
      }
    }

    return CompletionResult(
      replaceStart: start,
      replaceEnd: pos,
      items: items.take(24).toList(),
      signatureHint: sigHint,
    );
  }

  static SignatureHint? _buildSignatureHint(
    _CallContext ctx,
    CommandRegistry registry,
    Environment env,
  ) {
    final cmd = registry.lookup(ctx.name);
    if (cmd != null) {
      final active =
          ctx.activeNamedParam ??
          (ctx.positionalIndex < cmd.signature.positional.length
              ? cmd.signature.positional[ctx.positionalIndex].name
              : null);
      return SignatureHint(
        functionName: cmd.name,
        signatureText: cmd.signature.format(cmd.name),
        activeParamName: active,
        doc: cmd.doc,
      );
    }

    final userFn = env.functions[ctx.name];
    if (userFn != null) {
      final posParams = [
        for (final p in userFn.params)
          if (!p.isNamed) p.name,
      ];
      final active =
          ctx.activeNamedParam ??
          (ctx.positionalIndex < posParams.length
              ? posParams[ctx.positionalIndex]
              : null);
      return SignatureHint(
        functionName: userFn.name,
        signatureText: userFn.formatSignature(),
        activeParamName: active,
        doc: 'User-defined function',
      );
    }

    for (final info in ExprSyntax.standardFunctions) {
      if (info.name == ctx.name || info.aliases.contains(ctx.name)) {
        final active = ctx.positionalIndex < info.params.length
            ? info.params[ctx.positionalIndex]
            : null;
        return SignatureHint(
          functionName: info.name,
          signatureText: '${info.name}(${info.params.join(', ')})',
          activeParamName: active,
          doc: info.doc,
        );
      }
    }
    return null;
  }

  static _CallContext? _findEnclosingCall(String source, int cursor) {
    final tokens = CalcLexer.tokenize(source);
    final stack = <_CallFrame>[];

    for (final tok in tokens) {
      if (tok.start >= cursor) break;
      switch (tok.kind) {
        case TokenKind.lparen:
          final name = _precedingIdent(tokens, tok.start);
          stack.add(_CallFrame(name: name));
        case TokenKind.rparen:
          if (tok.end <= cursor && stack.isNotEmpty) {
            stack.removeLast();
          }
        case TokenKind.comma:
          if (stack.isNotEmpty && tok.end <= cursor) {
            final top = stack.last;
            top.positionalIndex++;
            top.currentNamedParam = null;
          }
        case TokenKind.paramLabel:
          if (stack.isNotEmpty && tok.end <= cursor) {
            final top = stack.last;
            top.usedNamedArgs.add(tok.text);
            top.currentNamedParam = tok.text;
          }
        default:
          break;
      }
    }

    if (stack.isEmpty) return null;
    for (var i = stack.length - 1; i >= 0; i--) {
      final f = stack[i];
      if (f.name != null) {
        return _CallContext(
          name: f.name!,
          positionalIndex: f.positionalIndex,
          activeNamedParam: f.currentNamedParam,
          usedNamedArgs: f.usedNamedArgs,
        );
      }
    }
    return null;
  }

  static String? _precedingIdent(List<Token> tokens, int lparenStart) {
    for (var i = tokens.length - 1; i >= 0; i--) {
      final t = tokens[i];
      if (t.end > lparenStart) continue;
      if (t.kind == TokenKind.whitespace) continue;
      if (t.kind == TokenKind.variable ||
          t.kind == TokenKind.command ||
          t.kind == TokenKind.mathFunc ||
          t.kind == TokenKind.userFunc) {
        return t.text;
      }
      return null;
    }
    return null;
  }

  static ({int start, String prefix, bool inQuotes}) _scanQuotedOrWordPrefix(
    String source,
    int cursor,
  ) {
    var i = cursor;
    while (i > 0 && _isIdentChar(source.codeUnitAt(i - 1))) {
      i--;
    }
    final inQuotes =
        i > 0 &&
        (source.codeUnitAt(i - 1) == 39 || source.codeUnitAt(i - 1) == 34);
    return (start: i, prefix: source.substring(i, cursor), inQuotes: inQuotes);
  }

  static bool _isIdentChar(int ch) =>
      (ch >= 65 && ch <= 90) ||
      (ch >= 97 && ch <= 122) ||
      (ch >= 48 && ch <= 57) ||
      ch == 95;
}

final class _CallFrame {
  new({required this.name});

  final String? name;
  int positionalIndex = 0;
  String? currentNamedParam;
  final Set<String> usedNamedArgs = {};
}

final class _CallContext {
  const new({
    required this.name,
    required this.positionalIndex,
    required this.activeNamedParam,
    required this.usedNamedArgs,
  });

  final String name;
  final int positionalIndex;
  final String? activeNamedParam;
  final Set<String> usedNamedArgs;
}
