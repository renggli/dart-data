import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/environment.dart';
import '../model/session.dart';
import '../model/stack.dart';
import 'render.dart';

/// Dynamic Reverse Polish Notation (RPN) stack register display showing
/// active levels `N: … 2: 1:` anchored with contextual actions.
final class RpnStackView {
  new({required this.onExecuteRpnCommand, required this.onInsertText}) {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-rpn-view hidden';
    _registersContainer =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-rpn-registers';
    element.append(_registersContainer);
  }

  final void Function(String command) onExecuteRpnCommand;
  final void Function(String snippet) onInsertText;

  late final web.HTMLDivElement element;
  late final web.HTMLDivElement _registersContainer;

  void render({
    required RpnStack stack,
    required Environment environment,
    required Session session,
  }) {
    _registersContainer.innerHTML = ''.toJS;
    final items = stack.items;

    if (items.isEmpty) {
      final emptyState = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-rpn-empty-state'
        ..textContent =
            'Stack is empty. Enter numbers, expressions, or operators below.';
      _registersContainer.append(emptyState);
      return;
    }

    for (var level = items.length; level >= 1; level--) {
      final row = web.document.createElement('div') as web.HTMLDivElement
        ..className = level == 1
            ? 'calc-rpn-row calc-rpn-level-1'
            : 'calc-rpn-row';

      final levelBadge =
          web.document.createElement('span') as web.HTMLSpanElement
            ..className = 'calc-rpn-level-badge'
            ..textContent = '$level:';
      row.append(levelBadge);

      final stackItem = items[items.length - level];
      final rBadge =
          web.document.createElement('button') as web.HTMLButtonElement
            ..type = 'button'
            ..className = 'calc-r-badge'
            ..textContent = 'r[${stackItem.resultId}]'
            ..title = 'Click to insert r[${stackItem.resultId}]';
      rBadge.addEventListener(
        'click',
        ((web.Event _) => onInsertText('r[${stackItem.resultId}]')).toJS,
      );

      final valNode = ValueRenderer.renderValue(
        stackItem.value,
        digits: environment.settings.digits,
      );

      final rowActions = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-rpn-row-actions';

      if (level == 1) {
        final dupBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-chip-secondary'
              ..textContent = 'Dup'
              ..title = 'Duplicate level 1:';
        dupBtn.addEventListener(
          'click',
          ((web.Event _) => onExecuteRpnCommand('DUP')).toJS,
        );

        final dropBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-btn-danger-outline'
              ..textContent = 'Drop'
              ..title = 'Drop level 1:';
        dropBtn.addEventListener(
          'click',
          ((web.Event _) => onExecuteRpnCommand('DROP')).toJS,
        );

        rowActions
          ..append(dupBtn)
          ..append(dropBtn);
      } else if (level == 2) {
        final swapBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-chip-secondary'
              ..textContent = 'Swap'
              ..title = 'Swap level 1: and 2:';
        swapBtn.addEventListener(
          'click',
          ((web.Event _) => onExecuteRpnCommand('SWAP')).toJS,
        );
        rowActions.append(swapBtn);
      } else {
        final rollBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-chip-secondary'
              ..textContent = '↑ Roll'
              ..title = 'Roll level $level: to level 1:';
        rollBtn.addEventListener(
          'click',
          ((web.Event _) => onExecuteRpnCommand('$level ROLL')).toJS,
        );
        rowActions.append(rollBtn);
      }

      row
        ..append(rBadge)
        ..append(valNode)
        ..append(rowActions);

      _registersContainer.append(row);
    }

    web.window.requestAnimationFrame(
      ((num _) {
        _registersContainer.scrollTop = _registersContainer.scrollHeight;
      }).toJS,
    );
  }
}
