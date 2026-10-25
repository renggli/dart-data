import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/session.dart';
import '../model/value.dart';
import 'chips.dart';
import 'render.dart';

/// Notebook-style Scroll mode worksheet view displaying numbered input/output
/// cells (`in[n]` / `r[n]`), click-to-insert result badges, inline cell editing,
/// stale dependency banners, and context-aware action chips.
final class ScrollWorksheetView {
  new({
    required this.onInsertText,
    required this.onRunStatement,
    required this.onUpdateCell,
    required this.onDeleteCell,
    required this.onRecomputeAllStale,
    required this.onQuickStartSelect,
    required this.onToast,
    this.onPushToStack,
  }) {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-scroll-view';
  }

  final void Function(String snippet) onInsertText;
  final void Function(String statement) onRunStatement;
  final void Function(int cellId, String newInput) onUpdateCell;
  final void Function(int cellId) onDeleteCell;
  final void Function() onRecomputeAllStale;
  final void Function(String statement) onQuickStartSelect;
  final void Function(String message) onToast;
  final void Function(int cellId)? onPushToStack;

  late final web.HTMLDivElement element;
  int? _editingCellId;

  void render({required Session session, required int digits}) {
    element.innerHTML = ''.toJS;

    final activeCells = session.activeCells;
    if (activeCells.isEmpty) {
      element.append(_buildEmptyState());
      return;
    }

    // Stale dependency banner if any cell is stale
    final staleCells = session.staleCells;
    if (staleCells.isNotEmpty) {
      final banner = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-stale-banner';
      final text = web.document.createElement('span') as web.HTMLSpanElement
        ..textContent =
            '⚠️ ${staleCells.length} dependent cell(s) out of date (${staleCells.map((c) => 'r[${c.id}]').join(', ')})';
      final btn = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = 'calc-btn-primary calc-btn-sm'
        ..textContent = 'Recompute All';
      btn.addEventListener(
        'click',
        ((web.Event _) => onRecomputeAllStale()).toJS,
      );
      banner
        ..append(text)
        ..append(btn);
      element.append(banner);
    }

    for (final cell in activeCells) {
      element.append(_buildCellCard(cell, digits: digits));
    }

    // Auto-scroll to bottom
    web.window.requestAnimationFrame(
      ((num _) {
        element.scrollTop = element.scrollHeight;
      }).toJS,
    );
  }

  web.HTMLElement _buildCellCard(WorksheetCell cell, {required int digits}) {
    final card = web.document.createElement('article') as web.HTMLElement
      ..className = cell.stale ? 'calc-cell-card stale' : 'calc-cell-card';

    // 1. Input row: in[n] | expression | Edit / Re-run / Delete
    final inRow = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-cell-in-row';
    final inBadge = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-in-badge'
      ..textContent = 'in[${cell.id}]';
    inRow.append(inBadge);

    if (_editingCellId == cell.id) {
      final editInput =
          web.document.createElement('input') as web.HTMLInputElement
            ..type = 'text'
            ..className = 'calc-cell-edit-input'
            ..value = cell.input;
      final saveBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-chip-btn'
            ..textContent = 'Save ↵';
      final cancelBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-chip-btn calc-chip-secondary'
            ..textContent = 'Cancel';

      void commitEdit() {
        final text = editInput.value.trim();
        _editingCellId = null;
        if (text.isNotEmpty) {
          onUpdateCell(cell.id, text);
        }
      }

      editInput.addEventListener(
        'keydown',
        ((web.KeyboardEvent e) {
          if (e.key == 'Enter') {
            e.preventDefault();
            commitEdit();
          } else if (e.key == 'Escape') {
            e.preventDefault();
            _editingCellId = null;
            onUpdateCell(cell.id, cell.input);
          }
        }).toJS,
      );
      saveBtn.addEventListener('click', ((web.Event _) => commitEdit()).toJS);
      cancelBtn.addEventListener(
        'click',
        ((web.Event _) {
          _editingCellId = null;
          onUpdateCell(cell.id, cell.input);
        }).toJS,
      );

      inRow
        ..append(editInput)
        ..append(saveBtn)
        ..append(cancelBtn);
    } else {
      final exprCode = web.document.createElement('code') as web.HTMLElement
        ..className = 'calc-cell-input-code'
        ..textContent = cell.input
        ..title = 'Click to edit cell in-place';
      exprCode.addEventListener(
        'click',
        ((web.Event _) {
          _editingCellId = cell.id;
          inRow.innerHTML = ''.toJS;
          card.replaceWith(_buildCellCard(cell, digits: digits));
        }).toJS,
      );

      final cellActions =
          web.document.createElement('div') as web.HTMLDivElement
            ..className = 'calc-cell-head-actions';

      if (cell.stale) {
        final staleTag =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-stale-pill'
              ..textContent = '↻ Stale — Recompute';
        staleTag.addEventListener(
          'click',
          ((web.Event _) => onUpdateCell(cell.id, cell.input)).toJS,
        );
        cellActions.append(staleTag);
      }

      final delBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-cell-icon-btn'
            ..textContent = '✕'
            ..title = 'Delete cell r[${cell.id}]';
      delBtn.addEventListener(
        'click',
        ((web.Event _) => onDeleteCell(cell.id)).toJS,
      );
      cellActions.append(delBtn);

      inRow
        ..append(exprCode)
        ..append(cellActions);
    }

    // 2. Output row: r[n] badge + rendered MathML / Plot / Matrix
    final outRow = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-cell-out-row';
    final rBadge = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-r-badge'
      ..textContent = 'r[${cell.id}]'
      ..title = 'Click to insert r[${cell.id}] at cursor';
    rBadge.addEventListener(
      'click',
      ((web.Event _) => onInsertText('r[${cell.id}]')).toJS,
    );

    final renderedValue = ValueRenderer.renderValue(
      cell.value,
      digits: digits,
      onPlotResample: (minX, maxX) {
        if (cell.value case PlotValue(:final expressions, :final variable)) {
          final exprArg = expressions.length == 1
              ? expressions.first.toString()
              : '[${expressions.map((e) => e.toString()).join(', ')}]';
          onUpdateCell(
            cell.id,
            'plot($exprArg, $variable, ${minX.toStringAsFixed(3)}, ${maxX.toStringAsFixed(3)})',
          );
        }
      },
    );

    outRow
      ..append(rBadge)
      ..append(renderedValue);

    card
      ..append(inRow)
      ..append(outRow);

    // 3. Action chips strip
    final chipStrip = ActionChips.build(
      cellId: cell.id,
      value: cell.value,
      onRunStatement: onRunStatement,
      onToast: onToast,
      onPushToStack: onPushToStack != null
          ? () => onPushToStack!(cell.id)
          : null,
    );
    if (chipStrip.hasChildNodes()) {
      card.append(chipStrip);
    }

    return card;
  }

  web.HTMLElement _buildEmptyState() {
    final box = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-empty-state';

    final heading = web.document.createElement('h2') as web.HTMLHeadingElement
      ..textContent = 'Symbolic & Scientific Calculator';
    final subtitle = web.document.createElement('p') as web.HTMLParagraphElement
      ..textContent =
          'Exact rational, radical, calculus, matrix, and complex CAS. Click any starter card below or type in the formula bar.';
    box
      ..append(heading)
      ..append(subtitle);

    final grid = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-quickstart-grid';

    const starters = <({String title, String category, String code})>[
      (
        title: 'Polynomial Factorization',
        category: 'Algebra',
        code: 'factor(x^6 - 1)',
      ),
      (
        title: 'Exact Symbolic Roots',
        category: 'Solver',
        code: 'solve(x^3 - 6*x^2 + 11*x - 6 = 0, x)',
      ),
      (
        title: 'Symbolic Integration',
        category: 'Calculus',
        code: 'integrate(x^2 * cos(x), x)',
      ),
      (
        title: 'Taylor Series Expansion',
        category: 'Series',
        code: 'taylor(sin(x) / x, x, 0, 6)',
      ),
      (
        title: 'Symbolic Matrix Inverse',
        category: 'Linear Algebra',
        code: 'inv([[a, b], [c, d]])',
      ),
      (
        title: 'Adaptive Function Plot',
        category: 'Plotting',
        code: 'plot([sin(x) / x, cos(x)], x, -10, 10)',
      ),
    ];

    for (final s in starters) {
      final card = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = 'calc-quickstart-card';
      final cat = web.document.createElement('span') as web.HTMLSpanElement
        ..className = 'calc-quickstart-cat'
        ..textContent = s.category;
      final title = web.document.createElement('strong') as web.HTMLElement
        ..className = 'calc-quickstart-title'
        ..textContent = s.title;
      final code = web.document.createElement('code') as web.HTMLElement
        ..className = 'calc-quickstart-code'
        ..textContent = s.code;
      card
        ..append(cat)
        ..append(title)
        ..append(code);
      card.addEventListener(
        'click',
        ((web.Event _) => onQuickStartSelect(s.code)).toJS,
      );
      grid.append(card);
    }

    box.append(grid);
    return box;
  }
}
