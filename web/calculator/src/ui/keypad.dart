import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/environment.dart';

/// Collapsible 6-tab virtual mathematical keypad (`Numbers`, `Algebra`,
/// `Trig`, `Calculus`, `Matrix`, `Stack`) for touch devices and desktop mouse
/// entry.
final class VirtualKeypad {
  new({
    required this.onInsert,
    required this.onBackspace,
    required this.onExecuteRpn,
    this.onToggleMatrixBuilder,
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
  final void Function() onBackspace;
  final void Function(String rpnCommand) onExecuteRpn;
  final void Function()? onToggleMatrixBuilder;
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
        ..className = 'calc-key-btn ${key.styleClass}'.trim()
        ..title = key.tooltip;
      if (key.svgHtml != null) {
        btn.innerHTML = key.svgHtml!.toJS;
        btn.setAttribute('aria-label', key.label);
      } else {
        btn.textContent = key.label;
      }
      btn.addEventListener(
        'mousedown',
        ((web.Event e) => e.preventDefault()).toJS,
      );
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
      String? svgHtml,
    }) => _KeySpec(
      label: label,
      tooltip: tip.isEmpty ? scrollText.trim() : tip,
      styleClass: cls,
      svgHtml: svgHtml,
      onTap: () {
        if (mode == CalcMode.rpn &&
            !(isInsideCompoundLiteral?.call() ?? false)) {
          onExecuteRpn(rpnCommand);
        } else {
          onInsert(scrollText, cursorBack: back);
        }
      },
    );

    const svgDiv =
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        '<line x1="5" y1="12" x2="19" y2="12"/>'
        '<circle cx="12" cy="6" r="1.5" fill="currentColor" stroke="none"/>'
        '<circle cx="12" cy="18" r="1.5" fill="currentColor" stroke="none"/>'
        '</svg>';
    const svgMul =
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        '<line x1="17" y1="7" x2="7" y2="17"/>'
        '<line x1="7" y1="7" x2="17" y2="17"/>'
        '</svg>';
    const svgSub =
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        '<line x1="5" y1="12" x2="19" y2="12"/>'
        '</svg>';
    const svgAdd =
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        '<line x1="12" y1="5" x2="12" y2="19"/>'
        '<line x1="5" y1="12" x2="19" y2="12"/>'
        '</svg>';
    const svgPlusMinus =
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        '<line x1="12" y1="4" x2="12" y2="14"/>'
        '<line x1="7" y1="9" x2="17" y2="9"/>'
        '<line x1="7" y1="19" x2="17" y2="19"/>'
        '</svg>';
    const svgBackspace =
        '<svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">'
        '<path d="M21 4H8l-7 8 7 8h13a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2z"/>'
        '<line x1="18" y1="9" x2="12" y2="15"/>'
        '<line x1="12" y1="9" x2="18" y2="15"/>'
        '</svg>';

    switch (tab) {
      case 'Numbers':
        if (mode == CalcMode.rpn) {
          return [
            ins('7', '7', cls: 'calc-key-num'),
            ins('8', '8', cls: 'calc-key-num'),
            ins('9', '9', cls: 'calc-key-num'),
            cmdKey(
              'Divide (/)',
              ' / ',
              rpnCommand: '/',
              cls: 'calc-key-op',
              svgHtml: svgDiv,
            ),
            cmdKey(
              'x²',
              '^2',
              rpnCommand: '²',
              tip: 'Square (x²)',
              cls: 'calc-key-op',
            ),
            cmdKey(
              '√x',
              'sqrt()',
              rpnCommand: 'sqrt',
              back: 1,
              tip: 'Square root (sqrt)',
              cls: 'calc-key-op',
            ),
            ins('4', '4', cls: 'calc-key-num'),
            ins('5', '5', cls: 'calc-key-num'),
            ins('6', '6', cls: 'calc-key-num'),
            cmdKey(
              'Multiply (*)',
              ' * ',
              rpnCommand: '*',
              cls: 'calc-key-op',
              svgHtml: svgMul,
            ),
            cmdKey(
              'xʸ',
              '^',
              rpnCommand: '^',
              tip: 'Power (^)',
              cls: 'calc-key-op',
            ),
            cmdKey(
              'Negate (±)',
              '-',
              rpnCommand: 'NEG',
              tip: 'Negate (NEG)',
              cls: 'calc-key-op',
              svgHtml: svgPlusMinus,
            ),
            ins('1', '1', cls: 'calc-key-num'),
            ins('2', '2', cls: 'calc-key-num'),
            ins('3', '3', cls: 'calc-key-num'),
            cmdKey(
              'Subtract (-)',
              ' - ',
              rpnCommand: '-',
              cls: 'calc-key-op',
              svgHtml: svgSub,
            ),
            ins('x', 'x', tip: 'Symbol x', cls: 'calc-key-sym'),
            ins('y', 'y', tip: 'Symbol y', cls: 'calc-key-sym'),
            ins('0', '0', cls: 'calc-key-num'),
            ins('.', '.', cls: 'calc-key-num'),
            ins('π', 'pi', tip: 'Constant π (pi)', cls: 'calc-key-sym'),
            cmdKey(
              'Add (+)',
              ' + ',
              rpnCommand: '+',
              cls: 'calc-key-op',
              svgHtml: svgAdd,
            ),
            ins(
              '␣ Space',
              ' ',
              tip: 'Space separator between RPN tokens',
              cls: 'calc-key-op',
            ),
            _KeySpec(
              label: 'Backspace',
              tooltip: 'Backspace',
              styleClass: 'calc-key-op',
              svgHtml: svgBackspace,
              onTap: onBackspace,
            ),
          ];
        }
        return [
          ins('7', '7', cls: 'calc-key-num'),
          ins('8', '8', cls: 'calc-key-num'),
          ins('9', '9', cls: 'calc-key-num'),
          cmdKey(
            'Divide (/)',
            ' / ',
            rpnCommand: '/',
            cls: 'calc-key-op',
            svgHtml: svgDiv,
          ),
          ins('(', '()', back: 1, tip: 'Parentheses ( )', cls: 'calc-key-op'),
          ins(')', ')', tip: 'Closing parenthesis )', cls: 'calc-key-op'),
          ins('4', '4', cls: 'calc-key-num'),
          ins('5', '5', cls: 'calc-key-num'),
          ins('6', '6', cls: 'calc-key-num'),
          cmdKey(
            'Multiply (*)',
            ' * ',
            rpnCommand: '*',
            cls: 'calc-key-op',
            svgHtml: svgMul,
          ),
          cmdKey(
            'xʸ',
            '^',
            rpnCommand: '^',
            tip: 'Power (^)',
            cls: 'calc-key-op',
          ),
          cmdKey(
            '√x',
            'sqrt()',
            rpnCommand: 'sqrt',
            back: 1,
            tip: 'Square root (sqrt)',
            cls: 'calc-key-op',
          ),
          ins('1', '1', cls: 'calc-key-num'),
          ins('2', '2', cls: 'calc-key-num'),
          ins('3', '3', cls: 'calc-key-num'),
          cmdKey(
            'Subtract (-)',
            ' - ',
            rpnCommand: '-',
            cls: 'calc-key-op',
            svgHtml: svgSub,
          ),
          ins('x', 'x', tip: 'Symbol x', cls: 'calc-key-sym'),
          ins('y', 'y', tip: 'Symbol y', cls: 'calc-key-sym'),
          ins('0', '0', cls: 'calc-key-num'),
          ins('.', '.', cls: 'calc-key-num'),
          ins('π', 'pi', tip: 'Constant π (pi)', cls: 'calc-key-sym'),
          cmdKey(
            'Add (+)',
            ' + ',
            rpnCommand: '+',
            cls: 'calc-key-op',
            svgHtml: svgAdd,
          ),
          ins('i', 'i', tip: 'Imaginary unit i', cls: 'calc-key-sym'),
          _KeySpec(
            label: 'Backspace',
            tooltip: 'Backspace',
            styleClass: 'calc-key-op',
            svgHtml: svgBackspace,
            onTap: onBackspace,
          ),
        ];

      case 'Algebra':
        return [
          cmdKey('x²', '^2', rpnCommand: '²'),
          cmdKey('√x', 'sqrt()', rpnCommand: 'sqrt', back: 1),
          cmdKey('n!', '!', rpnCommand: '!', tip: 'Factorial (!)'),
          ins('e', 'e', tip: "Euler's constant e", cls: 'calc-key-sym'),
          ins('=', ' = ', tip: 'Symbolic equation'),
          ins('r[-1]', 'r[-1]', tip: 'Previous result'),
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
            tooltip: 'Toggle docked matrix/vector grid builder',
            styleClass: 'calc-key-primary',
            onTap: () => onToggleMatrixBuilder?.call(),
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
    this.svgHtml,
  });

  final String label;
  final String tooltip;
  final String styleClass;
  final String? svgHtml;
  final void Function() onTap;
}
