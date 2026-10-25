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
    this.isInsideCompoundLiteral,
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
  final bool Function()? isInsideCompoundLiteral;

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

    _KeySpec cmdKey(
      String label,
      String scrollText, {
      required String rpnCommand,
      int back = 0,
      String tip = '',
      String cls = '',
    }) => _KeySpec(
      label: label,
      tooltip: tip.isEmpty ? scrollText : tip,
      styleClass: cls,
      onTap: () {
        if (mode == CalcMode.rpn &&
            !(isInsideCompoundLiteral?.call() ?? false)) {
          onExecuteRpn(rpnCommand);
        } else {
          onInsert(scrollText, cursorBack: back);
        }
      },
    );

    switch (tab) {
      case 'Numbers':
        return [
          ins('7', '7'),
          ins('8', '8'),
          ins('9', '9'),
          cmdKey('÷', ' / ', rpnCommand: '/', cls: 'calc-key-op'),
          ins('(', '()', back: 1, cls: 'calc-key-op'),
          ins('x', 'x', cls: 'calc-key-sym'),
          ins('4', '4'),
          ins('5', '5'),
          ins('6', '6'),
          cmdKey('×', ' * ', rpnCommand: '*', cls: 'calc-key-op'),
          ins(')', ')', cls: 'calc-key-op'),
          ins('y', 'y', cls: 'calc-key-sym'),
          ins('1', '1'),
          ins('2', '2'),
          ins('3', '3'),
          cmdKey('−', ' - ', rpnCommand: '-', cls: 'calc-key-op'),
          cmdKey('^', '^', rpnCommand: '^', cls: 'calc-key-op'),
          ins('π', 'pi', cls: 'calc-key-sym'),
          ins('0', '0'),
          ins('.', '.'),
          ins('i', 'i', cls: 'calc-key-sym'),
          cmdKey('+', ' + ', rpnCommand: '+', cls: 'calc-key-op'),
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
          cmdKey('x²', '^2', rpnCommand: '²'),
          cmdKey('√', 'sqrt()', rpnCommand: 'sqrt', back: 1),
          ins(':=', ' := ', tip: 'Assign variable or function'),
          ins('=', ' = ', tip: 'Symbolic equation'),
          ins('r[-1]', 'r[-1]', tip: 'Previous result'),
          _KeySpec(
            label: '≈',
            tooltip: 'Numeric evaluation (Alt+Enter)',
            styleClass: 'calc-key-primary',
            onTap: () => onEvaluate(forceNumeric: true),
          ),
          cmdKey('simplify', 'simplify()', rpnCommand: 'simplify', back: 1),
          cmdKey('expand', 'expand()', rpnCommand: 'expand', back: 1),
          cmdKey('factor', 'factor()', rpnCommand: 'factor', back: 1),
          cmdKey('solve', 'solve(, x)', rpnCommand: 'solve', back: 4),
          cmdKey('subs', 'subs(, x = )', rpnCommand: 'subs', back: 6),
          cmdKey('apart', 'apart(, x)', rpnCommand: 'apart', back: 4),
          cmdKey('together', 'together()', rpnCommand: 'together', back: 1),
          cmdKey('cancel', 'cancel()', rpnCommand: 'cancel', back: 1),
          cmdKey('collect', 'collect(, x)', rpnCommand: 'collect', back: 4),
          cmdKey('abs', 'abs()', rpnCommand: 'abs', back: 1),
          cmdKey('ln', 'ln()', rpnCommand: 'ln', back: 1),
          cmdKey('exp', 'exp()', rpnCommand: 'exp', back: 1),
        ];

      case 'Trig':
        return [
          cmdKey('sin', 'sin()', rpnCommand: 'sin', back: 1),
          cmdKey('cos', 'cos()', rpnCommand: 'cos', back: 1),
          cmdKey('tan', 'tan()', rpnCommand: 'tan', back: 1),
          cmdKey('asin', 'asin()', rpnCommand: 'asin', back: 1),
          cmdKey('acos', 'acos()', rpnCommand: 'acos', back: 1),
          cmdKey('atan', 'atan()', rpnCommand: 'atan', back: 1),
          cmdKey('sinh', 'sinh()', rpnCommand: 'sinh', back: 1),
          cmdKey('cosh', 'cosh()', rpnCommand: 'cosh', back: 1),
          cmdKey('tanh', 'tanh()', rpnCommand: 'tanh', back: 1),
          cmdKey('asinh', 'asinh()', rpnCommand: 'asinh', back: 1),
          cmdKey('acosh', 'acosh()', rpnCommand: 'acosh', back: 1),
          cmdKey('atanh', 'atanh()', rpnCommand: 'atanh', back: 1),
          cmdKey(
            'trigexpand',
            'trigexpand()',
            rpnCommand: 'trigexpand',
            back: 1,
          ),
          cmdKey(
            'trigsimp',
            'trigsimplify()',
            rpnCommand: 'trigsimplify',
            back: 1,
          ),
          cmdKey('re', 're()', rpnCommand: 're', back: 1),
          cmdKey('im', 'im()', rpnCommand: 'im', back: 1),
          cmdKey('conj', 'conj()', rpnCommand: 'conj', back: 1),
          cmdKey('polar', 'polar()', rpnCommand: 'polar', back: 1),
        ];

      case 'Calculus':
        return [
          cmdKey('d/dx', 'diff(, x)', rpnCommand: 'diff', back: 4),
          cmdKey('∫ dx', 'integrate(, x)', rpnCommand: 'integrate', back: 4),
          cmdKey(
            '∫ a..b',
            'integrate(, x, 0, 1)',
            rpnCommand: 'DEF∫',
            back: 10,
          ),
          cmdKey('limit', 'limit(, x, 0)', rpnCommand: 'limit', back: 7),
          cmdKey('taylor', 'taylor(, x, 0, 5)', rpnCommand: 'taylor', back: 10),
          cmdKey('series', 'series(, x, 0, 5)', rpnCommand: 'series', back: 10),
          cmdKey('∑ sum', 'sum(, k, 1, n)', rpnCommand: 'sum', back: 10),
          cmdKey(
            '∏ prod',
            'product(, k, 1, n)',
            rpnCommand: 'product',
            back: 10,
          ),
          cmdKey(
            '∇ grad',
            'gradient(, [x, y])',
            rpnCommand: 'gradient',
            back: 9,
          ),
          cmdKey(
            'hessian',
            'hessian(, [x, y])',
            rpnCommand: 'hessian',
            back: 9,
          ),
          cmdKey(
            'jacobian',
            'jacobian([], [x, y])',
            rpnCommand: 'jacobian',
            back: 10,
          ),
          cmdKey('plot', 'plot(, x, -5, 5)', rpnCommand: 'plot', back: 11),
          cmdKey(
            'n∫',
            'nintegrate(, x, 0, 1)',
            rpnCommand: 'nintegrate',
            back: 10,
          ),
          cmdKey('nsolve', 'nsolve(, x, 1)', rpnCommand: 'nsolve', back: 7),
          cmdKey(
            'nmin',
            'nminimize(, x, -2, 2)',
            rpnCommand: 'nminimize',
            back: 11,
          ),
          cmdKey('erf', 'erf()', rpnCommand: 'erf', back: 1),
          cmdKey('gamma', 'gamma()', rpnCommand: 'gamma', back: 1),
          cmdKey('W(x)', 'lambertw()', rpnCommand: 'lambertw', back: 1),
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
          cmdKey("A'", "'", rpnCommand: 'transpose', tip: 'Matrix transpose'),
          cmdKey('det', 'det()', rpnCommand: 'det', back: 1),
          cmdKey('inv', 'inv()', rpnCommand: 'inv', back: 1),
          cmdKey('trace', 'trace()', rpnCommand: 'trace', back: 1),
          cmdKey('rref', 'rref()', rpnCommand: 'rref', back: 1),
          cmdKey('rank', 'rank()', rpnCommand: 'rank', back: 1),
          cmdKey('eigenvals', 'eigenvals()', rpnCommand: 'eigenvals', back: 1),
          cmdKey(
            'eigenvects',
            'eigenvects()',
            rpnCommand: 'eigenvects',
            back: 1,
          ),
          cmdKey('charpoly', 'charpoly(, x)', rpnCommand: 'charpoly', back: 4),
          cmdKey('nullspace', 'nullspace()', rpnCommand: 'nullspace', back: 1),
          cmdKey('dot', 'dot(, )', rpnCommand: 'dot', back: 3),
          cmdKey('cross', 'cross(, )', rpnCommand: 'cross', back: 3),
          cmdKey('norm', 'norm()', rpnCommand: 'norm', back: 1),
          cmdKey('I(n)', 'identity(3)', rpnCommand: 'identity', back: 1),
          cmdKey('zeros', 'zeros(3, 3)', rpnCommand: 'zeros', back: 4),
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
