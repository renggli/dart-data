import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/notebook.dart';
import '../worker/engine_client.dart';
import 'markdown_cell_view.dart';
import 'math_cell_view.dart';

/// Main document-first notebook canvas rendering ordered [MarkdownCell]s and
/// [MathCell]s in a centered `820px` editorial column.
///
/// Focus changes update only the affected cells in-place so plots never
/// flicker and scroll position stays stable.
final class NotebookView {
  new(this.client, {this.onFocusChanged}) {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-document';
    _attachOutsideClickBlur();
    render();
  }

  final EngineClient client;
  final void Function()? onFocusChanged;
  late final web.HTMLDivElement root;

  String? _focusedUid;
  final Map<String, MathCellView> _mathViews = {};
  final Map<String, MarkdownCellView> _mdViews = {};

  String? get focusedUid => _focusedUid;

  /// Switches focus to [uid] in-place without rebuilding the document DOM or
  /// recreating WebGL plots. Any unsaved Markdown draft on the previously
  /// focused cell is committed automatically.
  void focusCell(String? uid, {bool moveToEnd = true}) {
    final prevUid = _focusedUid;
    if (prevUid == uid) {
      if (uid != null) {
        _mathViews[uid]?.focusEditor(moveToEnd: moveToEnd);
        _mdViews[uid]?.focusEditor(moveToEnd: moveToEnd);
      }
      return;
    }

    // Commit unsaved Markdown edits cleanly when leaving a Markdown cell
    if (prevUid != null) {
      final prevMd = _mdViews[prevUid];
      if (prevMd != null && prevMd.isEditing) {
        final draft = prevMd.currentSource;
        prevMd.setEditing(false);
        if (draft != prevMd.cell.source) {
          unawaited(client.updateMarkdown(prevUid, draft));
        }
      }
      _mathViews[prevUid]?.setFocused(false);
    }

    _focusedUid = uid;

    if (uid != null) {
      final nextMath = _mathViews[uid];
      final nextMd = _mdViews[uid];
      if (nextMath != null) {
        nextMath.setFocused(true, focusInput: true, moveToEnd: moveToEnd);
      } else if (nextMd != null) {
        nextMd.setEditing(true, focusInput: true, moveToEnd: moveToEnd);
      } else {
        // Cell not yet mounted in DOM; fall back to full sync.
        render(focusEditorUid: uid, moveToEnd: moveToEnd);
        onFocusChanged?.call();
        return;
      }
    }

    onFocusChanged?.call();
  }

  /// Synchronizes the document DOM with `client.document`, preserving existing
  /// mounted cell views (and their WebGL plots) whenever possible.
  void render({String? focusEditorUid, bool moveToEnd = true}) {
    final doc = client.document;
    final byUid = {for (final c in doc.cells) c.uid: c};

    // Dispose views for cells that were removed or changed type
    for (final uid in _mathViews.keys.toList()) {
      if (byUid[uid] is! MathCell) {
        _mathViews.remove(uid)?.dispose();
      }
    }
    for (final uid in _mdViews.keys.toList()) {
      if (byUid[uid] is! MarkdownCell) {
        _mdViews.remove(uid);
      }
    }
    if (_focusedUid != null && !byUid.containsKey(_focusedUid)) {
      _focusedUid = null;
    }

    final scrollY = web.window.scrollY;
    root.replaceChildren(<JSAny>[].toJS);

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

    final newlyMountedMath = <MathCellView>[];

    for (var i = 0; i < doc.cells.length; i++) {
      final cell = doc.cells[i];
      final isActive = cell.uid == _focusedUid;

      switch (cell) {
        case MarkdownCell():
          var mdView = _mdViews[cell.uid];
          if (mdView == null) {
            mdView = MarkdownCellView(
              cell: cell,
              document: doc,
              registry: client.registry,
              isEditing: isActive,
              onStartEdit: () => focusCell(cell.uid),
              onCommit: (src, {required bool advance}) async {
                await client.updateMarkdown(cell.uid, src);
                if (advance) {
                  final idx = client.document.indexOfUid(cell.uid);
                  if (idx >= 0 && idx + 1 < client.document.cells.length) {
                    focusCell(client.document.cells[idx + 1].uid);
                  } else {
                    final nextUid = await client.evalCell('');
                    focusCell(nextUid);
                  }
                } else {
                  focusCell(null);
                }
              },
              onMoveUp: () async {
                final idx = client.document.indexOfUid(cell.uid);
                if (idx > 0) await client.moveCell(cell.uid, idx - 1);
              },
              onMoveDown: () async {
                final idx = client.document.indexOfUid(cell.uid);
                if (idx >= 0 && idx + 1 < client.document.cells.length) {
                  await client.moveCell(cell.uid, idx + 1);
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
            _mdViews[cell.uid] = mdView;
          } else {
            mdView.update(cell, doc);
            mdView.setEditing(isActive);
          }
          root.append(mdView.root);

        case MathCell():
          var mathView = _mathViews[cell.uid];
          if (mathView == null) {
            mathView = MathCellView(
              cell: cell,
              env: doc.env,
              registry: client.registry,
              isFocused: isActive,
              onFocus: () => focusCell(cell.uid),
              onRun:
                  (src, {required bool advance, required bool approx}) async {
                    await client.evalCell(
                      src,
                      uid: cell.uid,
                      forceApprox: approx,
                    );
                    if (advance) {
                      final idx = client.document.indexOfUid(cell.uid);
                      if (idx >= 0 && idx + 1 < client.document.cells.length) {
                        focusCell(client.document.cells[idx + 1].uid);
                      } else {
                        final nextUid = await client.evalCell('');
                        focusCell(nextUid);
                      }
                    } else {
                      focusCell(cell.uid);
                    }
                  },
              onInsertFollowUp: (call) async {
                final idx = client.document.indexOfUid(cell.uid);
                final insertAt = idx >= 0
                    ? idx + 1
                    : client.document.cells.length;
                final nextUid = await client.evalCell(call, index: insertAt);
                focusCell(nextUid);
              },
              onMoveUp: () async {
                final idx = client.document.indexOfUid(cell.uid);
                if (idx > 0) await client.moveCell(cell.uid, idx - 1);
              },
              onMoveDown: () async {
                final idx = client.document.indexOfUid(cell.uid);
                if (idx >= 0 && idx + 1 < client.document.cells.length) {
                  await client.moveCell(cell.uid, idx + 1);
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
              onBlurExit: () => focusCell(null),
            );
            _mathViews[cell.uid] = mathView;
            newlyMountedMath.add(mathView);
          } else {
            mathView.update(cell, doc.env);
            mathView.setFocused(isActive);
          }
          root.append(mathView.root);
      }

      if (i + 1 < doc.cells.length) {
        root.append(_buildInsertDivider(i + 1));
      }
    }

    // Stable, always-visible footer actions to append a new cell
    root.append(_buildBottomAddBar(doc.cells.length));

    for (final mv in newlyMountedMath) {
      mv.mountRenderables();
    }
    if (focusEditorUid != null) {
      _mathViews[focusEditorUid]?.focusEditor(moveToEnd: moveToEnd);
      _mdViews[focusEditorUid]?.focusEditor(moveToEnd: moveToEnd);
    } else if (scrollY > 0) {
      web.window.scrollTo(0.toJS, scrollY);
    }
  }

  void _attachOutsideClickBlur() {
    web.document.addEventListener(
      'mousedown',
      ((web.MouseEvent e) {
        if (_focusedUid == null) return;
        final target = e.target;
        if (target == null || !target.isA<web.Element>()) return;
        final el = target as web.Element;
        // Keep focus when clicking inside a cell, modal, drawer, header, or sidebar
        if (el.closest('.nb-cell') != null ||
            el.closest('.nb-modal') != null ||
            el.closest('.nb-drawer') != null ||
            el.closest('.app-header') != null ||
            el.closest('.sidebar') != null ||
            el.closest('.nb-insert-divider') != null ||
            el.closest('.nb-bottom-add') != null) {
          return;
        }
        focusCell(null);
      }).toJS,
    );
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

  web.HTMLDivElement _buildBottomAddBar(int index) {
    final bar = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-bottom-add';

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

    bar
      ..append(addMath)
      ..append(sep)
      ..append(addText);
    return bar;
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
# Damped Harmonic Oscillator

Consider a damped oscillation \$f(x) = exp(-x/5) * sin(2 * x)\$ for \$0 <= x <= 4 * pi\$.

```math
f(x) := exp(-x/5) * sin(2 * x)
```

Compute its exact derivative with respect to \$x\$:

```math
diff(f(x), x)
```

Using the live result, the rate of change is {{r[2]}}. Plotting \$f(x)\$ alongside its exponential envelope:

```math
plot([f(x), exp(-x/5), -exp(-x/5)], x, from: 0, to: 12)
```
''';
}
