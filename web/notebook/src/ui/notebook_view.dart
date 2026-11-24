import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/notebook.dart';
import '../worker/engine_client.dart';
import 'markdown_cell_view.dart';
import 'math_cell_view.dart';

/// Main document-first notebook canvas rendering ordered [MarkdownCell]s and
/// [MathCell]s in a centered `820px` editorial column.
final class NotebookView {
  new(this.client) {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-document';
    render();
  }

  final EngineClient client;
  late final web.HTMLDivElement root;

  String? _focusedUid;
  final List<MathCellView> _activeMathViews = [];

  String? get focusedUid => _focusedUid;

  void focusCell(String? uid, {bool moveToEnd = true}) {
    _focusedUid = uid;
    render(focusEditorUid: uid, moveToEnd: moveToEnd);
  }

  void render({String? focusEditorUid, bool moveToEnd = true}) {
    for (final v in _activeMathViews) {
      v.dispose();
    }
    _activeMathViews.clear();
    root.innerHTML = ''.toJS;

    final doc = client.document;

    // Minimal stale banner only when downstream cells need recomputation
    final staleCount = doc.cells
        .where(
          (c) => (c is MathCell && c.stale) || (c is MarkdownCell && c.stale),
        )
        .length;
    if (staleCount > 0) {
      final banner = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-stale-banner';
      final msg = (web.document.createElement('span') as web.HTMLSpanElement)
        ..textContent =
            '$staleCount dependent cell${staleCount == 1 ? '' : 's'} out of date';
      final btn =
          (web.document.createElement('button') as web.HTMLButtonElement)
            ..type = 'button'
            ..className = 'nb-stale-btn'
            ..textContent = 'Recompute stale';
      btn.onclick = ((web.MouseEvent _) {
        client.recomputeStale();
      }).toJS;
      banner
        ..append(msg)
        ..append(btn);
      root.append(banner);
    }

    if (doc.cells.isEmpty) {
      root.append(_buildEmptyState());
      return;
    }

    root.append(_buildInsertDivider(0));

    MathCellView? targetMathView;
    MarkdownCellView? targetMdView;

    for (var i = 0; i < doc.cells.length; i++) {
      final cell = doc.cells[i];
      final isActive = cell.uid == _focusedUid;

      switch (cell) {
        case MarkdownCell():
          late final MarkdownCellView mdView;
          mdView = MarkdownCellView(
            cell: cell,
            document: doc,
            registry: client.registry,
            isEditing: isActive,
            onStartEdit: () => focusCell(cell.uid),
            onCommit: (src, {required bool advance}) async {
              await client.updateMarkdown(cell.uid, src);
              if (advance) {
                if (i + 1 < doc.cells.length) {
                  focusCell(doc.cells[i + 1].uid);
                } else {
                  final nextUid = await client.evalCell('');
                  focusCell(nextUid);
                }
              } else {
                _focusedUid = null;
                render();
              }
            },
            onMoveUp: () async {
              if (i > 0) await client.moveCell(cell.uid, i - 1);
            },
            onMoveDown: () async {
              if (i + 1 < doc.cells.length) {
                await client.moveCell(cell.uid, i + 1);
              }
            },
            onConvertToMath: () async {
              final nextUid = await client.convertCell(cell.uid);
              focusCell(nextUid);
            },
            onDelete: () async {
              _focusedUid = null;
              await client.deleteCell(cell.uid);
            },
          );
          if (focusEditorUid == cell.uid) targetMdView = mdView;
          root.append(mdView.root);

        case MathCell():
          final mathView = MathCellView(
            cell: cell,
            env: doc.env,
            registry: client.registry,
            isFocused: isActive,
            onFocus: () => focusCell(cell.uid),
            onRun: (src, {required bool advance, required bool approx}) async {
              await client.evalCell(src, uid: cell.uid, forceApprox: approx);
              if (advance) {
                final idx = doc.indexOfUid(cell.uid);
                if (idx >= 0 && idx + 1 < doc.cells.length) {
                  focusCell(doc.cells[idx + 1].uid);
                } else {
                  final nextUid = await client.evalCell('');
                  focusCell(nextUid);
                }
              } else {
                focusCell(cell.uid);
              }
            },
            onMoveUp: () async {
              if (i > 0) await client.moveCell(cell.uid, i - 1);
            },
            onMoveDown: () async {
              if (i + 1 < doc.cells.length) {
                await client.moveCell(cell.uid, i + 1);
              }
            },
            onConvertToText: () async {
              final nextUid = await client.convertCell(cell.uid);
              focusCell(nextUid);
            },
            onDelete: () async {
              _focusedUid = null;
              await client.deleteCell(cell.uid);
            },
            onBlurExit: () {
              _focusedUid = null;
              render();
            },
          );
          _activeMathViews.add(mathView);
          if (focusEditorUid == cell.uid) targetMathView = mathView;
          root.append(mathView.root);
      }

      root.append(_buildInsertDivider(i + 1));
    }

    // Mount plots after DOM attachment so boundingClientRect is non-zero
    for (final mv in _activeMathViews) {
      mv.mountRenderables();
    }
    targetMathView?.focusEditor(moveToEnd: moveToEnd);
    targetMdView?.focusEditor(moveToEnd: moveToEnd);
  }

  web.HTMLDivElement _buildInsertDivider(int index) {
    final div = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-insert-divider';

    final actions = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-insert-actions';

    final addMath =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-insert-btn'
          ..textContent = '+ Math';
    addMath.onclick = ((web.MouseEvent _) async {
      final uid = await client.evalCell('', index: index);
      focusCell(uid);
    }).toJS;

    final sep = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-insert-sep'
      ..textContent = '·';

    final addText =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-insert-btn'
          ..textContent = '+ Text';
    addText.onclick = ((web.MouseEvent _) async {
      final uid = await client.insertMarkdown('', index: index);
      focusCell(uid);
    }).toJS;

    actions
      ..append(addMath)
      ..append(sep)
      ..append(addText);
    div.append(actions);
    return div;
  }

  web.HTMLDivElement _buildEmptyState() {
    final box = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-empty-state';

    final heading = (web.document.createElement('h2') as web.HTMLHeadingElement)
      ..textContent = 'Symbolic Notebook';
    final sub = (web.document.createElement('p') as web.HTMLParagraphElement)
      ..textContent =
          'Combine Markdown prose, native MathML, and live symbolic computation.';

    final row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-empty-actions';

    final startMath =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-primary-btn'
          ..textContent = 'New Math Cell';
    startMath.onclick = ((web.MouseEvent _) async {
      final uid = await client.evalCell('');
      focusCell(uid);
    }).toJS;

    final startText =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-secondary-btn'
          ..textContent = 'New Text Cell';
    startText.onclick = ((web.MouseEvent _) async {
      final uid = await client.insertMarkdown('');
      focusCell(uid);
    }).toJS;

    final loadSample =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-secondary-btn'
          ..textContent = 'Load Calculus Tour';
    loadSample.onclick = ((web.MouseEvent _) async {
      await client.importMarkdown(_starterTemplate);
      _focusedUid = null;
      render();
    }).toJS;

    row
      ..append(startMath)
      ..append(startText)
      ..append(loadSample);
    box
      ..append(heading)
      ..append(sub)
      ..append(row);
    return box;
  }

  static const String _starterTemplate = '''
# Harmonic Oscillator & Symbolic Calculus

Consider a damped wave function \$f(x) = e^{-x/5} \\cdot \\sin(2 x)\$ on \$[0, 4\\pi]\$.

```math
f(x) := exp(-x/5) * sin(2*x)
```

Its exact derivative is {{r[1]}}'s rate of change:

```math
diff(f(x), x)
```

Visualizing both the function and its envelope:

```math
plot([f(x), exp(-x/5), -exp(-x/5)], x, from: 0, to: 12, title: 'Damped Oscillation')
```
''';
}
