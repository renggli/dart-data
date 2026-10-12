import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:web/web.dart' as web;

import '../shared/chart.dart';
import '../shared/utils.dart';
import 'presets.dart';

// Current Application State
ExpressionPreset? activePreset;
String currentFormula = 'x^3 - 3*x + 1';
Expr? parsedExpr;
double Function(double)? fnCompiled;
double Function(double)? dfCompiled;
double Function(double)? d2fCompiled;
double Function(double)? d3fCompiled;
double Function(double)? taylorCompiled;

double minX = -3.0;
double maxX = 3.0;
double pointX = 1.0;
double intA = -1.0;
double intB = 2.0;
IntegrationMethod intMethod = IntegrationMethod.gaussKronrod;
int taylorOrder = 3;
double taylorAround = 0.0;

bool showFx = true;
bool showDfx = false;
bool showD2fx = false;
bool showD3fx = false;
bool showTaylor = false;
bool showIntegral = false;
bool showTangent = false;
bool showRoots = true;
bool showMin = true;
bool showMax = true;

// Hover coordinates
double? mouseX;
double? mouseY;

// Critical points & roots
final List<double> exactRoots = [];
final List<double> numericRoots = [];
final List<(double, double)> localMinima = [];
final List<(double, double)> localMaxima = [];

// DOM References
late web.HTMLInputElement searchBox;
late web.HTMLElement presetsList;
late web.HTMLElement displayTitle;
late web.HTMLElement categoryBadge;
late web.HTMLElement displayDesc;

late web.HTMLInputElement exprInput;
late web.HTMLElement statusBadge;
late web.HTMLElement parseErrorMessage;

late web.HTMLCanvasElement plotCanvas;
late web.HTMLInputElement rangeMinX;
late web.HTMLInputElement rangeMaxX;
late web.HTMLButtonElement btnZoomReset;

late web.HTMLInputElement toggleFx;
late web.HTMLInputElement toggleDfx;
late web.HTMLInputElement toggleD2fx;
late web.HTMLInputElement toggleD3fx;
late web.HTMLInputElement toggleTaylor;
late web.HTMLInputElement toggleIntegral;
late web.HTMLInputElement toggleTangent;
late web.HTMLInputElement toggleRoots;
late web.HTMLInputElement toggleMin;
late web.HTMLInputElement toggleMax;

late web.HTMLElement toggleLblFx;
late web.HTMLElement toggleLblDfx;
late web.HTMLElement toggleLblD2fx;
late web.HTMLElement toggleLblD3fx;
late web.HTMLElement toggleLblTaylor;
late web.HTMLElement toggleLblIntegral;
late web.HTMLElement toggleLblTangent;
late web.HTMLElement toggleLblRoots;
late web.HTMLElement toggleLblMin;
late web.HTMLElement toggleLblMax;

late web.HTMLElement valSymFx;
late web.HTMLElement valSymText;
late web.HTMLElement valSymDf;
late web.HTMLElement valSymD2f;
late web.HTMLElement valSymD3f;
late web.HTMLElement valSymAntideriv;
late web.HTMLElement valSymLatex;
late web.HTMLElement valSymMathml;

late web.HTMLInputElement sliderPointX;
late web.HTMLInputElement inputPointX;
late web.HTMLElement pointXDisplay;
late web.HTMLElement valEvalFx;
late web.HTMLElement valEvalDfAnalytical;
late web.HTMLElement valEvalDfNumerical;
late web.HTMLElement valTangentEq;

late web.HTMLSelectElement selectIntMethod;
late web.HTMLInputElement inputIntA;
late web.HTMLInputElement inputIntB;
late web.HTMLElement valIntNumerical;
late web.HTMLElement valIntAnalytical;

late web.HTMLInputElement sliderTaylorOrder;
late web.HTMLSelectElement selectTaylorCenter;
late web.HTMLInputElement inputTaylorAround;
late web.HTMLElement taylorOrderVal;
late web.HTMLElement taylorPolynomialStr;

late web.HTMLElement valRootsExact;
late web.HTMLElement valRootsNumeric;
late web.HTMLElement valExtremaMin;
late web.HTMLElement valExtremaMax;

void main() {
  initDom();
  initGlobalCopyHandler();
  buildSidebar();
  attachEventListeners();
  loadFromUrlHash();
}

void initDom() {
  searchBox = web.document.querySelector('#search-box') as web.HTMLInputElement;
  presetsList = web.document.querySelector('#presets-list') as web.HTMLElement;
  displayTitle =
      web.document.querySelector('#display-title') as web.HTMLElement;
  categoryBadge =
      web.document.querySelector('#category-badge') as web.HTMLElement;
  displayDesc = web.document.querySelector('#display-desc') as web.HTMLElement;

  exprInput = web.document.querySelector('#expr-input') as web.HTMLInputElement;
  statusBadge = web.document.querySelector('#status-badge') as web.HTMLElement;
  parseErrorMessage =
      web.document.querySelector('#parse-error-message') as web.HTMLElement;

  plotCanvas =
      web.document.querySelector('#plot-canvas') as web.HTMLCanvasElement;
  rangeMinX =
      web.document.querySelector('#range-min-x') as web.HTMLInputElement;
  rangeMaxX =
      web.document.querySelector('#range-max-x') as web.HTMLInputElement;
  btnZoomReset =
      web.document.querySelector('#btn-zoom-reset') as web.HTMLButtonElement;

  toggleFx = web.document.querySelector('#toggle-fx') as web.HTMLInputElement;
  toggleDfx = web.document.querySelector('#toggle-dfx') as web.HTMLInputElement;
  toggleD2fx =
      web.document.querySelector('#toggle-d2fx') as web.HTMLInputElement;
  toggleD3fx =
      web.document.querySelector('#toggle-d3fx') as web.HTMLInputElement;
  toggleTaylor =
      web.document.querySelector('#toggle-taylor') as web.HTMLInputElement;
  toggleIntegral =
      web.document.querySelector('#toggle-integral') as web.HTMLInputElement;
  toggleTangent =
      web.document.querySelector('#toggle-tangent') as web.HTMLInputElement;
  toggleRoots =
      web.document.querySelector('#toggle-roots') as web.HTMLInputElement;
  toggleMin = web.document.querySelector('#toggle-min') as web.HTMLInputElement;
  toggleMax = web.document.querySelector('#toggle-max') as web.HTMLInputElement;

  toggleLblFx = web.document.querySelector('#toggle-lbl-fx') as web.HTMLElement;
  toggleLblDfx =
      web.document.querySelector('#toggle-lbl-dfx') as web.HTMLElement;
  toggleLblD2fx =
      web.document.querySelector('#toggle-lbl-d2fx') as web.HTMLElement;
  toggleLblD3fx =
      web.document.querySelector('#toggle-lbl-d3fx') as web.HTMLElement;
  toggleLblTaylor =
      web.document.querySelector('#toggle-lbl-taylor') as web.HTMLElement;
  toggleLblIntegral =
      web.document.querySelector('#toggle-lbl-integral') as web.HTMLElement;
  toggleLblTangent =
      web.document.querySelector('#toggle-lbl-tangent') as web.HTMLElement;
  toggleLblRoots =
      web.document.querySelector('#toggle-lbl-roots') as web.HTMLElement;
  toggleLblMin =
      web.document.querySelector('#toggle-lbl-min') as web.HTMLElement;
  toggleLblMax =
      web.document.querySelector('#toggle-lbl-max') as web.HTMLElement;

  valSymFx = web.document.querySelector('#val-sym-fx') as web.HTMLElement;
  valSymText = web.document.querySelector('#val-sym-text') as web.HTMLElement;
  valSymDf = web.document.querySelector('#val-sym-df') as web.HTMLElement;
  valSymD2f = web.document.querySelector('#val-sym-d2f') as web.HTMLElement;
  valSymD3f = web.document.querySelector('#val-sym-d3f') as web.HTMLElement;
  valSymAntideriv =
      web.document.querySelector('#val-sym-antideriv') as web.HTMLElement;
  valSymLatex = web.document.querySelector('#val-sym-latex') as web.HTMLElement;
  valSymMathml =
      web.document.querySelector('#val-sym-mathml') as web.HTMLElement;

  sliderPointX =
      web.document.querySelector('#slider-point-x') as web.HTMLInputElement;
  inputPointX =
      web.document.querySelector('#input-point-x') as web.HTMLInputElement;
  pointXDisplay =
      web.document.querySelector('#point-x-display') as web.HTMLElement;
  valEvalFx = web.document.querySelector('#val-eval-fx') as web.HTMLElement;
  valEvalDfAnalytical =
      web.document.querySelector('#val-eval-df-analytical') as web.HTMLElement;
  valEvalDfNumerical =
      web.document.querySelector('#val-eval-df-numerical') as web.HTMLElement;
  valTangentEq =
      web.document.querySelector('#val-tangent-eq') as web.HTMLElement;

  selectIntMethod =
      web.document.querySelector('#select-int-method') as web.HTMLSelectElement;
  inputIntA =
      web.document.querySelector('#input-int-a') as web.HTMLInputElement;
  inputIntB =
      web.document.querySelector('#input-int-b') as web.HTMLInputElement;
  valIntNumerical =
      web.document.querySelector('#val-int-numerical') as web.HTMLElement;
  valIntAnalytical =
      web.document.querySelector('#val-int-analytical') as web.HTMLElement;

  sliderTaylorOrder = web.document.querySelector(
    '#slider-taylor-order',
  ) as web.HTMLInputElement;
  selectTaylorCenter = web.document.querySelector(
    '#select-taylor-center',
  ) as web.HTMLSelectElement;
  inputTaylorAround = web.document.querySelector(
    '#input-taylor-around',
  ) as web.HTMLInputElement;
  taylorOrderVal =
      web.document.querySelector('#taylor-order-val') as web.HTMLElement;
  taylorPolynomialStr =
      web.document.querySelector('#taylor-polynomial-str') as web.HTMLElement;

  valRootsExact =
      web.document.querySelector('#val-roots-exact') as web.HTMLElement;
  valRootsNumeric =
      web.document.querySelector('#val-roots-numeric') as web.HTMLElement;
  valExtremaMin =
      web.document.querySelector('#val-extrema-min') as web.HTMLElement;
  valExtremaMax =
      web.document.querySelector('#val-extrema-max') as web.HTMLElement;
}

void buildSidebar() {
  presetsList.innerHTML = ''.toJS;

  final categories = <String, List<ExpressionPreset>>{};
  for (final preset in expressionPresets) {
    categories.putIfAbsent(preset.category, () => []).add(preset);
  }

  for (final entry in categories.entries) {
    final heading = web.document.createElement('div') as web.HTMLElement;
    heading.className = 'group-heading';
    heading.textContent = entry.key;
    presetsList.appendChild(heading);

    for (final preset in entry.value) {
      final item = web.document.createElement('div') as web.HTMLElement;
      item.className = 'sidebar-item';
      item.setAttribute('data-id', preset.id);
      item.title = '${preset.name} (${preset.formula})';

      final nameSpan = web.document.createElement('span') as web.HTMLElement;
      nameSpan.className = 'sidebar-item-name';
      nameSpan.textContent = preset.name;
      item.appendChild(nameSpan);

      final formulaSpan = web.document.createElement('span') as web.HTMLElement;
      formulaSpan.className = 'sidebar-item-formula';
      formulaSpan.textContent = preset.formula;
      item.appendChild(formulaSpan);

      item.onClick.listen((_) => selectPreset(preset));
      presetsList.appendChild(item);
    }
  }
}

void filterSidebar(String query) {
  final lowercaseQuery = query.toLowerCase();
  final items = presetsList.querySelectorAll('.sidebar-item');

  for (var i = 0; i < items.length; i++) {
    final item = items.item(i) as web.HTMLElement;
    final id = item.getAttribute('data-id') ?? '';
    final preset = expressionPresets.where((p) => p.id == id).firstOrNull;
    if (preset == null) continue;

    final matches =
        preset.name.toLowerCase().contains(lowercaseQuery) ||
        preset.formula.toLowerCase().contains(lowercaseQuery) ||
        preset.category.toLowerCase().contains(lowercaseQuery) ||
        preset.description.toLowerCase().contains(lowercaseQuery);

    item.style.display = matches ? '' : 'none';
  }
}

void selectPreset(ExpressionPreset preset) {
  activePreset = preset;
  currentFormula = preset.formula;
  exprInput.value = preset.formula;

  displayTitle.textContent = preset.name;
  categoryBadge.textContent = preset.category;
  displayDesc.textContent = preset.description;

  minX = preset.defaultMinX;
  maxX = preset.defaultMaxX;
  rangeMinX.value = minX.toString();
  rangeMaxX.value = maxX.toString();

  pointX = preset.defaultPointX;
  sliderPointX.value = pointX.toString();
  inputPointX.value = pointX.toString();
  pointXDisplay.textContent = formatNumber(pointX, precision: 2);
  if (selectTaylorCenter.value == 'x0') {
    taylorAround = pointX;
    inputTaylorAround.value = formatNumber(pointX, precision: 2);
  }

  intA = preset.defaultIntA;
  intB = preset.defaultIntB;
  inputIntA.value = intA.toString();
  inputIntB.value = intB.toString();

  highlightActiveSidebarItem(preset.id);
  updateAll();
  updateUrlHash();
}

void highlightActiveSidebarItem(String? id) {
  final items = presetsList.querySelectorAll('.sidebar-item');
  for (var i = 0; i < items.length; i++) {
    final item = items.item(i) as web.HTMLElement;
    if (item.getAttribute('data-id') == id) {
      item.classList.add('active');
    } else {
      item.classList.remove('active');
    }
  }
}

void attachEventListeners() {
  searchBox.onInput.listen((_) => filterSidebar(searchBox.value.trim()));

  exprInput.onInput.listen((_) {
    currentFormula = exprInput.value.trim();
    activePreset = null;
    displayTitle.textContent = 'Custom Expression';
    categoryBadge.textContent = 'User Defined';
    displayDesc.textContent = 'Interactive mathematical formula evaluation.';
    highlightActiveSidebarItem(null);
    updateAll();
    updateUrlHash();
  });

  // Range inputs
  rangeMinX.onChange.listen((_) {
    final val = double.tryParse(rangeMinX.value);
    if (val != null && val < maxX) {
      minX = val;
      updateRangeBounds();
      drawCharts();
      updateUrlHash();
    }
  });

  rangeMaxX.onChange.listen((_) {
    final val = double.tryParse(rangeMaxX.value);
    if (val != null && val > minX) {
      maxX = val;
      updateRangeBounds();
      drawCharts();
      updateUrlHash();
    }
  });

  btnZoomReset.onClick.listen((_) {
    if (activePreset != null) {
      minX = activePreset!.defaultMinX;
      maxX = activePreset!.defaultMaxX;
    } else {
      minX = -5.0;
      maxX = 5.0;
    }
    rangeMinX.value = minX.toString();
    rangeMaxX.value = maxX.toString();
    updateRangeBounds();
    drawCharts();
    updateUrlHash();
  });

  // Layer toggles
  void setupToggle(
    web.HTMLInputElement checkbox,
    web.HTMLElement label,
    void Function(bool) onState,
  ) {
    checkbox.onChange.listen((_) {
      onState(checkbox.checked);
      if (checkbox.checked) {
        label.classList.add('active');
      } else {
        label.classList.remove('active');
      }
      drawCharts();
    });
  }

  setupToggle(toggleFx, toggleLblFx, (v) => showFx = v);
  setupToggle(toggleDfx, toggleLblDfx, (v) => showDfx = v);
  setupToggle(toggleD2fx, toggleLblD2fx, (v) => showD2fx = v);
  setupToggle(toggleD3fx, toggleLblD3fx, (v) => showD3fx = v);
  setupToggle(toggleTaylor, toggleLblTaylor, (v) => showTaylor = v);
  setupToggle(toggleIntegral, toggleLblIntegral, (v) => showIntegral = v);
  setupToggle(toggleTangent, toggleLblTangent, (v) => showTangent = v);
  setupToggle(toggleRoots, toggleLblRoots, (v) => showRoots = v);
  setupToggle(toggleMin, toggleLblMin, (v) => showMin = v);
  setupToggle(toggleMax, toggleLblMax, (v) => showMax = v);

  // Point evaluation slider & input
  sliderPointX.onInput.listen((_) {
    final val = double.tryParse(sliderPointX.value) ?? pointX;
    setPointX(val);
  });
  inputPointX.onInput.listen((_) {
    final val = double.tryParse(inputPointX.value) ?? pointX;
    setPointX(val);
  });

  // Integration controls
  selectIntMethod.onChange.listen((_) {
    intMethod = selectIntMethod.value == 'simpson'
        ? IntegrationMethod.simpson
        : IntegrationMethod.gaussKronrod;
    updateIntegrationTelemetry();
  });
  inputIntA.onInput.listen((_) {
    intA = double.tryParse(inputIntA.value) ?? intA;
    updateIntegrationTelemetry();
    drawCharts();
  });
  inputIntB.onInput.listen((_) {
    intB = double.tryParse(inputIntB.value) ?? intB;
    updateIntegrationTelemetry();
    drawCharts();
  });

  // Taylor expansion controls
  sliderTaylorOrder.onInput.listen((_) {
    taylorOrder = int.tryParse(sliderTaylorOrder.value) ?? taylorOrder;
    taylorOrderVal.textContent = taylorOrder.toString();
    updateTaylorTelemetry();
    drawCharts();
  });
  selectTaylorCenter.onChange.listen((_) {
    final mode = selectTaylorCenter.value;
    if (mode == 'x0') {
      inputTaylorAround.disabled = true;
      taylorAround = pointX;
      inputTaylorAround.value = formatNumber(pointX, precision: 2);
    } else if (mode == 'zero') {
      inputTaylorAround.disabled = true;
      taylorAround = 0.0;
      inputTaylorAround.value = '0.00';
    } else {
      inputTaylorAround.disabled = false;
      taylorAround = double.tryParse(inputTaylorAround.value) ?? pointX;
      inputTaylorAround.focus();
    }
    updateTaylorTelemetry();
    drawCharts();
  });
  inputTaylorAround.onInput.listen((_) {
    taylorAround = double.tryParse(inputTaylorAround.value) ?? taylorAround;
    updateTaylorTelemetry();
    drawCharts();
  });

  // Mouse hover listeners on Canvas
  plotCanvas.onMouseMove.listen((web.MouseEvent event) {
    final rect = plotCanvas.getBoundingClientRect();
    mouseX = event.clientX - rect.left;
    mouseY = event.clientY - rect.top;
    drawCharts();
  });
  plotCanvas.onMouseLeave.listen((_) {
    mouseX = null;
    mouseY = null;
    drawCharts();
  });

  // Window resize
  web.window.addEventListener(
    'resize',
    (web.Event event) {
      drawCharts();
    }.toJS,
  );

  // Hash navigation
  web.window.addEventListener(
    'hashchange',
    (web.Event event) {
      loadFromUrlHash();
    }.toJS,
  );
}

void setPointX(double val) {
  pointX = val;
  sliderPointX.value = val.toString();
  inputPointX.value = val.toString();
  pointXDisplay.textContent = formatNumber(val, precision: 2);
  updatePointTelemetry();
  if (selectTaylorCenter.value == 'x0') {
    taylorAround = val;
    inputTaylorAround.value = formatNumber(val, precision: 2);
    updateTaylorTelemetry();
  }
  drawCharts();
}

void updateRangeBounds() {
  sliderPointX.min = minX.toString();
  sliderPointX.max = maxX.toString();
}

void updateAll() {
  Expr? expr;
  try {
    expr = Expr.tryParse(currentFormula);
  } catch (e) {
    expr = null;
  }

  if (expr == null) {
    statusBadge.className = 'formula-status-badge status-invalid';
    statusBadge.textContent = '✗ Invalid Syntax';
    parseErrorMessage.style.display = 'block';

    try {
      Expr.parse(currentFormula);
    } on FormatException catch (e) {
      parseErrorMessage.textContent = e.message;
    } catch (e) {
      parseErrorMessage.textContent = e.toString();
    }

    parsedExpr = null;
    fnCompiled = null;
    dfCompiled = null;
    d2fCompiled = null;
    d3fCompiled = null;
    taylorCompiled = null;
    clearTelemetry();
    drawCharts();
    return;
  }

  // Syntax is valid!
  statusBadge.className = 'formula-status-badge status-valid';
  statusBadge.textContent = '✓ Valid';
  parseErrorMessage.style.display = 'none';
  parsedExpr = expr;

  // 1. Analytical Calculus
  final simplified = expr.simplify();
  final d1 = expr.derivative('x').simplify();
  final d2 = d1.derivative('x').simplify();
  final d3 = d2.derivative('x').simplify();

  setAttrExpr(valSymFx, simplified);
  setAttrValue(valSymText, simplified.toString());
  setAttrExpr(valSymDf, d1);
  setAttrExpr(valSymD2f, d2);
  setAttrExpr(valSymD3f, d3);
  setAttrValue(valSymLatex, simplified.toLatex());
  setAttrValue(valSymMathml, simplified.toMathMl());

  try {
    final antideriv = expr.integrate('x').simplify();
    setAttrExpr(valSymAntideriv, antideriv);
  } catch (_) {
    setAttrValue(valSymAntideriv, 'No closed-form');
  }

  // 2. High-Speed Closure Compilation
  fnCompiled = expr.toFunction1D('x');
  dfCompiled = d1.toFunction1D('x');
  d2fCompiled = d2.toFunction1D('x');
  d3fCompiled = d3.toFunction1D('x');

  // 3. Update Panels
  updatePointTelemetry();
  updateIntegrationTelemetry();
  updateTaylorTelemetry();
  detectRootsAndExtrema();

  // 4. Redraw Plot
  drawCharts();
}

void clearTelemetry() {
  setAttrExpr(valSymFx, null);
  setAttrValue(valSymText, '-');
  setAttrExpr(valSymDf, null);
  setAttrExpr(valSymD2f, null);
  setAttrExpr(valSymD3f, null);
  setAttrExpr(valSymAntideriv, null);
  setAttrValue(valSymLatex, '-');
  setAttrValue(valSymMathml, '-');

  setAttrValue(valEvalFx, '-');
  setAttrValue(valEvalDfAnalytical, '-');
  setAttrValue(valEvalDfNumerical, '-');
  setAttrValue(valTangentEq, '-');

  setAttrValue(valIntNumerical, '-');
  setAttrValue(valIntAnalytical, '-');

  setAttrExpr(taylorPolynomialStr, null);
  setAttrValue(valRootsExact, '-');
  setAttrValue(valRootsNumeric, '-');
  setAttrValue(valExtremaMin, '-');
  setAttrValue(valExtremaMax, '-');
}

void updatePointTelemetry() {
  final fn = fnCompiled;
  final df = dfCompiled;
  if (fn == null || df == null) return;

  final y0 = safeGet(() => fn(pointX))?.toDouble();
  setAttrValue(valEvalFx, y0 != null ? formatNumber(y0) : 'undefined');

  final slopeAnalytical = safeGet(() => df(pointX))?.toDouble();
  setAttrValue(
    valEvalDfAnalytical,
    slopeAnalytical != null ? formatNumber(slopeAnalytical) : 'undefined',
  );

  final slopeNumerical = safeGet(() => derivative(fn, pointX))?.toDouble();
  setAttrValue(
    valEvalDfNumerical,
    slopeNumerical != null ? formatNumber(slopeNumerical) : 'undefined',
  );

  if (y0 != null && slopeAnalytical != null && slopeAnalytical.isFinite) {
    final intercept = y0 - slopeAnalytical * pointX;
    final mStr = formatNumber(slopeAnalytical, precision: 2);
    final bStr = intercept >= 0
        ? '+ ${formatNumber(intercept, precision: 2)}'
        : '- ${formatNumber(intercept.abs(), precision: 2)}';
    setAttrValue(valTangentEq, 'y = $mStr·x $bStr');
  } else {
    setAttrValue(valTangentEq, '-');
  }
}

void updateIntegrationTelemetry() {
  final fn = fnCompiled;
  final expr = parsedExpr;
  if (fn == null || expr == null) return;

  double? numVal;
  try {
    numVal = integrate(fn, intA, intB, method: intMethod);
  } catch (_) {
    numVal = null;
  }
  setAttrValue(
    valIntNumerical,
    numVal != null ? formatNumber(numVal) : 'undefined',
  );

  double? exactVal;
  try {
    final definiteExpr = expr.integrate('x', from: intA, to: intB);
    exactVal = definiteExpr.evaluate(const {}).toDouble();
  } catch (_) {
    exactVal = null;
  }
  setAttrValue(
    valIntAnalytical,
    exactVal != null ? formatNumber(exactVal) : 'No closed form',
  );
}

void updateTaylorTelemetry() {
  final expr = parsedExpr;
  if (expr == null) return;

  if (selectTaylorCenter.value == 'x0') {
    taylorAround = pointX;
    inputTaylorAround.value = formatNumber(pointX, precision: 2);
  } else if (selectTaylorCenter.value == 'zero') {
    taylorAround = 0.0;
    inputTaylorAround.value = '0.00';
  }

  try {
    final poly = expr
        .taylorSeries('x', order: taylorOrder, around: taylorAround)
        .simplify();
    setAttrExpr(taylorPolynomialStr, poly);
    taylorCompiled = poly.toFunction1D('x');
  } catch (_) {
    setAttrValue(taylorPolynomialStr, 'Non-analytic');
    taylorCompiled = null;
  }
}

void detectRootsAndExtrema() {
  exactRoots.clear();
  numericRoots.clear();
  localMinima.clear();
  localMaxima.clear();

  final expr = parsedExpr;
  final fn = fnCompiled;
  final df = dfCompiled;
  final d2f = d2fCompiled;
  if (expr == null || fn == null || df == null) return;

  // 1. Exact Symbolic Roots
  try {
    final solutions = expr.solve('x');
    for (final s in solutions) {
      if (s is Number && s.value.isFinite) {
        exactRoots.add(s.value);
      }
    }
  } catch (_) {}

  // 2. Numerical Roots Scanning in [minX, maxX]
  const steps = 60;
  final stepSize = (maxX - minX) / steps;
  var prevX = minX;
  var prevY = safeGet(() => fn(prevX))?.toDouble();

  for (var i = 1; i <= steps; i++) {
    final curX = minX + i * stepSize;
    final curY = safeGet(() => fn(curX))?.toDouble();

    if (prevY != null &&
        curY != null &&
        prevY.isFinite &&
        curY.isFinite &&
        prevY * curY <= 0) {
      try {
        final root = solve(fn, prevX, b: curX, method: RootMethod.brent);
        if (root.isFinite &&
            !numericRoots.any((r) => (r - root).abs() < 1e-4)) {
          numericRoots.add(root);
        }
      } catch (_) {}
    }
    prevX = curX;
    prevY = curY;
  }

  // 3. Extrema Detection via derivative zeros f'(x) = 0
  var prevSlopeX = minX;
  var prevSlope = safeGet(() => df(prevSlopeX))?.toDouble();

  for (var i = 1; i <= steps; i++) {
    final curX = minX + i * stepSize;
    final curSlope = safeGet(() => df(curX))?.toDouble();

    if (prevSlope != null &&
        curSlope != null &&
        prevSlope.isFinite &&
        curSlope.isFinite &&
        prevSlope * curSlope <= 0) {
      try {
        final critX = solve(df, prevSlopeX, b: curX, method: RootMethod.brent);
        if (critX.isFinite) {
          final yVal = safeGet(() => fn(critX))?.toDouble();
          final curvature = d2f != null
              ? safeGet(() => d2f(critX))?.toDouble()
              : null;

          if (yVal != null && yVal.isFinite) {
            if (curvature != null && curvature > 1e-6) {
              if (!localMinima.any((m) => (m.$1 - critX).abs() < 1e-3)) {
                localMinima.add((critX, yVal));
              }
            } else if (curvature != null && curvature < -1e-6) {
              if (!localMaxima.any((m) => (m.$1 - critX).abs() < 1e-3)) {
                localMaxima.add((critX, yVal));
              }
            }
          }
        }
      } catch (_) {}
    }
    prevSlopeX = curX;
    prevSlope = curSlope;
  }

  // Update Telemetry labels
  setAttrValue(
    valRootsExact,
    exactRoots.isNotEmpty
        ? exactRoots.map((r) => formatNumber(r, precision: 3)).join(', ')
        : 'None found',
  );

  setAttrValue(
    valRootsNumeric,
    numericRoots.isNotEmpty
        ? numericRoots.map((r) => formatNumber(r, precision: 3)).join(', ')
        : 'None in range',
  );

  setAttrValue(
    valExtremaMin,
    localMinima.isNotEmpty
        ? localMinima
              .map(
                (m) =>
                    '(${formatNumber(m.$1, precision: 2)}, ${formatNumber(m.$2, precision: 2)})',
              )
              .join('; ')
        : 'None in range',
  );

  setAttrValue(
    valExtremaMax,
    localMaxima.isNotEmpty
        ? localMaxima
              .map(
                (m) =>
                    '(${formatNumber(m.$1, precision: 2)}, ${formatNumber(m.$2, precision: 2)})',
              )
              .join('; ')
        : 'None in range',
  );
}

/// Dynamic bounds estimation for graphing X and Y windows.
(double, double) estimateYBounds(double Function(double) fn) {
  var minY = 0.0;
  var maxY = 0.0;
  var hasSamples = false;

  const sampleCount = 80;
  for (var i = 0; i <= sampleCount; i++) {
    final x = minX + i * (maxX - minX) / sampleCount;
    double y;
    try {
      y = fn(x);
    } catch (_) {
      continue;
    }
    if (y.isFinite && !y.isNaN) {
      if (!hasSamples) {
        minY = y;
        maxY = y;
        hasSamples = true;
      } else {
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }

  if (!hasSamples) {
    return (-5.0, 5.0);
  }

  final range = maxY - minY;
  if (range.abs() < 1e-4) {
    minY -= 1.0;
    maxY += 1.0;
  } else {
    // Add 15% margin
    minY -= range * 0.15;
    maxY += range * 0.15;
  }

  // Cap extreme bounds for vertical asymptotes
  minY = math.max(-100.0, minY);
  maxY = math.min(100.0, maxY);

  return (minY, maxY);
}

void drawCharts() {
  final init = initCanvas(plotCanvas);
  if (init == null) return;
  final (ctx, width, height) = init;

  final fn = fnCompiled;
  if (fn == null) return;

  final (minY, maxY) = estimateYBounds(fn);

  final vp = PlotViewport(
    minX: minX,
    maxX: maxX,
    minY: minY,
    maxY: maxY,
    width: width,
    height: height,
  );

  // 1. Grid & Axes
  drawGrid(ctx, vp);

  // 2. Shaded Integral Area
  if (showIntegral) {
    drawShadedInterval(
      ctx,
      vp,
      fn,
      intA,
      intB,
      fillColor: 'rgba(16, 185, 129, 0.20)',
      strokeColor: '#10b981',
    );
  }

  // 3. Primary Curve f(x)
  if (showFx) {
    drawCurve(
      ctx,
      vp,
      fn,
      strokeColor: '#3b82f6',
      lineWidth: 2.5,
      fillColor: 'rgba(59, 130, 246, 0.08)',
    );
  }

  // 4. First Derivative f'(x)
  final df = dfCompiled;
  if (showDfx && df != null) {
    drawCurve(
      ctx,
      vp,
      df,
      strokeColor: '#ef4444',
      lineWidth: 1.8,
      lineDash: [4, 4],
    );
  }

  // 5. Second Derivative f''(x)
  final d2f = d2fCompiled;
  if (showD2fx && d2f != null) {
    drawCurve(
      ctx,
      vp,
      d2f,
      strokeColor: '#a855f7',
      lineWidth: 1.5,
      lineDash: [2, 3],
    );
  }

  // 5b. Third Derivative f'''(x)
  final d3f = d3fCompiled;
  if (showD3fx && d3f != null) {
    drawCurve(
      ctx,
      vp,
      d3f,
      strokeColor: '#ec4899',
      lineWidth: 1.5,
      lineDash: [1, 3],
    );
  }

  // 6. Taylor Polynomial Approximation
  final taylor = taylorCompiled;
  if (showTaylor && taylor != null) {
    drawCurve(
      ctx,
      vp,
      taylor,
      strokeColor: '#f59e0b',
      lineWidth: 2.0,
      lineDash: [6, 3],
    );
  }

  // 7. Tangent Line at pointX
  if (showTangent && df != null) {
    final y0 = safeGet(() => fn(pointX))?.toDouble();
    final slope = safeGet(() => df(pointX))?.toDouble();
    if (y0 != null && slope != null && y0.isFinite && slope.isFinite) {
      double tangentLine(double x) => slope * (x - pointX) + y0;
      drawCurve(
        ctx,
        vp,
        tangentLine,
        strokeColor: 'rgba(255, 255, 255, 0.65)',
        lineWidth: 1.2,
      );
      // Tangent contact dot
      drawPointMarker(
        ctx,
        vp,
        pointX,
        y0,
        color: '#f8fafc',
        radius: 3.5,
        label: 'x0',
      );
    }
  }

  // 8. Roots Markers
  if (showRoots) {
    for (final r in numericRoots) {
      drawPointMarker(
        ctx,
        vp,
        r,
        0.0,
        color: '#10b981',
        radius: 4.5,
        label: 'root',
      );
    }
  }

  // 8b. Local Minima Markers
  if (showMin) {
    for (final minPt in localMinima) {
      drawPointMarker(
        ctx,
        vp,
        minPt.$1,
        minPt.$2,
        color: '#06b6d4',
        radius: 4.5,
        label: 'min',
      );
    }
  }

  // 8c. Local Maxima Markers
  if (showMax) {
    for (final maxPt in localMaxima) {
      drawPointMarker(
        ctx,
        vp,
        maxPt.$1,
        maxPt.$2,
        color: '#f59e0b',
        radius: 4.5,
        label: 'max',
      );
    }
  }

  // 9. Reference line for x0
  drawReferenceLine(
    ctx,
    vp,
    pointX,
    color: 'rgba(248, 250, 252, 0.4)',
    label: 'x₀ = ${formatNumber(pointX, precision: 2)}',
  );

  // 10. Mouse Hover Crosshair & Tooltip
  final mx = mouseX;
  final my = mouseY;
  if (mx != null && my != null && vp.containsPixel(mx, my)) {
    final hx = vp.fromPixelX(mx);
    final hy = safeGet(() => fn(hx))?.toDouble();
    if (hy != null && hy.isFinite) {
      final hSlope = df != null ? safeGet(() => df(hx))?.toDouble() : null;
      final hCurv = d2f != null ? safeGet(() => d2f(hx))?.toDouble() : null;
      final hJerk = d3f != null ? safeGet(() => d3f(hx))?.toDouble() : null;
      final tooltipLines = [
        'x: ${formatNumber(hx, precision: 4)}',
        'f(x): ${formatNumber(hy, precision: 4)}',
        if (hSlope != null && hSlope.isFinite)
          'f\'(x): ${formatNumber(hSlope, precision: 4)}',
        if (showD2fx && hCurv != null && hCurv.isFinite)
          'f\'\'(x): ${formatNumber(hCurv, precision: 4)}',
        if (showD3fx && hJerk != null && hJerk.isFinite)
          'f\'\'\'(x): ${formatNumber(hJerk, precision: 4)}',
      ];
      drawCrosshairAndTooltip(
        ctx,
        vp,
        targetX: hx,
        targetY: hy,
        tooltipLines: tooltipLines,
        color: '#3b82f6',
      );
    }
  }
}

void updateUrlHash() {
  final queryParams = <String>[
    'expr=${Uri.encodeComponent(currentFormula)}',
    'minx=$minX',
    'maxx=$maxX',
    'x0=$pointX',
    'a=$intA',
    'b=$intB',
  ];
  web.window.location.hash = queryParams.join('&');
}

void loadFromUrlHash() {
  var hash = web.window.location.hash;
  if (hash.startsWith('#')) {
    hash = hash.substring(1);
  }

  if (hash.isNotEmpty) {
    final pairs = hash.split('&');
    for (final pair in pairs) {
      final kv = pair.split('=');
      if (kv.length == 2) {
        final key = kv[0];
        final val = Uri.decodeComponent(kv[1]);
        switch (key) {
          case 'expr':
            currentFormula = val;
            exprInput.value = val;
          case 'minx':
            final parsed = double.tryParse(val);
            if (parsed != null) minX = parsed;
          case 'maxx':
            final parsed = double.tryParse(val);
            if (parsed != null) maxX = parsed;
          case 'x0':
            final parsed = double.tryParse(val);
            if (parsed != null) pointX = parsed;
          case 'a':
            final parsed = double.tryParse(val);
            if (parsed != null) intA = parsed;
          case 'b':
            final parsed = double.tryParse(val);
            if (parsed != null) intB = parsed;
        }
      }
    }
  } else {
    // Default to first preset
    selectPreset(expressionPresets[0]);
    return;
  }

  final matchingPreset = expressionPresets
      .where((p) => p.formula == currentFormula)
      .firstOrNull;
  if (matchingPreset != null) {
    activePreset = matchingPreset;
    displayTitle.textContent = matchingPreset.name;
    categoryBadge.textContent = matchingPreset.category;
    displayDesc.textContent = matchingPreset.description;
    highlightActiveSidebarItem(matchingPreset.id);
  } else {
    displayTitle.textContent = 'Custom Expression';
    categoryBadge.textContent = 'User Defined';
    displayDesc.textContent = 'Interactive mathematical formula evaluation.';
    highlightActiveSidebarItem(null);
  }

  rangeMinX.value = minX.toString();
  rangeMaxX.value = maxX.toString();
  sliderPointX.value = pointX.toString();
  inputPointX.value = pointX.toString();
  pointXDisplay.textContent = formatNumber(pointX, precision: 2);
  if (selectTaylorCenter.value == 'x0') {
    taylorAround = pointX;
    inputTaylorAround.value = formatNumber(pointX, precision: 2);
  }
  inputIntA.value = intA.toString();
  inputIntB.value = intB.toString();
  updateRangeBounds();

  updateAll();
}
