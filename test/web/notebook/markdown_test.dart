import 'package:checks/checks.dart';
import 'package:test/scaffolding.dart';

import '../../../web/notebook/src/language/markdown.dart';

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
  });
}
