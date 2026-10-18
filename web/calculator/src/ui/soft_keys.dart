import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/environment.dart';
import '../model/session.dart';

/// HP48-style 6-slot soft-key menu bar (`F1`–`F6`) with `STACK`, `ALG`, `CALC`,
/// `MATRIX`, `CPLX`, `NUM`, `PLOT`, `VARS` category tabs and `NXT` paging.
final class SoftKeyBar {
  new({required this.onExecuteRpnCommand, required this.onInsertText}) {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-softkey-container';
    _categoryBar = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-softkey-categories';
    _slotsRow = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-softkey-slots';
    element
      ..append(_categoryBar)
      ..append(_slotsRow);
  }

  final void Function(String command) onExecuteRpnCommand;
  final void Function(String snippet) onInsertText;

  late final web.HTMLDivElement element;
  late final web.HTMLDivElement _categoryBar;
  late final web.HTMLDivElement _slotsRow;

  String _activeMenu = 'STACK';
  int _pageIndex = 0;

  static const List<String> _menus = [
    'STACK',
    'ALG',
    'CALC',
    'MATRIX',
    'CPLX',
    'NUM',
    'NUMERIC',
    'PLOT',
    'VARS',
  ];

  void render({required Environment environment, required Session session}) {
    _categoryBar.innerHTML = ''.toJS;
    for (final menu in _menus) {
      final tab = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = menu == _activeMenu
            ? 'calc-softkey-cat active'
            : 'calc-softkey-cat'
        ..textContent = menu;
      tab.addEventListener(
        'click',
        ((web.Event _) {
          _activeMenu = menu;
          _pageIndex = 0;
          render(environment: environment, session: session);
        }).toJS,
      );
      _categoryBar.append(tab);
    }

    final items = _itemsForMenu(_activeMenu, environment);
    const pageSize = 5;
    final pageCount = items.isEmpty ? 1 : ((items.length - 1) ~/ pageSize) + 1;
    if (_pageIndex >= pageCount) _pageIndex = 0;

    final start = _pageIndex * pageSize;
    final visible = items.skip(start).take(pageSize).toList();

    _slotsRow.innerHTML = ''.toJS;
    for (var i = 0; i < 5; i++) {
      if (i < visible.length) {
        final item = visible[i];
        final btn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-softkey-btn'
              ..title = '${item.tooltip} (F${i + 1})';
        final fKey = web.document.createElement('span') as web.HTMLSpanElement
          ..className = 'calc-softkey-fkey'
          ..textContent = 'F${i + 1}';
        final label = web.document.createElement('span') as web.HTMLSpanElement
          ..className = 'calc-softkey-label'
          ..textContent = item.label;
        btn
          ..append(fKey)
          ..append(label);
        btn.addEventListener('click', ((web.Event _) => item.action()).toJS);
        _slotsRow.append(btn);
      } else {
        final emptyBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-softkey-btn disabled'
              ..disabled = true;
        _slotsRow.append(emptyBtn);
      }
    }

    // Slot F6: NXT page button
    final nxtBtn = web.document.createElement('button') as web.HTMLButtonElement
      ..type = 'button'
      ..className = 'calc-softkey-btn calc-softkey-nxt'
      ..title = 'Next page (F6)';
    final f6Span = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-softkey-fkey'
      ..textContent = 'F6';
    final nxtSpan = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'calc-softkey-label'
      ..textContent = pageCount > 1
          ? 'NXT (${_pageIndex + 1}/$pageCount)'
          : 'NXT';
    nxtBtn
      ..append(f6Span)
      ..append(nxtSpan);
    nxtBtn.addEventListener(
      'click',
      ((web.Event _) {
        _pageIndex = (_pageIndex + 1) % pageCount;
        render(environment: environment, session: session);
      }).toJS,
    );
    _slotsRow.append(nxtBtn);
  }

  /// Handles function keys `F1`–`F6`.
  bool handleFunctionKey(
    String key, {
    required Environment environment,
    required Session session,
  }) {
    const fKeys = ['F1', 'F2', 'F3', 'F4', 'F5', 'F6'];
    final idx = fKeys.indexOf(key);
    if (idx == -1) return false;
    final items = _itemsForMenu(_activeMenu, environment);
    const pageSize = 5;
    final pageCount = items.isEmpty ? 1 : ((items.length - 1) ~/ pageSize) + 1;
    if (idx == 5) {
      _pageIndex = (_pageIndex + 1) % pageCount;
      render(environment: environment, session: session);
      return true;
    }
    final targetIdx = _pageIndex * pageSize + idx;
    if (targetIdx < items.length) {
      items[targetIdx].action();
      return true;
    }
    return false;
  }

  List<_SoftKeyItem> _itemsForMenu(String menu, Environment env) {
    if (menu == 'STACK') {
      return [
        for (final op in const [
          ('SWAP', 'Swap levels 1: and 2:'),
          ('DUP', 'Duplicate level 1:'),
          ('DROP', 'Drop level 1:'),
          ('OVER', 'Copy level 2: to top'),
          ('ROT', 'Rotate top 3 stack levels'),
          ('UNDO', 'Undo last stack operation'),
          ('REDO', 'Redo stack operation'),
          ('LASTARG', 'Recall arguments of last operation'),
          ('PICK', 'Copy level n: to top'),
          ('ROLL', 'Roll level n: to top'),
          ('DEPTH', 'Push current stack depth'),
          ('CLEAR', 'Clear entire stack'),
        ])
          _SoftKeyItem(
            label: op.$1,
            tooltip: op.$2,
            action: () => onExecuteRpnCommand(op.$1),
          ),
      ];
    }

    if (menu == 'VARS') {
      final list = <_SoftKeyItem>[
        _SoftKeyItem(
          label: 'STO',
          tooltip: 'Store level 2: into symbol on level 1:',
          action: () => onExecuteRpnCommand('STO'),
        ),
        _SoftKeyItem(
          label: 'RCL',
          tooltip: 'Recall variable onto stack',
          action: () => onExecuteRpnCommand('RCL'),
        ),
        _SoftKeyItem(
          label: 'PURGE',
          tooltip: 'Delete variable on level 1:',
          action: () => onExecuteRpnCommand('PURGE'),
        ),
      ];
      for (final varName in env.variables.keys) {
        list.add(
          _SoftKeyItem(
            label: varName,
            tooltip: 'Push $varName onto stack',
            action: () => onExecuteRpnCommand(varName),
          ),
        );
      }
      return list;
    }

    final category = CommandCategory.values.firstWhere(
      (c) => c.softMenuLabel == menu,
      orElse: () => CommandCategory.algebra,
    );
    return [
      for (final cmd in CommandRegistry.forCategory(category))
        _SoftKeyItem(
          label: cmd.rpnLabel,
          tooltip: '${cmd.signature} (${cmd.rpnArity}-arg RPN): ${cmd.doc}',
          action: () => onExecuteRpnCommand(cmd.name),
        ),
    ];
  }
}

final class _SoftKeyItem {
  const new({required this.label, required this.tooltip, required this.action});

  final String label;
  final String tooltip;
  final void Function() action;
}
