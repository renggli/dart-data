import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';

/// Slide-over Help & Syntax Reference drawer (`Ctrl/Cmd+/` or `?` button) with
/// click-to-run examples across all 8 command categories, RPN stack reference,
/// and keyboard shortcuts.
final class HelpDrawerModal {
  static void open({required void Function(String example) onRunExample}) {
    final backdrop = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-modal-backdrop';
    final drawer = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-help-drawer';

    final header = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-modal-header';
    final title = web.document.createElement('h3') as web.HTMLHeadingElement
      ..textContent = 'Symbolic Calculator Reference';
    final closeBtn =
        web.document.createElement('button') as web.HTMLButtonElement
          ..type = 'button'
          ..className = 'calc-icon-btn'
          ..textContent = '✕';
    header
      ..append(title)
      ..append(closeBtn);

    final body = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-help-body';

    // Quick syntax section
    final syntaxSec = web.document.createElement('section')
      ..className = 'calc-help-section';
    syntaxSec.innerHTML =
        '''
      <h4>Syntax &amp; Input</h4>
      <ul class="calc-help-list">
        <li><strong>Variables &amp; Functions:</strong> <code>a := 5</code>, <code>f(x, y) := x^2 + y</code></li>
        <li><strong>Result References:</strong> <code>r[1]</code> (cell #1), <code>r[-1]</code> (previous result)</li>
        <li><strong>Vectors &amp; Matrices:</strong> <code>[1, x, x^2]</code>, <code>[[a, b], [c, d]]</code>, transpose <code>A'</code></li>
        <li><strong>Constants:</strong> <code>pi</code> (<code>π</code>), <code>e</code>, <code>i</code>, <code>infinity</code> (<code>∞</code>)</li>
        <li><strong>RPN Mode:</strong> Enter numbers or single-quoted algebraics <code>'x^2 - 1'</code>, then press operators or commands (<code>factor</code>, <code>diff</code>, <code>integrate</code>, <code>SWAP</code>, <code>DUP</code>).</li>
      </ul>
      <h4>Keyboard Shortcuts</h4>
      <ul class="calc-help-list">
        <li><kbd>Enter</kbd> Evaluate exact &bull; <kbd>Alt+Enter</kbd> Evaluate numeric (<code>≈</code>) &bull; <kbd>Shift+Enter</kbd> Newline</li>
        <li><kbd>Ctrl/Cmd+K</kbd> Command Palette &bull; <kbd>Ctrl/Cmd+M</kbd> Toggle Scroll / RPN &bull; <kbd>Ctrl/Cmd+/</kbd> Help</li>
        <li><kbd>↑</kbd> / <kbd>↓</kbd> Input history (or RPN <code>SWAP</code> / <code>DROP</code>) &bull; <kbd>Backspace</kbd> RPN <code>DROP</code></li>
      </ul>
    '''
            .toJS;
    body.append(syntaxSec);

    // Categories
    for (final category in CommandCategory.values) {
      final sec = web.document.createElement('section')
        ..className = 'calc-help-section';
      final h4 = web.document.createElement('h4') as web.HTMLHeadingElement
        ..textContent = '${category.title} (${category.softMenuLabel})';
      sec.append(h4);

      for (final cmd in CommandRegistry.forCategory(category)) {
        final card = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-help-cmd-card';
        final sig = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-help-cmd-sig'
          ..textContent = cmd.signature;
        final doc = web.document.createElement('div') as web.HTMLDivElement
          ..className = 'calc-help-cmd-doc'
          ..textContent = cmd.doc;
        card
          ..append(sig)
          ..append(doc);

        if (cmd.examples.isNotEmpty) {
          final exWrap = web.document.createElement('div') as web.HTMLDivElement
            ..className = 'calc-help-examples';
          for (final ex in cmd.examples) {
            final exBtn =
                web.document.createElement('button') as web.HTMLButtonElement
                  ..type = 'button'
                  ..className = 'calc-chip-btn'
                  ..textContent = '▶ $ex'
                  ..title = 'Click to run in calculator';
            exBtn.addEventListener(
              'click',
              ((web.Event _) {
                backdrop.remove();
                onRunExample(ex);
              }).toJS,
            );
            exWrap.append(exBtn);
          }
          card.append(exWrap);
        }
        sec.append(card);
      }
      body.append(sec);
    }

    closeBtn.addEventListener(
      'click',
      ((web.Event _) => backdrop.remove()).toJS,
    );
    backdrop.addEventListener(
      'click',
      ((web.MouseEvent e) {
        if (e.target == backdrop) backdrop.remove();
      }).toJS,
    );

    drawer
      ..append(header)
      ..append(body);
    backdrop.append(drawer);
    web.document.body?.append(backdrop);
  }
}
