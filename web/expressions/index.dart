import 'dart:js_interop';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:data/linear.dart';
import 'package:data/numeric.dart';
import 'package:data/symbolic.dart';
import 'package:data/type.dart';
import 'package:web/web.dart' as web;

import '../shared/chart.dart';
import '../shared/utils.dart';
import '../shared/webgl_surface.dart';
import 'algebra.dart';
import 'presets.dart';

// Current Application State
ExpressionPreset? activePreset;
String currentFormula = '(x - 1) * (x - 2) * (x + 2)';
VariableDomain currentDomain = VariableDomain.unknown;

Assumptions get currentAssumptions => currentDomain == VariableDomain.unknown
    ? Assumptions.none
    : Assumptions(defaultDomain: currentDomain);

Expr? parsedExpr;
Expr? cachedD1;
Expr? cachedD2;
Expr? cachedD3;
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
String pointXStr = '0';
String intAStr = '-2';
String intBStr = '2';
int taylorOrder = 3;

bool showFx = true;
bool showIm = true;
bool showDfx = true;
bool showD2fx = false;
bool showD3fx = false;
bool showTaylor = false;
bool showIntegral = false;
bool showTangent = false;
bool showRoots = true;
bool showMin = true;
bool showMax = true;
bool hasImaginary = false;

late InteractiveChartController chartController;

typedef ExtremumPoint = ({double x, double y});

// Plot markers for roots & extrema
final List<double> plotRoots = [];
final List<ExtremumPoint> localMinima = [];
final List<ExtremumPoint> localMaxima = [];

// DOM References
late web.HTMLElement presetsList;
late web.HTMLElement displayTitle;
late web.HTMLElement categoryBadge;
late web.HTMLElement displayDesc;

late web.HTMLInputElement exprInput;
late web.HTMLSelectElement selectDomain;
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

// Card 1: Outputs
late web.HTMLElement valOutParsed;
late web.HTMLElement valOutText;
late web.HTMLElement valOutMathMl;
late web.HTMLElement valOutLatex;

// Card 2: Simplification & Normal Forms
late web.HTMLElement valAlgSimplified;
late web.HTMLElement valAlgExpanded;
late web.HTMLElement valAlgFactored;
late web.HTMLElement valAlgApproximated;
late web.HTMLElement valAlgRationalized;

// Card 2: Rational & Polynomial Algebra
late web.HTMLElement valRatApart;
late web.HTMLElement valRatTogether;
late web.HTMLElement valRatCancel;
late web.HTMLElement valRatCollect;
late web.HTMLElement valRatNum;
late web.HTMLElement valRatDen;

// Card 3: Trigonometric & Complex Forms
late web.HTMLElement valTrigExpand;
late web.HTMLElement valTrigSimplify;
late web.HTMLElement valTrigExp;
late web.HTMLElement valTrigSinCos;
late web.HTMLElement valComplexRect;
late web.HTMLElement valComplexPolar;

// Card 4: Differentiation
late web.HTMLElement valSymDf;
late web.HTMLElement valSymD2f;
late web.HTMLElement valSymD3f;
late web.HTMLElement valSymDfAtX0;
late web.HTMLElement valTangentEq;

// Card 5: Integration
late web.HTMLInputElement inputIntA;
late web.HTMLInputElement inputIntB;
late web.HTMLElement valSymAntideriv;
late web.HTMLElement valIntDefinite;
late web.HTMLElement valIntHalfInf;
late web.HTMLElement valIntFullInf;

// Card 6: Series, Sums & Products
late web.HTMLInputElement sliderTaylorOrder;
late web.HTMLSelectElement selectTaylorCenter;
late web.HTMLElement taylorOrderVal;
late web.HTMLElement valFormalSeries;
late web.HTMLElement taylorPolynomialStr;
late web.HTMLElement valSymSum;
late web.HTMLElement valSymAntidiff;
late web.HTMLElement valSymProduct;

// Card 7: Evaluation & Limits
late web.HTMLInputElement inputPointX;
late web.HTMLElement valEvalFx;
late web.HTMLElement valEvalLim;
late web.HTMLElement valEvalLimDir;
late web.HTMLElement valEvalLimPosInf;
late web.HTMLElement valEvalLimNegInf;

// Card 8: Equations, Roots & Extrema
late web.HTMLElement valRootsExact;
late web.HTMLElement valCriticalExact;
late web.HTMLElement valInflectionExact;
late web.HTMLElement valExtremaMin;
late web.HTMLElement valExtremaMax;

// Card 12: Bytecode Compilation & VM
late web.HTMLElement valBcStack;
late web.HTMLElement valBcRegs;
late web.HTMLElement bytecodePre;

// Card 11: Multivariable Calculus
late web.HTMLInputElement inputMvVars;
late web.HTMLElement valMvFreeVars;
late web.HTMLElement valMvGrad;
late web.HTMLElement valMvLaplacian;
late web.HTMLElement valMvHessian;
late web.HTMLElement valMvHessianDet;
late web.HTMLElement valMvStationary;

void main() {
  initDom();
  initGlobalCopyHandler();
  buildSidebar();
  attachEventListeners();
  loadFromUrlHash();
}

void initDom() {
  presetsList = web.document.querySelector('#presets-list') as web.HTMLElement;
  displayTitle =
      web.document.querySelector('#display-title') as web.HTMLElement;
  categoryBadge =
      web.document.querySelector('#category-badge') as web.HTMLElement;
  displayDesc = web.document.querySelector('#display-desc') as web.HTMLElement;

  exprInput = web.document.querySelector('#expr-input') as web.HTMLInputElement;
  selectDomain =
      web.document.querySelector('#select-domain') as web.HTMLSelectElement;
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

  // Card 1: Outputs
  valOutParsed =
      web.document.querySelector('#val-out-parsed') as web.HTMLElement;
  valOutText = web.document.querySelector('#val-out-text') as web.HTMLElement;
  valOutMathMl =
      web.document.querySelector('#val-out-mathml') as web.HTMLElement;
  valOutLatex = web.document.querySelector('#val-out-latex') as web.HTMLElement;

  // Card 2: Simplification & Normal Forms
  valAlgSimplified =
      web.document.querySelector('#val-alg-simplified') as web.HTMLElement;
  valAlgExpanded =
      web.document.querySelector('#val-alg-expanded') as web.HTMLElement;
  valAlgFactored =
      web.document.querySelector('#val-alg-factored') as web.HTMLElement;
  valAlgApproximated =
      web.document.querySelector('#val-alg-approximated') as web.HTMLElement;
  valAlgRationalized =
      web.document.querySelector('#val-alg-rationalized') as web.HTMLElement;

  // Card 2
  valRatApart = web.document.querySelector('#val-rat-apart') as web.HTMLElement;
  valRatTogether =
      web.document.querySelector('#val-rat-together') as web.HTMLElement;
  valRatCancel =
      web.document.querySelector('#val-rat-cancel') as web.HTMLElement;
  valRatCollect =
      web.document.querySelector('#val-rat-collect') as web.HTMLElement;
  valRatNum = web.document.querySelector('#val-rat-num') as web.HTMLElement;
  valRatDen = web.document.querySelector('#val-rat-den') as web.HTMLElement;

  // Card 3
  valTrigExpand =
      web.document.querySelector('#val-trig-expand') as web.HTMLElement;
  valTrigSimplify =
      web.document.querySelector('#val-trig-simplify') as web.HTMLElement;
  valTrigExp = web.document.querySelector('#val-trig-exp') as web.HTMLElement;
  valTrigSinCos =
      web.document.querySelector('#val-trig-sincos') as web.HTMLElement;
  valComplexRect =
      web.document.querySelector('#val-complex-rect') as web.HTMLElement;
  valComplexPolar =
      web.document.querySelector('#val-complex-polar') as web.HTMLElement;

  // Card 4
  valSymDf = web.document.querySelector('#val-sym-df') as web.HTMLElement;
  valSymD2f = web.document.querySelector('#val-sym-d2f') as web.HTMLElement;
  valSymD3f = web.document.querySelector('#val-sym-d3f') as web.HTMLElement;
  valSymDfAtX0 =
      web.document.querySelector('#val-sym-df-at-x0') as web.HTMLElement;
  valTangentEq =
      web.document.querySelector('#val-tangent-eq') as web.HTMLElement;

  // Card 5
  inputIntA =
      web.document.querySelector('#input-int-a') as web.HTMLInputElement;
  inputIntB =
      web.document.querySelector('#input-int-b') as web.HTMLInputElement;
  valSymAntideriv =
      web.document.querySelector('#val-sym-antideriv') as web.HTMLElement;
  valIntDefinite =
      web.document.querySelector('#val-int-definite') as web.HTMLElement;
  valIntHalfInf =
      web.document.querySelector('#val-int-half-inf') as web.HTMLElement;
  valIntFullInf =
      web.document.querySelector('#val-int-full-inf') as web.HTMLElement;

  // Card 6
  sliderTaylorOrder = web.document.querySelector(
    '#slider-taylor-order',
  ) as web.HTMLInputElement;
  selectTaylorCenter = web.document.querySelector(
    '#select-taylor-center',
  ) as web.HTMLSelectElement;
  taylorOrderVal =
      web.document.querySelector('#taylor-order-val') as web.HTMLElement;
  valFormalSeries =
      web.document.querySelector('#val-formal-series') as web.HTMLElement;
  taylorPolynomialStr =
      web.document.querySelector('#taylor-polynomial-str') as web.HTMLElement;
  valSymSum = web.document.querySelector('#val-sym-sum') as web.HTMLElement;
  valSymAntidiff =
      web.document.querySelector('#val-sym-antidiff') as web.HTMLElement;
  valSymProduct =
      web.document.querySelector('#val-sym-product') as web.HTMLElement;

  // Card 7
  inputPointX =
      web.document.querySelector('#input-point-x') as web.HTMLInputElement;
  valEvalFx = web.document.querySelector('#val-eval-fx') as web.HTMLElement;
  valEvalLim = web.document.querySelector('#val-eval-lim') as web.HTMLElement;
  valEvalLimDir =
      web.document.querySelector('#val-eval-lim-dir') as web.HTMLElement;
  valEvalLimPosInf =
      web.document.querySelector('#val-eval-lim-pos-inf') as web.HTMLElement;
  valEvalLimNegInf =
      web.document.querySelector('#val-eval-lim-neg-inf') as web.HTMLElement;

  // Card 8
  valRootsExact =
      web.document.querySelector('#val-roots-exact') as web.HTMLElement;
  valCriticalExact =
      web.document.querySelector('#val-critical-exact') as web.HTMLElement;
  valInflectionExact =
      web.document.querySelector('#val-inflection-exact') as web.HTMLElement;
  valExtremaMin =
      web.document.querySelector('#val-extrema-min') as web.HTMLElement;
  valExtremaMax =
      web.document.querySelector('#val-extrema-max') as web.HTMLElement;

  // Card 12: Bytecode Compilation & VM
  valBcStack = web.document.querySelector('#val-bc-stack') as web.HTMLElement;
  valBcRegs = web.document.querySelector('#val-bc-regs') as web.HTMLElement;
  bytecodePre = web.document.querySelector('#bytecode-pre') as web.HTMLElement;

  // Card 11: Multivariable Calculus
  inputMvVars =
      web.document.querySelector('#input-mv-vars') as web.HTMLInputElement;
  valMvFreeVars =
      web.document.querySelector('#val-mv-free-vars') as web.HTMLElement;
  valMvGrad = web.document.querySelector('#val-mv-grad') as web.HTMLElement;
  valMvLaplacian =
      web.document.querySelector('#val-mv-laplacian') as web.HTMLElement;
  valMvHessian =
      web.document.querySelector('#val-mv-hessian') as web.HTMLElement;
  valMvHessianDet =
      web.document.querySelector('#val-mv-hessian-det') as web.HTMLElement;
  valMvStationary =
      web.document.querySelector('#val-mv-stationary') as web.HTMLElement;
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

VariableDomain _parseDomain(String value) => switch (value) {
  'complex' => VariableDomain.complex,
  'real' => VariableDomain.real,
  'positive' => VariableDomain.positive,
  'integer' => VariableDomain.integer,
  _ => VariableDomain.unknown,
};

String _domainToString(VariableDomain domain) => switch (domain) {
  VariableDomain.complex => 'complex',
  VariableDomain.real => 'real',
  VariableDomain.positive => 'positive',
  VariableDomain.integer => 'integer',
  VariableDomain.unknown => 'unknown',
};

void selectPreset(ExpressionPreset preset) {
  activePreset = preset;
  currentFormula = preset.formula;
  exprInput.value = preset.formula;

  currentDomain = preset.defaultDomain;
  selectDomain.value = _domainToString(currentDomain);

  displayTitle.textContent = preset.name;
  categoryBadge.textContent = preset.category;
  displayDesc.textContent = preset.description;

  minX = preset.defaultMinX;
  maxX = preset.defaultMaxX;
  rangeMinX.value = minX.toString();
  rangeMaxX.value = maxX.toString();
  chartController.setBounds(
    minX: minX,
    maxX: maxX,
    asDefault: true,
    clearUserInteraction: true,
  );

  pointXStr = preset.defaultPointX;
  inputPointX.value = pointXStr;

  intAStr = preset.defaultIntA;
  intBStr = preset.defaultIntB;
  inputIntA.value = intAStr;
  inputIntB.value = intBStr;

  if (preset.defaultMvVars != null) {
    inputMvVars.value = preset.defaultMvVars!;
  } else {
    final freeVars =
        (Expr.tryParse(preset.formula) ?? parsedExpr)?.freeVariables.toList() ??
        [];
    if (freeVars.length > 1) {
      freeVars.sort();
      inputMvVars.value = freeVars.join(', ');
    } else {
      inputMvVars.value = 'x, y';
    }
  }

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
  chartController = InteractiveChartController(
    plotCanvas,
    minX: minX,
    maxX: maxX,
    onUpdate: drawCharts,
    onViewportChanged: (newMinX, newMaxX, _, _) {
      minX = double.parse(newMinX.toStringAsFixed(4));
      maxX = double.parse(newMaxX.toStringAsFixed(4));
      rangeMinX.value = formatNumber(minX, precision: 3);
      rangeMaxX.value = formatNumber(maxX, precision: 3);
      updateImaginaryDetection();
      detectRootsAndExtrema();
      updateUrlHash();
    },
  );

  exprInput.onInput.listen((_) {
    currentFormula = exprInput.value.trim();
    activePreset = null;
    displayTitle.textContent = 'Custom Expression';
    categoryBadge.textContent = 'User Defined';
    displayDesc.textContent =
        'Interactive symbolic algebra and calculus exploration.';
    highlightActiveSidebarItem(null);
    chartController.hasUserPannedOrZoomed = false;
    updateAll();
    updateUrlHash();
  });

  selectDomain.onChange.listen((_) {
    currentDomain = _parseDomain(selectDomain.value);
    updateAll();
    updateUrlHash();
  });

  // Range inputs
  rangeMinX.onChange.listen((_) {
    final val = double.tryParse(rangeMinX.value);
    if (val != null && val < maxX) {
      minX = val;
      chartController.setBounds(minX: minX, clearUserInteraction: true);
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
      chartController.setBounds(maxX: maxX, clearUserInteraction: true);
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
    chartController.setBounds(
      minX: minX,
      maxX: maxX,
      asDefault: true,
      clearUserInteraction: true,
    );
    WebGLSurfaceRenderer.forCanvas(
      plotCanvas,
      onUpdate: drawCharts,
    ).resetCamera();
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

  // Symbolic point x0 input
  inputPointX.onInput.listen((_) {
    pointXStr = inputPointX.value.trim();
    updatePointTelemetry();
    if (selectTaylorCenter.value == 'x0') {
      updateTaylorTelemetry();
    }
    drawCharts();
    updateUrlHash();
  });

  // Symbolic integration bounds
  inputIntA.onInput.listen((_) {
    intAStr = inputIntA.value.trim();
    updateIntegrationTelemetry();
    drawCharts();
    updateUrlHash();
  });
  inputIntB.onInput.listen((_) {
    intBStr = inputIntB.value.trim();
    updateIntegrationTelemetry();
    drawCharts();
    updateUrlHash();
  });

  // Taylor expansion controls
  sliderTaylorOrder.onInput.listen((_) {
    taylorOrder = int.tryParse(sliderTaylorOrder.value) ?? taylorOrder;
    taylorOrderVal.textContent = taylorOrder.toString();
    updateTaylorTelemetry();
    drawCharts();
  });
  selectTaylorCenter.onChange.listen((_) {
    updateTaylorTelemetry();
    drawCharts();
  });

  // Multivariable variable list input
  inputMvVars.onInput.listen((_) {
    updateMultivariableTelemetry();
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

void _trySetExpr(web.HTMLElement element, Expr? Function() compute) {
  try {
    final result = compute();
    setAttrExpr(element, result);
  } catch (_) {
    setAttrValue(element, 'Undefined');
  }
}

void _setDirectionalLimits(web.HTMLElement element, Expr? left, Expr? right) {
  if (left == null && right == null) {
    setAttrValue(element, '-');
    return;
  }
  final lExpr = left ?? Constant.undefined;
  final rExpr = right ?? Constant.undefined;
  final plainText = 'x→x₀⁻: $lExpr | x→x₀⁺: $rExpr';
  element.title = plainText;
  element.setAttribute('data-copy', plainText);
  try {
    final html =
        '${lExpr.toMathMl()} <span style="opacity:0.4;padding:0 6px;">|</span> ${rExpr.toMathMl()}';
    element.innerHTML = html.toJS;
  } catch (_) {
    element.textContent = plainText;
  }
}

void updateAll() {
  Expr? expr;
  try {
    expr = Expr.tryParse(currentFormula);
  } catch (_) {
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
    cachedD1 = null;
    cachedD2 = null;
    cachedD3 = null;
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

  statusBadge.className = 'formula-status-badge status-valid';
  statusBadge.textContent = '✓ Valid';
  parseErrorMessage.style.display = 'none';
  parsedExpr = expr;
  final assumptions = currentAssumptions;

  // Card 1: Outputs
  setAttrExpr(valOutParsed, expr);
  try {
    setAttrValue(valOutText, expr.format());
  } catch (_) {
    setAttrValue(valOutText, '-');
  }
  try {
    setAttrValue(valOutMathMl, expr.toMathMl());
  } catch (_) {
    setAttrValue(valOutMathMl, '-');
  }
  try {
    setAttrValue(valOutLatex, expr.toLatex());
  } catch (_) {
    setAttrValue(valOutLatex, '-');
  }

  // Card 2: Simplification & Normal Forms
  Expr simplified;
  try {
    simplified = expr.simplify(assumptions: assumptions);
  } catch (_) {
    simplified = expr;
  }
  setAttrExpr(valAlgSimplified, simplified);
  _trySetExpr(valAlgExpanded, () => expr!.expand(assumptions: assumptions));
  _trySetExpr(
    valAlgFactored,
    () => factorExpr(expr!, assumptions: assumptions),
  );
  _trySetExpr(valAlgApproximated, () => simplified.approximate());
  _trySetExpr(valAlgRationalized, () => expr!.rationalize());

  // Card 2: Rational & Polynomial Algebra
  _trySetExpr(valRatApart, () => expr!.apart('x', assumptions: assumptions));
  _trySetExpr(valRatTogether, () => expr!.together(assumptions: assumptions));
  _trySetExpr(valRatCancel, () => expr!.cancel(assumptions: assumptions));
  _trySetExpr(
    valRatCollect,
    () => expr!.collect('x', assumptions: assumptions),
  );
  _trySetExpr(valRatNum, () => expr!.numerator);
  _trySetExpr(valRatDen, () => expr!.denominator);

  // Card 3: Trigonometric & Complex Forms
  _trySetExpr(valTrigExpand, () => expr!.expandTrig(assumptions: assumptions));
  _trySetExpr(
    valTrigSimplify,
    () => expr!.simplifyTrig(assumptions: assumptions),
  );
  _trySetExpr(
    valTrigExp,
    () => expr!.rewrite(RewriteTarget.exp, assumptions: assumptions),
  );
  _trySetExpr(
    valTrigSinCos,
    () => expr!.rewrite(RewriteTarget.trig, assumptions: assumptions),
  );
  _trySetExpr(
    valComplexRect,
    () => expr!.toRectangular(assumptions: assumptions),
  );
  _trySetExpr(valComplexPolar, () => expr!.toPolar(assumptions: assumptions));

  // Card 4: Differentiation
  try {
    cachedD1 = expr
        .derivative('x', assumptions: assumptions)
        .simplify(assumptions: assumptions);
  } catch (_) {
    cachedD1 = null;
  }
  try {
    cachedD2 = cachedD1
        ?.derivative('x', assumptions: assumptions)
        .simplify(assumptions: assumptions);
  } catch (_) {
    cachedD2 = null;
  }
  try {
    cachedD3 = cachedD2
        ?.derivative('x', assumptions: assumptions)
        .simplify(assumptions: assumptions);
  } catch (_) {
    cachedD3 = null;
  }

  setAttrExpr(valSymDf, cachedD1);
  setAttrExpr(valSymD2f, cachedD2);
  setAttrExpr(valSymD3f, cachedD3);

  // Card 5: Indefinite & Improper Integration
  try {
    cachedAntideriv = expr
        .integrate('x', assumptions: assumptions)
        .simplify(assumptions: assumptions);
    setAttrExpr(valSymAntideriv, cachedAntideriv);
  } catch (_) {
    cachedAntideriv = null;
    setAttrValue(valSymAntideriv, 'Undefined');
  }

  _trySetExpr(
    valIntHalfInf,
    () => expr!
        .integrate(
          'x',
          from: IntegerNumber.zero,
          to: Constant.infinity,
          assumptions: assumptions,
        )
        .simplify(assumptions: assumptions),
  );
  _trySetExpr(
    valIntFullInf,
    () => expr!
        .integrate(
          'x',
          from: -Constant.infinity,
          to: Constant.infinity,
          assumptions: assumptions,
        )
        .simplify(assumptions: assumptions),
  );

  // Card 6: Summations & Products
  _trySetExpr(
    valSymSum,
    () => expr!
        .sum(
          'x',
          IntegerNumber.one,
          const Variable('n'),
          assumptions: assumptions,
        )
        .simplify(assumptions: assumptions),
  );
  try {
    final antidiff = expr.indefiniteSum('x', assumptions: assumptions);
    if (antidiff != null) {
      setAttrExpr(valSymAntidiff, antidiff);
    } else {
      setAttrValue(valSymAntidiff, 'No closed form');
    }
  } catch (_) {
    setAttrValue(valSymAntidiff, 'No closed form');
  }
  _trySetExpr(
    valSymProduct,
    () => expr!
        .product(
          'x',
          IntegerNumber.one,
          const Variable('n'),
          assumptions: assumptions,
        )
        .simplify(assumptions: assumptions),
  );

  // Card 7: Infinite Limits
  _trySetExpr(
    valEvalLimPosInf,
    () => expr!.limit('x', Constant.infinity, assumptions: assumptions),
  );
  _trySetExpr(
    valEvalLimNegInf,
    () => expr!.limit('x', -Constant.infinity, assumptions: assumptions),
  );

  // Compile evaluation closures for plotting (slicing auxiliary variables at 1)
  final plotExpr = _sliceFor1DPlot(expr);
  final plotD1 = cachedD1 != null ? _sliceFor1DPlot(cachedD1!) : null;
  final plotD2 = cachedD2 != null ? _sliceFor1DPlot(cachedD2!) : null;
  final plotD3 = cachedD3 != null ? _sliceFor1DPlot(cachedD3!) : null;

  try {
    fnCompiled = plotExpr.toFunction1D('x');
  } catch (_) {
    fnCompiled = null;
  }
  try {
    dfCompiled = plotD1?.toFunction1D('x');
  } catch (_) {
    dfCompiled = null;
  }
  try {
    d2fCompiled = plotD2?.toFunction1D('x');
  } catch (_) {
    d2fCompiled = null;
  }
  try {
    d3fCompiled = plotD3?.toFunction1D('x');
  } catch (_) {
    d3fCompiled = null;
  }

  try {
    fnComplexCompiled = plotExpr.toComplexFunction1D('x');
  } catch (_) {
    fnComplexCompiled = null;
  }
  try {
    dfComplexCompiled = plotD1?.toComplexFunction1D('x');
  } catch (_) {
    dfComplexCompiled = null;
  }
  try {
    d2fComplexCompiled = plotD2?.toComplexFunction1D('x');
  } catch (_) {
    d2fComplexCompiled = null;
  }
  try {
    d3fComplexCompiled = cachedD3?.toComplexFunction1D('x');
  } catch (_) {
    d3fComplexCompiled = null;
  }

  updateImaginaryDetection();
  updatePointTelemetry();
  updateIntegrationTelemetry();
  updateTaylorTelemetry();
  updateBytecodeTelemetry();
  updateMultivariableTelemetry();
  detectRootsAndExtrema();
  drawCharts();
}

void clearTelemetry() {
  hasImaginary = false;
  toggleLblFxText.textContent = 'f(x)';
  toggleLblIm.style.display = 'none';

  for (final el in [
    valOutParsed,
    valOutText,
    valOutMathMl,
    valOutLatex,
    valAlgSimplified,
    valAlgExpanded,
    valAlgFactored,
    valAlgApproximated,
    valAlgRationalized,
    valRatApart,
    valRatTogether,
    valRatCancel,
    valRatCollect,
    valRatNum,
    valRatDen,
    valTrigExpand,
    valTrigSimplify,
    valTrigExp,
    valTrigSinCos,
    valComplexRect,
    valComplexPolar,
    valSymDf,
    valSymD2f,
    valSymD3f,
    valSymDfAtX0,
    valTangentEq,
    valSymAntideriv,
    valIntDefinite,
    valIntHalfInf,
    valIntFullInf,
    valFormalSeries,
    taylorPolynomialStr,
    valSymSum,
    valSymAntidiff,
    valSymProduct,
    valEvalFx,
    valEvalLim,
    valEvalLimDir,
    valEvalLimPosInf,
    valEvalLimNegInf,
    valRootsExact,
    valCriticalExact,
    valInflectionExact,
    valExtremaMin,
    valExtremaMax,
    valBcStack,
    valBcRegs,
    valMvFreeVars,
    valMvGrad,
    valMvLaplacian,
    valMvHessian,
    valMvHessianDet,
    valMvStationary,
  ]) {
    setAttrExpr(el, null);
  }
  setAttrValue(bytecodePre, 'No bytecode compiled.');
}

bool _isUsableSymbolicValue(Expr expr) => !expr.anyNode(
  (n) =>
      n == Constant.undefined ||
      n == Constant.infinity ||
      n is Integral ||
      n is Derivative ||
      n is Limit ||
      n is Sum ||
      n is Product,
);

Expr? _parsePointExpr(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed == '-infinity' || trimmed == '-∞' || trimmed == '-inf') {
    return -Constant.infinity;
  }
  if (trimmed == 'infinity' ||
      trimmed == '+infinity' ||
      trimmed == '∞' ||
      trimmed == '+∞' ||
      trimmed == 'inf') {
    return Constant.infinity;
  }
  return Expr.tryParse(trimmed);
}

double? _currentPointPlotX() {
  final x0Expr = _parsePointExpr(pointXStr);
  if (x0Expr == null) return null;
  try {
    final c = x0Expr.evaluateComplex();
    if (c.b.abs() < 1e-9 && c.a.isFinite) return c.a.toDouble();
  } catch (_) {}
  return null;
}

void updatePointTelemetry() {
  final expr = parsedExpr;
  if (expr == null) return;

  final x0Expr = _parsePointExpr(pointXStr);
  if (x0Expr == null) {
    setAttrValue(valEvalFx, 'Invalid point');
    setAttrValue(valSymDfAtX0, 'Invalid point');
    setAttrValue(valTangentEq, 'Invalid point');
    setAttrValue(valEvalLim, 'Invalid point');
    setAttrValue(valEvalLimDir, 'Invalid point');
    return;
  }

  final assumptions = currentAssumptions;

  // 1. Exact symbolic f(x0)
  Expr? fx0Sym;
  try {
    fx0Sym = expr.substitute('x', x0Expr).simplify(assumptions: assumptions);
    setAttrExpr(valEvalFx, fx0Sym);
  } catch (_) {
    fx0Sym = null;
    setAttrExpr(valEvalFx, Constant.undefined);
  }

  // 2. Exact symbolic f'(x0)
  Expr? dfx0Sym;
  final d1 = cachedD1;
  if (d1 != null) {
    try {
      dfx0Sym = d1.substitute('x', x0Expr).simplify(assumptions: assumptions);
      setAttrExpr(valSymDfAtX0, dfx0Sym);
    } catch (_) {
      dfx0Sym = null;
      setAttrExpr(valSymDfAtX0, Constant.undefined);
    }
  } else {
    setAttrExpr(valSymDfAtX0, Constant.undefined);
  }

  // 3. Exact symbolic tangent line y = f(x0) + f'(x0)*(x - x0)
  if (fx0Sym != null &&
      dfx0Sym != null &&
      _isUsableSymbolicValue(fx0Sym) &&
      _isUsableSymbolicValue(dfx0Sym)) {
    try {
      final rhs = (fx0Sym + dfx0Sym * (const Variable('x') - x0Expr))
          .expand(assumptions: assumptions)
          .simplify(assumptions: assumptions);
      setAttrExpr(valTangentEq, Equal(const Variable('y'), rhs));
    } catch (_) {
      setAttrExpr(valTangentEq, Constant.undefined);
    }
  } else {
    setAttrExpr(valTangentEq, Constant.undefined);
  }

  // 4. Two-sided and directional limits at x0
  _trySetExpr(
    valEvalLim,
    () => expr.limit('x', x0Expr, assumptions: assumptions),
  );

  Expr? limLeft;
  Expr? limRight;
  try {
    limLeft = expr.limit(
      'x',
      x0Expr,
      direction: LimitDirection.fromBelow,
      assumptions: assumptions,
    );
  } catch (_) {}
  try {
    limRight = expr.limit(
      'x',
      x0Expr,
      direction: LimitDirection.fromAbove,
      assumptions: assumptions,
    );
  } catch (_) {}
  _setDirectionalLimits(valEvalLimDir, limLeft, limRight);
}

double? _boundToPlotCoordinate(Expr? boundExpr) {
  if (boundExpr == null) return null;
  if (boundExpr == Constant.infinity) return maxX;
  if (boundExpr == -Constant.infinity) return minX;
  try {
    final c = boundExpr.evaluateComplex();
    if (c.b.abs() < 1e-9) {
      if (c.a.isInfinite) return c.a.isNegative ? minX : maxX;
      if (c.a.isFinite) return c.a.toDouble();
    }
  } catch (_) {}
  return null;
}

void updateIntegrationTelemetry() {
  final expr = parsedExpr;
  if (expr == null) return;

  final aExpr = _parsePointExpr(intAStr);
  final bExpr = _parsePointExpr(intBStr);
  if (aExpr == null || bExpr == null) {
    setAttrValue(valIntDefinite, 'Invalid bounds');
    return;
  }

  final assumptions = currentAssumptions;
  _trySetExpr(
    valIntDefinite,
    () => expr
        .integrate('x', from: aExpr, to: bExpr, assumptions: assumptions)
        .simplify(assumptions: assumptions),
  );
}

void updateTaylorTelemetry() {
  final expr = parsedExpr;
  if (expr == null) return;

  final assumptions = currentAssumptions;
  final centerExpr = selectTaylorCenter.value == 'x0'
      ? (_parsePointExpr(pointXStr) ?? IntegerNumber.zero)
      : IntegerNumber.zero;

  try {
    final formal = expr.series(
      'x',
      point: centerExpr,
      order: taylorOrder + 1,
      assumptions: assumptions,
    );
    setAttrExpr(valFormalSeries, formal);
    final poly = expr
        .series(
          'x',
          point: centerExpr,
          order: taylorOrder + 1,
          includeOrder: false,
          assumptions: assumptions,
        )
        .simplify(assumptions: assumptions);
    setAttrExpr(taylorPolynomialStr, poly);
    final plotPoly = _sliceFor1DPlot(poly);
    try {
      taylorCompiled = plotPoly.toFunction1D('x');
    } catch (_) {
      taylorCompiled = null;
    }
    try {
      taylorComplexCompiled = plotPoly.toComplexFunction1D('x');
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

String _formatInstruction(int pc, Instruction instr, [List<String>? varNames]) {
  final opName = instr.op.name.padRight(12);
  final payload = switch (instr.op) {
    Op.pushConst =>
      instr.complexValue.b != 0.0
          ? '${formatNumber(instr.complexValue.a)} + ${formatNumber(instr.complexValue.b)}i'
          : formatNumber(instr.realValue),
    Op.loadVar =>
      (varNames != null && instr.index < varNames.length)
          ? 'var[${instr.index}] (${varNames[instr.index]})'
          : 'var[${instr.index}]',
    Op.storeReg => 'reg[${instr.index}]',
    Op.loadReg => 'reg[${instr.index}]',
    Op.jump => '-> pc ${instr.index}',
    Op.jumpIfFalse => '-> pc ${instr.index}',
    Op.evalNode => '${instr.node}',
    Op.pow when instr.index != 0 => 'mode:${instr.index}',
    _ => '',
  };
  return '${pc.toString().padLeft(3)}: $opName $payload'.trimRight();
}

void updateBytecodeTelemetry() {
  final expr = parsedExpr;
  if (expr == null) {
    setAttrValue(valBcStack, '-');
    setAttrValue(valBcRegs, '-');
    setAttrValue(bytecodePre, 'No bytecode compiled.');
    return;
  }

  try {
    final freeVars = expr.freeVariables.toList()..sort();
    final evaluator = expr.toBytecode(
      variables: freeVars.isNotEmpty ? freeVars : ['x'],
      optimize: true,
      assumptions: currentAssumptions,
    );
    setAttrValue(valBcStack, evaluator.maxStack.toString());
    setAttrValue(valBcRegs, evaluator.registerCount.toString());

    final buffer = StringBuffer();
    for (var i = 0; i < evaluator.instructions.length; i++) {
      buffer.writeln(
        _formatInstruction(i, evaluator.instructions[i], evaluator.variables),
      );
    }
    final disasm = buffer.toString().trimRight();
    setAttrValue(
      bytecodePre,
      disasm.isNotEmpty ? disasm : '(empty program)',
      customCopy: disasm.isNotEmpty ? disasm : null,
    );
  } catch (e) {
    setAttrValue(valBcStack, '-');
    setAttrValue(valBcRegs, '-');
    setAttrValue(bytecodePre, 'Bytecode compilation failed: $e');
  }
}

void updateMultivariableTelemetry() {
  final expr = parsedExpr;
  if (expr == null) {
    setAttrValue(valMvFreeVars, '-');
    setAttrValue(valMvGrad, '-');
    setAttrValue(valMvLaplacian, '-');
    setAttrValue(valMvHessian, '-');
    setAttrValue(valMvHessianDet, '-');
    setAttrValue(valMvStationary, '-');
    return;
  }

  final freeVars = expr.freeVariables.toList()..sort();
  setAttrValue(
    valMvFreeVars,
    freeVars.isNotEmpty ? freeVars.join(', ') : 'None (constant)',
  );

  var rawInput = inputMvVars.value.trim();
  if (rawInput.isEmpty ||
      (freeVars.length > 1 && !freeVars.any((v) => rawInput.contains(v)))) {
    rawInput = freeVars.isNotEmpty ? freeVars.join(', ') : 'x';
    inputMvVars.value = rawInput;
  }

  final vars = rawInput
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  if (vars.isEmpty) {
    setAttrValue(valMvGrad, 'No variables specified');
    setAttrValue(valMvLaplacian, '-');
    setAttrValue(valMvHessian, 'No variables specified');
    setAttrValue(valMvHessianDet, 'No variables specified');
    setAttrValue(valMvStationary, '-');
    return;
  }

  final assumptions = currentAssumptions;

  // Gradient ∇f
  Vector<Expr>? grad;
  try {
    grad = expr.gradient(vars, assumptions: assumptions);
    setAttrVector(valMvGrad, grad);
  } catch (_) {
    setAttrValue(valMvGrad, '-');
  }

  // Hessian matrix H, determinant |H|, and Laplacian Δf
  try {
    final hessian = expr.hessian(vars, assumptions: assumptions);

    // Laplacian Δf = tr(H)
    try {
      final diagTerms = <Expr>[
        for (var i = 0; i < hessian.rowCount; i++) hessian.getUnchecked(i, i),
      ];
      final laplacian = Add(diagTerms).simplify(assumptions: assumptions);
      setAttrExpr(valMvLaplacian, laplacian);
    } catch (_) {
      setAttrValue(valMvLaplacian, '-');
    }

    // Determinant |H|
    try {
      final det = hessian.determinant().simplify(assumptions: assumptions);
      setAttrExpr(valMvHessianDet, det);
    } catch (_) {
      setAttrValue(valMvHessianDet, '-');
    }

    setAttrMatrix(valMvHessian, hessian);
  } catch (e) {
    setAttrValue(valMvLaplacian, '-');
    setAttrValue(valMvHessian, '-');
    setAttrValue(valMvHessianDet, '-');
  }

  // Stationary points ∇f = 0
  if (grad != null) {
    try {
      final equations = [for (var i = 0; i < grad.length; i++) grad[i]];
      final solutions = equations.solve(vars, assumptions: assumptions);
      if (solutions.isEmpty) {
        setAttrValue(valMvStationary, 'None found');
      } else {
        final formatted = solutions
            .map((sol) {
              final entries = sol.entries
                  .map((e) => '${e.key} = ${e.value.format()}')
                  .join(', ');
              return '($entries)';
            })
            .join('; ');
        setAttrValue(valMvStationary, formatted);
      }
    } catch (_) {
      setAttrValue(valMvStationary, 'Underdetermined');
    }
  } else {
    setAttrValue(valMvStationary, '-');
  }
}

void detectRootsAndExtrema() {
  plotRoots.clear();
  localMinima.clear();
  localMaxima.clear();

  final expr = parsedExpr;
  if (expr == null) return;

  final assumptions = currentAssumptions;

  // 1. Exact symbolic roots f(x) = 0
  final exactSolutions = <Expr>[];
  try {
    for (final s in expr.solve('x', assumptions: assumptions)) {
      if (!exactSolutions.contains(s)) {
        exactSolutions.add(s);
      }
    }
  } catch (_) {}
  setAttrExprList(valRootsExact, exactSolutions, emptyText: 'None found');

  for (final s in exactSolutions) {
    try {
      final cVal = s.evaluateComplex();
      if (cVal.b.abs() < 1e-7 && cVal.a.toDouble().isFinite) {
        final rx = cVal.a.toDouble();
        if (rx >= minX &&
            rx <= maxX &&
            !plotRoots.any((r) => (r - rx).abs() < 1e-4)) {
          plotRoots.add(rx);
        }
      }
    } catch (_) {}
  }

  // 2. Exact symbolic critical points f'(x) = 0
  final exactCritical = <Expr>[];
  final d1 = cachedD1;
  if (d1 != null && d1 != IntegerNumber.zero) {
    try {
      for (final s in d1.solve('x', assumptions: assumptions)) {
        if (!exactCritical.contains(s)) {
          exactCritical.add(s);
        }
      }
    } catch (_) {}
  }
  setAttrExprList(valCriticalExact, exactCritical, emptyText: 'None found');

  // 3. Exact symbolic inflection points f''(x) = 0
  final exactInflection = <Expr>[];
  final d2 = cachedD2;
  if (d2 != null && d2 != IntegerNumber.zero) {
    try {
      for (final s in d2.solve('x', assumptions: assumptions)) {
        if (!exactInflection.contains(s)) {
          exactInflection.add(s);
        }
      }
    } catch (_) {}
  }
  setAttrExprList(valInflectionExact, exactInflection, emptyText: 'None found');

  // Classify exact symbolic critical points into minima and maxima
  final symbolicMinima = <Expr>[];
  final symbolicMaxima = <Expr>[];
  for (final crit in exactCritical) {
    try {
      final cVal = crit.evaluateComplex();
      if (cVal.b.abs() > 1e-7 || !cVal.a.toDouble().isFinite) continue;
      final cx = cVal.a.toDouble();

      double? yVal;
      if (fnCompiled != null) {
        yVal = safeGet(() => fnCompiled!(cx))?.toDouble();
      } else if (fnComplexCompiled != null) {
        final cy = fnComplexCompiled!(Complex(cx, 0));
        if (cy.b.abs() < 1e-6) yVal = cy.a.toDouble();
      }

      double? curv;
      if (d2 != null) {
        try {
          final c2 = d2.substitute('x', crit).evaluateComplex();
          if (c2.b.abs() < 1e-6) curv = c2.a.toDouble();
        } catch (_) {}
      }
      curv ??= d2fCompiled != null
          ? safeGet(() => d2fCompiled!(cx))?.toDouble()
          : null;

      if (curv != null && curv > 1e-6) {
        symbolicMinima.add(crit);
        if (yVal != null &&
            yVal.isFinite &&
            cx >= minX &&
            cx <= maxX &&
            !localMinima.any((m) => (m.x - cx).abs() < 1e-3)) {
          localMinima.add((x: cx, y: yVal));
        }
      } else if (curv != null && curv < -1e-6) {
        symbolicMaxima.add(crit);
        if (yVal != null &&
            yVal.isFinite &&
            cx >= minX &&
            cx <= maxX &&
            !localMaxima.any((m) => (m.x - cx).abs() < 1e-3)) {
          localMaxima.add((x: cx, y: yVal));
        }
      }
    } catch (_) {}
  }

  // Supplement plot markers for periodic/transcendental functions within [minX, maxX]
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
              realFn(root).abs() < 1e-3 &&
              !plotRoots.any((r) => (r - root).abs() < 1e-4)) {
            plotRoots.add(root);
          }
        } catch (_) {}
      }
      prevX = curX;
      prevY = curY;
    }
  }

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
          if (critX.isFinite && realDf(critX).abs() < 1e-3) {
            final yVal = safeGet(() => realFn(critX))?.toDouble();
            final curvature = realD2f != null
                ? safeGet(() => realD2f(critX))?.toDouble()
                : null;

            if (yVal != null && yVal.isFinite) {
              if (curvature != null && curvature > 1e-6) {
                if (!localMinima.any((m) => (m.x - critX).abs() < 1e-3)) {
                  localMinima.add((x: critX, y: yVal));
                }
              } else if (curvature != null && curvature < -1e-6) {
                if (!localMaxima.any((m) => (m.x - critX).abs() < 1e-3)) {
                  localMaxima.add((x: critX, y: yVal));
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

  // Present exact symbolic extrema when available, otherwise numeric values (never guess irrationals)
  if (symbolicMinima.isNotEmpty) {
    setAttrExprList(valExtremaMin, symbolicMinima);
  } else if (localMinima.isNotEmpty) {
    setAttrValue(
      valExtremaMin,
      localMinima
          .map(
            (m) =>
                '(${formatNumber(m.x, precision: 3)}, ${formatNumber(m.y, precision: 3)})',
          )
          .join('; '),
    );
  } else {
    setAttrValue(valExtremaMin, 'None found');
  }

  if (symbolicMaxima.isNotEmpty) {
    setAttrExprList(valExtremaMax, symbolicMaxima);
  } else if (localMaxima.isNotEmpty) {
    setAttrValue(
      valExtremaMax,
      localMaxima
          .map(
            (m) =>
                '(${formatNumber(m.x, precision: 3)}, ${formatNumber(m.y, precision: 3)})',
          )
          .join('; '),
    );
  } else {
    setAttrValue(valExtremaMax, 'None found');
  }
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
    minY -= range * 0.15;
    maxY += range * 0.15;
  }

  minY = math.max(-100.0, minY);
  maxY = math.min(100.0, maxY);

  return (minY, maxY);
}

String _cached3dKey = '';
Float64List _cached3dZ = Float64List(0);
double _cached3dMinZ = -1.0;
double _cached3dMaxZ = 1.0;
String _cached3dXVar = 'x';
String _cached3dYVar = 'y';

void _renderMultivariable3dSurface(Expr expr) {
  final free = expr.freeVariables.toList()..sort();
  final xVar = (free.contains('x') && free.contains('y')) ? 'x' : free[0];
  final yVar = (free.contains('x') && free.contains('y')) ? 'y' : free[1];
  const gridSize = 64;
  final key = '${expr.toString()}|$minX|$maxX|$xVar|$yVar';

  if (_cached3dKey != key) {
    _cached3dKey = key;
    _cached3dXVar = xVar;
    _cached3dYVar = yVar;
    final vecFn = expr.toVectorFunction([xVar, yVar]);
    final zVals = Float64List(gridSize * gridSize);
    final finite = <double>[];
    final vecView = Vector<double>.filled(2, 0.0, type: DataType.float64);
    for (var iy = 0; iy < gridSize; iy++) {
      final v = iy / (gridSize - 1);
      vecView.setUnchecked(1, minX + v * (maxX - minX));
      for (var ix = 0; ix < gridSize; ix++) {
        final u = ix / (gridSize - 1);
        vecView.setUnchecked(0, minX + u * (maxX - minX));
        double z;
        try {
          z = vecFn(vecView);
        } catch (_) {
          z = double.nan;
        }
        zVals[iy * gridSize + ix] = z;
        if (z.isFinite) finite.add(z);
      }
    }
    _cached3dZ = zVals;
    if (finite.isEmpty) {
      _cached3dMinZ = -1.0;
      _cached3dMaxZ = 1.0;
    } else {
      finite.sort();
      final lo = finite[(finite.length * 0.02).floor()];
      final hi = finite[(finite.length * 0.98).floor()];
      final span = (hi - lo).abs() < 1e-6 ? 1.0 : (hi - lo);
      _cached3dMinZ = lo - span * 0.08;
      _cached3dMaxZ = hi + span * 0.08;
    }
  }

  chartController.enabled = false;
  final surfaceRenderer = WebGLSurfaceRenderer.forCanvas(
    plotCanvas,
    onUpdate: drawCharts,
  );
  surfaceRenderer.renderSurface(
    gridSize: gridSize,
    zValues: _cached3dZ,
    minX: minX,
    maxX: maxX,
    minY: minX,
    maxY: maxX,
    minZ: _cached3dMinZ,
    maxZ: _cached3dMaxZ,
    xVar: _cached3dXVar,
    yVar: _cached3dYVar,
    title: 'z = ${expr.toString()}',
  );
}

void drawCharts() {
  if (parsedExpr != null && parsedExpr!.freeVariables.length == 2) {
    _renderMultivariable3dSurface(parsedExpr!);
    return;
  }
  WebGLSurfaceRenderer.setActive(plotCanvas, false);
  chartController.enabled = true;

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

  if (!chartController.hasUserPannedOrZoomed) {
    final (autoMinY, autoMaxY) = estimateYBounds(realFn, imagFn);
    chartController.setBounds(
      minX: minX,
      maxX: maxX,
      minY: autoMinY,
      maxY: autoMaxY,
      asDefault: true,
    );
  }

  final vp = chartController.viewport(width, height);

  // 1. Grid & Axes
  drawGrid(ctx, vp);

  // 2. Shaded Integral Area
  if (showIntegral) {
    final plotA = _boundToPlotCoordinate(_parsePointExpr(intAStr));
    final plotB = _boundToPlotCoordinate(_parsePointExpr(intBStr));
    if (plotA != null && plotB != null) {
      drawShadedInterval(
        ctx,
        vp,
        realFn,
        plotA,
        plotB,
        fillColor: 'rgba(16, 185, 129, 0.20)',
        strokeColor: '#10b981',
      );
    }
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

  // 4. First Derivative f'(x)
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

  // 5. Second Derivative f''(x)
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

  // 5b. Third Derivative f'''(x)
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

  // 7. Tangent Line & Reference Line at x0
  final ptX = _currentPointPlotX();
  if (ptX != null && showTangent && realDf != null) {
    final y0 = safeGet(() => realFn(ptX))?.toDouble();
    final slope = safeGet(() => realDf(ptX))?.toDouble();
    if (y0 != null && slope != null && y0.isFinite && slope.isFinite) {
      double tangentLine(double x) => slope * (x - ptX) + y0;
      drawCurve(
        ctx,
        vp,
        tangentLine,
        strokeColor: 'rgba(255, 255, 255, 0.65)',
        lineWidth: 1.2,
      );
      drawPointMarker(
        ctx,
        vp,
        ptX,
        y0,
        color: '#f8fafc',
        radius: 3.5,
        label: 'x0',
      );
    }
  }

  // 8. Roots Markers
  if (showRoots) {
    for (final r in plotRoots) {
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
        minPt.x,
        minPt.y,
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
        maxPt.x,
        maxPt.y,
        color: '#f59e0b',
        radius: 4.5,
        label: 'max',
      );
    }
  }

  // 9. Reference line for x0
  if (ptX != null) {
    drawReferenceLine(
      ctx,
      vp,
      ptX,
      color: 'rgba(248, 250, 252, 0.4)',
      label: 'x₀ = $pointXStr',
    );
  }

  // 10. Mouse Hover Crosshair & Tooltip
  final mx = chartController.hoverPixelX;
  final my = chartController.hoverPixelY;
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
    if (currentDomain != VariableDomain.unknown)
      'domain=${_domainToString(currentDomain)}',
    'minx=$minX',
    'maxx=$maxX',
    'x0=${Uri.encodeComponent(pointXStr)}',
    'a=${Uri.encodeComponent(intAStr)}',
    'b=${Uri.encodeComponent(intBStr)}',
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
          case 'domain':
            currentDomain = _parseDomain(val);
            selectDomain.value = _domainToString(currentDomain);
          case 'minx':
            final parsed = double.tryParse(val);
            if (parsed != null) minX = parsed;
          case 'maxx':
            final parsed = double.tryParse(val);
            if (parsed != null) maxX = parsed;
          case 'x0':
            pointXStr = val;
          case 'a':
            intAStr = val;
          case 'b':
            intBStr = val;
        }
      }
    }
  } else {
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
    displayDesc.textContent =
        'Interactive symbolic algebra and calculus exploration.';
    highlightActiveSidebarItem(null);
  }

  rangeMinX.value = minX.toString();
  rangeMaxX.value = maxX.toString();
  inputPointX.value = pointXStr;
  inputIntA.value = intAStr;
  inputIntB.value = intBStr;
  chartController.setBounds(
    minX: minX,
    maxX: maxX,
    asDefault: true,
    clearUserInteraction: true,
  );

  updateAll();
}

Expr _sliceFor1DPlot(Expr expr) {
  final freeVars = expr.freeVariables;
  if (freeVars.length <= 1) return expr;
  var sub = expr;
  for (final v in freeVars) {
    if (v != 'x') {
      sub = sub.substitute(v, IntegerNumber.one);
    }
  }
  return sub;
}
