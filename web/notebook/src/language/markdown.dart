import 'package:petitparser/petitparser.dart';

/// Block-level Markdown AST node.
sealed class MdBlock {
  const new();
}

final class MdHeading extends MdBlock {
  const new(this.level, this.inlines);

  final int level;
  final List<MdInline> inlines;
}

final class MdParagraph extends MdBlock {
  const new(this.inlines);

  final List<MdInline> inlines;
}

final class MdCodeBlock extends MdBlock {
  const new(this.language, this.code);

  final String language;
  final String code;
}

final class MdBlockquote extends MdBlock {
  const new(this.blocks);

  final List<MdBlock> blocks;
}

final class MdUnorderedList extends MdBlock {
  const new(this.items);

  final List<List<MdInline>> items;
}

final class MdOrderedList extends MdBlock {
  const new(this.items, {this.start = 1});

  final List<List<MdInline>> items;
  final int start;
}

final class MdTable extends MdBlock {
  const new(this.headers, this.rows);

  final List<List<MdInline>> headers;
  final List<List<List<MdInline>>> rows;
}

final class MdHorizontalRule extends MdBlock {
  const new();
}

final class MdDisplayMath extends MdBlock {
  const new(this.exprText);

  final String exprText;
}

/// Inline-level Markdown AST node.
sealed class MdInline {
  const new();
}

final class MdText extends MdInline {
  const new(this.text);

  final String text;
}

final class MdBold extends MdInline {
  const new(this.children);

  final List<MdInline> children;
}

final class MdItalic extends MdInline {
  const new(this.children);

  final List<MdInline> children;
}

final class MdStrike extends MdInline {
  const new(this.children);

  final List<MdInline> children;
}

final class MdCodeSpan extends MdInline {
  const new(this.code);

  final String code;
}

final class MdLink extends MdInline {
  const new(this.label, this.url);

  final List<MdInline> label;
  final String url;
}

final class MdInlineMath extends MdInline {
  const new(this.exprText);

  final String exprText;
}

final class MdInterpolation extends MdInline {
  const new(this.target, {this.resultId, this.symbol});

  final String target;
  final int? resultId;
  final String? symbol;
}

/// Pure-Dart Markdown + inline/display math + live interpolation parser.
final class MarkdownParser {
  const new _();

  static final RegExp _headingRe = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _hrRe = RegExp(r'^(\*{3,}|-{3,}|_{3,})\s*$');
  static final RegExp _ulRe = RegExp(r'^[-*+]\s+(.*)$');
  static final RegExp _olRe = RegExp(r'^(\d+)\.\s+(.*)$');
  static final RegExp _interpRe = RegExp(r'\{\{\s*([^}]+?)\s*\}\}');
  static final RegExp _resultRefRe = RegExp(r'^r\[(\d+)\]$');

  /// Extracts `{{r[n]}}` result IDs and `{{var}}` symbol names referenced in
  /// a Markdown source string.
  static ({Set<int> results, Set<String> symbols}) extractReferences(
    String source,
  ) {
    final results = <int>{};
    final symbols = <String>{};
    for (final m in _interpRe.allMatches(source)) {
      final raw = m.group(1)!.trim();
      final rMatch = _resultRefRe.firstMatch(raw);
      if (rMatch != null) {
        results.add(int.parse(rMatch.group(1)!));
      } else if (raw.isNotEmpty) {
        symbols.add(raw);
      }
    }
    return (results: results, symbols: symbols);
  }

  /// Parses [source] into a list of [MdBlock] nodes.
  static List<MdBlock> parseBlocks(String source) {
    final lines = source.replaceAll('\r\n', '\n').split('\n');
    final blocks = <MdBlock>[];
    var i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        i++;
        continue;
      }

      // Fenced code block ```lang
      if (trimmed.startsWith('```')) {
        final lang = trimmed.substring(3).trim();
        i++;
        final codeLines = <String>[];
        while (i < lines.length && !lines[i].trim().startsWith('```')) {
          codeLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) i++; // consume closing ```
        blocks.add(MdCodeBlock(lang, codeLines.join('\n')));
        continue;
      }

      // Display math block $$...$$
      if (trimmed.startsWith(r'$$')) {
        if (trimmed.length > 4 && trimmed.endsWith(r'$$')) {
          blocks.add(
            MdDisplayMath(trimmed.substring(2, trimmed.length - 2).trim()),
          );
          i++;
          continue;
        }
        final firstRest = trimmed.substring(2).trim();
        final mathLines = <String>[if (firstRest.isNotEmpty) firstRest];
        i++;
        while (i < lines.length && !lines[i].trim().endsWith(r'$$')) {
          mathLines.add(lines[i]);
          i++;
        }
        if (i < lines.length) {
          final last = lines[i].trim();
          final beforeClose = last.substring(0, last.length - 2).trim();
          if (beforeClose.isNotEmpty) mathLines.add(beforeClose);
          i++;
        }
        blocks.add(MdDisplayMath(mathLines.join('\n').trim()));
        continue;
      }

      // Horizontal rule
      if (_hrRe.hasMatch(trimmed)) {
        blocks.add(const MdHorizontalRule());
        i++;
        continue;
      }

      // Heading
      final hMatch = _headingRe.firstMatch(trimmed);
      if (hMatch != null) {
        final level = hMatch.group(1)!.length;
        final text = hMatch.group(2)!.trim();
        blocks.add(MdHeading(level, parseInlines(text)));
        i++;
        continue;
      }

      // Blockquote
      if (trimmed.startsWith('>')) {
        final quoteLines = <String>[];
        while (i < lines.length && lines[i].trim().startsWith('>')) {
          final q = lines[i].trim().substring(1);
          quoteLines.add(q.startsWith(' ') ? q.substring(1) : q);
          i++;
        }
        blocks.add(MdBlockquote(parseBlocks(quoteLines.join('\n'))));
        continue;
      }

      // Table (header | separator | rows)
      if (trimmed.contains('|') &&
          i + 1 < lines.length &&
          _isTableSeparator(lines[i + 1])) {
        final headers = _splitTableRow(trimmed).map(parseInlines).toList();
        i += 2;
        final rows = <List<List<MdInline>>>[];
        while (i < lines.length &&
            lines[i].trim().contains('|') &&
            lines[i].trim().isNotEmpty) {
          rows.add(_splitTableRow(lines[i].trim()).map(parseInlines).toList());
          i++;
        }
        blocks.add(MdTable(headers, rows));
        continue;
      }

      // Unordered list
      if (_ulRe.hasMatch(trimmed)) {
        final items = <List<MdInline>>[];
        while (i < lines.length) {
          final m = _ulRe.firstMatch(lines[i].trim());
          if (m == null) break;
          items.add(parseInlines(m.group(1)!));
          i++;
        }
        blocks.add(MdUnorderedList(items));
        continue;
      }

      // Ordered list
      final olFirst = _olRe.firstMatch(trimmed);
      if (olFirst != null) {
        final start = int.parse(olFirst.group(1)!);
        final items = <List<MdInline>>[];
        while (i < lines.length) {
          final m = _olRe.firstMatch(lines[i].trim());
          if (m == null) break;
          items.add(parseInlines(m.group(2)!));
          i++;
        }
        blocks.add(MdOrderedList(items, start: start));
        continue;
      }

      // Paragraph (accumulate until blank line or block starter)
      final paraLines = <String>[line.trim()];
      i++;
      while (i < lines.length) {
        final next = lines[i].trim();
        if (next.isEmpty ||
            next.startsWith('```') ||
            next.startsWith(r'$$') ||
            next.startsWith('>') ||
            _headingRe.hasMatch(next) ||
            _hrRe.hasMatch(next) ||
            _ulRe.hasMatch(next) ||
            _olRe.hasMatch(next)) {
          break;
        }
        paraLines.add(next);
        i++;
      }
      blocks.add(MdParagraph(parseInlines(paraLines.join(' '))));
    }

    return blocks;
  }

  static final Parser<List<MdInline>> _inlineParser = _buildInlineParser();

  /// Parses inline Markdown spans including `$expr$` and `{{ref}}`.
  static List<MdInline> parseInlines(String text) {
    if (text.isEmpty) return const [];
    final res = _inlineParser.parse(text);
    if (res is Success<List<MdInline>>) {
      return _coalesceText(res.value);
    }
    return [MdText(text)];
  }

  static Parser<List<MdInline>> _buildInlineParser() {
    final inline = undefined<MdInline>();

    final codeSpan = seq3(
      char('`'),
      noneOf('`').plusString(),
      char('`'),
    ).map3((_, code, _) => MdCodeSpan(code));

    final inlineMath = seq3(
      char(r'$'),
      seq2(char(r'$').not(), any()).map2((_, c) => c).plusString(),
      char(r'$'),
    ).map3((_, expr, _) => MdInlineMath(expr.trim()));

    final interpolation =
        seq3(
          string('{{'),
          seq2(string('}}').not(), any()).map2((_, c) => c).plusString(),
          string('}}'),
        ).map3((_, raw, _) {
          final target = raw.trim();
          final rMatch = _resultRefRe.firstMatch(target);
          if (rMatch != null) {
            return MdInterpolation(
              target,
              resultId: int.parse(rMatch.group(1)!),
            );
          }
          return MdInterpolation(target, symbol: target);
        });

    final boldStar = seq3(
      string('**'),
      seq2(string('**').not(), inline).map2((_, node) => node).plus(),
      string('**'),
    ).map3((_, children, _) => MdBold(children));

    final boldUnder = seq3(
      string('__'),
      seq2(string('__').not(), inline).map2((_, node) => node).plus(),
      string('__'),
    ).map3((_, children, _) => MdBold(children));

    final strike = seq3(
      string('~~'),
      seq2(string('~~').not(), inline).map2((_, node) => node).plus(),
      string('~~'),
    ).map3((_, children, _) => MdStrike(children));

    final italicStar = seq3(
      char('*'),
      seq2(char('*').not(), inline).map2((_, node) => node).plus(),
      char('*'),
    ).map3((_, children, _) => MdItalic(children));

    final italicUnder = seq3(
      char('_'),
      seq2(char('_').not(), inline).map2((_, node) => node).plus(),
      char('_'),
    ).map3((_, children, _) => MdItalic(children));

    final link = seq6(
      char('['),
      seq2(char(']').not(), inline).map2((_, node) => node).plus(),
      char(']'),
      char('('),
      noneOf(')').starString(),
      char(')'),
    ).map6((_, label, _, _, url, _) => MdLink(label, url));

    final escaped = seq2(char(r'\'), any()).map2((_, c) => MdText(c));
    final plainChar = any().map(MdText.new);

    inline.set(
      <Parser<MdInline>>[
        escaped,
        codeSpan,
        interpolation,
        inlineMath,
        link,
        boldStar,
        boldUnder,
        strike,
        italicStar,
        italicUnder,
        plainChar,
      ].toChoiceParser(),
    );

    return inline.star().end();
  }

  static List<MdInline> _coalesceText(List<MdInline> nodes) {
    final out = <MdInline>[];
    final buf = StringBuffer();
    void flush() {
      if (buf.isNotEmpty) {
        out.add(MdText(buf.toString()));
        buf.clear();
      }
    }

    for (final n in nodes) {
      if (n is MdText) {
        buf.write(n.text);
      } else {
        flush();
        out.add(n);
      }
    }
    flush();
    return out;
  }

  static bool _isTableSeparator(String line) {
    final trimmed = line.trim();
    if (!trimmed.contains('|')) return false;
    final stripped = trimmed.replaceAll('|', '').replaceAll(' ', '');
    return stripped.isNotEmpty && RegExp(r'^[-:]+$').hasMatch(stripped);
  }

  static List<String> _splitTableRow(String line) {
    var s = line.trim();
    if (s.startsWith('|')) s = s.substring(1);
    if (s.endsWith('|')) s = s.substring(0, s.length - 1);
    return [for (final cell in s.split('|')) cell.trim()];
  }
}
