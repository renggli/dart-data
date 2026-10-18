import 'dart:js_interop';
import 'dart:math' as math;

import 'package:web/web.dart' as web;

import '../model/environment.dart';
import '../model/session.dart';
import '../model/stack.dart';
import 'render.dart';
import 'soft_keys.dart';

/// HP48-inspired Reverse Polish Notation (RPN) stack register display showing
/// levels `N: … 4: 3: 2: 1:` anchored at the bottom above the 6-slot soft-key
/// menu bar (`F1`–`F6`).
final class RpnStackView {
  new({required this.onExecuteRpnCommand, required this.onInsertText}) {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-rpn-view hidden';
    _registersContainer =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-rpn-registers';
    softKeyBar = SoftKeyBar(
      onExecuteRpnCommand: onExecuteRpnCommand,
      onInsertText: onInsertText,
    );
    element
      ..append(_registersContainer)
      ..append(softKeyBar.element);
  }

  final void Function(String command) onExecuteRpnCommand;
  final void Function(String snippet) onInsertText;

  late final web.HTMLDivElement element;
  late final web.HTMLDivElement _registersContainer;
  late final SoftKeyBar softKeyBar;

  void render({
    required RpnStack stack,
    required Environment environment,
    required Session session,
  }) {
    _registersContainer.innerHTML = ''.toJS;
    final items = stack.items;
    final totalRows = math.max(4, items.length);

    for (var level = totalRows; level >= 1; level--) {
      final row = web.document.createElement('div') as web.HTMLDivElement
        ..className = level == 1
            ? 'calc-rpn-row calc-rpn-level-1'
            : 'calc-rpn-row';

      final levelBadge =
          web.document.createElement('span') as web.HTMLSpanElement
            ..className = 'calc-rpn-level-badge'
            ..textContent = '$level:';
      row.append(levelBadge);

      if (level <= items.length) {
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

        final rowActions =
            web.document.createElement('div') as web.HTMLDivElement
              ..className = 'calc-rpn-row-actions';
        if (level > 1) {
          final rollBtn =
              web.document.createElement('button') as web.HTMLButtonElement
                ..type = 'button'
                ..className = 'calc-chip-btn calc-chip-secondary'
                ..textContent = '↑ Roll to 1:'
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
      } else {
        final emptySlot =
            web.document.createElement('span') as web.HTMLSpanElement
              ..className = 'calc-rpn-empty-slot'
              ..textContent = '—';
        row.append(emptySlot);
      }

      _registersContainer.append(row);
    }

    softKeyBar.render(environment: environment, session: session);

    web.window.requestAnimationFrame(
      ((num _) {
        _registersContainer.scrollTop = _registersContainer.scrollHeight;
      }).toJS,
    );
  }
}
