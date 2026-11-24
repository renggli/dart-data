import 'dart:js_interop';

import 'package:data/symbolic.dart';
import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/environment.dart';
import 'highlighter.dart';

/// Quick-insert command & function palette (`Cmd/Ctrl+K`).
final class CommandPalette {
  new({required this.registry, required this.env, required this.onInsert}) {
    _buildDom();
  }

  final CommandRegistry registry;
  final Environment env;
  final void Function(String snippet) onInsert;

  late final web.HTMLDivElement backdrop;
  late final web.HTMLInputElement _input;
  late final web.HTMLDivElement _list;

  void open() {
    backdrop.style.display = 'flex';
    _input.value = '';
    _renderList('');
    _input.focus();
  }

  void close() {
    backdrop.style.display = 'none';
  }

  void _buildDom() {
    backdrop = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-modal-backdrop'
      ..style.display = 'none';

    final modal = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-modal nb-palette';

    _input = (web.document.createElement('input') as web.HTMLInputElement)
      ..type = 'text'
      ..className = 'nb-palette-input'
      ..placeholder =
          'Search commands, special functions, or orthogonal polynomials...';

    _list = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-palette-list';

    modal
      ..append(_input)
      ..append(_list);
    backdrop.append(modal);

    backdrop.onclick = ((web.MouseEvent e) {
      if (e.target == backdrop) close();
    }).toJS;

    _input.oninput = ((web.Event _) => _renderList(_input.value)).toJS;
    _input.onkeydown = ((web.KeyboardEvent e) {
      if (e.key == 'Escape') {
        e.preventDefault();
        close();
      }
    }).toJS;
  }

  void _renderList(String query) {
    final q = query.trim().toLowerCase();
    _list.innerHTML = ''.toJS;

    var count = 0;
    for (final cmd in registry.all) {
      if (q.isNotEmpty &&
          !cmd.name.toLowerCase().contains(q) &&
          !cmd.doc.toLowerCase().contains(q)) {
        continue;
      }
      final ex = cmd.examples.isNotEmpty ? cmd.examples.first : '${cmd.name}()';
      _appendRow(
        title: cmd.signature.format(cmd.name),
        doc: cmd.doc,
        example: ex,
      );
      if (++count >= 25) return;
    }

    for (final fn in ExprSyntax.standardFunctions) {
      if (q.isNotEmpty &&
          !fn.name.toLowerCase().contains(q) &&
          !fn.doc.toLowerCase().contains(q)) {
        continue;
      }
      final ex = '${fn.name}(${fn.params.join(', ')})';
      _appendRow(title: ex, doc: fn.doc, example: ex);
      if (++count >= 25) return;
    }
  }

  void _appendRow({
    required String title,
    required String doc,
    required String example,
  }) {
    final btn = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'nb-palette-item';
    final sigHtml = SyntaxHighlighter.highlightMathHtml(
      title,
      registry: registry,
      env: env,
    );
    btn.innerHTML =
        '<div class="nb-palette-title"><code>$sigHtml</code></div>'
                '<div class="nb-palette-doc">${_escapeHtml(doc)}</div>'
            .toJS;
    btn.onclick = ((web.MouseEvent _) {
      close();
      onInsert(example);
    }).toJS;
    _list.append(btn);
  }

  static String _escapeHtml(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}
