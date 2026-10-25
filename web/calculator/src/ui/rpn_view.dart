import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/environment.dart';
import '../model/session.dart';
import '../model/stack.dart';
import 'chips.dart';
import 'render.dart';

/// Dynamic Reverse Polish Notation (RPN) stack register display showing
/// active levels `N: … 2: 1:` anchored with contextual actions.
final class RpnStackView {
  new({
    required this.onExecuteRpnCommand,
    required this.onInsertText,
    required this.onQuickStartSelect,
  }) {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-rpn-view hidden';
    _registersContainer =
        web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-rpn-registers';
    element.append(_registersContainer);
  }

  final void Function(String command) onExecuteRpnCommand;
  final void Function(String snippet) onInsertText;
  final void Function(String rpnLine) onQuickStartSelect;

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
      _registersContainer.append(_buildEmptyState());
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

        final dropBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-btn-danger-outline'
              ..textContent = 'Drop'
              ..title = 'Drop level 2:';
        dropBtn.addEventListener(
          'click',
          ((web.Event _) => onExecuteRpnCommand('2 DROP')).toJS,
        );

        rowActions
          ..append(swapBtn)
          ..append(dropBtn);
      } else {
        final rollBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-chip-secondary'
              ..textContent = '↑ Move to 1'
              ..title = 'Move level $level: to top of stack (level 1:)';
        rollBtn.addEventListener(
          'click',
          ((web.Event _) => onExecuteRpnCommand('$level ROLL')).toJS,
        );

        final dropBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-chip-btn calc-btn-danger-outline'
              ..textContent = 'Drop'
              ..title = 'Drop level $level:';
        dropBtn.addEventListener(
          'click',
          ((web.Event _) => onExecuteRpnCommand('$level DROP')).toJS,
        );

        rowActions
          ..append(rollBtn)
          ..append(dropBtn);
      }

      row
        ..append(rBadge)
        ..append(valNode)
        ..append(rowActions);

      if (level == 1) {
        final (:primary, :overflow) = CommandRegistry.chipsFor(
          stackItem.value,
          maxChips: 6,
        );
        if (primary.isNotEmpty || overflow.isNotEmpty) {
          final card = web.document.createElement('div') as web.HTMLDivElement
            ..className = 'calc-rpn-level-1-card';
          row.className = 'calc-rpn-row';
          final chipStrip =
              web.document.createElement('div') as web.HTMLDivElement
                ..className = 'calc-chip-strip calc-rpn-chip-strip';
          for (final cmd in primary) {
            final chipBtn =
                web.document.createElement('button') as web.HTMLButtonElement
                  ..type = 'button'
                  ..className = 'calc-chip-btn'
                  ..textContent = cmd.chipLabel
                  ..title = '${cmd.signature} — ${cmd.doc}';
            chipBtn.addEventListener(
              'click',
              ((web.Event _) => onExecuteRpnCommand(cmd.name)).toJS,
            );
            chipStrip.append(chipBtn);
          }
          if (overflow.isNotEmpty) {
            final moreWrap =
                web.document.createElement('div') as web.HTMLDivElement
                  ..className = 'calc-chip-more-wrap';
            final moreBtn =
                web.document.createElement('button') as web.HTMLButtonElement
                  ..type = 'button'
                  ..className = 'calc-chip-btn'
                  ..textContent = '⋯'
                  ..title = 'More operations on level 1:';
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
                  onExecuteRpnCommand(cmd.name);
                }).toJS,
              );
              menu.append(item);
            }
            moreBtn.addEventListener(
              'click',
              ((web.Event e) {
                e.stopPropagation();
                ActionChips.toggleDropdown(moreBtn, menu);
              }).toJS,
            );
            moreWrap
              ..append(moreBtn)
              ..append(menu);
            chipStrip.append(moreWrap);
          }
          card
            ..append(row)
            ..append(chipStrip);
          _registersContainer.append(card);
        } else {
          _registersContainer.append(row);
        }
      } else {
        _registersContainer.append(row);
      }
    }

    web.window.requestAnimationFrame(
      ((num _) {
        _registersContainer.scrollTop = _registersContainer.scrollHeight;
      }).toJS,
    );
  }

  web.HTMLElement _buildEmptyState() {
    final box = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-empty-state';

    final heading = web.document.createElement('h2') as web.HTMLHeadingElement
      ..textContent = 'RPN Stack Workbench';
    final subtitle = web.document.createElement('p') as web.HTMLParagraphElement
      ..textContent =
          "Push numbers or quoted symbolic expressions ('x^2 - 1'), then apply postfix operators or commands to stack levels.";
    box
      ..append(heading)
      ..append(subtitle);

    final grid = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-quickstart-grid';

    const starters = <({String title, String category, String code})>[
      (
        title: 'Postfix Arithmetic',
        category: 'Push & Operate',
        code: '12 4 + 3 *',
      ),
      (
        title: 'Symbolic Factoring',
        category: 'Algebra',
        code: "'x^3 - x' factor",
      ),
      (
        title: 'Symbolic Calculus',
        category: 'Calculus',
        code: "'sin(x)^2' diff",
      ),
      (
        title: 'Matrix Eigenvalues',
        category: 'Linear Algebra',
        code: '[[2, 1], [1, 2]] eigenvals',
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
