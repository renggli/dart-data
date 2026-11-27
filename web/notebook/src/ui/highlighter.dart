import 'package:data/symbolic.dart';

import '../engine/commands.dart';
import '../language/lexer.dart';
import '../model/environment.dart';

/// Shared HTML syntax highlighter for math expressions and Markdown prose.
final class SyntaxHighlighter {
  const new _();

  static final Set<String> _mathFuncNames = {
    for (final f in ExprSyntax.standardFunctions) f.name,
    ...ExprSyntax.standardUnaryFunctions.keys,
    ...ExprSyntax.standardBinaryFunctions.keys,
    ...ExprSyntax.standardVariadicFunctions.keys,
  };

  /// Highlights a notebook math expression into `.tok-*` HTML `<span>`s with
  /// depth-colored and cursor-matched brackets.
  static String highlightMathHtml(
    String source, {
    CommandRegistry? registry,
    Environment? env,
    int? cursorOffset,
  }) {
    if (source.isEmpty) return '';
    final tokens = CalcLexer.tokenize(
      source,
      commands: registry?.allNames ?? const {},
      mathFuncs: _mathFuncNames,
      userFuncs: env?.functions.keys.toSet() ?? const {},
      boundVars: env?.variables.keys.toSet() ?? const {},
    );

    final matchPair = _computeBracketMatches(tokens, cursorOffset);
    final buf = StringBuffer();
    var depth = 0;

    for (var i = 0; i < tokens.length; i++) {
      final tok = tokens[i];
      final escaped = _escapeHtml(tok.text);

      if (_isOpenBracket(tok.kind)) {
        final cls = StringBuffer('tok-bracket-${depth % 3}');
        if (matchPair.matchedIndices.contains(i)) {
          cls.write(' tok-bracket-match');
        }
        if (matchPair.mismatchedIndices.contains(i)) {
          cls.write(' tok-bracket-mismatch');
        }
        buf.write('<span class="$cls">$escaped</span>');
        depth++;
        continue;
      }

      if (_isCloseBracket(tok.kind)) {
        if (depth > 0) depth--;
        final cls = StringBuffer('tok-bracket-${depth % 3}');
        if (matchPair.matchedIndices.contains(i)) {
          cls.write(' tok-bracket-match');
        }
        if (matchPair.mismatchedIndices.contains(i)) {
          cls.write(' tok-bracket-mismatch');
        }
        buf.write('<span class="$cls">$escaped</span>');
        continue;
      }

      final cls = _tokenClass(tok.kind);
      if (cls == null) {
        buf.write(escaped);
      } else {
        buf.write('<span class="$cls">$escaped</span>');
      }
    }

    return buf.toString();
  }

  /// Highlights Markdown source with subtle syntax coloring for headings,
  /// `$...$` math spans, `{{...}}` interpolations, and fenced blocks.
  static String highlightMarkdownHtml(String source) {
    if (source.isEmpty) return '';
    final lines = source.split('\n');
    final out = <String>[];
    var inMathBlock = false;

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed == '```math') {
        inMathBlock = true;
        out.add('<span class="tok-comment">${_escapeHtml(line)}</span>');
        continue;
      }
      if (trimmed == '```' && inMathBlock) {
        inMathBlock = false;
        out.add('<span class="tok-comment">${_escapeHtml(line)}</span>');
        continue;
      }
      if (inMathBlock) {
        out.add(highlightMathHtml(line));
        continue;
      }
      if (trimmed.startsWith('#')) {
        out.add('<span class="tok-command">${_escapeHtml(line)}</span>');
        continue;
      }
      if (trimmed.startsWith('>')) {
        out.add('<span class="tok-comment">${_escapeHtml(line)}</span>');
        continue;
      }
      out.add(_highlightMarkdownInline(line));
    }
    return out.join('\n');
  }

  static String _highlightMarkdownInline(String line) {
    final buf = StringBuffer();
    var i = 0;
    while (i < line.length) {
      // Interpolation {{...}}
      if (i + 1 < line.length && line[i] == '{' && line[i + 1] == '{') {
        final end = line.indexOf('}}', i + 2);
        if (end != -1) {
          buf.write(
            '<span class="tok-result-ref">${_escapeHtml(line.substring(i, end + 2))}</span>',
          );
          i = end + 2;
          continue;
        }
      }
      // Inline math $...$
      if (line[i] == r'$') {
        final end = line.indexOf(r'$', i + 1);
        if (end != -1) {
          buf.write(
            '<span class="tok-math-func">${_escapeHtml(line.substring(i, end + 1))}</span>',
          );
          i = end + 1;
          continue;
        }
      }
      // Inline code `...`
      if (line[i] == '`') {
        final end = line.indexOf('`', i + 1);
        if (end != -1) {
          buf.write(
            '<span class="tok-string">${_escapeHtml(line.substring(i, end + 1))}</span>',
          );
          i = end + 1;
          continue;
        }
      }
      buf.write(_escapeHtml(line[i]));
      i++;
    }
    return buf.toString();
  }

  static ({Set<int> matchedIndices, Set<int> mismatchedIndices})
  _computeBracketMatches(List<Token> tokens, int? cursor) {
    final stack = <({int index, TokenKind kind})>[];
    final pairs = <int, int>{};
    final mismatched = <int>{};

    for (var i = 0; i < tokens.length; i++) {
      final k = tokens[i].kind;
      if (_isOpenBracket(k)) {
        stack.add((index: i, kind: k));
      } else if (_isCloseBracket(k)) {
        if (stack.isNotEmpty && _bracketsMatch(stack.last.kind, k)) {
          final open = stack.removeLast();
          pairs[open.index] = i;
          pairs[i] = open.index;
        } else {
          mismatched.add(i);
        }
      }
    }
    for (final unclosed in stack) {
      mismatched.add(unclosed.index);
    }

    final matched = <int>{};
    if (cursor != null) {
      for (var i = 0; i < tokens.length; i++) {
        final tok = tokens[i];
        if ((tok.start == cursor || tok.end == cursor) &&
            pairs.containsKey(i)) {
          matched.add(i);
          matched.add(pairs[i]!);
        }
      }
    }
    return (matchedIndices: matched, mismatchedIndices: mismatched);
  }

  static bool _isOpenBracket(TokenKind k) =>
      k == TokenKind.lparen || k == TokenKind.lbracket || k == TokenKind.lbrace;

  static bool _isCloseBracket(TokenKind k) =>
      k == TokenKind.rparen || k == TokenKind.rbracket || k == TokenKind.rbrace;

  static bool _bracketsMatch(TokenKind open, TokenKind close) =>
      (open == TokenKind.lparen && close == TokenKind.rparen) ||
      (open == TokenKind.lbracket && close == TokenKind.rbracket) ||
      (open == TokenKind.lbrace && close == TokenKind.rbrace);

  static String? _tokenClass(TokenKind kind) => switch (kind) {
    TokenKind.number => 'tok-number',
    TokenKind.string => 'tok-string',
    TokenKind.boolean => 'tok-boolean',
    TokenKind.constant => 'tok-constant',
    TokenKind.command => 'tok-command',
    TokenKind.mathFunc => 'tok-math-func',
    TokenKind.userFunc => 'tok-user-func',
    TokenKind.variable => 'tok-variable',
    TokenKind.paramLabel => 'tok-param-label',
    TokenKind.resultRef => 'tok-result-ref',
    TokenKind.operator => 'tok-operator',
    TokenKind.comment => 'tok-comment',
    TokenKind.error => 'tok-error',
    _ => null,
  };

  static String _escapeHtml(String text) => text
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&#39;');
}
