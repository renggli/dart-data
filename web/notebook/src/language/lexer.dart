/// Lexical token categories for the notebook math language.
enum TokenKind {
  number,
  string,
  boolean,
  constant,
  command,
  mathFunc,
  userFunc,
  variable,
  paramLabel,
  resultRef,
  operator,
  lparen,
  rparen,
  lbracket,
  rbracket,
  lbrace,
  rbrace,
  comma,
  colon,
  semicolon,
  newline,
  comment,
  whitespace,
  error,
}

/// A single source-span token produced by [CalcLexer].
final class Token {
  const new(this.kind, this.start, this.end, this.text);

  final TokenKind kind;
  final int start;
  final int end;
  final String text;

  int get length => end - start;

  @override
  String toString() => 'Token($kind, $start..$end, "$text")';
}

/// Single-pass, span-preserving lexer for the notebook math language.
///
/// Never throws; every character in `[0, source.length)` is covered by exactly
/// one [Token] in order.
final class CalcLexer {
  const new _();

  static const Set<String> defaultConstants = {
    'pi',
    'π',
    'e',
    'i',
    'infinity',
    '∞',
    'undefined',
  };

  static final RegExp _resultRefPattern = RegExp(r'r\[-?\d+\]');

  /// Tokenizes [source] into contiguous [Token] spans.
  static List<Token> tokenize(
    String source, {
    Set<String> commands = const {},
    Set<String> mathFuncs = const {},
    Set<String> userFuncs = const {},
    Set<String> boundVars = const {},
  }) {
    final tokens = <Token>[];
    final len = source.length;
    var i = 0;

    while (i < len) {
      final start = i;
      final ch = source.codeUnitAt(i);

      // Newline
      if (ch == 10 /* \n */ || ch == 13 /* \r */ ) {
        if (ch == 13 && i + 1 < len && source.codeUnitAt(i + 1) == 10) {
          i += 2;
        } else {
          i++;
        }
        tokens.add(
          Token(TokenKind.newline, start, i, source.substring(start, i)),
        );
        continue;
      }

      // Horizontal whitespace
      if (_isHorizontalSpace(ch)) {
        i++;
        while (i < len && _isHorizontalSpace(source.codeUnitAt(i))) {
          i++;
        }
        tokens.add(
          Token(TokenKind.whitespace, start, i, source.substring(start, i)),
        );
        continue;
      }

      // Line comment: // ...
      if (ch == 47 /* / */ && i + 1 < len && source.codeUnitAt(i + 1) == 47) {
        i += 2;
        while (i < len &&
            source.codeUnitAt(i) != 10 &&
            source.codeUnitAt(i) != 13) {
          i++;
        }
        tokens.add(
          Token(TokenKind.comment, start, i, source.substring(start, i)),
        );
        continue;
      }

      // String literal: '...' or "..."
      if (ch == 39 /* ' */ || ch == 34 /* " */ ) {
        final quote = ch;
        i++;
        var closed = false;
        while (i < len) {
          final c = source.codeUnitAt(i);
          if (c == 92 /* \ */ && i + 1 < len) {
            i += 2;
            continue;
          }
          if (c == quote) {
            i++;
            closed = true;
            break;
          }
          if (c == 10 || c == 13) break;
          i++;
        }
        tokens.add(
          Token(
            closed ? TokenKind.string : TokenKind.error,
            start,
            i,
            source.substring(start, i),
          ),
        );
        continue;
      }

      // Result reference: r[n] or r[-n]
      if (ch == 114 /* r */ && i + 1 < len && source.codeUnitAt(i + 1) == 91) {
        final match = _resultRefPattern.matchAsPrefix(source, i);
        if (match != null) {
          i = match.end;
          tokens.add(
            Token(TokenKind.resultRef, start, i, source.substring(start, i)),
          );
          continue;
        }
      }

      // Number literal
      if (_isDigit(ch) ||
          (ch == 46 /* . */ &&
              i + 1 < len &&
              _isDigit(source.codeUnitAt(i + 1)))) {
        i = _scanNumber(source, i);
        tokens.add(
          Token(TokenKind.number, start, i, source.substring(start, i)),
        );
        continue;
      }

      // Delimiters & punctuation
      switch (ch) {
        case 40: // (
          i++;
          tokens.add(Token(TokenKind.lparen, start, i, '('));
          continue;
        case 41: // )
          i++;
          tokens.add(Token(TokenKind.rparen, start, i, ')'));
          continue;
        case 91: // [
          i++;
          tokens.add(Token(TokenKind.lbracket, start, i, '['));
          continue;
        case 93: // ]
          i++;
          tokens.add(Token(TokenKind.rbracket, start, i, ']'));
          continue;
        case 123: // {
          i++;
          tokens.add(Token(TokenKind.lbrace, start, i, '{'));
          continue;
        case 125: // }
          i++;
          tokens.add(Token(TokenKind.rbrace, start, i, '}'));
          continue;
        case 44: // ,
          i++;
          tokens.add(Token(TokenKind.comma, start, i, ','));
          continue;
        case 59: // ;
          i++;
          tokens.add(Token(TokenKind.semicolon, start, i, ';'));
          continue;
        case 58: // : or :=
          if (i + 1 < len && source.codeUnitAt(i + 1) == 61 /* = */ ) {
            i += 2;
            tokens.add(Token(TokenKind.operator, start, i, ':='));
          } else {
            i++;
            tokens.add(Token(TokenKind.colon, start, i, ':'));
          }
          continue;
      }

      // Multi-char operators
      if (i + 1 < len) {
        final two = source.substring(i, i + 2);
        if (two == '**' ||
            two == '<=' ||
            two == '>=' ||
            two == '!=' ||
            two == '==' ||
            two == '->') {
          i += 2;
          tokens.add(Token(TokenKind.operator, start, i, two));
          continue;
        }
      }

      // Single-char ASCII & Unicode operators
      final charStr = source[i];
      if (_operatorChars.contains(charStr)) {
        i++;
        tokens.add(Token(TokenKind.operator, start, i, charStr));
        continue;
      }

      // Constants that are single-char Unicode symbols (π, ∞)
      if (charStr == 'π' || charStr == '∞') {
        i++;
        tokens.add(Token(TokenKind.constant, start, i, charStr));
        continue;
      }

      // Identifier (variable, boolean, constant, command, func, or paramLabel)
      if (!_isSymbolChar(ch)) {
        i++;
        while (i < len) {
          final c = source.codeUnitAt(i);
          if (_isHorizontalSpace(c) || c == 10 || c == 13 || _isSymbolChar(c)) {
            break;
          }
          i++;
        }
        final text = source.substring(start, i);

        // Check if followed by `:` (and not `:=`) -> paramLabel
        var look = i;
        while (look < len && _isHorizontalSpace(source.codeUnitAt(look))) {
          look++;
        }
        final isParamLabel =
            look < len &&
            source.codeUnitAt(look) == 58 /* : */ &&
            (look + 1 >= len || source.codeUnitAt(look + 1) != 61 /* = */ );

        final TokenKind kind;
        if (isParamLabel) {
          kind = TokenKind.paramLabel;
        } else if (text == 'true' || text == 'false') {
          kind = TokenKind.boolean;
        } else if (defaultConstants.contains(text)) {
          kind = TokenKind.constant;
        } else if (commands.contains(text)) {
          kind = TokenKind.command;
        } else if (userFuncs.contains(text)) {
          kind = TokenKind.userFunc;
        } else if (mathFuncs.contains(text)) {
          kind = TokenKind.mathFunc;
        } else {
          // Whether bound or free, classify as variable
          kind = TokenKind.variable;
          if (boundVars.contains(text)) {
            // Valid bound variable
          }
        }
        tokens.add(Token(kind, start, i, text));
        continue;
      }

      // Fallback unrecognized character
      i++;
      tokens.add(Token(TokenKind.error, start, i, charStr));
    }

    return tokens;
  }

  static int _scanNumber(String source, int start) {
    final len = source.length;
    var i = start;
    while (i < len && _isDigit(source.codeUnitAt(i))) {
      i++;
    }
    if (i < len && source.codeUnitAt(i) == 46 /* . */ ) {
      i++;
      while (i < len && _isDigit(source.codeUnitAt(i))) {
        i++;
      }
    }
    if (i < len &&
        (source.codeUnitAt(i) == 101 || source.codeUnitAt(i) == 69)) {
      var expPos = i + 1;
      if (expPos < len &&
          (source.codeUnitAt(expPos) == 43 ||
              source.codeUnitAt(expPos) == 45)) {
        expPos++;
      }
      if (expPos < len && _isDigit(source.codeUnitAt(expPos))) {
        i = expPos;
        while (i < len && _isDigit(source.codeUnitAt(i))) {
          i++;
        }
      }
    }
    return i;
  }

  static bool _isHorizontalSpace(int ch) => ch == 32 || ch == 9;

  static bool _isDigit(int ch) => ch >= 48 && ch <= 57;

  static const Set<String> _operatorChars = {
    '+',
    '-',
    '*',
    '/',
    '^',
    'ˆ',
    '\u0302',
    '‸',
    '＾',
    '=',
    '<',
    '>',
    '!',
    '≤',
    '≥',
    '≠',
    '×',
    '·',
    '÷',
    '−',
    '–',
    '√',
    '²',
    '³',
    '⁴',
  };

  static const String _symbolChars =
      '+-*/^ˆ\u0302‸＾()[]{},;:.=<>!&|~?@#\$%\\\'"`´¨˜−–×·÷≤≥≠²³⁴√π∞';

  static bool _isSymbolChar(int ch) =>
      _symbolChars.contains(String.fromCharCode(ch));
}
