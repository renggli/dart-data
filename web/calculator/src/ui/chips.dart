import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/value.dart';
import 'persistence.dart';

/// Builds the context-aware action chip strip shown beneath a Scroll worksheet
/// cell or RPN stack level (`Simplify`, `Expand`, `Factor`, `d/dx`, `∫ dx`,
/// `Roots`, `Plot`, `≈`, `Copy`, `⋯`).
abstract final class ActionChips {
  static bool _documentListenerRegistered = false;

  static void _ensureDocumentListener() {
    if (_documentListenerRegistered) return;
    _documentListenerRegistered = true;
    web.document.addEventListener(
      'click',
      ((web.MouseEvent e) {
        final target = e.target as web.Element?;
        if (target == null || target.closest('.calc-chip-more-wrap') == null) {
          closeAllDropdowns();
        }
      }).toJS,
    );
  }

  /// Closes all currently open `.calc-chip-dropdown` overflow menus.
  static void closeAllDropdowns({web.HTMLElement? except}) {
    final openMenus = web.document.querySelectorAll('.calc-chip-dropdown');
    for (var i = 0; i < openMenus.length; i++) {
      final el = openMenus.item(i) as web.HTMLElement?;
      if (el != null && el != except) {
        el.classList.add('hidden');
      }
    }
  }

  /// Toggles an overflow dropdown [menu] anchored to [moreBtn], automatically
  /// flipping downward (`.open-down`) when there is insufficient room above
  /// inside the scroll/stack container or viewport.
  static void toggleDropdown(web.HTMLElement moreBtn, web.HTMLElement menu) {
    _ensureDocumentListener();
    final wasHidden = menu.classList.contains('hidden');
    closeAllDropdowns(except: menu);
    if (!wasHidden) {
      menu.classList.add('hidden');
      return;
    }
    final btnRect = moreBtn.getBoundingClientRect();
    final container =
        moreBtn.closest('.calc-scroll-view') ??
        moreBtn.closest('.calc-rpn-registers');
    final containerTop = container?.getBoundingClientRect().top ?? 0.0;
    if (btnRect.top - containerTop < 220) {
      menu.classList.add('open-down');
    } else {
      menu.classList.remove('open-down');
    }
    menu.classList.remove('hidden');
  }

  static web.HTMLElement build({
    required int cellId,
    required CalcValue value,
    required void Function(String commandStatement) onRunStatement,
    required void Function(String message) onToast,
    void Function()? onPushToStack,
    String? overlayPlotCall,
  }) {
    _ensureDocumentListener();
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

    if (overlayPlotCall != null) {
      final overlayBtn =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-chip-btn'
            ..textContent = '+ Plot'
            ..title = 'Overlay r[$cellId] onto the most recent plot';
      overlayBtn.addEventListener(
        'click',
        ((web.Event _) => onRunStatement(overlayPlotCall)).toJS,
      );
      strip.append(overlayBtn);
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
          toggleDropdown(moreBtn, menu);
        }).toJS,
      );
      moreWrap
        ..append(moreBtn)
        ..append(menu);
      strip.append(moreWrap);
    }

    // Copy split menu (Expr, LaTeX) and Push to Stack
    if (value is! PlotValue && value is! ErrorValue && value is! InfoValue) {
      if (onPushToStack != null) {
        final pushBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-chip-secondary'
              ..textContent = '⤓ Stack'
              ..title = 'Push r[$cellId] to RPN stack level 1:';
        pushBtn.addEventListener(
          'click',
          ((web.Event _) => onPushToStack()).toJS,
        );
        strip.append(pushBtn);
      }

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
