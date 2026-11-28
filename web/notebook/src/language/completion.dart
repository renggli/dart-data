import 'package:data/symbolic.dart';

import '../engine/commands.dart';
import '../model/environment.dart';
import 'lexer.dart';
import 'signature.dart';

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
    this.cursorBackOffset = 0,
  });

  final String label;
  final String insertText;
  final CompletionKind kind;
  final String detail;
  final String doc;
  final int cursorBackOffset;
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
    final tokens = CalcLexer.tokenize(source);

    // 1. Suppress completions inside comments or right after numeric literals
    //    (e.g. `2.` or `42`).
    for (final tok in tokens) {
      if (tok.start < pos && pos <= tok.end) {
        if (tok.kind == TokenKind.comment) {
          return CompletionResult(
            replaceStart: pos,
            replaceEnd: pos,
            items: const [],
          );
        }
        if (tok.kind == TokenKind.number && pos == tok.end) {
          return CompletionResult(
            replaceStart: pos,
            replaceEnd: pos,
            items: const [],
          );
        }
        break;
      }
    }

    // 2. Suppress completions inside function-definition parameter heads:
    //    `f(x, y|) := ...`
    if (_isInFunctionDefHead(tokens, pos)) {
      return CompletionResult(
        replaceStart: pos,
        replaceEnd: pos,
        items: const [],
      );
    }

    final callCtx = _analyzeCallContext(tokens, pos);
    final sigHint = callCtx == null
        ? null
        : _buildSignatureHint(callCtx, registry, env);

    // Check if cursor is inside a string literal (either open/unclosed or closed).
    final stringSpan = _findEnclosingString(tokens, pos);

    // 3. Enum string completion for active named or positional enum params.
    final activeParam = callCtx == null
        ? null
        : _findActiveParamSpec(callCtx, registry);
    if (activeParam != null) {
      if (activeParam.enumValues case final enumVals?
          when enumVals.isNotEmpty) {
        if (callCtx!.inParamValueSlot ||
            (activeParam.isPositional && callCtx.atArgStart) ||
            stringSpan != null) {
          final int replaceStart;
          final int replaceEnd;
          final String prefix;
          final bool wrapQuotes;
          if (stringSpan != null) {
            replaceStart = stringSpan.contentStart;
            replaceEnd = stringSpan.hasClosingQuote
                ? stringSpan.contentEnd
                : pos;
            prefix = source.substring(stringSpan.contentStart, pos);
            wrapQuotes = false;
          } else {
            final prefixInfo = _scanWordPrefix(source, pos);
            replaceStart = prefixInfo.start;
            replaceEnd = pos;
            prefix = prefixInfo.prefix;
            wrapQuotes = true;
          }
          final q = prefix.toLowerCase();
          final items = [
            for (final v in enumVals)
              if (v.toLowerCase().startsWith(q))
                CompletionItem(
                  label: "'$v'",
                  insertText: wrapQuotes ? "'$v'" : v,
                  kind: CompletionKind.enumValue,
                  detail: '${activeParam.name} option',
                  doc: activeParam.doc,
                ),
          ];
          return CompletionResult(
            replaceStart: replaceStart,
            replaceEnd: replaceEnd,
            items: items,
            signatureHint: sigHint,
          );
        }
      }
    }

    // Any other string literal -> no completions.
    if (stringSpan != null) {
      return CompletionResult(
        replaceStart: pos,
        replaceEnd: pos,
        items: const [],
        signatureHint: sigHint,
      );
    }

    // Scan identifier prefix at cursor
    final word = _scanWordPrefix(source, pos);
    final start = word.start;
    final prefix = word.prefix;
    final q = prefix.toLowerCase();

    // If cursor is immediately preceded by an unquoted string token or right
    // after `'` / `"`, do not suggest identifiers.
    if (start > 0) {
      final prevCh = source.codeUnitAt(start - 1);
      if (prevCh == 39 /* ' */ || prevCh == 34 /* " */ ) {
        return CompletionResult(
          replaceStart: pos,
          replaceEnd: pos,
          items: const [],
          signatureHint: sigHint,
        );
      }
    }

    final items = <CompletionItem>[];
    final seen = <String>{};

    void addItem(CompletionItem item) {
      if (seen.add(item.label)) items.add(item);
    }

    // 4. Boolean param value slot (`grid: |`, `contours: |`, etc.)
    if (callCtx != null &&
        callCtx.inParamValueSlot &&
        activeParam?.type == ParamType.boolean) {
      for (final b in ['true', 'false']) {
        if (b.startsWith(q)) {
          addItem(
            CompletionItem(
              label: b,
              insertText: b,
              kind: CompletionKind.constant,
              detail: '${activeParam!.name} option',
              doc: activeParam.doc,
            ),
          );
        }
      }
      if (q.isEmpty) {
        return CompletionResult(
          replaceStart: start,
          replaceEnd: pos,
          items: items,
          signatureHint: sigHint,
        );
      }
    }

    // 5. Named parameter labels (`name: `) inside a known command or user func
    //    call — ONLY at an argument start slot (not after `param:` and not in
    //    the middle of an expression), and only once required positional args
    //    are supplied or the user is actively typing a matching param prefix.
    if (callCtx != null && !callCtx.inParamValueSlot && callCtx.atArgStart) {
      final cmd = registry.lookup(callCtx.name);
      if (cmd != null) {
        final reqPos = cmd.signature.positional
            .where((p) => p.isRequired)
            .length;
        final showWhenEmpty =
            callCtx.usedNamedArgs.isNotEmpty ||
            callCtx.positionalIndex >= reqPos;
        if (q.isNotEmpty || showWhenEmpty) {
          for (final n in cmd.signature.named) {
            if (callCtx.usedNamedArgs.contains(n.name)) continue;
            if (q.isEmpty || n.name.toLowerCase().startsWith(q)) {
              addItem(
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
        }
      } else if (env.functions[callCtx.name] case final userFn?) {
        final reqPos = userFn.params
            .where((p) => !p.isNamed && !p.isOptionalPositional)
            .length;
        final showWhenEmpty =
            callCtx.usedNamedArgs.isNotEmpty ||
            callCtx.positionalIndex >= reqPos;
        if (q.isNotEmpty || showWhenEmpty) {
          for (final p in userFn.params) {
            if (!p.isNamed || callCtx.usedNamedArgs.contains(p.name)) continue;
            if (q.isEmpty || p.name.toLowerCase().startsWith(q)) {
              addItem(
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
    }

    // Do not spam general commands/functions when no prefix has been typed.
    if (q.isEmpty) {
      return CompletionResult(
        replaceStart: start,
        replaceEnd: pos,
        items: items,
        signatureHint: sigHint,
      );
    }

    // Determine whether we are in a top-level statement position vs inside
    // another call / expression argument.
    final isNestedCall = callCtx != null;
    final inParamValue = callCtx?.inParamValueSlot ?? false;

    // 6. Bound variables & user functions
    for (final v in env.variables.keys) {
      if (v.toLowerCase().startsWith(q)) {
        addItem(
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
        addItem(
          CompletionItem(
            label: fn.name,
            insertText: '${fn.name}()',
            kind: CompletionKind.userFunc,
            detail: fn.formatSignature(),
            cursorBackOffset: fn.params.isEmpty ? 0 : 1,
          ),
        );
      }
    }

    // 7. Commands from CommandRegistry.all
    for (final cmd in registry.all) {
      // Suppress statement-level plotting and session commands inside nested
      // function calls or named parameter values.
      if ((isNestedCall || inParamValue) &&
          (cmd.category == CommandCategory.plot ||
              cmd.category == CommandCategory.session)) {
        continue;
      }
      if (cmd.name.toLowerCase().startsWith(q)) {
        final hasArgs =
            cmd.signature.positional.isNotEmpty ||
            cmd.signature.named.isNotEmpty ||
            cmd.signature.variadic;
        addItem(
          CompletionItem(
            label: cmd.name,
            insertText: '${cmd.name}()',
            kind: CompletionKind.command,
            detail: cmd.signature.format(cmd.name),
            doc: cmd.doc,
            cursorBackOffset: hasArgs ? 1 : 0,
          ),
        );
      }
    }

    // 8. Built-in math functions from ExprSyntax.standardFunctions (deduped)
    for (final info in ExprSyntax.standardFunctions) {
      if (info.name.toLowerCase().startsWith(q)) {
        addItem(
          CompletionItem(
            label: info.name,
            insertText: '${info.name}()',
            kind: CompletionKind.mathFunc,
            detail: '${info.name}(${info.params.join(', ')})',
            doc: info.doc,
            cursorBackOffset: 1,
          ),
        );
      }
    }

    // 9. Constants
    for (final c in _constants) {
      if (c.name.toLowerCase().startsWith(q)) {
        addItem(
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

  static ParamSpec? _findActiveParamSpec(
    _CallContext ctx,
    CommandRegistry registry,
  ) {
    final cmd = registry.lookup(ctx.name);
    if (cmd == null) return null;
    if (ctx.activeNamedParam != null) {
      for (final n in cmd.signature.named) {
        if (n.name == ctx.activeNamedParam) return n;
      }
      return null;
    }
    if (ctx.positionalIndex < cmd.signature.positional.length) {
      return cmd.signature.positional[ctx.positionalIndex];
    }
    return null;
  }

  static bool _isInFunctionDefHead(List<Token> tokens, int cursor) {
    // Locate the current statement range (between `;` / `\n` boundaries).
    var stmtStartIdx = 0;
    var stmtEndIdx = tokens.length;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t.kind == TokenKind.semicolon || t.kind == TokenKind.newline) {
        if (t.end <= cursor) {
          stmtStartIdx = i + 1;
        } else {
          stmtEndIdx = i;
          break;
        }
      }
    }

    // Find `:=` operator in this statement.
    var assignTokStart = -1;
    for (var i = stmtStartIdx; i < stmtEndIdx; i++) {
      final t = tokens[i];
      if (t.kind == TokenKind.operator && t.text == ':=') {
        assignTokStart = t.start;
        break;
      }
    }
    if (assignTokStart == -1 || cursor > assignTokStart) return false;

    // Inside `f(...) := ...` before `:=` -> suppress identifier completions.
    var parenDepth = 0;
    for (var i = stmtStartIdx; i < stmtEndIdx; i++) {
      final t = tokens[i];
      if (t.start >= cursor) break;
      if (t.kind == TokenKind.lparen) parenDepth++;
      if (t.kind == TokenKind.rparen && parenDepth > 0) parenDepth--;
    }
    return parenDepth > 0;
  }

  static ({int contentStart, int contentEnd, bool hasClosingQuote})?
  _findEnclosingString(List<Token> tokens, int cursor) {
    for (final t in tokens) {
      if (t.kind == TokenKind.string) {
        if (cursor > t.start && cursor < t.end) {
          return (
            contentStart: t.start + 1,
            contentEnd: t.end - 1,
            hasClosingQuote: true,
          );
        }
      } else if (t.kind == TokenKind.error &&
          t.text.isNotEmpty &&
          (t.text.startsWith("'") || t.text.startsWith('"'))) {
        if (cursor > t.start && cursor <= t.end) {
          return (
            contentStart: t.start + 1,
            contentEnd: t.end,
            hasClosingQuote: false,
          );
        }
      }
    }
    return null;
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
      if (info.name == ctx.name) {
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

  static _CallContext? _analyzeCallContext(List<Token> tokens, int cursor) {
    final stack = <_CallFrame>[];

    for (final tok in tokens) {
      if (tok.start >= cursor) break;
      switch (tok.kind) {
        case TokenKind.lparen:
          if (stack.isNotEmpty) {
            stack.last.hasNonPrefixTokenInArg = true;
          }
          final name = _precedingIdent(tokens, tok.start);
          stack.add(_CallFrame(name: name, isBracket: false));
        case TokenKind.lbracket || TokenKind.lbrace:
          if (stack.isNotEmpty) {
            stack.last.hasNonPrefixTokenInArg = true;
          }
          stack.add(_CallFrame(name: null, isBracket: true));
        case TokenKind.rparen || TokenKind.rbracket || TokenKind.rbrace:
          if (tok.end <= cursor && stack.isNotEmpty) {
            stack.removeLast();
          }
        case TokenKind.comma:
          if (stack.isNotEmpty && !stack.last.isBracket && tok.end <= cursor) {
            final top = stack.last;
            top.positionalIndex++;
            top.currentNamedParam = null;
            top.hasNonPrefixTokenInArg = false;
            top.seenPrefixCandidate = false;
          }
        case TokenKind.paramLabel:
          if (stack.isNotEmpty && !stack.last.isBracket && tok.end <= cursor) {
            final top = stack.last;
            top.usedNamedArgs.add(tok.text);
            top.currentNamedParam = tok.text;
            top.hasNonPrefixTokenInArg = false;
            top.seenPrefixCandidate = false;
          }
        case TokenKind.whitespace || TokenKind.newline || TokenKind.colon:
          break;
        default:
          if (stack.isNotEmpty && !stack.last.isBracket) {
            final top = stack.last;
            // Allow a single trailing identifier touching or immediately before
            // the cursor as the typed named-arg prefix.
            final isTrailingPartialIdent =
                tok.end == cursor &&
                !top.seenPrefixCandidate &&
                !top.hasNonPrefixTokenInArg &&
                (tok.kind == TokenKind.variable ||
                    tok.kind == TokenKind.command ||
                    tok.kind == TokenKind.mathFunc ||
                    tok.kind == TokenKind.userFunc ||
                    tok.kind == TokenKind.constant ||
                    tok.kind == TokenKind.boolean);
            if (isTrailingPartialIdent) {
              top.seenPrefixCandidate = true;
            } else {
              top.hasNonPrefixTokenInArg = true;
            }
          }
      }
    }

    if (stack.isEmpty) return null;
    for (var i = stack.length - 1; i >= 0; i--) {
      final f = stack[i];
      if (!f.isBracket && f.name != null) {
        return _CallContext(
          name: f.name!,
          positionalIndex: f.positionalIndex,
          activeNamedParam: f.currentNamedParam,
          usedNamedArgs: f.usedNamedArgs,
          inParamValueSlot: f.currentNamedParam != null,
          atArgStart: !f.hasNonPrefixTokenInArg && f.currentNamedParam == null,
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

  static ({int start, String prefix}) _scanWordPrefix(
    String source,
    int cursor,
  ) {
    var i = cursor;
    while (i > 0 && _isIdentChar(source.codeUnitAt(i - 1))) {
      i--;
    }
    return (start: i, prefix: source.substring(i, cursor));
  }

  static bool _isIdentChar(int ch) =>
      (ch >= 65 && ch <= 90) ||
      (ch >= 97 && ch <= 122) ||
      (ch >= 48 && ch <= 57) ||
      ch == 95;
}

final class _CallFrame {
  new({required this.name, required this.isBracket});

  final String? name;
  final bool isBracket;
  int positionalIndex = 0;
  String? currentNamedParam;
  final Set<String> usedNamedArgs = {};
  bool hasNonPrefixTokenInArg = false;
  bool seenPrefixCandidate = false;
}

final class _CallContext {
  const new({
    required this.name,
    required this.positionalIndex,
    required this.activeNamedParam,
    required this.usedNamedArgs,
    required this.inParamValueSlot,
    required this.atArgStart,
  });

  final String name;
  final int positionalIndex;
  final String? activeNamedParam;
  final Set<String> usedNamedArgs;
  final bool inParamValueSlot;
  final bool atArgStart;
}
