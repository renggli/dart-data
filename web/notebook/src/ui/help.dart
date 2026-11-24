import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/environment.dart';
import 'highlighter.dart';

/// Slide-over reference drawer listing all notebook commands by category with
/// syntax-highlighted examples.
final class HelpDrawer {
  new({
    required this.registry,
    required this.env,
    required this.onInsertExample,
  }) {
    _buildDom();
  }

  final CommandRegistry registry;
  final Environment env;
  final void Function(String example) onInsertExample;

  late final web.HTMLDivElement backdrop;

  void open() {
    backdrop.style.display = 'flex';
  }

  void close() {
    backdrop.style.display = 'none';
  }

  void _buildDom() {
    backdrop = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-drawer-backdrop'
      ..style.display = 'none';

    final drawer = (web.document.createElement('aside') as web.HTMLElement)
      ..className = 'nb-drawer';

    final header = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-drawer-header';
    final title = (web.document.createElement('h3') as web.HTMLHeadingElement)
      ..textContent = 'Command Reference';
    final closeBtn =
        (web.document.createElement('button') as web.HTMLButtonElement)
          ..type = 'button'
          ..className = 'nb-bar-text-btn'
          ..textContent = 'Close';
    closeBtn.onclick = ((web.MouseEvent _) => close()).toJS;
    header
      ..append(title)
      ..append(closeBtn);

    final body = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-drawer-body';

    final grouped = <CommandCategory, List<Command>>{};
    for (final cmd in registry.all) {
      grouped.putIfAbsent(cmd.category, () => []).add(cmd);
    }

    for (final entry in grouped.entries) {
      final sec = (web.document.createElement('section') as web.HTMLElement)
        ..className = 'nb-help-section';
      final h4 = (web.document.createElement('h4') as web.HTMLHeadingElement)
        ..textContent = entry.key.label;
      sec.append(h4);

      for (final cmd in entry.value) {
        final item = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-item';
        final sigHtml = SyntaxHighlighter.highlightMathHtml(
          cmd.signature.format(cmd.name),
          registry: registry,
          env: env,
        );
        final sigEl = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-sig'
          ..innerHTML = '<code>$sigHtml</code>'.toJS;
        final docEl = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-help-doc'
          ..textContent = cmd.doc;
        item
          ..append(sigEl)
          ..append(docEl);

        if (cmd.examples.isNotEmpty) {
          final exRow =
              (web.document.createElement('div') as web.HTMLDivElement)
                ..className = 'nb-help-examples';
          for (final ex in cmd.examples) {
            final exBtn =
                (web.document.createElement('button') as web.HTMLButtonElement)
                  ..type = 'button'
                  ..className = 'nb-help-ex-btn'
                  ..title = 'Insert example'
                  ..innerHTML =
                      '<code>${SyntaxHighlighter.highlightMathHtml(ex, registry: registry, env: env)}</code>'
                          .toJS;
            exBtn.onclick = ((web.MouseEvent _) {
              close();
              onInsertExample(ex);
            }).toJS;
            exRow.append(exBtn);
          }
          item.append(exRow);
        }
        sec.append(item);
      }
      body.append(sec);
    }

    drawer
      ..append(header)
      ..append(body);
    backdrop.append(drawer);

    backdrop.onclick = ((web.MouseEvent e) {
      if (e.target == backdrop) close();
    }).toJS;
  }
}
