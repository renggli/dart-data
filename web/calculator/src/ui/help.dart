import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../language/completion.dart';

/// Renders the Help & Syntax Reference (`Ctrl/Cmd+/` or `?` button) with
/// click-to-run examples across all 8 command categories, RPN stack reference,
/// and keyboard shortcuts into a side panel body.
final class HelpPanel {
  static void render(
    web.HTMLElement container, {
    required void Function(String example) onRunExample,
  }) {
    container.innerHTML = ''.toJS;
    final body = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-help-body';

    // Quick syntax section
    final syntaxSec = web.document.createElement('section')
      ..className = 'calc-help-section';
    syntaxSec.innerHTML =
        '''
      <h4>Syntax</h4>
      <ul class="calc-help-list">
        <li><code>a := 5</code>, <code>f(x, y) := x^2 + y</code> &mdash; assign variables &amp; functions</li>
        <li><code>r[1]</code>, <code>r[-1]</code> &mdash; reference cell #1 or previous result</li>
        <li><code>[1, x, x^2]</code>, <code>[[a, b], [c, d]]</code>, <code>A'</code> &mdash; vectors, matrices, transpose</li>
        <li><code>pi</code> (<code>π</code>), <code>e</code>, <code>i</code>, <code>infinity</code> (<code>∞</code>) &mdash; constants (angles in radians)</li>
        <li>RPN: postfix (<code>x 2 ^ 1 - factor</code>) or quoted infix (<code>'x^2 - 1'</code>)</li>
      </ul>
    '''
            .toJS;

    final shortcutsSec = web.document.createElement('section')
      ..className = 'calc-help-section';
    shortcutsSec.innerHTML =
        '''
      <h4>Shortcuts</h4>
      <ul class="calc-help-list">
        <li><kbd>Enter</kbd> exact &bull; <kbd>Alt+Enter</kbd> numeric (<code>≈</code>) &bull; <kbd>Shift+Enter</kbd> newline</li>
        <li><kbd>⌘K</kbd> palette &bull; <kbd>⌘M</kbd> Scroll / RPN &bull; <kbd>⌘/</kbd> help</li>
        <li><kbd>↑</kbd>/<kbd>↓</kbd> history or RPN <code>SWAP</code>/<code>DROP</code> &bull; <kbd>Backspace</kbd> RPN <code>DROP</code></li>
      </ul>
    '''
            .toJS;
    body
      ..append(syntaxSec)
      ..append(shortcutsSec);

    // Categories
    for (final category in CommandCategory.values) {
      final sec = web.document.createElement('section')
        ..className = 'calc-help-section';
      final h4 = web.document.createElement('h4') as web.HTMLHeadingElement
        ..textContent = category.title;
      sec.append(h4);

      for (final cmd in CommandRegistry.forCategory(category)) {
        sec.append(
          _buildHelpItem(
            signature: cmd.signature,
            doc: cmd.doc,
            examples: cmd.examples,
            onRunExample: onRunExample,
          ),
        );
      }
      body.append(sec);
    }

    // Mathematical & Special Functions
    final fnSec = web.document.createElement('section')
      ..className = 'calc-help-section';
    final fnHeader = web.document.createElement('h4') as web.HTMLHeadingElement
      ..textContent = 'Mathematical & Special Functions';
    fnSec.append(fnHeader);
    for (final fn in CalcCompletion.mathFunctions) {
      if (CommandRegistry.byName.containsKey(fn.name)) continue;
      fnSec.append(
        _buildHelpItem(
          signature: fn.signature,
          doc: fn.doc,
          examples: fn.examples,
          onRunExample: onRunExample,
        ),
      );
    }
    body.append(fnSec);

    container.append(body);
  }

  static web.HTMLDivElement _buildHelpItem({
    required String signature,
    required String doc,
    required List<String> examples,
    required void Function(String example) onRunExample,
  }) {
    final item = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-help-cmd';
    final sigEl = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-help-cmd-sig'
      ..textContent = signature;
    final docEl = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-help-cmd-doc'
      ..textContent = doc;
    item
      ..append(sigEl)
      ..append(docEl);

    if (examples.isNotEmpty) {
      final exWrap = web.document.createElement('div') as web.HTMLDivElement
        ..className = 'calc-help-examples';
      for (final ex in examples) {
        final exBtn =
            web.document.createElement('button') as web.HTMLButtonElement
              ..type = 'button'
              ..className = 'calc-help-example-btn'
              ..textContent = ex
              ..title = 'Run example';
        exBtn.addEventListener(
          'click',
          ((web.Event _) => onRunExample(ex)).toJS,
        );
        exWrap.append(exBtn);
      }
      item.append(exWrap);
    }
    return item;
  }
}
