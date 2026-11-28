import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../shared/html.dart';
import '../model/examples.dart';
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
  new(this.client, {this.onFocusChanged, this.onLoadExample}) {
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-document';
    _attachOutsideClickBlur();
    render();
  }

  final EngineClient client;
  final void Function()? onFocusChanged;
  final void Function(NotebookExample example)? onLoadExample;
  late final web.HTMLDivElement root;

  List<NotebookExample> _examples = const [];
  String? _focusedUid;
  String? _mountedSignature;
  web.HTMLSpanElement? _staleBannerMsg;
  final Map<String, MathCellView> _mathViews = {};
  final Map<String, MarkdownCellView> _mdViews = {};
  final Map<String, double> _plotHeights = {};

  String? get focusedUid => _focusedUid;

  /// Updates the curated examples displayed on the empty-notebook view.
  void setExamples(List<NotebookExample> examples) {
    _examples = examples;
    if (client.document.cells.isEmpty) {
      render();
    }
  }

  /// Scrolls to [uid] and focuses it for editing.
  void scrollToAndFocusCell(String uid) {
    focusCell(uid);
    final el = _mathViews[uid]?.root ?? _mdViews[uid]?.root;
    el?.scrollIntoView();
  }

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
        _plotHeights.remove(uid);
      }
    }
    for (final uid in _mdViews.keys.toList()) {
      if (byUid[uid] is! MarkdownCell) {
        _mdViews.remove(uid)?.dispose();
      }
    }
    if (_focusedUid != null && !byUid.containsKey(_focusedUid)) {
      _focusedUid = null;
    }

    final staleCount = doc.cells
        .where(
          (c) => (c is MathCell && c.stale) || (c is MarkdownCell && c.stale),
        )
        .length;

    final nextSignature = doc.cells.isEmpty
        ? ''
        : '${staleCount > 0 ? 'S' : ''}|'
              '${doc.cells.map((c) => '${c is MathCell ? 'M' : 'T'}:${c.uid}').join(',')}';

    // Update mounted views in-place when structure hasn't changed so live
    // slider drags, formula inputs, and WebGL plots never lose DOM state.
    if (doc.cells.isNotEmpty &&
        nextSignature == _mountedSignature &&
        focusEditorUid == null) {
      if (staleCount > 0 && _staleBannerMsg != null) {
        _staleBannerMsg!.textContent =
            '$staleCount dependent cell${staleCount == 1 ? '' : 's'} out of date';
      }
      for (final cell in doc.cells) {
        final isActive = cell.uid == _focusedUid;
        switch (cell) {
          case MarkdownCell():
            _mdViews[cell.uid]
              ?..update(cell, doc)
              ..setEditing(isActive);
          case MathCell():
            _mathViews[cell.uid]
              ?..update(cell, doc.env, plotHeight: _plotHeights[cell.uid])
              ..setFocused(isActive);
        }
      }
      return;
    }

    _mountedSignature = nextSignature;
    _staleBannerMsg = null;

    final scrollY = web.window.scrollY;
    root.replaceChildren(<JSAny>[].toJS);

    if (staleCount > 0) {
      final banner = (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-stale-banner';
      final msg = (web.document.createElement('span') as web.HTMLSpanElement)
        ..textContent =
            '$staleCount dependent cell${staleCount == 1 ? '' : 's'} out of date';
      _staleBannerMsg = msg;
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
              onInsertMathBelow: () async {
                final idx = client.document.indexOfUid(cell.uid);
                final insertAt = idx >= 0
                    ? idx + 1
                    : client.document.cells.length;
                final nextUid = await client.evalCell('', index: insertAt);
                focusCell(nextUid);
              },
              onInsertTextBelow: () async {
                final idx = client.document.indexOfUid(cell.uid);
                final insertAt = idx >= 0
                    ? idx + 1
                    : client.document.cells.length;
                final nextUid = await client.insertMarkdown(
                  '',
                  index: insertAt,
                );
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
              initialPlotHeight: _plotHeights[cell.uid],
              onPlotHeightChanged: (h) => _plotHeights[cell.uid] = h,
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
              onControlChanged: (key, value, {required recordUndo}) => client
                  .updateControl(cell.uid, key, value, recordUndo: recordUndo),
              onInsertFollowUp: (call) async {
                final idx = client.document.indexOfUid(cell.uid);
                final insertAt = idx >= 0
                    ? idx + 1
                    : client.document.cells.length;
                final nextUid = await client.evalCell(call, index: insertAt);
                focusCell(nextUid);
              },
              onInsertMathBelow: () async {
                final idx = client.document.indexOfUid(cell.uid);
                final insertAt = idx >= 0
                    ? idx + 1
                    : client.document.cells.length;
                final nextUid = await client.evalCell('', index: insertAt);
                focusCell(nextUid);
              },
              onInsertTextBelow: () async {
                final idx = client.document.indexOfUid(cell.uid);
                final insertAt = idx >= 0
                    ? idx + 1
                    : client.document.cells.length;
                final nextUid = await client.insertMarkdown(
                  '',
                  index: insertAt,
                );
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
            mathView.update(cell, doc.env, plotHeight: _plotHeights[cell.uid]);
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
            el.closest('.nb-ctrl-group') != null ||
            el.closest('.nb-modal') != null ||
            el.closest('.nb-right-sidebar') != null ||
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
          ..className = 'btn btn-primary'
          ..textContent = 'New Math Cell';
    startMath.onclick = ((web.MouseEvent _) async {
      final uid = await client.evalCell('');
      focusCell(uid);
    }).toJS;

    final startText =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'btn btn-secondary'
          ..textContent = 'New Text Cell';
    startText.onclick = ((web.MouseEvent _) async {
      final uid = await client.insertMarkdown('');
      focusCell(uid);
    }).toJS;

    row
      ..append(startMath)
      ..append(startText);
    box
      ..append(heading)
      ..append(sub)
      ..append(row);

    final examplesSection =
        (web.document.createElement('section') as web.HTMLElement)
          ..className = 'nb-empty-examples';
    examplesSection.append(
      (web.document.createElement('div') as web.HTMLDivElement)
        ..className = 'nb-empty-examples-heading'
        ..textContent = 'Example Notebooks',
    );

    final grid = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-empty-examples-grid';
    for (final ex in _examples) {
      final card =
          (web.document.createElement('button') as web.HTMLButtonElement)
            ..type = 'button'
            ..className = 'nb-empty-example-card';
      card.innerHTML =
          '<span class="nb-empty-example-cat">${escapeHtml(ex.category)}</span>'
                  '<span class="nb-empty-example-title">${escapeHtml(ex.title)}</span>'
                  '<span class="nb-empty-example-desc">${escapeHtml(ex.description)}</span>'
              .toJS;
      card.onclick = ((web.MouseEvent _) => onLoadExample?.call(ex)).toJS;
      grid.append(card);
    }
    examplesSection.append(grid);
    box.append(examplesSection);

    return box;
  }
}
