import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:more/number.dart' show Complex;
import 'package:web/web.dart' as web;

import '../shared/chart.dart';
import '../shared/utils.dart';
import 'algebra.dart';
import 'presets.dart';

// Current Application State
ExpressionPreset? activePreset;
String currentFormula = 'x^3 - 3*x + 1';
Expr? parsedExpr;
Expr? cachedAntideriv;
double Function(double)? fnCompiled;
double Function(double)? dfCompiled;
double Function(double)? d2fCompiled;
double Function(double)? d3fCompiled;
Complex Function(Complex)? fnComplexCompiled;
Complex Function(Complex)? dfComplexCompiled;
Complex Function(Complex)? d2fComplexCompiled;
Complex Function(Complex)? d3fComplexCompiled;
double Function(double)? taylorCompiled;
Complex Function(Complex)? taylorComplexCompiled;

double minX = -3.0;
double maxX = 3.0;
double pointX = 1.0;
double intA = -1.0;
double intB = 2.0;
IntegrationMethod intMethod = IntegrationMethod.gaussKronrod;
int taylorOrder = 3;
double taylorAround = 0.0;

bool showFx = true;
bool showIm = true;
bool showDfx = false;
bool showD2fx = false;
bool showD3fx = false;
bool showTaylor = false;
bool showIntegral = false;
bool showTangent = false;
bool showRoots = true;
bool showMin = true;
bool showMax = true;
bool hasImaginary = false;

// Hover coordinates
double? mouseX;
double? mouseY;
bool _rafPending = false;

// Critical points & roots
final List<double> exactRoots = [];
final List<Expr> exactSolutions = [];
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
late web.HTMLInputElement toggleIm;
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
late web.HTMLElement toggleLblFxText;
late web.HTMLElement toggleLblIm;
late web.HTMLElement toggleLblDfx;
late web.HTMLElement toggleLblD2fx;
late web.HTMLElement toggleLblD3fx;
late web.HTMLElement toggleLblTaylor;
late web.HTMLElement toggleLblIntegral;
late web.HTMLElement toggleLblTangent;
late web.HTMLElement toggleLblRoots;
late web.HTMLElement toggleLblMin;
late web.HTMLElement toggleLblMax;

late web.HTMLElement valAlgVerbatim;
late web.HTMLElement valAlgSimplified;
late web.HTMLElement valAlgExpanded;
late web.HTMLElement valAlgFactored;
late web.HTMLElement valSymDf;
late web.HTMLElement valSymD2f;
late web.HTMLElement valSymD3f;
late web.HTMLElement valSymAntideriv;

late web.HTMLInputElement sliderPointX;
late web.HTMLInputElement inputPointX;
late web.HTMLElement pointXDisplay;
late web.HTMLElement valEvalFx;
late web.HTMLElement valEvalDfAnalytical;
late web.HTMLElement valEvalDfNumerical;
late web.HTMLElement valTangentEq;
late web.HTMLElement valEvalLim;
late web.HTMLElement valEvalLimInf;

late web.HTMLSelectElement selectIntMethod;
late web.HTMLInputElement inputIntA;
late web.HTMLInputElement inputIntB;
late web.HTMLElement valIntNumerical;
late web.HTMLElement valIntAnalytical;

late web.HTMLInputElement sliderTaylorOrder;
late web.HTMLSelectElement selectTaylorCenter;
late web.HTMLInputElement inputTaylorAround;
late web.HTMLElement taylorOrderVal;
late web.HTMLElement valFormalSeries;
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
  toggleIm = web.document.querySelector('#toggle-im') as web.HTMLInputElement;
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
  toggleLblFxText =
      web.document.querySelector('#toggle-lbl-fx-text') as web.HTMLElement;
  toggleLblIm = web.document.querySelector('#toggle-lbl-im') as web.HTMLElement;
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

  valAlgVerbatim =
      web.document.querySelector('#val-alg-verbatim') as web.HTMLElement;
  valAlgSimplified =
      web.document.querySelector('#val-alg-simplified') as web.HTMLElement;
  valAlgExpanded =
      web.document.querySelector('#val-alg-expanded') as web.HTMLElement;
  valAlgFactored =
      web.document.querySelector('#val-alg-factored') as web.HTMLElement;
  valSymDf = web.document.querySelector('#val-sym-df') as web.HTMLElement;
  valSymD2f = web.document.querySelector('#val-sym-d2f') as web.HTMLElement;
  valSymD3f = web.document.querySelector('#val-sym-d3f') as web.HTMLElement;
  valSymAntideriv =
      web.document.querySelector('#val-sym-antideriv') as web.HTMLElement;

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
  valEvalLim = web.document.querySelector('#val-eval-lim') as web.HTMLElement;
  valEvalLimInf =
      web.document.querySelector('#val-eval-lim-inf') as web.HTMLElement;

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
  valFormalSeries =
      web.document.querySelector('#val-formal-series') as web.HTMLElement;
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
      updateImaginaryDetection();
      detectRootsAndExtrema();
      drawCharts();
      updateUrlHash();
    }
  });

  rangeMaxX.onChange.listen((_) {
    final val = double.tryParse(rangeMaxX.value);
    if (val != null && val > minX) {
      maxX = val;
      updateRangeBounds();
      updateImaginaryDetection();
      detectRootsAndExtrema();
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
    updateImaginaryDetection();
    detectRootsAndExtrema();
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
  setupToggle(toggleIm, toggleLblIm, (v) => showIm = v);
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
    if (!_rafPending) {
      _rafPending = true;
      web.window.requestAnimationFrame(
        ((num _) {
          _rafPending = false;
          drawCharts();
        }).toJS,
      );
    }
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

Complex? safeGetComplex(Complex Function() getter) {
  try {
    final val = getter();
    return (val.a.isNaN || val.b.isNaN) ? null : val;
  } catch (_) {
    return null;
  }
}

void updateImaginaryDetection() {
  final expr = parsedExpr;
  if (expr == null) {
    hasImaginary = false;
    toggleLblFxText.textContent = 'f(x)';
    toggleLblIm.style.display = 'none';
    return;
  }
  hasImaginary = containsImaginary(expr);
  if (!hasImaginary && fnComplexCompiled != null) {
    const sampleCount = 20;
    for (var i = 0; i <= sampleCount; i++) {
      final x = minX + i * (maxX - minX) / sampleCount;
      try {
        final c = fnComplexCompiled!(Complex(x, 0));
        if (c.b.abs() > 1e-6) {
          hasImaginary = true;
          break;
        }
      } catch (_) {}
    }
  }

  if (hasImaginary) {
    toggleLblFxText.textContent = 'Re f(x)';
    toggleLblIm.style.display = 'inline-flex';
  } else {
    toggleLblFxText.textContent = 'f(x)';
    toggleLblIm.style.display = 'none';
  }
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
    cachedAntideriv = null;
    fnCompiled = null;
    dfCompiled = null;
    d2fCompiled = null;
    d3fCompiled = null;
    fnComplexCompiled = null;
    dfComplexCompiled = null;
    d2fComplexCompiled = null;
    d3fComplexCompiled = null;
    taylorCompiled = null;
    taylorComplexCompiled = null;
    clearTelemetry();
    drawCharts();
    return;
  }

  // Syntax is valid!
  statusBadge.className = 'formula-status-badge status-valid';
  statusBadge.textContent = '✓ Valid';
  parseErrorMessage.style.display = 'none';
  parsedExpr = expr;

  // 1. Algebra Card (only MathML rendering)
  setAttrExpr(valAlgVerbatim, expr);
  Expr simplified;
  try {
    simplified = expr.simplify();
    setAttrExpr(valAlgSimplified, simplified);
  } catch (_) {
    simplified = expr;
    setAttrExpr(valAlgSimplified, expr);
  }

  try {
    final expanded = expr.expand();
    setAttrExpr(valAlgExpanded, expanded);
  } catch (_) {
    setAttrExpr(valAlgExpanded, expr);
  }

  try {
    final factored = factorExpr(expr);
    setAttrExpr(valAlgFactored, factored);
  } catch (_) {
    setAttrExpr(valAlgFactored, expr);
  }

  // 2. Analytical Calculus
  Expr? d1;
  Expr? d2;
  Expr? d3;
  try {
    d1 = expr.derivative('x').simplify();
  } catch (_) {}
  try {
    d2 = d1?.derivative('x').simplify();
  } catch (_) {}
  try {
    d3 = d2?.derivative('x').simplify();
  } catch (_) {}

  if (d1 != null) {
    setAttrExpr(valSymDf, d1);
  } else {
    setAttrValue(valSymDf, 'Undefined');
  }
  if (d2 != null) {
    setAttrExpr(valSymD2f, d2);
  } else {
    setAttrValue(valSymD2f, 'Undefined');
  }
  if (d3 != null) {
    setAttrExpr(valSymD3f, d3);
  } else {
    setAttrValue(valSymD3f, 'Undefined');
  }

  try {
    cachedAntideriv = expr.integrate('x').simplify();
    setAttrExpr(valSymAntideriv, cachedAntideriv);
  } catch (_) {
    cachedAntideriv = null;
    setAttrValue(valSymAntideriv, 'No closed form');
  }

  // Asymptotic limits at +/- infinity depend only on expr, not pointX
  try {
    final limPos = expr.limit('x', ConstantNumber.infinity);
    try {
      final limNeg = expr.limit('x', const Neg(ConstantNumber.infinity));
      if (limPos == limNeg) {
        setAttrExpr(valEvalLimInf, limPos);
      } else {
        setAttrValue(valEvalLimInf, '+∞: $limPos | -∞: $limNeg');
      }
    } catch (_) {
      setAttrValue(valEvalLimInf, '+∞: $limPos');
    }
  } catch (_) {
    try {
      final limNeg = expr.limit('x', const Neg(ConstantNumber.infinity));
      setAttrValue(valEvalLimInf, '-∞: $limNeg');
    } catch (_) {
      setAttrValue(valEvalLimInf, 'Undefined');
    }
  }

  // 3. Closure Compilation
  try {
    fnCompiled = expr.toFunction1D('x');
  } catch (_) {
    fnCompiled = null;
  }
  try {
    dfCompiled = d1?.toFunction1D('x');
  } catch (_) {
    dfCompiled = null;
  }
  try {
    d2fCompiled = d2?.toFunction1D('x');
  } catch (_) {
    d2fCompiled = null;
  }
  try {
    d3fCompiled = d3?.toFunction1D('x');
  } catch (_) {
    d3fCompiled = null;
  }

  try {
    fnComplexCompiled = expr.toComplexFunction1D('x');
  } catch (_) {
    fnComplexCompiled = null;
  }
  try {
    dfComplexCompiled = d1?.toComplexFunction1D('x');
  } catch (_) {
    dfComplexCompiled = null;
  }
  try {
    d2fComplexCompiled = d2?.toComplexFunction1D('x');
  } catch (_) {
    d2fComplexCompiled = null;
  }
  try {
    d3fComplexCompiled = d3?.toComplexFunction1D('x');
  } catch (_) {
    d3fComplexCompiled = null;
  }

  // 4. Complex / Imaginary Detection
  updateImaginaryDetection();

  // 5. Update Panels
  updatePointTelemetry();
  updateIntegrationTelemetry();
  updateTaylorTelemetry();
  detectRootsAndExtrema();

  // 6. Redraw Plot
  drawCharts();
}

void clearTelemetry() {
  hasImaginary = false;
  toggleLblFxText.textContent = 'f(x)';
  toggleLblIm.style.display = 'none';

  setAttrExpr(valAlgVerbatim, null);
  setAttrExpr(valAlgSimplified, null);
  setAttrExpr(valAlgExpanded, null);
  setAttrExpr(valAlgFactored, null);
  setAttrExpr(valSymDf, null);
  setAttrExpr(valSymD2f, null);
  setAttrExpr(valSymD3f, null);
  setAttrExpr(valSymAntideriv, null);

  setAttrValue(valEvalFx, '-');
  setAttrValue(valEvalDfAnalytical, '-');
  setAttrValue(valEvalDfNumerical, '-');
  setAttrValue(valTangentEq, '-');
  setAttrExpr(valEvalLim, null);
  setAttrValue(valEvalLimInf, '-');

  setAttrValue(valIntNumerical, '-');
  setAttrValue(valIntAnalytical, '-');

  setAttrExpr(valFormalSeries, null);
  setAttrExpr(taylorPolynomialStr, null);
  setAttrValue(valRootsExact, '-');
  setAttrValue(valRootsNumeric, '-');
  setAttrValue(valExtremaMin, '-');
  setAttrValue(valExtremaMax, '-');
}

void updatePointTelemetry() {
  Complex? c0;
  if (fnComplexCompiled != null) {
    c0 = safeGetComplex(() => fnComplexCompiled!(Complex(pointX, 0)));
  } else if (parsedExpr != null) {
    c0 = safeGetComplex(
      () => parsedExpr!.evaluateComplex({'x': Complex(pointX, 0)}),
    );
  }

  if (c0 != null) {
    setAttrValue(valEvalFx, formatComplex(c0));
  } else if (fnCompiled != null) {
    final y0 = safeGet(() => fnCompiled!(pointX))?.toDouble();
    setAttrValue(valEvalFx, y0 != null ? formatNumber(y0) : 'Undefined');
  } else {
    setAttrValue(valEvalFx, 'Undefined');
  }

  Complex? cd;
  if (dfComplexCompiled != null) {
    cd = safeGetComplex(() => dfComplexCompiled!(Complex(pointX, 0)));
  }

  if (cd != null) {
    setAttrValue(valEvalDfAnalytical, formatComplex(cd));
  } else if (dfCompiled != null) {
    final s0 = safeGet(() => dfCompiled!(pointX))?.toDouble();
    setAttrValue(
      valEvalDfAnalytical,
      s0 != null ? formatNumber(s0) : 'Undefined',
    );
  } else {
    setAttrValue(valEvalDfAnalytical, 'Undefined');
  }

  if (!hasImaginary && fnCompiled != null) {
    final slopeNumerical = safeGet(() => derivative(fnCompiled!, pointX))
        ?.toDouble();
    setAttrValue(
      valEvalDfNumerical,
      slopeNumerical != null ? formatNumber(slopeNumerical) : 'Undefined',
    );
  } else if (fnComplexCompiled != null) {
    final realSlope = safeGet(
      () => derivative(
        (x) => fnComplexCompiled!(Complex(x, 0)).a.toDouble(),
        pointX,
      ),
    )?.toDouble();
    final imagSlope = safeGet(
      () => derivative(
        (x) => fnComplexCompiled!(Complex(x, 0)).b.toDouble(),
        pointX,
      ),
    )?.toDouble();
    if (realSlope != null && imagSlope != null) {
      setAttrValue(
        valEvalDfNumerical,
        formatComplex(Complex(realSlope, imagSlope)),
      );
    } else {
      setAttrValue(valEvalDfNumerical, 'Undefined');
    }
  } else {
    setAttrValue(valEvalDfNumerical, 'Undefined');
  }

  final realY0 =
      c0?.a.toDouble() ??
      (fnCompiled != null
          ? safeGet(() => fnCompiled!(pointX))?.toDouble()
          : null);
  final realSlope =
      cd?.a.toDouble() ??
      (dfCompiled != null
          ? safeGet(() => dfCompiled!(pointX))?.toDouble()
          : null);
  if (realY0 != null &&
      realSlope != null &&
      realY0.isFinite &&
      realSlope.isFinite) {
    final intercept = realY0 - realSlope * pointX;
    final mStr = formatNumber(realSlope, precision: 2);
    final bStr = intercept >= 0
        ? '+ ${formatNumber(intercept, precision: 2)}'
        : '- ${formatNumber(intercept.abs(), precision: 2)}';
    final prefix = hasImaginary ? 'Re: ' : '';
    setAttrValue(valTangentEq, '${prefix}y = $mStr·x $bStr');
  } else {
    setAttrValue(valTangentEq, 'Undefined');
  }

  final expr = parsedExpr;
  if (expr != null) {
    final ptExpr = (pointX - pointX.round()).abs() < 1e-9
        ? RationalNumber(pointX.round())
        : RationalNumber.fromDouble(pointX);
    try {
      final limVal = expr.limit('x', ptExpr);
      setAttrExpr(valEvalLim, limVal);
    } catch (_) {
      setAttrValue(valEvalLim, 'Undefined');
    }
  } else {
    setAttrExpr(valEvalLim, null);
  }
}

void updateIntegrationTelemetry() {
  final expr = parsedExpr;
  if (expr == null) return;

  if (!hasImaginary && fnCompiled != null) {
    double? numVal;
    try {
      numVal = integrate(fnCompiled!, intA, intB, method: intMethod);
    } catch (_) {
      numVal = null;
    }
    setAttrValue(
      valIntNumerical,
      numVal != null ? formatNumber(numVal) : 'Undefined',
    );
  } else if (fnComplexCompiled != null) {
    try {
      final realVal = integrate(
        (x) => fnComplexCompiled!(Complex(x, 0)).a.toDouble(),
        intA,
        intB,
        method: intMethod,
      );
      final imagVal = integrate(
        (x) => fnComplexCompiled!(Complex(x, 0)).b.toDouble(),
        intA,
        intB,
        method: intMethod,
      );
      setAttrValue(valIntNumerical, formatComplex(Complex(realVal, imagVal)));
    } catch (_) {
      setAttrValue(valIntNumerical, 'Undefined');
    }
  } else {
    setAttrValue(valIntNumerical, 'Undefined');
  }

  final antideriv = cachedAntideriv;
  if (antideriv != null) {
    try {
      final fb = antideriv.evaluateComplex({'x': Complex(intB, 0)});
      final fa = antideriv.evaluateComplex({'x': Complex(intA, 0)});
      final exact = fb - fa;
      if (exact.a.isFinite && exact.b.isFinite) {
        setAttrValue(valIntAnalytical, formatComplex(exact));
      } else if (exact.a.isInfinite || exact.b.isInfinite) {
        setAttrValue(valIntAnalytical, exact.a.isNegative ? '-∞' : '∞');
      } else {
        setAttrValue(valIntAnalytical, 'Undefined');
      }
    } catch (_) {
      setAttrValue(valIntAnalytical, 'Undefined');
    }
  } else {
    setAttrValue(valIntAnalytical, 'No closed form');
  }
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

  final centerExpr = (taylorAround - taylorAround.round()).abs() < 1e-9
      ? RationalNumber(taylorAround.round())
      : RationalNumber.fromDouble(taylorAround);

  try {
    final seriesObj = expr.toPowerSeries(
      'x',
      point: centerExpr,
      order: taylorOrder + 1,
    );
    final formal = seriesObj.toExpr();
    setAttrExpr(valFormalSeries, formal);
    final poly = seriesObj.toExpr(includeOrder: false).simplify();
    setAttrExpr(taylorPolynomialStr, poly);
    try {
      taylorCompiled = poly.toFunction1D('x');
    } catch (_) {
      taylorCompiled = null;
    }
    try {
      taylorComplexCompiled = poly.toComplexFunction1D('x');
    } catch (_) {
      taylorComplexCompiled = null;
    }
  } catch (_) {
    try {
      final poly = expr
          .taylorSeries('x', order: taylorOrder, around: taylorAround)
          .simplify();
      setAttrExpr(valFormalSeries, poly);
      setAttrExpr(taylorPolynomialStr, poly);
      try {
        taylorCompiled = poly.toFunction1D('x');
      } catch (_) {
        taylorCompiled = null;
      }
      try {
        taylorComplexCompiled = poly.toComplexFunction1D('x');
      } catch (_) {
        taylorComplexCompiled = null;
      }
    } catch (_) {
      setAttrValue(valFormalSeries, 'Undefined');
      setAttrValue(taylorPolynomialStr, 'Undefined');
      taylorCompiled = null;
      taylorComplexCompiled = null;
    }
  }
}

void detectRootsAndExtrema() {
  exactRoots.clear();
  exactSolutions.clear();
  numericRoots.clear();
  localMinima.clear();
  localMaxima.clear();

  final expr = parsedExpr;
  if (expr == null) return;

  // 1. Exact Symbolic Solutions (supports real, imaginary, and complex roots)
  try {
    final solutions = expr.solve('x');
    for (final s in solutions) {
      if (!exactSolutions.contains(s)) {
        exactSolutions.add(s);
      }
    }
    for (final s in solutions) {
      try {
        final cVal = s.evaluateComplex();
        if (cVal.b.abs() < 1e-9 && cVal.a.toDouble().isFinite) {
          if (!exactRoots.any((r) => (r - cVal.a.toDouble()).abs() < 1e-4)) {
            exactRoots.add(cVal.a.toDouble());
          }
        }
      } catch (_) {}
    }
  } catch (_) {}

  // 2. Numerical Roots Scanning in [minX, maxX]
  final realFn =
      fnCompiled ??
      (fnComplexCompiled != null
          ? (double x) {
              try {
                return fnComplexCompiled!(Complex(x, 0)).a.toDouble();
              } catch (_) {
                return double.nan;
              }
            }
          : null);

  final realDf =
      dfCompiled ??
      (dfComplexCompiled != null
          ? (double x) {
              try {
                return dfComplexCompiled!(Complex(x, 0)).a.toDouble();
              } catch (_) {
                return double.nan;
              }
            }
          : null);

  final realD2f =
      d2fCompiled ??
      (d2fComplexCompiled != null
          ? (double x) {
              try {
                return d2fComplexCompiled!(Complex(x, 0)).a.toDouble();
              } catch (_) {
                return double.nan;
              }
            }
          : null);

  if (realFn != null) {
    const steps = 60;
    final stepSize = (maxX - minX) / steps;
    var prevX = minX;
    var prevY = safeGet(() => realFn(prevX))?.toDouble();

    for (var i = 1; i <= steps; i++) {
      final curX = minX + i * stepSize;
      final curY = safeGet(() => realFn(curX))?.toDouble();

      if (prevY != null &&
          curY != null &&
          prevY.isFinite &&
          curY.isFinite &&
          prevY * curY <= 0) {
        try {
          final root = solve(realFn, prevX, b: curX, method: RootMethod.brent);
          if (root.isFinite &&
              !numericRoots.any((r) => (r - root).abs() < 1e-4)) {
            numericRoots.add(root);
          }
        } catch (_) {}
      }
      prevX = curX;
      prevY = curY;
    }
  }

  // Include analytical real roots within range for plotting
  for (final r in exactRoots) {
    if (r >= minX &&
        r <= maxX &&
        !numericRoots.any((nr) => (nr - r).abs() < 1e-4)) {
      numericRoots.add(r);
    }
  }

  // 3. Extrema Detection via derivative zeros Re f'(x) = 0
  if (realFn != null && realDf != null) {
    const steps = 60;
    final stepSize = (maxX - minX) / steps;
    var prevSlopeX = minX;
    var prevSlope = safeGet(() => realDf(prevSlopeX))?.toDouble();

    for (var i = 1; i <= steps; i++) {
      final curX = minX + i * stepSize;
      final curSlope = safeGet(() => realDf(curX))?.toDouble();

      if (prevSlope != null &&
          curSlope != null &&
          prevSlope.isFinite &&
          curSlope.isFinite &&
          prevSlope * curSlope <= 0) {
        try {
          final critX = solve(
            realDf,
            prevSlopeX,
            b: curX,
            method: RootMethod.brent,
          );
          if (critX.isFinite) {
            final yVal = safeGet(() => realFn(critX))?.toDouble();
            final curvature = realD2f != null
                ? safeGet(() => realD2f(critX))?.toDouble()
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
  }

  // Update Telemetry labels
  setAttrExprList(valRootsExact, exactSolutions, emptyText: 'None found');

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
(double, double) estimateYBounds(
  double Function(double) fnReal, [
  double Function(double)? fnImag,
]) {
  var minY = 0.0;
  var maxY = 0.0;
  var hasSamples = false;

  void sample(double x, double Function(double) f) {
    double y;
    try {
      y = f(x);
    } catch (_) {
      return;
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

  const sampleCount = 80;
  for (var i = 0; i <= sampleCount; i++) {
    final x = minX + i * (maxX - minX) / sampleCount;
    sample(x, fnReal);
    if (fnImag != null && showIm) {
      sample(x, fnImag);
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

  final realFn =
      fnCompiled ??
      (fnComplexCompiled != null
          ? (double x) {
              try {
                return fnComplexCompiled!(Complex(x, 0)).a.toDouble();
              } catch (_) {
                return double.nan;
              }
            }
          : null);
  final imagFn = (hasImaginary && fnComplexCompiled != null)
      ? (double x) {
          try {
            return fnComplexCompiled!(Complex(x, 0)).b.toDouble();
          } catch (_) {
            return double.nan;
          }
        }
      : null;

  final realDf =
      dfCompiled ??
      (dfComplexCompiled != null
          ? (double x) {
              try {
                return dfComplexCompiled!(Complex(x, 0)).a.toDouble();
              } catch (_) {
                return double.nan;
              }
            }
          : null);

  final realD2f =
      d2fCompiled ??
      (d2fComplexCompiled != null
          ? (double x) {
              try {
                return d2fComplexCompiled!(Complex(x, 0)).a.toDouble();
              } catch (_) {
                return double.nan;
              }
            }
          : null);

  final realD3f =
      d3fCompiled ??
      (d3fComplexCompiled != null
          ? (double x) {
              try {
                return d3fComplexCompiled!(Complex(x, 0)).a.toDouble();
              } catch (_) {
                return double.nan;
              }
            }
          : null);

  final realTaylor =
      taylorCompiled ??
      (taylorComplexCompiled != null
          ? (double x) {
              try {
                return taylorComplexCompiled!(Complex(x, 0)).a.toDouble();
              } catch (_) {
                return double.nan;
              }
            }
          : null);

  if (realFn == null) return;

  final (minY, maxY) = estimateYBounds(realFn, imagFn);

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
      realFn,
      intA,
      intB,
      fillColor: 'rgba(16, 185, 129, 0.20)',
      strokeColor: '#10b981',
    );
  }

  // 3. Primary Curve Re f(x) or f(x)
  if (showFx) {
    drawCurve(
      ctx,
      vp,
      realFn,
      strokeColor: '#3b82f6',
      lineWidth: 2.5,
      fillColor: hasImaginary ? null : 'rgba(59, 130, 246, 0.08)',
    );
  }

  // 3b. Imaginary Component Curve Im f(x)
  if (showIm && imagFn != null) {
    drawCurve(
      ctx,
      vp,
      imagFn,
      strokeColor: '#a855f7',
      lineWidth: 2.0,
      lineDash: [4, 4],
    );
  }

  // 4. First Derivative f'(x) / Re f'(x)
  if (showDfx && realDf != null) {
    drawCurve(
      ctx,
      vp,
      realDf,
      strokeColor: '#ef4444',
      lineWidth: 1.8,
      lineDash: [4, 4],
    );
  }

  // 5. Second Derivative f''(x) / Re f''(x)
  if (showD2fx && realD2f != null) {
    drawCurve(
      ctx,
      vp,
      realD2f,
      strokeColor: '#a855f7',
      lineWidth: 1.5,
      lineDash: [2, 3],
    );
  }

  // 5b. Third Derivative f'''(x) / Re f'''(x)
  if (showD3fx && realD3f != null) {
    drawCurve(
      ctx,
      vp,
      realD3f,
      strokeColor: '#ec4899',
      lineWidth: 1.5,
      lineDash: [1, 3],
    );
  }

  // 6. Taylor Polynomial Approximation
  if (showTaylor && realTaylor != null) {
    drawCurve(
      ctx,
      vp,
      realTaylor,
      strokeColor: '#f59e0b',
      lineWidth: 2.0,
      lineDash: [6, 3],
    );
  }

  // 7. Tangent Line at pointX
  if (showTangent && realDf != null) {
    final y0 = safeGet(() => realFn(pointX))?.toDouble();
    final slope = safeGet(() => realDf(pointX))?.toDouble();
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
    final hyReal = safeGet(() => realFn(hx))?.toDouble();
    final hyImag = imagFn != null
        ? safeGet(() => imagFn(hx))?.toDouble()
        : null;
    if (hyReal != null && hyReal.isFinite) {
      final hSlope = realDf != null
          ? safeGet(() => realDf(hx))?.toDouble()
          : null;
      final hCurv = realD2f != null
          ? safeGet(() => realD2f(hx))?.toDouble()
          : null;
      final hJerk = realD3f != null
          ? safeGet(() => realD3f(hx))?.toDouble()
          : null;
      final tooltipLines = [
        'x: ${formatNumber(hx, precision: 4)}',
        if (hasImaginary) ...[
          'Re f(x): ${formatNumber(hyReal, precision: 4)}',
          if (hyImag != null && hyImag.isFinite)
            'Im f(x): ${formatNumber(hyImag, precision: 4)}',
        ] else
          'f(x): ${formatNumber(hyReal, precision: 4)}',
        if (hSlope != null && hSlope.isFinite)
          '${hasImaginary ? "Re " : ""}f\'(x): ${formatNumber(hSlope, precision: 4)}',
        if (showD2fx && hCurv != null && hCurv.isFinite)
          '${hasImaginary ? "Re " : ""}f\'\'(x): ${formatNumber(hCurv, precision: 4)}',
        if (showD3fx && hJerk != null && hJerk.isFinite)
          '${hasImaginary ? "Re " : ""}f\'\'\'(x): ${formatNumber(hJerk, precision: 4)}',
      ];
      drawCrosshairAndTooltip(
        ctx,
        vp,
        targetX: hx,
        targetY: hyReal,
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
  web.window.history.replaceState(null, '', '#${queryParams.join('&')}');
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
            if (web.document.activeElement != exprInput) {
              exprInput.value = val;
            }
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
