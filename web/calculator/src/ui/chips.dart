import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/value.dart';
import 'persistence.dart';

/// Builds the context-aware action chip strip shown beneath a Scroll worksheet
/// cell (`Simplify`, `Expand`, `Factor`, `d/dx`, `∫ dx`, `Roots`, `Plot`,
/// `≈`, `Copy`, `⋯`).
abstract final class ActionChips {
  static web.HTMLElement build({
    required int cellId,
    required CalcValue value,
    required void Function(String commandStatement) onRunStatement,
    required void Function(String message) onToast,
  }) {
    final strip = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-chip-strip';

    final (:primary, :overflow) = CommandRegistry.chipsFor(value, maxChips: 6);

    for (final cmd in primary) {
      final btn = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = 'calc-chip-btn'
        ..textContent = cmd.chipLabel
        ..title = '${cmd.signature} — ${cmd.doc}';
      btn.addEventListener(
        'click',
        ((web.Event _) {
          onRunStatement(cmd.buildChipCall(cellId, value));
        }).toJS,
      );
      strip.append(btn);
    }

    // Overflow "⋯" menu if more commands apply
    if (overflow.isNotEmpty) {
      final moreWrap = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-chip-more-wrap';
      final moreBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-chip-btn'
            ..textContent = '⋯'
            ..title = 'More operations on r[$cellId]';
      final menu = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-chip-dropdown hidden';

      for (final cmd in overflow) {
        final item =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-dropdown-item'
              ..textContent = '${cmd.chipLabel} (${cmd.name})';
        item.addEventListener(
          'click',
          ((web.Event _) {
            menu.classList.add('hidden');
            onRunStatement(cmd.buildChipCall(cellId, value));
          }).toJS,
        );
        menu.append(item);
      }

      moreBtn.addEventListener(
        'click',
        ((web.Event e) {
          e.stopPropagation();
          menu.classList.toggle('hidden');
        }).toJS,
      );
      moreWrap
        ..append(moreBtn)
        ..append(menu);
      strip.append(moreWrap);
    }

    // Copy split menu (Expr, LaTeX, MathML)
    if (value is! PlotValue && value is! ErrorValue) {
      final copyExprBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-chip-btn calc-chip-secondary'
            ..textContent = 'Copy'
            ..title = 'Copy canonical expression';
      copyExprBtn.addEventListener(
        'click',
        ((web.Event _) {
          CalcPersistence.copyToClipboard(
            value.toCanonicalText(),
            onCopied: () => onToast('Copied expression to clipboard'),
          );
        }).toJS,
      );
      strip.append(copyExprBtn);

      final latex = value.toLatex();
      if (latex.isNotEmpty) {
        final copyTexBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-chip-secondary'
              ..textContent = 'LaTeX'
              ..title = 'Copy LaTeX representation';
        copyTexBtn.addEventListener(
          'click',
          ((web.Event _) {
            CalcPersistence.copyToClipboard(
              latex,
              onCopied: () => onToast('Copied LaTeX to clipboard'),
            );
          }).toJS,
        );
        strip.append(copyTexBtn);
      }
    }

    return strip;
  }
}
