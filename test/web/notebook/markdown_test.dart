import 'dart:io';

import 'package:checks/checks.dart';
import 'package:data/symbolic.dart';
import 'package:test/scaffolding.dart';

import '../../../web/notebook/src/engine/evaluator.dart';
import '../../../web/notebook/src/language/markdown.dart';
import '../../../web/notebook/src/model/examples.dart';
import '../../../web/notebook/src/model/notebook.dart';
import '../../../web/notebook/src/model/value.dart';
import '../../../web/notebook/src/ui/markdown_render.dart';
import '../../../web/shared/html.dart';

void main() {
  group('MarkdownParser', () {
    test('parses headings, lists, code blocks, display math, and tables', () {
      const md = '''
# Heading 1

Paragraph with **bold**, *italic*, `code`, \$x^2 + 1\$, and {{r[1]}}.

\$\$
\\int_0^1 x^2 dx
\$\$

- item 1
- item 2

| A | B |
|---|---|
| 1 | 2 |

```math
diff(sin(x), x)
```
''';
      final blocks = MarkdownParser.parseBlocks(md);
      check(blocks.whereType<MdHeading>().length).equals(1);
      check(blocks.whereType<MdParagraph>().length).equals(1);
      check(blocks.whereType<MdDisplayMath>().length).equals(1);
      check(blocks.whereType<MdUnorderedList>().length).equals(1);
      check(blocks.whereType<MdTable>().length).equals(1);
      check(blocks.whereType<MdCodeBlock>().length).equals(1);

      final para = blocks.whereType<MdParagraph>().first;
      check(para.inlines.whereType<MdBold>().length).equals(1);
      check(para.inlines.whereType<MdItalic>().length).equals(1);
      check(para.inlines.whereType<MdCodeSpan>().length).equals(1);
      check(para.inlines.whereType<MdInlineMath>().length).equals(1);
      final interp = para.inlines.whereType<MdInterpolation>().first;
      check(interp.resultId).equals(1);
    });

    test('extracts result and symbol references', () {
      final refs = MarkdownParser.extractReferences(
        'Value {{r[2]}} and {{alpha}} plus {{r[5]}}.',
      );
      check(refs.results).unorderedEquals({2, 5});
      check(refs.symbols).unorderedEquals({'alpha'});
    });

    test('renders all curated example MathML without fallback and evaluates all code blocks', () {
      final rawJson = File('web/notebook/examples.json').readAsStringSync();
      final examples = NotebookExample.parseJson(rawJson);
      check(examples.length).equals(10);
      for (final example in examples) {
        final doc = NotebookDocument()..loadFromMarkdown(example.markdown);
        final evaluator = NotebookEvaluator(env: doc.env);
        for (final cell in doc.cells) {
          switch (cell) {
            case MathCell():
              final res = evaluator.evaluate(
                cell.source,
                lookupResult: doc.lookupResult,
                currentMathId: cell.id,
              );
              cell
                ..value = res.value
                ..assignedSymbol = res.assignedSymbol
                ..definedFunction = res.definedFunction;
              check(
                res.value is ErrorValue,
                because: '${example.id}: ${cell.source} (${res.value})',
              ).isFalse;
              if (res.value case final PlotValue plot) {
                for (final expr in plot.expressions) {
                  if (plot.isComplex) {
                    expr.toComplexFunction1D(plot.variable);
                  } else if (plot.plotKind == PlotKind.surface3d ||
                      plot.plotKind == PlotKind.heatmap2d ||
                      plot.plotKind == PlotKind.vectorField2d ||
                      plot.plotKind == PlotKind.ode2d) {
                    expr.toVectorFunction([
                      plot.variable,
                      plot.yVariable ?? 'y',
                    ]);
                  } else if (plot.plotKind == PlotKind.vectorField3d) {
                    expr.toVectorFunction([
                      plot.variable,
                      plot.yVariable ?? 'y',
                      'z',
                    ]);
                  } else {
                    expr.toFunction1D(plot.variable);
                  }
                }
              }
            case MarkdownCell():
              final html = MarkdownRenderer.renderToHtml(cell.source, doc);
              check(
                html.contains('nb-math-fallback'),
                because: '${example.id} markdown cell: ${cell.source}',
              ).isFalse;
              check(
                html.contains('nb-interp-missing'),
                because: '${example.id} missing interp: ${cell.source}',
              ).isFalse;
          }
        }
      }
    });

    test('escapeHtml escapes reserved HTML characters safely', () {
      check(
        escapeHtml('<script>"a" & \'b\'</script>'),
      ).equals('&lt;script&gt;&quot;a&quot; &amp; &#39;b&#39;&lt;/script&gt;');
    });
  });
}
