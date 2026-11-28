import 'dart:js_interop';

import 'package:data/symbolic.dart';
import 'package:web/web.dart' as web;

import '../../../shared/html.dart';
import '../engine/commands.dart';
import '../model/environment.dart';
import 'icons.dart';

/// Filter category in [CommandPalette].
enum PaletteCategory {
  all('All'),
  actions('Actions'),
  commands('Commands'),
  functions('Functions');

  new(this.label);
  final String label;
}

/// Workspace or navigation action exposed inside [CommandPalette].
final class PaletteAction {
  const new({
    required this.id,
    required this.label,
    required this.description,
    required this.category,
    required this.onRun,
    this.shortcut,
  });

  final String id;
  final String label;
  final String description;
  final String category;
  final String? shortcut;
  final void Function() onRun;
}

/// Unified command, function, and workspace action palette (`Cmd/Ctrl+K`).
final class CommandPalette {
  new({
    required this.registry,
    required this.env,
    required this.actions,
    required this.onInsert,
  }) {
    _buildDom();
  }

  final CommandRegistry registry;
  final Environment env;
  final List<PaletteAction> actions;
  final void Function(String snippet) onInsert;

  late final web.HTMLDivElement backdrop;
  late final web.HTMLInputElement _input;
  late final web.HTMLDivElement _list;
  late final web.HTMLSpanElement _countLabel;

  final Map<PaletteCategory, web.HTMLButtonElement> _filterButtons = {};
  final List<({web.HTMLButtonElement button, void Function() run})> _items = [];
  PaletteCategory _filter = PaletteCategory.all;
  int _selectedIndex = -1;

  /// Opens the command palette and focuses the search input.
  void open() {
    backdrop.style.display = 'flex';
    _input.value = '';
    _setFilter(PaletteCategory.all);
    _input.focus();
  }

  /// Closes the command palette modal.
  void close() {
    backdrop.style.display = 'none';
  }

  void _setFilter(PaletteCategory next) {
    _filter = next;
    for (final entry in _filterButtons.entries) {
      final isSel = entry.key == next;
      entry.value
        ..classList.toggle('active', isSel)
        ..setAttribute('aria-pressed', isSel ? 'true' : 'false');
    }
    _renderList(_input.value);
  }

  void _buildDom() {
    backdrop = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'modal-backdrop'
      ..style.display = 'none';

    final modal = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'modal-dialog nb-palette'
      ..setAttribute('role', 'dialog')
      ..setAttribute('aria-modal', 'true')
      ..setAttribute('aria-label', 'Command Palette');

    final header = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-palette-header';

    final searchRow = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-palette-search-row';
    final cmdIcon = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-palette-search-icon'
      ..innerHTML = NbIcons.commandPalette.toJS;
    _input = (web.document.createElement('input') as web.HTMLInputElement)
      ..type = 'text'
      ..className = 'nb-palette-input'
      ..setAttribute('aria-label', 'Filter commands, actions, and functions')
      ..placeholder = 'Type an action, command, or math function...';
    final escBadge = (web.document.createElement('kbd') as web.HTMLElement)
      ..className = 'nb-palette-kbd'
      ..textContent = 'Esc';
    searchRow
      ..append(cmdIcon)
      ..append(_input)
      ..append(escBadge);

    final filters = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'segmented-control nb-palette-filters';
    for (final cat in PaletteCategory.values) {
      final isSel = cat == _filter;
      final btn =
          (web.document.createElement('button') as web.HTMLButtonElement)
            ..type = 'button'
            ..className = isSel ? 'segmented-btn active' : 'segmented-btn'
            ..textContent = cat.label
            ..setAttribute('aria-pressed', isSel ? 'true' : 'false')
            ..onclick = ((web.MouseEvent _) {
              _setFilter(cat);
              _input.focus();
            }).toJS;
      _filterButtons[cat] = btn;
      filters.append(btn);
    }

    header
      ..append(searchRow)
      ..append(filters);

    _list = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-palette-list'
      ..setAttribute('role', 'listbox');

    final footer = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-palette-footer';
    _countLabel = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-palette-count';
    final hints = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-palette-hints'
      ..textContent = '↑↓ Navigate · ↵ Run / Insert · Esc Close';
    footer
      ..append(_countLabel)
      ..append(hints);

    modal
      ..append(header)
      ..append(_list)
      ..append(footer);
    backdrop.append(modal);

    backdrop.onclick = ((web.MouseEvent e) {
      if (e.target == backdrop) close();
    }).toJS;

    _input.oninput = ((web.Event _) => _renderList(_input.value)).toJS;
    _input.onkeydown = ((web.KeyboardEvent e) {
      if (e.key == 'Escape') {
        e.preventDefault();
        close();
      } else if (e.key == 'ArrowDown') {
        e.preventDefault();
        _moveSelection(1);
      } else if (e.key == 'ArrowUp') {
        e.preventDefault();
        _moveSelection(-1);
      } else if (e.key == 'Enter') {
        if (_selectedIndex >= 0 && _selectedIndex < _items.length) {
          e.preventDefault();
          final run = _items[_selectedIndex].run;
          close();
          run();
        }
      }
    }).toJS;
  }

  void _renderList(String query) {
    final q = query.trim().toLowerCase();
    _list.replaceChildren(<JSAny>[].toJS);
    _items.clear();
    _selectedIndex = -1;

    final includeActions =
        _filter == PaletteCategory.all || _filter == PaletteCategory.actions;
    final includeCommands =
        _filter == PaletteCategory.all || _filter == PaletteCategory.commands;
    final includeFunctions =
        _filter == PaletteCategory.all || _filter == PaletteCategory.functions;

    if (includeActions) {
      final matching = [
        for (final act in actions)
          if (q.isEmpty ||
              act.label.toLowerCase().contains(q) ||
              act.description.toLowerCase().contains(q) ||
              act.category.toLowerCase().contains(q))
            act,
      ];
      if (matching.isNotEmpty) {
        _appendHeading('Actions', '${matching.length}');
        for (final act in matching) {
          _appendPlainRow(
            title: act.label,
            doc: act.description,
            badge: act.shortcut ?? act.category,
            isShortcut: act.shortcut != null,
            onRun: act.onRun,
          );
        }
      }
    }

    if (includeCommands) {
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
        _appendHeading(entry.key.label, '${entry.value.length}');
        for (final cmd in entry.value) {
          final fullSig = cmd.signature.format(cmd.name);
          final paramsPart = fullSig.startsWith(cmd.name)
              ? fullSig.substring(cmd.name.length)
              : '';
          final ex = cmd.examples.isNotEmpty
              ? cmd.examples.first
              : '${cmd.name}()';
          _appendSymbolRow(
            name: cmd.name,
            params: paramsPart,
            doc: cmd.doc,
            badge: 'Insert & run',
            onRun: () => onInsert(ex),
          );
        }
      }
    }

    if (includeFunctions) {
      final cmdNames = registry.allNames;
      final matching = [
        for (final fn in ExprSyntax.standardFunctions)
          if (!cmdNames.contains(fn.name) &&
              (q.isEmpty ||
                  fn.name.toLowerCase().contains(q) ||
                  fn.doc.toLowerCase().contains(q)))
            fn,
      ];
      if (matching.isNotEmpty) {
        _appendHeading('Mathematical Functions', '${matching.length}');
        for (final fn in matching) {
          final params = '(${fn.params.join(', ')})';
          _appendSymbolRow(
            name: fn.name,
            params: params,
            doc: fn.doc,
            badge: 'Insert',
            onRun: () => onInsert('${fn.name}$params'),
          );
        }
      }
    }

    if (_items.isEmpty) {
      _list.append(
        (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-palette-empty'
          ..textContent = 'No matching actions, commands, or functions.',
      );
      _countLabel.textContent = '0 items';
    } else {
      _selectIndex(0);
      _countLabel.textContent =
          '${_items.length} item${_items.length == 1 ? '' : 's'}';
    }
  }

  void _appendHeading(String title, String count) {
    final row = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-palette-group-heading'
      ..innerHTML =
          '<span>${escapeHtml(title)}</span>'
                  '<span class="nb-palette-group-count">${escapeHtml(count)}</span>'
              .toJS;
    _list.append(row);
  }

  void _appendPlainRow({
    required String title,
    required String doc,
    required String badge,
    required void Function() onRun,
    bool isShortcut = false,
  }) {
    final badgeHtml = isShortcut
        ? '<kbd class="nb-palette-kbd">${escapeHtml(badge)}</kbd>'
        : '<span class="nb-palette-badge">${escapeHtml(badge)}</span>';
    _appendButtonRow(
      headerHtml:
          '<span class="nb-palette-action-title">${escapeHtml(title)}</span>$badgeHtml',
      doc: doc,
      onRun: onRun,
    );
  }

  void _appendSymbolRow({
    required String name,
    required String params,
    required String doc,
    required String badge,
    required void Function() onRun,
  }) {
    _appendButtonRow(
      headerHtml:
          '<span class="nb-palette-sig">'
          '<span class="nb-help-fn-name">${escapeHtml(name)}</span>'
          '<span class="nb-help-fn-params">${escapeHtml(params)}</span>'
          '</span>'
          '<span class="nb-palette-badge">${escapeHtml(badge)}</span>',
      doc: doc,
      onRun: onRun,
    );
  }

  void _appendButtonRow({
    required String headerHtml,
    required String doc,
    required void Function() onRun,
  }) {
    final idx = _items.length;
    final btn = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'nb-palette-item'
      ..setAttribute('role', 'option')
      ..innerHTML =
          '<div class="nb-palette-item-top">$headerHtml</div>'
                  '<div class="nb-palette-doc">${escapeHtml(doc)}</div>'
              .toJS;
    btn.onmouseenter = ((web.MouseEvent _) => _selectIndex(idx)).toJS;
    btn.onclick = ((web.MouseEvent _) {
      close();
      onRun();
    }).toJS;
    _items.add((button: btn, run: onRun));
    _list.append(btn);
  }

  void _moveSelection(int delta) {
    if (_items.isEmpty) return;
    final next = (_selectedIndex + delta) % _items.length;
    _selectIndex(next < 0 ? next + _items.length : next, scroll: true);
  }

  void _selectIndex(int idx, {bool scroll = false}) {
    if (idx < 0 || idx >= _items.length) return;
    if (_selectedIndex >= 0 && _selectedIndex < _items.length) {
      _items[_selectedIndex].button
        ..classList.remove('selected')
        ..setAttribute('aria-selected', 'false');
    }
    _selectedIndex = idx;
    _items[idx].button
      ..classList.add('selected')
      ..setAttribute('aria-selected', 'true');
    if (scroll) {
      _items[idx].button.scrollIntoView();
    }
  }
}
