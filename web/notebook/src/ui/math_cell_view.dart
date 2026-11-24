import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../engine/commands.dart';
import '../model/environment.dart';
import '../model/notebook.dart';
import '../model/value.dart';
import 'chips.dart';
import 'code_editor.dart';
import 'highlighter.dart';
import 'icons.dart';
import 'plot_view.dart';

/// Document-first view for a [MathCell]: clean syntax-highlighted input +
/// rendered MathML/Plot output at rest; inline [CodeEditor], compact toolbar,
/// and contextual chips strictly when focused.
final class MathCellView {
  new({
    required this.cell,
    required this.env,
    required this.registry,
    required this.isFocused,
    required this.onFocus,
    required this.onRun,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onConvertToText,
    required this.onDelete,
    required this.onBlurExit,
  }) {
    _buildDom();
  }

  final MathCell cell;
  final Environment env;
  final CommandRegistry registry;
  final bool isFocused;

  final void Function() onFocus;
  final void Function(
    String source, {
    required bool advance,
    required bool approx,
  })
  onRun;
  final void Function() onMoveUp;
  final void Function() onMoveDown;
  final void Function() onConvertToText;
  final void Function() onDelete;
  final void Function() onBlurExit;

  late final web.HTMLDivElement root;
  CodeEditor? _editor;
  PlotView? _plotView;

  void focusEditor({bool moveToEnd = true}) {
    _editor?.focus(moveToEnd: moveToEnd);
  }

  void mountRenderables() {
    _plotView?.render();
  }

  void dispose() {
    _plotView?.dispose();
  }

  void _buildDom() {
    final classes = <String>[
      'nb-cell',
      'nb-cell-math',
      if (isFocused) 'focused',
      if (cell.stale) 'stale',
    ];
    root = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = classes.join(' ')
      ..setAttribute('data-uid', cell.uid);

    // Muted r[n] margin badge (visible on hover / focus)
    final badge = (web.document.createElement('span') as web.HTMLSpanElement)
      ..className = 'nb-margin-id'
      ..textContent = 'r[${cell.id}]'
      ..title = 'Reference this result as r[${cell.id}]';
    root.append(badge);

    if (isFocused) {
      root.append(_buildToolbar());
      final editor = CodeEditor(
        mode: CodeEditorMode.math,
        registry: registry,
        env: env,
        initialText: cell.source,
        placeholder: 'Enter expression, assignment (a := ...), or command...',
        onRunAndAdvance: (val) => onRun(val, advance: true, approx: false),
        onRunInPlace: (val) => onRun(val, advance: false, approx: false),
        onApprox: (val) => onRun(val, advance: false, approx: true),
        onEscape: onBlurExit,
      );
      if (cell.value case ErrorValue(:final message, :final offset)) {
        editor.setError(message, offset: offset);
      }
      _editor = editor;
      root.append(editor.root);

      final chips = ActionChips.build(
        cell.source,
        cell.value,
        registry,
        (call) => onRun(call, advance: false, approx: false),
      );
      if (chips.children.length > 0) {
        root.append(chips);
      }
    } else {
      final inputPreview =
          (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-math-input-rest';
      final pre = (web.document.createElement('pre') as web.HTMLPreElement)
        ..className = 'nb-math-code-rest'
        ..innerHTML =
            (cell.source.trim().isEmpty
                    ? '<span class="tok-comment">Empty math cell — click to edit</span>'
                    : SyntaxHighlighter.highlightMathHtml(
                        cell.source,
                        registry: registry,
                        env: env,
                      ))
                .toJS;
      inputPreview
        ..append(pre)
        ..onclick = ((web.MouseEvent _) => onFocus()).toJS;
      root.append(inputPreview);
    }

    if (cell.value case final val?) {
      if (val is! InfoValue || val.message.isNotEmpty) {
        root.append(_buildOutput(val));
      }
    }
  }

  web.HTMLDivElement _buildToolbar() {
    final bar = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-contextual-bar';

    bar
      ..append(
        _btn(
          'Run (Shift+Enter)',
          NbIcons.play,
          () => onRun(
            _editor?.value ?? cell.source,
            advance: true,
            approx: false,
          ),
        ),
      )
      ..append(
        _btn(
          'Approximate (Alt+Enter)',
          NbIcons.approx,
          () => onRun(
            _editor?.value ?? cell.source,
            advance: false,
            approx: true,
          ),
        ),
      )
      ..append(_btn('Move up', NbIcons.arrowUp, onMoveUp))
      ..append(_btn('Move down', NbIcons.arrowDown, onMoveDown))
      ..append(_textBtn('Text', 'Convert to Markdown cell', onConvertToText))
      ..append(_btn('Delete cell', NbIcons.trash, onDelete));

    return bar;
  }

  web.HTMLDivElement _buildOutput(CalcValue val) {
    final out = (web.document.createElement('div') as web.HTMLDivElement)
      ..className = 'nb-math-output';

    switch (val) {
      case PlotValue():
        final pv = PlotView(val);
        _plotView = pv;
        out.append(pv.root);

      case ErrorValue(:final message, :final suggestion):
        final err = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-output-error'
          ..textContent = suggestion != null
              ? '$message ($suggestion)'
              : message;
        out.append(err);

      case InfoValue(:final message, :final title):
        final info = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-output-info';
        if (title != null && title.isNotEmpty) {
          final t = (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-output-info-title'
            ..textContent = title;
          info.append(t);
        }
        final body = (web.document.createElement('pre') as web.HTMLPreElement)
          ..className = 'nb-output-info-body'
          ..textContent = message;
        info.append(body);
        out.append(info);

      default:
        final mathEl = (web.document.createElement('div') as web.HTMLDivElement)
          ..className = 'nb-output-math'
          ..innerHTML = val.toMathMl(display: true).toJS;
        out.append(mathEl);

        final approx = val.approxSummary(digits: env.settings.digits);
        if (approx != null) {
          final sub = (web.document.createElement('div') as web.HTMLDivElement)
            ..className = 'nb-output-approx'
            ..textContent = '≈ $approx';
          out.append(sub);
        }
    }

    return out;
  }

  web.HTMLButtonElement _btn(String title, String svg, void Function() onTap) {
    final b = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'icon-btn'
      ..title = title
      ..innerHTML = svg.toJS;
    b.onmousedown = ((web.MouseEvent e) {
      e.preventDefault();
      onTap();
    }).toJS;
    return b;
  }

  web.HTMLButtonElement _textBtn(
    String label,
    String title,
    void Function() onTap,
  ) {
    final b = (web.document.createElement('button') as web.HTMLButtonElement)
      ..type = 'button'
      ..className = 'nb-bar-text-btn'
      ..title = title
      ..textContent = label;
    b.onmousedown = ((web.MouseEvent e) {
      e.preventDefault();
      onTap();
    }).toJS;
    return b;
  }
}
