import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/environment.dart';
import 'matrix_editor.dart';

/// Collapsible 6-tab virtual mathematical keypad (`Numbers`, `Algebra`,
/// `Trig`, `Calculus`, `Matrix`, `Stack`) for touch devices and desktop mouse
/// entry.
final class VirtualKeypad {
  new({
    required this.onInsert,
    required this.onEvaluate,
    required this.onBackspace,
    required this.onExecuteRpn,
  }) {
    element = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-keypad hidden';
    _tabsBar = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-keypad-tabs';
    _grid = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'calc-keypad-grid';
    element
      ..append(_tabsBar)
      ..append(_grid);
  }

  final void Function(String text, {int cursorBack}) onInsert;
  final void Function({required bool forceNumeric}) onEvaluate;
  final void Function() onBackspace;
  final void Function(String rpnCommand) onExecuteRpn;

  late final web.HTMLDivElement element;
  late final web.HTMLDivElement _tabsBar;
  late final web.HTMLDivElement _grid;

  String _activeTab = 'Numbers';

  static const List<String> _tabs = [
    'Numbers',
    'Algebra',
    'Trig',
    'Calculus',
    'Matrix',
    'Stack',
  ];

  void setVisible(bool visible, {required CalcMode mode}) {
    if (visible) {
      element.classList.remove('hidden');
      render(mode: mode);
    } else {
      element.classList.add('hidden');
    }
  }

  void render({required CalcMode mode}) {
    if (mode == CalcMode.scroll && _activeTab == 'Stack') {
      _activeTab = 'Numbers';
    }
    _tabsBar.innerHTML = ''.toJS;
    for (final tab in _tabs) {
      if (tab == 'Stack' && mode != CalcMode.rpn) continue;
      final btn = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = tab == _activeTab
            ? 'calc-keypad-tab active'
            : 'calc-keypad-tab'
        ..textContent = tab;
      btn.addEventListener(
        'click',
        ((web.Event _) {
          _activeTab = tab;
          render(mode: mode);
        }).toJS,
      );
      _tabsBar.append(btn);
    }

    _grid.innerHTML = ''.toJS;
    final keys = _keysForTab(_activeTab, mode);
    for (final key in keys) {
      final btn = web.document.createElement('button') as web.HTMLButtonElement
        ..type = 'button'
        ..className = 'calc-key-btn ${key.styleClass}'
        ..textContent = key.label
        ..title = key.tooltip;
      btn.addEventListener('click', ((web.Event _) => key.onTap()).toJS);
      _grid.append(btn);
    }
  }

  List<_KeySpec> _keysForTab(String tab, CalcMode mode) {
    _KeySpec ins(
      String label,
      String text, {
      int back = 0,
      String tip = '',
      String cls = '',
    }) => _KeySpec(
      label: label,
      tooltip: tip.isEmpty ? text : tip,
      styleClass: cls,
      onTap: () => onInsert(text, cursorBack: back),
    );

    switch (tab) {
      case 'Numbers':
        return [
          ins('7', '7'),
          ins('8', '8'),
          ins('9', '9'),
          ins('÷', ' / ', cls: 'calc-key-op'),
          ins('(', '()', back: 1, cls: 'calc-key-op'),
          ins('x', 'x', cls: 'calc-key-sym'),
          ins('4', '4'),
          ins('5', '5'),
          ins('6', '6'),
          ins('×', ' * ', cls: 'calc-key-op'),
          ins(')', ')', cls: 'calc-key-op'),
          ins('y', 'y', cls: 'calc-key-sym'),
          ins('1', '1'),
          ins('2', '2'),
          ins('3', '3'),
          ins('−', ' - ', cls: 'calc-key-op'),
          ins('^', '^', cls: 'calc-key-op'),
          ins('π', 'pi', cls: 'calc-key-sym'),
          ins('0', '0'),
          ins('.', '.'),
          ins('i', 'i', cls: 'calc-key-sym'),
          ins('+', ' + ', cls: 'calc-key-op'),
          _KeySpec(
            label: '⌫',
            tooltip: 'Backspace',
            styleClass: 'calc-key-op',
            onTap: onBackspace,
          ),
          _KeySpec(
            label: mode == CalcMode.rpn ? 'ENTER' : '=',
            tooltip: 'Evaluate (Enter)',
            styleClass: 'calc-key-primary',
            onTap: () => onEvaluate(forceNumeric: false),
          ),
        ];

      case 'Algebra':
        return [
          ins('x²', '^2'),
          ins('√', 'sqrt()', back: 1),
          ins(':=', ' := ', tip: 'Assign variable or function'),
          ins('=', ' = ', tip: 'Symbolic equation'),
          ins('r[-1]', 'r[-1]', tip: 'Previous result'),
          _KeySpec(
            label: '≈',
            tooltip: 'Numeric evaluation (Alt+Enter)',
            styleClass: 'calc-key-primary',
            onTap: () => onEvaluate(forceNumeric: true),
          ),
          ins('simplify', 'simplify()', back: 1),
          ins('expand', 'expand()', back: 1),
          ins('factor', 'factor()', back: 1),
          ins('solve', 'solve(, x)', back: 4),
          ins('subs', 'subs(, x = )', back: 6),
          ins('apart', 'apart(, x)', back: 4),
          ins('together', 'together()', back: 1),
          ins('cancel', 'cancel()', back: 1),
          ins('collect', 'collect(, x)', back: 4),
          ins('abs', 'abs()', back: 1),
          ins('ln', 'ln()', back: 1),
          ins('exp', 'exp()', back: 1),
        ];

      case 'Trig':
        return [
          ins('sin', 'sin()', back: 1),
          ins('cos', 'cos()', back: 1),
          ins('tan', 'tan()', back: 1),
          ins('asin', 'asin()', back: 1),
          ins('acos', 'acos()', back: 1),
          ins('atan', 'atan()', back: 1),
          ins('sinh', 'sinh()', back: 1),
          ins('cosh', 'cosh()', back: 1),
          ins('tanh', 'tanh()', back: 1),
          ins('asinh', 'asinh()', back: 1),
          ins('acosh', 'acosh()', back: 1),
          ins('atanh', 'atanh()', back: 1),
          ins('trigexpand', 'trigexpand()', back: 1),
          ins('trigsimp', 'trigsimplify()', back: 1),
          ins('re', 're()', back: 1),
          ins('im', 'im()', back: 1),
          ins('conj', 'conj()', back: 1),
          ins('polar', 'polar()', back: 1),
        ];

      case 'Calculus':
        return [
          ins('d/dx', 'diff(, x)', back: 4),
          ins('∫ dx', 'integrate(, x)', back: 4),
          ins('∫ a..b', 'integrate(, x, 0, 1)', back: 10),
          ins('limit', 'limit(, x, 0)', back: 7),
          ins('taylor', 'taylor(, x, 0, 5)', back: 10),
          ins('series', 'series(, x, 0, 5)', back: 10),
          ins('∑ sum', 'sum(, k, 1, n)', back: 10),
          ins('∏ prod', 'product(, k, 1, n)', back: 10),
          ins('∇ grad', 'gradient(, [x, y])', back: 9),
          ins('hessian', 'hessian(, [x, y])', back: 9),
          ins('jacobian', 'jacobian([], [x, y])', back: 10),
          ins('plot', 'plot(, x, -5, 5)', back: 11),
          ins('n∫', 'nintegrate(, x, 0, 1)', back: 10),
          ins('nsolve', 'nsolve(, x, 1)', back: 7),
          ins('nmin', 'nminimize(, x, -2, 2)', back: 11),
          ins('erf', 'erf()', back: 1),
          ins('gamma', 'gamma()', back: 1),
          ins('W(x)', 'lambertw()', back: 1),
        ];

      case 'Matrix':
        return [
          _KeySpec(
            label: '⊞ Grid',
            tooltip: 'Open visual matrix/vector grid builder',
            styleClass: 'calc-key-primary',
            onTap: () => MatrixEditorModal.open(onInsert: onInsert),
          ),
          ins('[v]', '[, ]', back: 3),
          ins('[[M]]', '[[, ], [, ]]', back: 10),
          ins("A'", "'", tip: 'Matrix transpose'),
          ins('det', 'det()', back: 1),
          ins('inv', 'inv()', back: 1),
          ins('trace', 'trace()', back: 1),
          ins('rref', 'rref()', back: 1),
          ins('rank', 'rank()', back: 1),
          ins('eigenvals', 'eigenvals()', back: 1),
          ins('eigenvects', 'eigenvects()', back: 1),
          ins('charpoly', 'charpoly(, x)', back: 4),
          ins('nullspace', 'nullspace()', back: 1),
          ins('dot', 'dot(, )', back: 3),
          ins('cross', 'cross(, )', back: 3),
          ins('norm', 'norm()', back: 1),
          ins('I(n)', 'identity(3)', back: 1),
          ins('zeros', 'zeros(3, 3)', back: 4),
        ];

      case 'Stack':
      default:
        return [
          _KeySpec(
            label: 'Swap',
            tooltip: 'Swap levels 1: and 2:',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('SWAP'),
          ),
          _KeySpec(
            label: 'Dup',
            tooltip: 'Duplicate level 1:',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('DUP'),
          ),
          _KeySpec(
            label: 'Drop',
            tooltip: 'Drop level 1:',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('DROP'),
          ),
          _KeySpec(
            label: 'Over',
            tooltip: 'Copy level 2: to top',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('OVER'),
          ),
          _KeySpec(
            label: 'Rotate',
            tooltip: 'Rotate top 3 stack levels',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('ROT'),
          ),
          _KeySpec(
            label: 'Undo',
            tooltip: 'Undo last stack operation',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('UNDO'),
          ),
          _KeySpec(
            label: 'Redo',
            tooltip: 'Redo last undone operation',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('REDO'),
          ),
          _KeySpec(
            label: 'Last Args',
            tooltip: 'Recall previous operation arguments',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('LASTARG'),
          ),
          _KeySpec(
            label: 'Pick',
            tooltip: 'Copy level n: to top',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('PICK'),
          ),
          _KeySpec(
            label: 'Roll',
            tooltip: 'Roll level n: to top',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('ROLL'),
          ),
          _KeySpec(
            label: 'Depth',
            tooltip: 'Push current stack depth',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('DEPTH'),
          ),
          _KeySpec(
            label: 'Clear',
            tooltip: 'Clear entire stack',
            styleClass: 'calc-key-op',
            onTap: () => onExecuteRpn('CLEAR'),
          ),
          ins(
            "'expr'",
            "''",
            back: 1,
            tip: 'Quoted algebraic expression for RPN entry',
          ),
          _KeySpec(
            label: 'Store',
            tooltip: 'Store level 2: into variable named on level 1:',
            onTap: () => onExecuteRpn('STO'),
          ),
          _KeySpec(
            label: 'Recall',
            tooltip: 'Recall variable named on level 1:',
            onTap: () => onExecuteRpn('RCL'),
          ),
          _KeySpec(
            label: 'Delete',
            tooltip: 'Delete variable named on level 1:',
            onTap: () => onExecuteRpn('DELETE'),
          ),
          _KeySpec(
            label: 'Approx',
            tooltip: 'Convert level 1: to decimal approximation (≈)',
            styleClass: 'calc-key-fn',
            onTap: () => onExecuteRpn('approx'),
          ),
          _KeySpec(
            label: 'Exact',
            tooltip: 'Convert level 1: to exact fraction / rational',
            styleClass: 'calc-key-fn',
            onTap: () => onExecuteRpn('exact'),
          ),
        ];
    }
  }
}

final class _KeySpec {
  const new({
    required this.label,
    required this.tooltip,
    required this.onTap,
    this.styleClass = '',
  });

  final String label;
  final String tooltip;
  final String styleClass;
  final void Function() onTap;
}
