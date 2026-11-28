import 'dart:js_interop';

import 'package:data/symbolic.dart';
import 'package:web/web.dart' as web;

import '../../../shared/html.dart';
import '../engine/commands.dart';
import '../model/environment.dart';
import 'highlighter.dart';
import 'icons.dart';

/// Active tab of [RightSidebar].
enum RightSidebarTab { text, math }

/// Docked right reference sidebar with two tabs (`Text` Markdown/MathML guide
/// and `Math` syntax & function reference).
///
/// Stays open persistently on desktop and becomes a full-screen panel on
/// mobile, closing on mobile when inserting examples.
final class RightSidebar {
  new({
    required this.registry,
    required this.env,
    required this.onInsertMathExample,
    required this.onInsertTextExample,
    required this.onMobileExampleInserted,
  }) {
    _buildDom();
  }

  final CommandRegistry registry;
  final Environment env;
  final void Function(String code) onInsertMathExample;
  final void Function(String markdown) onInsertTextExample;
  final void Function() onMobileExampleInserted;

  late final web.HTMLDivElement root;
  late final web.HTMLDivElement _textPane;
  late final web.HTMLDivElement _mathPane;
  late final web.HTMLInputElement _mathSearch;
  late final web.HTMLDivElement _mathSections;

  final Map<RightSidebarTab, web.HTMLButtonElement> _tabButtons = {};
  RightSidebarTab _activeTab = RightSidebarTab.math;

  void setTab(RightSidebarTab tab) {
    _activeTab = tab;
    for (final entry in _tabButtons.entries) {
      final isSel = entry.key == tab;
      entry.value
        ..classList.toggle('active', isSel)
        ..setAttribute('aria-selected', isSel ? 'true' : 'false');
    }
    _textPane.style.display = tab == RightSidebarTab.text ? 'flex' : 'none';
    _mathPane.style.display = tab == RightSidebarTab.math ? 'flex' : 'none';
  }

  void _buildDom() {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-shell';

    final header = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-tabs-bar';

    final tabs = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'segmented-control nb-tabs-group'
      ..setAttribute('role', 'tablist');

    tabs
      ..append(_buildTabButton(RightSidebarTab.text, 'Text', NbIcons.fileText))
      ..append(_buildTabButton(RightSidebarTab.math, 'Math', NbIcons.bookOpen));

    header.append(tabs);

    _textPane = _buildTextPane();
    _mathPane = _buildMathPane();

    root
      ..append(header)
      ..append(_textPane)
      ..append(_mathPane);

    setTab(RightSidebarTab.math);
  }

  web.HTMLButtonElement _buildTabButton(
    RightSidebarTab tab,
    String label,
    String iconSvg,
  ) {
    final isSel = tab == _activeTab;
    final btn = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = isSel ? 'segmented-btn active' : 'segmented-btn'
      ..setAttribute('role', 'tab')
      ..setAttribute('aria-selected', isSel ? 'true' : 'false')
      ..innerHTML =
          '<span class="nb-tab-icon">$iconSvg</span><span>$label</span>'.toJS;
    btn.onclick = ((web.MouseEvent _) => setTab(tab)).toJS;
    _tabButtons[tab] = btn;
    return btn;
  }

  web.HTMLDivElement _buildTextPane() {
    final pane = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-pane nb-ref-pane'
      ..setAttribute('role', 'tabpanel');

    final mathSec = (web.document.createElement('section') as web.HTMLElement)
      ..className = 'nb-help-section';
    mathSec.append(
      (web.document.createElement('h4') as web.HTMLHeadingElement)
        ..textContent = 'Math & Live Interpolation',
    );
    const interpolationEntries = [
      (
        title: 'Inline Math',
        syntax: r'$sin(x)^2 + cos(x)^2 = 1$',
        desc: 'Inline static MathML parsed using symbolic syntax.',
      ),
      (
        title: 'Display Math',
        syntax: r'$$integrate(exp(-x^2), x)$$',
        desc: 'Centered display MathML block parsed using symbolic syntax.',
      ),
      (
        title: 'Live Cell Output',
        syntax: '{{r[1]}}',
        desc: 'Inserts the evaluated output of cell r[n] and marks prose stale if updated.',
      ),
      (
        title: 'Live Variable',
        syntax: '{{alpha}}',
        desc: 'Inserts the current MathML value bound to variable alpha.',
      ),
    ];
    for (final entry in interpolationEntries) {
      final item = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-help-item'
        ..innerHTML =
            '<div class="nb-help-item-title">${escapeHtml(entry.title)}</div>'
                    '<div class="nb-help-doc">${escapeHtml(entry.desc)}</div>'
                    '<div class="nb-ref-inline-code"><code>${escapeHtml(entry.syntax)}</code></div>'
                .toJS;
      mathSec.append(item);
    }
    final mathExBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-help-ex-btn'
          ..title = 'Insert math prose example'
          ..innerHTML =
              '<code>${escapeHtml(r'''The derivative is $diff(f(x), x)$, and cell `r[1]` evaluates to {{r[1]}}.

$$integrate(x^2, x) = x^3 / 3$$''')}</code>'
                  .toJS
          ..onclick = ((web.MouseEvent _) {
            onInsertTextExample(r'''The derivative is $diff(f(x), x)$, and cell `r[1]` evaluates to {{r[1]}}.

$$integrate(x^2, x) = x^3 / 3$$''');
            onMobileExampleInserted();
          }).toJS;
    mathSec.append(mathExBtn);
    pane.append(mathSec);

    final sections =
        <
          ({
            String title,
            List<({String title, String syntax, String desc, String snippet})>
            items,
          })
        >[
          (
            title: 'Structure & Headings',
            items: [
              (
                title: 'Headings',
                syntax: '# Heading 1\n## Heading 2\n### Heading 3',
                desc: 'Section titles (also listed in the Structure tab).',
                snippet: '## Section Overview\n\nWrite concise notes alongside calculations.',
              ),
              (
                title: 'Blockquote',
                syntax: '> Quoted note or theorem',
                desc: 'Highlighted callout paragraph.',
                snippet: "> **Note:** Use `assume(x, 'positive')` to simplify radicals.",
              ),
              (
                title: 'Horizontal Rule',
                syntax: '---',
                desc: 'Horizontal section divider.',
                snippet: '---',
              ),
            ],
          ),
          (
            title: 'Inline Formatting & Links',
            items: [
              (
                title: 'Emphasis & Inline Code',
                syntax: '**bold**, *italic*, ~~strike~~, `code`',
                desc: 'Typographic emphasis and monospace inline code.',
                snippet: 'Compute the **exact** result using `simplify(x)` or *numerical* fallback.',
              ),
              (
                title: 'Hyperlinks',
                syntax: '[Label](https://example.com)',
                desc: 'External link inside text paragraphs.',
                snippet: 'See [Effective Dart](https://dart.dev/effective-dart) for style conventions.',
              ),
            ],
          ),
          (
            title: 'Lists, Tables & Code',
            items: [
              (
                title: 'Ordered & Bullet Lists',
                syntax: '- Bullet item\n1. Numbered item',
                desc: 'Unordered and ordered lists.',
                snippet: '1. Define \$f(x)\$\n2. Differentiate with `diff(f(x), x)`\n3. Plot over `-pi..pi`',
              ),
              (
                title: 'Tables',
                syntax: '| Method | Order |\n| --- | --- |\n| RK4 | 4 |',
                desc: 'Pipe-delimited Markdown tables.',
                snippet: '| Method | Convergence | Domain |\n| --- | --- | --- |\n| Bisection | Linear | Bracketed |\n| Brent | Superlinear | Bracketed |',
              ),
              (
                title: 'Math Code Block',
                syntax: '```math\nsin(x)^2 + cos(x)^2\n```',
                desc: 'Fenced math block (used when importing or exporting .md notebooks).',
                snippet: '```math\ntaylor(sin(x), x, order: 7)\n```',
              ),
            ],
          ),
        ];

    for (final sec in sections) {
      final secEl = (web.document.createElement('section') as web.HTMLElement)
        ..className = 'nb-help-section';
      secEl.append(
        (web.document.createElement('h4') as web.HTMLHeadingElement)
          ..textContent = sec.title,
      );
      for (final item in sec.items) {
        final row = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-item';
        row.innerHTML =
            '<div class="nb-help-item-title">${escapeHtml(item.title)}</div>'
                    '<div class="nb-help-doc">${escapeHtml(item.desc)}</div>'
                .toJS;
        final btn =
            (web.document.createElement('button') as web.HTMLButtonElement)
              ..type = 'button'
              ..className = 'nb-help-ex-btn'
              ..title = 'Insert example'
              ..innerHTML = '<code>${escapeHtml(item.syntax)}</code>'.toJS
              ..onclick = ((web.MouseEvent _) {
                onInsertTextExample(item.snippet);
                onMobileExampleInserted();
              }).toJS;
        row.append(btn);
        secEl.append(row);
      }
      pane.append(secEl);
    }

    return pane;
  }

  web.HTMLDivElement _buildMathPane() {
    final pane = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-sidebar-pane nb-ref-pane'
      ..setAttribute('role', 'tabpanel');

    _mathSearch = (web.document.createElement('input') as web.HTMLInputElement)
      ..type = 'search'
      ..className = 'nb-ref-search'
      ..setAttribute('aria-label', 'Filter commands and functions')
      ..placeholder = 'Filter commands & functions...';
    _mathSearch.oninput = ((web.Event _) {
      _renderMathSections(_mathSearch.value);
    }).toJS;

    _mathSections = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-ref-sections';

    pane
      ..append(_mathSearch)
      ..append(_mathSections);

    _renderMathSections('');
    return pane;
  }

  void _renderMathSections(String query) {
    final q = query.trim().toLowerCase();
    _mathSections.replaceChildren(<JSAny>[].toJS);

    if (q.isEmpty) {
      final syntaxSec =
          (web.document.createElement('section') as web.HTMLElement)
            ..className = 'nb-help-section';
      syntaxSec.append(
        (web.document.createElement('h4') as web.HTMLHeadingElement)
          ..textContent = 'Syntax',
      );
      const syntaxItems = [
        (code: 'a := expr', desc: 'Bind a variable (use = inside equations).'),
        (
          code: 'f(x, [a = 1], {k: 2}) := ...',
          desc: 'Define a function with optional or named parameters.',
        ),
        (
          code: 'start..end',
          desc: 'First-class range value (such as 0..pi or re: -2..2).',
        ),
        (code: '[1, 2, 3]', desc: 'Vector literal.'),
        (code: '[[a, b], [c, d]]', desc: 'Matrix literal (row-major).'),
        (code: 'r[1]', desc: 'Reference output of cell 1 (absolute).'),
        (code: 'r[-1]', desc: 'Reference output of previous cell (relative).'),
        (code: 'pi, e, i, infinity', desc: 'Built-in mathematical constants.'),
        (code: '// comment', desc: 'Single-line comment.'),
      ];
      for (final entry in syntaxItems) {
        syntaxSec.append(
          (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-ref-kv'
            ..innerHTML =
                '<code>${escapeHtml(entry.code)}</code>'
                        '<span>${escapeHtml(entry.desc)}</span>'
                    .toJS,
        );
      }
      _mathSections.append(syntaxSec);

      final shortcutsSec =
          (web.document.createElement('section') as web.HTMLElement)
            ..className = 'nb-help-section';
      shortcutsSec.append(
        (web.document.createElement('h4') as web.HTMLHeadingElement)
          ..textContent = 'Keyboard Shortcuts',
      );
      const shortcuts = [
        (keys: ['Shift', 'Enter'], desc: 'Evaluate active cell'),
        (keys: ['Alt', 'Enter'], desc: 'Evaluate numerically'),
        (keys: ['Cmd/Ctrl', 'K'], desc: 'Open command palette'),
        (keys: ['Cmd/Ctrl', 'Z'], desc: 'Undo last edit'),
        (keys: ['Cmd/Ctrl', 'Shift', 'Z'], desc: 'Redo edit'),
        (keys: ['Cmd/Ctrl', 'Shift', 'M'], desc: 'Insert new math cell'),
      ];
      final scList = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-shortcut-list';
      for (final sc in shortcuts) {
        final keyHtml = [
          for (final k in sc.keys) '<kbd class="nb-kbd">${escapeHtml(k)}</kbd>',
        ].join('<span class="nb-shortcut-plus">+</span>');
        scList.append(
          (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-shortcut-row'
            ..innerHTML =
                '<span>${escapeHtml(sc.desc)}</span>'
                        '<span class="nb-shortcut-keys">$keyHtml</span>'
                    .toJS,
        );
      }
      shortcutsSec.append(scList);
      _mathSections.append(shortcutsSec);
    }

    final grouped = <CommandCategory, List<Command>>{};
    for (final cmd in registry.all) {
      if (q.isNotEmpty &&
          !cmd.name.toLowerCase().contains(q) &&
          !cmd.doc.toLowerCase().contains(q) &&
          !cmd.category.label.toLowerCase().contains(q)) {
        continue;
      }
      grouped.putIfAbsent(cmd.category, () => []).add(cmd);
    }

    for (final entry in grouped.entries) {
      final sec = (web.document.createElement('section') as web.HTMLElement)
        ..className = 'nb-help-section';
      sec.append(
        (web.document.createElement('h4') as web.HTMLHeadingElement)
          ..textContent = entry.key.label,
      );

      for (final cmd in entry.value) {
        final item = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-item';
        final fullSig = cmd.signature.format(cmd.name);
        final paramsPart = fullSig.startsWith(cmd.name)
            ? fullSig.substring(cmd.name.length)
            : '';
        final sigEl = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-sig'
          ..innerHTML =
              '<span class="nb-help-fn-name">${escapeHtml(cmd.name)}</span>'
                      '<span class="nb-help-fn-params">${escapeHtml(paramsPart)}</span>'
                  .toJS;
        final docEl = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-doc'
          ..textContent = cmd.doc;
        item
          ..append(sigEl)
          ..append(docEl);

        if (cmd.examples.isNotEmpty) {
          final exRow =
              (web.document.createElement('div') as web.HTMLDivElement)
                ..className = 'nb-help-examples';
          for (final ex in cmd.examples) {
            final exBtn =
                (web.document.createElement('button') as web.HTMLButtonElement)
                  ..type = 'button'
                  ..className = 'nb-help-ex-btn'
                  ..title = 'Insert and run example'
                  ..innerHTML =
                      '<code>${SyntaxHighlighter.highlightMathHtml(ex, registry: registry, env: env)}</code>'
                          .toJS;
            exBtn.onclick = ((web.MouseEvent _) {
              onInsertMathExample(ex);
              onMobileExampleInserted();
            }).toJS;
            exRow.append(exBtn);
          }
          item.append(exRow);
        }
        sec.append(item);
      }
      _mathSections.append(sec);
    }

    final cmdNames = registry.allNames;
    final fnItems = <({String name, String params, String doc, String ex})>[];
    for (final fn in ExprSyntax.standardFunctions) {
      if (cmdNames.contains(fn.name)) continue;
      if (q.isNotEmpty &&
          !fn.name.toLowerCase().contains(q) &&
          !fn.doc.toLowerCase().contains(q)) {
        continue;
      }
      final params = '(${fn.params.join(', ')})';
      fnItems.add((
        name: fn.name,
        params: params,
        doc: fn.doc,
        ex: '${fn.name}$params',
      ));
    }

    if (fnItems.isNotEmpty) {
      final sec = (web.document.createElement('section') as web.HTMLElement)
        ..className = 'nb-help-section';
      sec.append(
        (web.document.createElement('h4') as web.HTMLHeadingElement)
          ..textContent = 'Mathematical Functions',
      );
      for (final fn in fnItems) {
        final item = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-item';
        item.innerHTML =
            '<div class="nb-help-sig">'
                    '<span class="nb-help-fn-name">${escapeHtml(fn.name)}</span>'
                    '<span class="nb-help-fn-params">${escapeHtml(fn.params)}</span>'
                    '</div>'
                    '<div class="nb-help-doc">${escapeHtml(fn.doc)}</div>'
                .toJS;
        final exRow = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-examples';
        final exBtn =
            (web.document.createElement('button') as web.HTMLButtonElement)
              ..type = 'button'
              ..className = 'nb-help-ex-btn'
              ..title = 'Insert example template'
              ..innerHTML =
                  '<code>${SyntaxHighlighter.highlightMathHtml(fn.ex, registry: registry, env: env)}</code>'
                      .toJS;
        exBtn.onclick = ((web.MouseEvent _) {
          onInsertMathExample(fn.ex);
          onMobileExampleInserted();
        }).toJS;
        exRow.append(exBtn);
        item.append(exRow);
        sec.append(item);
      }
      _mathSections.append(sec);
    }

    if (_mathSections.children.length == 0) {
      _mathSections.append(
        (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-outline-empty'
          ..textContent = 'No matching commands or functions.',
      );
    }
  }
}
