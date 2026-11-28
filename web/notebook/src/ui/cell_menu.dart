import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../../../shared/utils.dart';
import 'icons.dart';

/// Shared dropdown action menu attached to a cell's `⋯` overflow button.
///
/// Uses shared `.dropdown-menu` styles, closes any sibling open cell menu,
/// dismisses cleanly on outside pointer clicks or `Escape` (returning focus to
/// the trigger button), and exposes clean item / divider builders.
final class CellActionMenu {
  new({required this.cellRoot, required this.buildItems}) {
    button = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'icon-btn nb-cell-more-btn'
      ..title = 'Cell actions'
      ..setAttribute('aria-label', 'Cell actions')
      ..setAttribute('aria-haspopup', 'menu')
      ..setAttribute('aria-expanded', 'false')
      ..innerHTML = NbIcons.moreVertical.toJS;

    popup = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'dropdown-menu nb-cell-menu'
      ..setAttribute('role', 'menu');
    setHidden(popup, true);

    button.onmousedown = ((web.MouseEvent e) {
      e.preventDefault();
      e.stopPropagation();
    }).toJS;
    button.onclick = ((web.MouseEvent e) {
      e.stopPropagation();
      if (_isOpen) {
        close();
      } else {
        open();
      }
    }).toJS;
  }

  static CellActionMenu? _activeMenu;

  final web.HTMLDivElement cellRoot;
  final List<CellMenuEntry> Function() buildItems;

  late final web.HTMLButtonElement button;
  late final web.HTMLDivElement popup;

  bool _isOpen = false;
  JSFunction? _outsideJs;
  JSFunction? _keyJs;

  void open() {
    if (_activeMenu != null && _activeMenu != this) {
      _activeMenu!.close();
    }
    _activeMenu = this;
    _populate();
    _isOpen = true;
    setHidden(popup, false);
    button.setAttribute('aria-expanded', 'true');
    _cellRootRefClass(add: true);

    _outsideJs ??= ((web.Event e) {
      final target = e.target;
      if (target != null &&
          target.isA<web.Node>() &&
          (popup.contains(target as web.Node) || button.contains(target))) {
        return;
      }
      close();
    }).toJS;
    _keyJs ??= ((web.KeyboardEvent e) {
      if (_isOpen && e.key == 'Escape') {
        e.preventDefault();
        close(returnFocus: true);
      }
    }).toJS;
    web.document.addEventListener('pointerdown', _outsideJs);
    web.document.addEventListener('keydown', _keyJs);
  }

  void close({bool returnFocus = false}) {
    if (!_isOpen) return;
    _isOpen = false;
    if (_activeMenu == this) _activeMenu = null;
    setHidden(popup, true);
    button.setAttribute('aria-expanded', 'false');
    _cellRootRefClass(add: false);
    if (_outsideJs != null) {
      web.document.removeEventListener('pointerdown', _outsideJs);
    }
    if (_keyJs != null) {
      web.document.removeEventListener('keydown', _keyJs);
    }
    if (returnFocus) button.focus();
  }

  void _cellRootRefClass({required bool add}) {
    cellRoot.classList.toggle('menu-open', add);
  }

  void dispose() => close();

  void _populate() {
    popup.replaceChildren(<JSAny>[].toJS);
    for (final entry in buildItems()) {
      switch (entry) {
        case CellMenuDivider():
          popup.append(
            (web.document.createElement('div') as web.HTMLDivElement)
              ..className = 'dropdown-menu-divider'
              ..setAttribute('role', 'separator'),
          );
        case CellMenuAction(
          :final label,
          :final iconSvg,
          :final onTap,
          :final shortcut,
          :final danger,
        ):
          final btn =
              (web.document.createElement('button') as web.HTMLButtonElement)
                ..type = 'button'
                ..className = danger
                    ? 'dropdown-menu-item danger'
                    : 'dropdown-menu-item'
                ..setAttribute('role', 'menuitem');
          final kbdHtml = shortcut == null
              ? ''
              : '<span class="dropdown-menu-kbd">$shortcut</span>';
          btn.innerHTML =
              '<span class="dropdown-menu-icon">$iconSvg</span>'
                      '<span class="dropdown-menu-label">$label</span>'
                      '$kbdHtml'
                  .toJS;
          btn.onmousedown = ((web.MouseEvent e) {
            e.preventDefault();
            e.stopPropagation();
          }).toJS;
          btn.onclick = ((web.MouseEvent e) {
            e.stopPropagation();
            close();
            onTap();
          }).toJS;
          popup.append(btn);
      }
    }
  }
}

/// Entry inside a [CellActionMenu].
sealed class CellMenuEntry {
  const new();
}

/// Action button inside a [CellActionMenu].
final class CellMenuAction extends CellMenuEntry {
  const new(
    this.label,
    this.iconSvg,
    this.onTap, {
    this.shortcut,
    this.danger = false,
  });

  final String label;
  final String iconSvg;
  final void Function() onTap;
  final String? shortcut;
  final bool danger;
}

/// Horizontal separator inside a [CellActionMenu].
final class CellMenuDivider extends CellMenuEntry {
  const new();
}
