import 'package:data/symbolic.dart';

import '../../../shared/html.dart';
import '../engine/commands.dart';
import '../language/markdown.dart';
import '../model/notebook.dart';
import 'highlighter.dart';

/// Renders [MdBlock] / [MdInline] ASTs into clean semantic HTML with native
/// MathML (`$...$`, `$$...$$`), syntax-highlighted `math` code blocks, and
/// live `{{...}}` document interpolations.
final class MarkdownRenderer {
  const new _();

  static String renderToHtml(
    String source,
    NotebookDocument doc, {
    CommandRegistry? registry,
  }) {
    final blocks = MarkdownParser.parseBlocks(source);
    if (blocks.isEmpty) {
      return '<p class="nb-md-empty">Empty text cell — click to write Markdown or \$math\$.</p>';
    }
    return [for (final b in blocks) _renderBlock(b, doc, registry)].join('\n');
  }

  static String _renderBlock(
    MdBlock block,
    NotebookDocument doc,
    CommandRegistry? registry,
  ) => switch (block) {
    MdHeading(:final level, :final inlines) =>
      '<h$level>${_renderInlines(inlines, doc)}</h$level>',
    MdParagraph(:final inlines) => '<p>${_renderInlines(inlines, doc)}</p>',
    MdCodeBlock(:final language, :final code) =>
      language == 'math'
          ? '<pre class="nb-md-code"><code>${SyntaxHighlighter.highlightMathHtml(code, registry: registry, env: doc.env)}</code></pre>'
          : '<pre class="nb-md-code"><code>${escapeHtml(code)}</code></pre>',
    MdBlockquote(:final blocks) =>
      '<blockquote>${[for (final b in blocks) _renderBlock(b, doc, registry)].join('\n')}</blockquote>',
    MdUnorderedList(:final items) =>
      '<ul>${[for (final item in items) '<li>${_renderInlines(item, doc)}</li>'].join()}</ul>',
    MdOrderedList(:final items, :final start) =>
      '<ol start="$start">${[for (final item in items) '<li>${_renderInlines(item, doc)}</li>'].join()}</ol>',
    MdTable(:final headers, :final rows) => () {
      final th = [for (final h in headers) '<th>${_renderInlines(h, doc)}</th>']
          .join();
      final trs = [
        for (final r in rows)
          '<tr>${[for (final cell in r) '<td>${_renderInlines(cell, doc)}</td>'].join()}</tr>',
      ].join();
      return '<table><thead><tr>$th</tr></thead><tbody>$trs</tbody></table>';
    }(),
    MdHorizontalRule() => '<hr>',
    MdDisplayMath(:final exprText) =>
      '<div class="nb-md-display-math">${_renderMathMl(exprText, display: true)}</div>',
  };

  static String _renderInlines(List<MdInline> inlines, NotebookDocument doc) =>
      [for (final i in inlines) _renderInline(i, doc)].join();

  static String _renderInline(
    MdInline inline,
    NotebookDocument doc,
  ) => switch (inline) {
    MdText(:final text) => escapeHtml(text),
    MdBold(:final children) =>
      '<strong>${_renderInlines(children, doc)}</strong>',
    MdItalic(:final children) => '<em>${_renderInlines(children, doc)}</em>',
    MdStrike(:final children) => '<del>${_renderInlines(children, doc)}</del>',
    MdCodeSpan(:final code) => '<code>${escapeHtml(code)}</code>',
    MdLink(:final label, :final url) =>
      '<a href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer">${_renderInlines(label, doc)}</a>',
    MdInlineMath(:final exprText) => _renderMathMl(exprText, display: false),
    MdInterpolation(:final target, :final resultId, :final symbol) => () {
      final val = resultId != null
          ? doc.lookupResult(resultId)
          : (symbol != null ? doc.env.variables[symbol] : null);
      if (val == null) {
        return '<span class="nb-interp nb-interp-missing" title="Unresolved: ${escapeHtml(target)}">{{${escapeHtml(target)}}}</span>';
      }
      return '<span class="nb-interp" title="${escapeHtml(target)}">${val.toMathMl(display: false)}</span>';
    }(),
  };

  static String _renderMathMl(String exprText, {required bool display}) {
    final parsed = Expr.tryParse(exprText);
    if (parsed != null) {
      return parsed.toMathMl(display: display);
    }
    return '<code class="nb-math-fallback">${escapeHtml(exprText)}</code>';
  }
}
