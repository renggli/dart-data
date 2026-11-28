import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/linear.dart';
import 'package:data/stats.dart';
import 'package:data/type.dart';
import 'package:web/web.dart' as web;

import '../shared/graph/model/axis.dart';
import '../shared/graph/model/dataset_2d.dart';
import '../shared/graph/model/dataset_3d.dart';
import '../shared/graph/model/style.dart';
import '../shared/graph/sampling/sampler_2d.dart';
import '../shared/graph/sampling/sampler_3d.dart';
import '../shared/graph/ui/graph_widget.dart';
import '../shared/utils.dart';
import 'config.dart';

// Current states
DistributionConfig? activeDef;
Distribution<num>? activeDist;
MultivariateDistributionConfig? activeMvDef;
MultivariateDistribution<num>? activeMvDist;
bool mvView3d = false;

List<double> currentParamValues = [];
final List<num> generatedSamples = [];
final List<Vector<num>> generatedMvSamples = [];
final List<void Function()> _paramSyncCallbacks = [];
bool isAppInitialized = false;

bool get isMultivariateActive => activeMvDef != null;

// Interactive graph widget
GraphWidget? distGraph;

// DOM references
late web.HTMLElement continuousGroup;
late web.HTMLElement discreteGroup;
late web.HTMLElement multivariateGroup;
late web.HTMLElement distTitle;
late web.HTMLElement distTypeBadge;
late web.HTMLElement distDescription;
late web.HTMLElement configInputsContainer;

late web.HTMLElement univariatePropsPanel;
late web.HTMLElement multivariatePropsPanel;
late web.HTMLElement univariateEvalPanel;
late web.HTMLElement multivariateEvalPanel;
late web.HTMLElement mvViewControls;
late web.HTMLButtonElement btnView2d;
late web.HTMLButtonElement btnView3d;
late web.HTMLElement chartTitleText;
late web.HTMLElement evalCardTitle;

late web.HTMLElement valMean;
late web.HTMLElement valMedian;
late web.HTMLElement valMode;
late web.HTMLElement valVariance;
late web.HTMLElement valStdDev;
late web.HTMLElement valSkewness;
late web.HTMLElement valKurtosis;
late web.HTMLElement valBounds;

late web.HTMLElement valMvDims;
late web.HTMLElement valMvCorr;
late web.HTMLElement valMvMean;
late web.HTMLElement valMvCov;
late web.HTMLElement lblMvSummary;
late web.HTMLElement valMvSummary;
late web.HTMLElement valMvSupport;

late web.HTMLElement distGraphHost;

late web.HTMLButtonElement btnSample1;
late web.HTMLButtonElement btnSample10;
late web.HTMLButtonElement btnSample100;
late web.HTMLButtonElement btnSample1000;
late web.HTMLButtonElement btnSampleClear;

late web.HTMLElement sampleCountBadge;
late web.HTMLElement samplesText;

late web.HTMLElement lblEMean;
late web.HTMLElement lblEStdDev;
late web.HTMLElement lblEVariance;
late web.HTMLElement eMean;
late web.HTMLElement eVariance;
late web.HTMLElement eStdDev;

// Quantile & Probability interactive calculator (univariate)
late web.HTMLInputElement calcPSlider;
late web.HTMLInputElement calcPInput;
late web.HTMLElement valQuantile;
late web.HTMLElement valUpperQuantile;
late web.HTMLElement valCdfEval;
late web.HTMLElement valSurvivalEval;
late web.HTMLElement valPdfEval;
late web.HTMLElement valLogPdfEval;
late web.HTMLElement valHazardEval;
late web.HTMLElement valOddsEval;
double currentEvalP = 0.50;

// Point Probability interactive evaluator (multivariate)
late web.HTMLElement lblMvX1;
late web.HTMLInputElement mvEvalX1Slider;
late web.HTMLInputElement mvEvalX1Input;
late web.HTMLElement lblMvX2;
late web.HTMLInputElement mvEvalX2Slider;
late web.HTMLInputElement mvEvalX2Input;
late web.HTMLElement valMvPoint;
late web.HTMLElement lblMvPdf;
late web.HTMLElement valMvPdf;
late web.HTMLElement lblMvLogPdf;
late web.HTMLElement valMvLogPdf;
late web.HTMLElement lblMvExtra;
late web.HTMLElement valMvExtra;
double mvEvalX1 = 0.0;
double mvEvalX2 = 0.0;

/// Prettily formats statistical results.
String formatVal(num value) => formatNumber(value);

/// Initialize application and attach listeners.
void main() {
  continuousGroup =
      web.document.querySelector('#continuous-group') as web.HTMLElement;
  discreteGroup =
      web.document.querySelector('#discrete-group') as web.HTMLElement;
  multivariateGroup =
      web.document.querySelector('#multivariate-group') as web.HTMLElement;
  distTitle = web.document.querySelector('#dist-title') as web.HTMLElement;
  distTypeBadge =
      web.document.querySelector('#dist-type-badge') as web.HTMLElement;
  distDescription =
      web.document.querySelector('#dist-description') as web.HTMLElement;
  configInputsContainer =
      web.document.querySelector('#config-inputs-container') as web.HTMLElement;

  univariatePropsPanel =
      web.document.querySelector('#univariate-props') as web.HTMLElement;
  multivariatePropsPanel =
      web.document.querySelector('#multivariate-props') as web.HTMLElement;
  univariateEvalPanel =
      web.document.querySelector('#univariate-eval-panel') as web.HTMLElement;
  multivariateEvalPanel =
      web.document.querySelector('#multivariate-eval-panel') as web.HTMLElement;
  mvViewControls =
      web.document.querySelector('#mv-view-controls') as web.HTMLElement;
  btnView2d =
      web.document.querySelector('#btn-view-2d') as web.HTMLButtonElement;
  btnView3d =
      web.document.querySelector('#btn-view-3d') as web.HTMLButtonElement;
  chartTitleText =
      web.document.querySelector('#chart-title-text') as web.HTMLElement;
  evalCardTitle =
      web.document.querySelector('#eval-card-title') as web.HTMLElement;

  valMean = web.document.querySelector('#val-mean') as web.HTMLElement;
  valMedian = web.document.querySelector('#val-median') as web.HTMLElement;
  valMode = web.document.querySelector('#val-mode') as web.HTMLElement;
  valVariance = web.document.querySelector('#val-variance') as web.HTMLElement;
  valStdDev = web.document.querySelector('#val-stddev') as web.HTMLElement;
  valSkewness = web.document.querySelector('#val-skewness') as web.HTMLElement;
  valKurtosis = web.document.querySelector('#val-kurtosis') as web.HTMLElement;
  valBounds = web.document.querySelector('#val-bounds') as web.HTMLElement;

  valMvDims = web.document.querySelector('#val-mv-dims') as web.HTMLElement;
  valMvCorr = web.document.querySelector('#val-mv-corr') as web.HTMLElement;
  valMvMean = web.document.querySelector('#val-mv-mean') as web.HTMLElement;
  valMvCov = web.document.querySelector('#val-mv-cov') as web.HTMLElement;
  lblMvSummary =
      web.document.querySelector('#lbl-mv-summary') as web.HTMLElement;
  valMvSummary =
      web.document.querySelector('#val-mv-summary') as web.HTMLElement;
  valMvSupport =
      web.document.querySelector('#val-mv-support') as web.HTMLElement;

  distGraphHost = web.document.querySelector('#dist-graph') as web.HTMLElement;

  btnSample1 =
      web.document.querySelector('#btn-sample-1') as web.HTMLButtonElement;
  btnSample10 =
      web.document.querySelector('#btn-sample-10') as web.HTMLButtonElement;
  btnSample100 =
      web.document.querySelector('#btn-sample-100') as web.HTMLButtonElement;
  btnSample1000 =
      web.document.querySelector('#btn-sample-1000') as web.HTMLButtonElement;
  btnSampleClear =
      web.document.querySelector('#btn-sample-clear') as web.HTMLButtonElement;
  sampleCountBadge =
      web.document.querySelector('#sample-count-badge') as web.HTMLElement;
  samplesText = web.document.querySelector('#samples-text') as web.HTMLElement;

  lblEMean = web.document.querySelector('#lbl-e-mean') as web.HTMLElement;
  lblEStdDev = web.document.querySelector('#lbl-e-stddev') as web.HTMLElement;
  lblEVariance =
      web.document.querySelector('#lbl-e-variance') as web.HTMLElement;
  eMean = web.document.querySelector('#e-mean') as web.HTMLElement;
  eVariance = web.document.querySelector('#e-variance') as web.HTMLElement;
  eStdDev = web.document.querySelector('#e-stddev') as web.HTMLElement;

  calcPSlider =
      web.document.querySelector('#calc-p-slider') as web.HTMLInputElement;
  calcPInput =
      web.document.querySelector('#calc-p-input') as web.HTMLInputElement;
  valQuantile = web.document.querySelector('#val-quantile') as web.HTMLElement;
  valUpperQuantile =
      web.document.querySelector('#val-upper-quantile') as web.HTMLElement;
  valCdfEval = web.document.querySelector('#val-cdf-eval') as web.HTMLElement;
  valSurvivalEval =
      web.document.querySelector('#val-survival-eval') as web.HTMLElement;
  valPdfEval = web.document.querySelector('#val-pdf-eval') as web.HTMLElement;
  valLogPdfEval =
      web.document.querySelector('#val-log-pdf-eval') as web.HTMLElement;
  valHazardEval =
      web.document.querySelector('#val-hazard-eval') as web.HTMLElement;
  valOddsEval = web.document.querySelector('#val-odds-eval') as web.HTMLElement;

  lblMvX1 = web.document.querySelector('#lbl-mv-x1') as web.HTMLElement;
  mvEvalX1Slider =
      web.document.querySelector('#mv-eval-x1-slider') as web.HTMLInputElement;
  mvEvalX1Input =
      web.document.querySelector('#mv-eval-x1-input') as web.HTMLInputElement;
  lblMvX2 = web.document.querySelector('#lbl-mv-x2') as web.HTMLElement;
  mvEvalX2Slider =
      web.document.querySelector('#mv-eval-x2-slider') as web.HTMLInputElement;
  mvEvalX2Input =
      web.document.querySelector('#mv-eval-x2-input') as web.HTMLInputElement;
  valMvPoint = web.document.querySelector('#val-mv-point') as web.HTMLElement;
  lblMvPdf = web.document.querySelector('#lbl-mv-pdf') as web.HTMLElement;
  valMvPdf = web.document.querySelector('#val-mv-pdf') as web.HTMLElement;
  lblMvLogPdf =
      web.document.querySelector('#lbl-mv-log-pdf') as web.HTMLElement;
  valMvLogPdf =
      web.document.querySelector('#val-mv-log-pdf') as web.HTMLElement;
  lblMvExtra = web.document.querySelector('#lbl-mv-extra') as web.HTMLElement;
  valMvExtra = web.document.querySelector('#val-mv-extra') as web.HTMLElement;

  void updateEvalP(double p) {
    currentEvalP = p.clamp(0.0, 1.0);
    calcPSlider.value = currentEvalP.toString();
    calcPInput.value = currentEvalP.toStringAsFixed(2);
    updateQuantileCalculator();
    if (!isMultivariateActive) {
      drawCharts();
    }
  }

  calcPSlider.onInput.listen((_) {
    final val = double.tryParse(calcPSlider.value) ?? 0.50;
    updateEvalP(val);
  });

  calcPInput.onInput.listen((_) {
    final val = double.tryParse(calcPInput.value) ?? 0.50;
    updateEvalP(val);
  });

  void setMvViewMode(bool use3d) {
    if (mvView3d == use3d) return;
    mvView3d = use3d;
    btnView2d.setAttribute('aria-pressed', (!use3d).toString());
    btnView3d.setAttribute('aria-pressed', use3d.toString());
    if (isMultivariateActive) {
      drawMultivariateChart();
    }
  }

  btnView2d.onClick.listen((_) => setMvViewMode(false));
  btnView3d.onClick.listen((_) => setMvViewMode(true));

  mvEvalX1Slider.onInput.listen((_) {
    mvEvalX1 = double.tryParse(mvEvalX1Slider.value) ?? mvEvalX1;
    _syncMvPointInputs(changedAxis: 1);
    updateMultivariatePointEvaluator();
    if (!mvView3d) drawMultivariateChart();
  });
  mvEvalX1Input.onInput.listen((_) {
    final parsed = double.tryParse(mvEvalX1Input.value);
    if (parsed != null && parsed.isFinite) {
      mvEvalX1 = parsed;
      _syncMvPointInputs(changedAxis: 1);
      updateMultivariatePointEvaluator();
      if (!mvView3d) drawMultivariateChart();
    }
  });
  mvEvalX2Slider.onInput.listen((_) {
    mvEvalX2 = double.tryParse(mvEvalX2Slider.value) ?? mvEvalX2;
    _syncMvPointInputs(changedAxis: 2);
    updateMultivariatePointEvaluator();
    if (!mvView3d) drawMultivariateChart();
  });
  mvEvalX2Input.onInput.listen((_) {
    final parsed = double.tryParse(mvEvalX2Input.value);
    if (parsed != null && parsed.isFinite) {
      mvEvalX2 = parsed;
      _syncMvPointInputs(changedAxis: 2);
      updateMultivariatePointEvaluator();
      if (!mvView3d) drawMultivariateChart();
    }
  });

  // Initialize universal copy handler
  initGlobalCopyHandler();

  // Render Sidebar & Setup Collapse Toggle
  buildSidebar();
  setupSidebarToggle(
    onToggled: (_) {
      distGraph?.resize();
    },
  );

  // Random Sampler Button bindings
  btnSample1.onClick.listen((_) => drawSamples(1));
  btnSample10.onClick.listen((_) => drawSamples(10));
  btnSample100.onClick.listen((_) => drawSamples(100));
  btnSample1000.onClick.listen((_) => drawSamples(1000));
  btnSampleClear.onClick.listen((_) => clearSamples());

  // Listen to Window resizing for responsive graphics redraw
  web.window.addEventListener(
    'resize',
    (web.Event event) {
      drawCharts();
    }.toJS,
  );

  // Listen to hashchange events for browser history navigation
  web.window.addEventListener(
    'hashchange',
    (web.Event event) {
      loadFromUrlHash();
    }.toJS,
  );

  // Load saved distribution from URL hash if available at startup, otherwise default to Normal
  loadFromUrlHash();
}

/// Render items inside the sidebar.
void buildSidebar() {
  continuousGroup.innerHTML = ''.toJS;
  discreteGroup.innerHTML = ''.toJS;
  multivariateGroup.innerHTML = ''.toJS;

  for (final def in distributions) {
    final item = web.document.createElement('div') as web.HTMLElement;
    item.className = 'sidebar-item';
    item.setAttribute('data-id', def.id);

    final nameSpan = web.document.createElement('span') as web.HTMLElement;
    nameSpan.textContent = def.name;
    item.appendChild(nameSpan);

    final typeSpan = web.document.createElement('span') as web.HTMLElement;
    typeSpan.className =
        'badge ${def.isContinuous ? 'badge-continuous' : 'badge-discrete'}';
    typeSpan.textContent = def.isContinuous ? 'Cont' : 'Disc';
    item.appendChild(typeSpan);

    item.onClick.listen((_) => selectDistribution(def));

    if (def.isContinuous) {
      continuousGroup.appendChild(item);
    } else {
      discreteGroup.appendChild(item);
    }
  }

  for (final def in multivariateDistributions) {
    final item = web.document.createElement('div') as web.HTMLElement;
    item.className = 'sidebar-item';
    item.setAttribute('data-id', def.id);

    final nameSpan = web.document.createElement('span') as web.HTMLElement;
    nameSpan.textContent = def.name;
    item.appendChild(nameSpan);

    final typeSpan = web.document.createElement('span') as web.HTMLElement;
    typeSpan.className = 'badge badge-multivariate';
    typeSpan.textContent = 'Multi';
    item.appendChild(typeSpan);

    item.onClick.listen((_) => selectMultivariateDistribution(def));
    multivariateGroup.appendChild(item);
  }
}

void _highlightSidebarItem(String id) {
  final items = web.document.querySelectorAll('.sidebar-item');
  for (var i = 0; i < items.length; i++) {
    final item = items.item(i) as web.HTMLElement;
    if (item.getAttribute('data-id') == id) {
      item.classList.add('active');
    } else {
      item.classList.remove('active');
    }
  }
}

void _setModeUi({required bool multivariate}) {
  setHidden(univariatePropsPanel, multivariate);
  setHidden(multivariatePropsPanel, !multivariate);
  setHidden(univariateEvalPanel, multivariate);
  setHidden(multivariateEvalPanel, !multivariate);
  setHidden(mvViewControls, !multivariate);

  if (multivariate) {
    final isCont = activeMvDef?.isContinuous ?? true;
    chartTitleText.textContent = isCont
        ? 'Joint Probability Density'
        : 'Joint Probability Mass';
    evalCardTitle.textContent = 'Point Probability';
    lblEMean.textContent = 'Sample Mean (x̄)';
    lblEStdDev.textContent = 'Sample Std Dev (s)';
    lblEVariance.textContent = 'Sample Covariance (S)';
  } else {
    chartTitleText.textContent =
        'Probability Density & Cumulative Distribution';
    evalCardTitle.textContent = 'Quantile & Probability';
    lblEMean.textContent = 'Sample Mean';
    lblEStdDev.textContent = 'Sample Std Dev';
    lblEVariance.textContent = 'Sample Variance';
  }
}

/// Change active univariate distribution.
void selectDistribution(
  DistributionConfig def, {
  Map<String, double>? parameterOverrides,
}) {
  activeMvDef = null;
  activeMvDist = null;
  activeDef = def;

  _highlightSidebarItem(def.id);

  distTitle.textContent = def.name;
  distDescription.textContent = def.description;
  distTypeBadge.textContent = def.isContinuous ? 'Continuous' : 'Discrete';
  distTypeBadge.className =
      'badge ${def.isContinuous ? 'badge-continuous' : 'badge-discrete'}';
  _setModeUi(multivariate: false);

  currentParamValues = _resolveInitialParams(
    def.parameters,
    parameterOverrides,
  );

  clearSamples(redraw: false);
  rebuildConfigInputs(def.parameters);
  recreateDistribution();
  isAppInitialized = true;
}

/// Change active multivariate distribution.
void selectMultivariateDistribution(
  MultivariateDistributionConfig def, {
  Map<String, double>? parameterOverrides,
}) {
  activeDef = null;
  activeDist = null;
  activeMvDef = def;

  _highlightSidebarItem(def.id);

  distTitle.textContent = def.name;
  distDescription.textContent = def.description;
  distTypeBadge.textContent = def.isContinuous
      ? 'Multivariate · Continuous'
      : 'Multivariate · Discrete';
  distTypeBadge.className = 'badge badge-multivariate';
  _setModeUi(multivariate: true);

  currentParamValues = _resolveInitialParams(
    def.parameters,
    parameterOverrides,
  );
  syncMultivariateParameters(def, currentParamValues);

  _configureMvPointControls(def, resetPoint: true);
  clearSamples(redraw: false);
  rebuildConfigInputs(def.parameters);
  recreateDistribution();
  isAppInitialized = true;
}

List<double> _resolveInitialParams(
  List<ParameterConfig> parameters,
  Map<String, double>? overrides,
) {
  final values = <double>[];
  for (final p in parameters) {
    if (overrides != null && overrides.containsKey(p.name)) {
      var val = overrides[p.name]!;
      if (!val.isFinite) {
        val = p.defaultValue;
      } else {
        val = val.clamp(p.min, p.max);
        if (p.isInt) val = val.roundToDouble();
      }
      values.add(val);
    } else {
      values.add(p.defaultValue);
    }
  }
  return values;
}

/// Rebuild configuration slider and text nodes inside panel.
void rebuildConfigInputs(List<ParameterConfig> parameters) {
  configInputsContainer.innerHTML = ''.toJS;
  _paramSyncCallbacks.clear();

  if (parameters.isEmpty) {
    final emptyMsg = web.document.createElement('div') as web.HTMLElement;
    emptyMsg.style.color = 'var(--text-muted)';
    emptyMsg.style.fontSize = '13px';
    emptyMsg.style.fontStyle = 'italic';
    emptyMsg.textContent = 'This distribution does not require any parameters.';
    configInputsContainer.appendChild(emptyMsg);
    return;
  }

  for (var i = 0; i < parameters.length; i++) {
    final param = parameters[i];
    final index = i;
    final sliderId = 'param-slider-${param.name}-$index';

    final group = web.document.createElement('div') as web.HTMLElement;
    group.className = 'parameter-input-group';

    final labelRow = web.document.createElement('div') as web.HTMLElement;
    labelRow.className = 'parameter-label-row';

    final labelContainer = web.document.createElement('div') as web.HTMLElement;
    labelContainer.style.display = 'flex';
    labelContainer.style.alignItems = 'center';
    labelContainer.style.gap = '6px';

    final nameLabel =
        web.document.createElement('label') as web.HTMLLabelElement;
    nameLabel.className = 'parameter-name';
    nameLabel.htmlFor = sliderId;
    nameLabel.textContent = param.label;

    final copyBtn = createCopyButton(title: 'Copy ${param.label}');
    void updateCopyData() {
      final val = currentParamValues[index];
      copyBtn.setAttribute(
        'data-copy',
        param.isInt ? val.toInt().toString() : val.toString(),
      );
    }

    updateCopyData();

    labelContainer.appendChild(nameLabel);
    labelContainer.appendChild(copyBtn);
    labelRow.appendChild(labelContainer);

    group.appendChild(labelRow);

    final controlsRow = web.document.createElement('div') as web.HTMLElement;
    controlsRow.className = 'parameter-control-row';

    final slider = web.document.createElement('input') as web.HTMLInputElement;
    slider.type = 'range';
    slider.id = sliderId;
    slider.className = 'custom-slider';
    slider.min = param.min.toString();
    slider.max = param.max.toString();
    slider.step = param.step.toString();
    slider.value = currentParamValues[index].toString();
    controlsRow.appendChild(slider);

    final numInput =
        web.document.createElement('input') as web.HTMLInputElement;
    numInput.type = 'number';
    numInput.className = 'custom-number-input';
    numInput.setAttribute('aria-label', param.label);
    numInput.min = param.min.toString();
    numInput.max = param.max.toString();
    numInput.step = param.step.toString();
    numInput.value = currentParamValues[index].toString();
    controlsRow.appendChild(numInput);

    _paramSyncCallbacks.add(() {
      final val = currentParamValues[index];
      slider.value = val.toString();
      numInput.value = val.toString();
      updateCopyData();
    });

    group.appendChild(controlsRow);
    configInputsContainer.appendChild(group);

    void updateVal(double newVal) {
      var validatedVal = newVal;
      if (validatedVal < param.min) validatedVal = param.min;
      if (validatedVal > param.max) validatedVal = param.max;
      if (param.isInt) {
        validatedVal = validatedVal.roundToDouble();
      }

      currentParamValues[index] = validatedVal;
      updateCopyData();
      slider.value = validatedVal.toString();
      numInput.value = validatedVal.toString();
      recreateDistribution(changedParamIndex: index);
    }

    slider.onInput.listen((_) {
      final val = double.tryParse(slider.value) ?? param.defaultValue;
      updateVal(val);
    });

    numInput.onInput.listen((_) {
      final val = double.tryParse(numInput.value) ?? param.defaultValue;
      updateVal(val);
    });
  }
}

/// Serializes the current active distribution and parameters into the URL hash.
void updateUrlHash() {
  final String id;
  final List<ParameterConfig> params;
  if (isMultivariateActive) {
    id = activeMvDef!.id;
    params = activeMvDef!.parameters;
  } else {
    id = activeDef!.id;
    params = activeDef!.parameters;
  }

  final queryParams = <String>[];
  for (var i = 0; i < params.length; i++) {
    final param = params[i];
    final val = currentParamValues[i];
    queryParams.add(
      '${Uri.encodeComponent(param.name)}=${Uri.encodeComponent(val.toString())}',
    );
  }
  final queryString = queryParams.isEmpty ? '' : '?${queryParams.join('&')}';
  web.window.history.replaceState(
    null,
    '',
    '#${Uri.encodeComponent(id)}$queryString',
  );
}

/// Parses the URL hash and loads the saved distribution and parameters safely.
void loadFromUrlHash() {
  DistributionConfig? targetDef;
  MultivariateDistributionConfig? targetMvDef;
  Map<String, double>? targetOverrides;

  var hash = web.window.location.hash;
  if (hash.startsWith('#')) {
    hash = hash.substring(1);
  }

  if (hash.isNotEmpty) {
    final parts = hash.split('?');
    final distId = Uri.decodeComponent(parts[0].trim());

    targetDef = distributions.where((d) => d.id == distId).firstOrNull;
    if (targetDef == null) {
      targetMvDef = multivariateDistributions
          .where((d) => d.id == distId)
          .firstOrNull;
    }

    if (parts.length > 1) {
      final queryString = parts[1];
      final pairs = queryString.split('&');
      final overrides = <String, double>{};
      for (final pair in pairs) {
        final kv = pair.split('=');
        if (kv.length == 2) {
          final name = Uri.decodeComponent(kv[0]);
          final val = double.tryParse(Uri.decodeComponent(kv[1]));
          if (val != null) {
            overrides[name] = val;
          }
        }
      }
      if (overrides.isNotEmpty) {
        targetOverrides = overrides;
      }
    }
  }

  if (targetMvDef != null) {
    if (!isAppInitialized ||
        activeMvDef?.id != targetMvDef.id ||
        _paramsDiffer(targetMvDef.parameters, targetOverrides)) {
      selectMultivariateDistribution(
        targetMvDef,
        parameterOverrides: targetOverrides,
      );
    }
    return;
  }

  final defToLoad =
      targetDef ?? distributions.firstWhere((d) => d.isContinuous);

  if (!isAppInitialized ||
      activeDef?.id != defToLoad.id ||
      _paramsDiffer(defToLoad.parameters, targetOverrides)) {
    selectDistribution(defToLoad, parameterOverrides: targetOverrides);
  }
}

bool _paramsDiffer(
  List<ParameterConfig> params,
  Map<String, double>? overrides,
) {
  if (currentParamValues.length != params.length) return true;
  for (var i = 0; i < params.length; i++) {
    final p = params[i];
    final currentVal = currentParamValues[i];
    var targetVal = overrides?[p.name] ?? p.defaultValue;
    if (!targetVal.isFinite) {
      targetVal = p.defaultValue;
    } else {
      targetVal = targetVal.clamp(p.min, p.max);
      if (p.isInt) targetVal = targetVal.roundToDouble();
    }
    if ((currentVal - targetVal).abs() > 1e-6) {
      return true;
    }
  }
  return false;
}

void _syncCrossParameters({int? changedParamIndex}) {
  if (isMultivariateActive) {
    syncMultivariateParameters(
      activeMvDef!,
      currentParamValues,
      changedIndex: changedParamIndex,
    );
    return;
  }
  if (activeDef!.id == 'uniform_continuous' && currentParamValues.length >= 2) {
    if (currentParamValues[1] < currentParamValues[0] + 0.1) {
      currentParamValues[1] = (currentParamValues[0] + 0.1).clamp(
        activeDef!.parameters[1].min,
        activeDef!.parameters[1].max,
      );
    }
  } else if (activeDef!.id == 'uniform_discrete' &&
      currentParamValues.length >= 2) {
    if (currentParamValues[1] < currentParamValues[0]) {
      currentParamValues[1] = currentParamValues[0].clamp(
        activeDef!.parameters[1].min,
        activeDef!.parameters[1].max,
      );
    }
  } else if (activeDef!.id == 'hypergeometric' &&
      currentParamValues.length >= 3) {
    final pop = currentParamValues[0];
    if (currentParamValues[1] > pop) currentParamValues[1] = pop;
    if (currentParamValues[2] > pop) currentParamValues[2] = pop;
  }
}

/// Recreate the stats distribution using configured inputs.
void recreateDistribution({int? changedParamIndex}) {
  _syncCrossParameters(changedParamIndex: changedParamIndex);
  for (final cb in _paramSyncCallbacks) {
    cb();
  }
  if (isMultivariateActive) {
    activeMvDist = activeMvDef!.creator(currentParamValues);
    _configureMvPointControls(activeMvDef!, resetPoint: false);
    clearSamples(redraw: false);
    updateMultivariateTelemetry();
    updateMultivariatePointEvaluator();
    drawCharts();
    updateEmpiricalStats();
    updateUrlHash();
    return;
  }

  activeDist = activeDef!.creator(currentParamValues);
  clearSamples(redraw: false);
  updateTelemetry();
  updateQuantileCalculator();
  drawCharts();
  updateEmpiricalStats();
  updateUrlHash();
}

/// Update mathematical properties panel for univariate distributions.
void updateTelemetry() {
  final dist = activeDist;
  if (dist == null) return;
  setAttrValue(valMean, formatProperty(() => dist.mean));
  setAttrValue(valMedian, formatProperty(() => dist.median));
  setAttrValue(valMode, formatProperty(() => dist.mode));
  setAttrValue(valVariance, formatProperty(() => dist.variance));
  setAttrValue(valStdDev, formatProperty(() => dist.standardDeviation));
  setAttrValue(valSkewness, formatProperty(() => dist.skewness));
  setAttrValue(valKurtosis, formatProperty(() => dist.excessKurtosis));

  try {
    final buffer = StringBuffer();
    buffer.write(dist.isLowerBoundOpen ? '(' : '[');
    buffer.write(formatNumber(dist.lowerBound));
    buffer.write(', ');
    buffer.write(formatNumber(dist.upperBound));
    buffer.write(dist.isUpperBoundOpen ? ')' : ']');
    setAttrValue(valBounds, buffer.toString());
  } catch (_) {
    setAttrValue(valBounds, '[-]');
  }
}

void updateMultivariateTelemetry() {
  final def = activeMvDef;
  final dist = activeMvDist;
  if (def == null || dist == null) return;
  final mean = dist.mean;
  final cov = dist.covariance;

  setAttrValue(valMvDims, '${dist.dimensions}');
  setAttrValue(valMvSupport, def.supportLabel(currentParamValues));

  final meanParts = [
    for (var i = 0; i < mean.length; i++) formatNumber(mean.getUnchecked(i)),
  ];
  setAttrValue(valMvMean, '[${meanParts.join(', ')}]');

  final var0 = cov.getUnchecked(0, 0);
  final var1 = cov.getUnchecked(1, 1);
  final cov01 = cov.getUnchecked(0, 1);
  final denom = math.sqrt(math.max(0.0, var0 * var1));
  final corr = denom > 0 ? cov01 / denom : 0.0;
  setAttrValue(valMvCorr, formatNumber(corr));

  if (def.id == 'multivariate_normal') {
    lblMvSummary.textContent = 'Determinant |Σ|';
    final det = var0 * var1 - cov01 * cov01;
    setAttrValue(valMvSummary, formatNumber(det));
  } else {
    lblMvSummary.textContent = 'Trace tr(Σ)';
    var trace = 0.0;
    for (var i = 0; i < cov.rowCount; i++) {
      trace += cov.getUnchecked(i, i);
    }
    setAttrValue(valMvSummary, formatNumber(trace));
  }

  _setMatrixAttr(valMvCov, cov);
}

void _setMatrixAttr(web.HTMLElement element, Matrix<double> matrix) {
  final rowsPlain = [
    for (var r = 0; r < matrix.rowCount; r++)
      '[${[for (var c = 0; c < matrix.colCount; c++) formatNumber(matrix.getUnchecked(r, c), precision: 3)].join(', ')}]',
  ];
  final plainText = '[${rowsPlain.join(', ')}]';
  element.title = plainText;
  element.setAttribute('data-copy', plainText);

  final mtableRows = StringBuffer();
  for (var r = 0; r < matrix.rowCount; r++) {
    mtableRows.write('<mtr>');
    for (var c = 0; c < matrix.colCount; c++) {
      mtableRows.write(
        '<mtd><mn>${formatNumber(matrix.getUnchecked(r, c), precision: 3)}</mn></mtd>',
      );
    }
    mtableRows.write('</mtr>');
  }
  element.innerHTML =
      '<math><mrow><mo>[</mo><mtable>$mtableRows</mtable><mo>]</mo></mrow></math>'
          .toJS;
}

/// Evaluates probability density (continuous) or mass (discrete) correctly
/// handling generic type requirements.
double evalDistProbability(num x) {
  if (x == double.negativeInfinity || x == double.infinity) return 0.0;
  if (activeDef!.isContinuous) {
    final val = (activeDist! as Distribution<double>).probability(x.toDouble());
    return val.isNaN ? 0.0 : val;
  } else {
    if (!x.isFinite) return 0.0;
    return (activeDist! as Distribution<int>).probability(x.round());
  }
}

/// Evaluates log-density or log-probability mass using the distribution's
/// native implementation.
double evalDistLogProbability(num x) {
  if (x == double.negativeInfinity || x == double.infinity) {
    return double.negativeInfinity;
  }
  if (activeDef!.isContinuous) {
    return (activeDist! as Distribution<double>).logProbability(x.toDouble());
  } else {
    if (!x.isFinite) return double.negativeInfinity;
    return (activeDist! as Distribution<int>).logProbability(x.round());
  }
}

/// Evaluates cumulative probability distribution (CDF) correctly
/// handling generic type requirements.
double evalDistCumulativeProbability(num x) {
  if (x == double.negativeInfinity) return 0.0;
  if (x == double.infinity) return 1.0;
  if (activeDef!.isContinuous) {
    final val = (activeDist! as Distribution<double>).cumulativeProbability(
      x.toDouble(),
    );
    return val.isNaN ? (x < 0 ? 0.0 : 1.0) : val;
  } else {
    if (!x.isFinite) return x < 0 ? 0.0 : 1.0;
    return (activeDist! as Distribution<int>).cumulativeProbability(x.floor());
  }
}

/// Evaluates survival function correctly handling generic type requirements.
double evalDistSurvival(num x) {
  if (x == double.negativeInfinity) return 1.0;
  if (x == double.infinity) return 0.0;
  if (activeDef!.isContinuous) {
    final val = (activeDist! as Distribution<double>).survival(x.toDouble());
    return val.isNaN ? (x < 0 ? 1.0 : 0.0) : val;
  } else {
    if (!x.isFinite) return x < 0 ? 1.0 : 0.0;
    return (activeDist! as Distribution<int>).survival(x.floor());
  }
}

num? _evalQuantileAt(Distribution<num> dist, double p) {
  if (p <= 0.0 && dist.isLowerBoundOpen) {
    return dist.lowerBound;
  }
  if (p >= 1.0 && dist.isUpperBoundOpen) {
    return dist.upperBound;
  }
  return safeGet(() => dist.inverseCumulativeProbability(p));
}

/// Update quantile and probability evaluation card.
void updateQuantileCalculator() {
  final dist = activeDist;
  if (dist == null) return;
  try {
    num evalUpperQuantileAt(double p) {
      if (p <= 0.0 && dist.isUpperBoundOpen) {
        return dist.upperBound;
      }
      if (p >= 1.0 && dist.isLowerBoundOpen) {
        return dist.lowerBound;
      }
      return dist.inverseSurvival(p);
    }

    final q = _evalQuantileAt(dist, currentEvalP);
    if (q == null) {
      setAttrValue(valQuantile, '-');
      setAttrValue(valCdfEval, '-');
      setAttrValue(valSurvivalEval, '-');
      setAttrValue(valPdfEval, '-');
      setAttrValue(valLogPdfEval, '-');
      setAttrValue(valHazardEval, '-');
    } else {
      setAttrValue(valQuantile, formatNumber(q));

      final cdfAtQ = evalDistCumulativeProbability(q);
      setAttrValue(valCdfEval, formatNumber(cdfAtQ));

      final survAtQ = evalDistSurvival(q);
      setAttrValue(valSurvivalEval, formatNumber(survAtQ));

      final pdfAtQ = evalDistProbability(q);
      setAttrValue(valPdfEval, formatNumber(pdfAtQ));

      final logPdf = evalDistLogProbability(q);
      setAttrValue(valLogPdfEval, formatNumber(logPdf));

      final hazard = survAtQ > 0
          ? pdfAtQ / survAtQ
          : (pdfAtQ > 0 ? double.infinity : double.nan);
      setAttrValue(valHazardEval, hazard.isNaN ? '-' : formatNumber(hazard));
    }

    final upperQ = evalUpperQuantileAt(currentEvalP);
    setAttrValue(valUpperQuantile, formatNumber(upperQ));

    final odds = currentEvalP >= 1.0
        ? double.infinity
        : currentEvalP / (1.0 - currentEvalP);
    setAttrValue(valOddsEval, formatNumber(odds));
  } catch (_) {
    setAttrValue(valQuantile, '-');
    setAttrValue(valUpperQuantile, '-');
    setAttrValue(valCdfEval, '-');
    setAttrValue(valSurvivalEval, '-');
    setAttrValue(valPdfEval, '-');
    setAttrValue(valLogPdfEval, '-');
    setAttrValue(valHazardEval, '-');
    setAttrValue(valOddsEval, '-');
  }
}

void _configureMvPointControls(
  MultivariateDistributionConfig def, {
  required bool resetPoint,
}) {
  if (def.id == 'multivariate_normal') {
    final mu1 = currentParamValues[0];
    final mu2 = currentParamValues[1];
    final s1 = math.max(0.2, currentParamValues[2]);
    final s2 = math.max(0.2, currentParamValues[3]);
    lblMvX1.textContent = 'Coordinate x₁';
    lblMvX2.textContent = 'Coordinate x₂';
    _setRangeConfig(
      mvEvalX1Slider,
      mvEvalX1Input,
      mu1 - 3.5 * s1,
      mu1 + 3.5 * s1,
      0.05,
    );
    _setRangeConfig(
      mvEvalX2Slider,
      mvEvalX2Input,
      mu2 - 3.5 * s2,
      mu2 + 3.5 * s2,
      0.05,
    );
    if (resetPoint) {
      mvEvalX1 = mu1;
      mvEvalX2 = mu2;
    } else {
      mvEvalX1 = mvEvalX1.clamp(mu1 - 3.5 * s1, mu1 + 3.5 * s1);
      mvEvalX2 = mvEvalX2.clamp(mu2 - 3.5 * s2, mu2 + 3.5 * s2);
    }
    lblMvPdf.textContent = 'Density f(x)';
    lblMvLogPdf.textContent = 'Log-Density ln f(x)';
    lblMvExtra.textContent = 'Mahalanobis d';
  } else if (def.id == 'dirichlet') {
    lblMvX1.textContent = 'Proportion x₁ ∈ (0, 1)';
    lblMvX2.textContent = 'Proportion x₂ ∈ (0, 1 − x₁)';
    _setRangeConfig(mvEvalX1Slider, mvEvalX1Input, 0.01, 0.98, 0.01);
    _setRangeConfig(mvEvalX2Slider, mvEvalX2Input, 0.01, 0.98, 0.01);
    if (resetPoint) {
      mvEvalX1 = 0.33;
      mvEvalX2 = 0.33;
    }
    lblMvPdf.textContent = 'Density f(x)';
    lblMvLogPdf.textContent = 'Log-Density ln f(x)';
    lblMvExtra.textContent = 'Total Concentration α₀';
  } else {
    final n = math.max(1, currentParamValues[0].round()).toDouble();
    lblMvX1.textContent = 'Count k₁';
    lblMvX2.textContent = 'Count k₂';
    _setRangeConfig(mvEvalX1Slider, mvEvalX1Input, 0, n, 1);
    _setRangeConfig(mvEvalX2Slider, mvEvalX2Input, 0, n, 1);
    if (resetPoint) {
      mvEvalX1 = (n * currentParamValues[1]).roundToDouble();
      mvEvalX2 = math.min(
        n - mvEvalX1,
        (n * currentParamValues[2]).roundToDouble(),
      );
    }
    lblMvPdf.textContent = 'Probability P(k)';
    lblMvLogPdf.textContent = 'Log-Prob. ln P(k)';
    lblMvExtra.textContent = 'Remainder Prob. p₃';
  }
  _syncMvPointInputs();
}

void _setRangeConfig(
  web.HTMLInputElement slider,
  web.HTMLInputElement input,
  double minVal,
  double maxVal,
  double stepVal,
) {
  final minS = minVal.toStringAsFixed(stepVal >= 1 ? 0 : 2);
  final maxS = maxVal.toStringAsFixed(stepVal >= 1 ? 0 : 2);
  final stepS = stepVal.toString();
  slider
    ..min = minS
    ..max = maxS
    ..step = stepS;
  input
    ..min = minS
    ..max = maxS
    ..step = stepS;
}

void _syncMvPointInputs({int? changedAxis}) {
  final def = activeMvDef;
  if (def == null) return;

  if (def.id == 'dirichlet') {
    mvEvalX1 = mvEvalX1.clamp(0.01, 0.98);
    mvEvalX2 = mvEvalX2.clamp(0.01, 0.98);
    if (mvEvalX1 + mvEvalX2 > 0.99) {
      if (changedAxis == 1) {
        mvEvalX2 = math.max(0.01, 0.99 - mvEvalX1);
      } else {
        mvEvalX1 = math.max(0.01, 0.99 - mvEvalX2);
      }
    }
    mvEvalX1Slider.value = mvEvalX1.toStringAsFixed(2);
    mvEvalX1Input.value = mvEvalX1.toStringAsFixed(2);
    mvEvalX2Slider.value = mvEvalX2.toStringAsFixed(2);
    mvEvalX2Input.value = mvEvalX2.toStringAsFixed(2);
  } else if (def.id == 'multinomial') {
    final n = math.max(1, currentParamValues[0].round());
    var k1 = mvEvalX1.round().clamp(0, n);
    var k2 = mvEvalX2.round().clamp(0, n);
    if (k1 + k2 > n) {
      if (changedAxis == 1) {
        k2 = math.max(0, n - k1);
      } else {
        k1 = math.max(0, n - k2);
      }
    }
    mvEvalX1 = k1.toDouble();
    mvEvalX2 = k2.toDouble();
    mvEvalX1Slider.value = k1.toString();
    mvEvalX1Input.value = k1.toString();
    mvEvalX2Slider.value = k2.toString();
    mvEvalX2Input.value = k2.toString();
  } else {
    mvEvalX1Slider.value = mvEvalX1.toStringAsFixed(2);
    mvEvalX1Input.value = mvEvalX1.toStringAsFixed(2);
    mvEvalX2Slider.value = mvEvalX2.toStringAsFixed(2);
    mvEvalX2Input.value = mvEvalX2.toStringAsFixed(2);
  }
}

void updateMultivariatePointEvaluator() {
  final def = activeMvDef;
  final dist = activeMvDist;
  if (def == null || dist == null) return;

  try {
    if (def.id == 'multivariate_normal') {
      final mvn = dist as MultivariateNormalDistribution;
      final pt = Vector<double>.fromList([
        mvEvalX1,
        mvEvalX2,
      ], type: DataType.float64);
      final pdf = mvn.probability(pt);
      final logPdf = mvn.logProbability(pt);

      // Mahalanobis distance sqrt((x - mu)^T Sigma^-1 (x - mu))
      final mean = mvn.mean;
      final cov = mvn.covariance;
      final d1 = mvEvalX1 - mean.getUnchecked(0);
      final d2 = mvEvalX2 - mean.getUnchecked(1);
      final a = cov.getUnchecked(0, 0);
      final b = cov.getUnchecked(0, 1);
      final d = cov.getUnchecked(1, 1);
      final det = a * d - b * b;
      final mahaSq = det > 0
          ? (d * d1 * d1 - 2 * b * d1 * d2 + a * d2 * d2) / det
          : 0.0;

      setAttrValue(
        valMvPoint,
        '(${formatNumber(mvEvalX1, precision: 2)}, ${formatNumber(mvEvalX2, precision: 2)})',
      );
      setAttrValue(valMvPdf, formatNumber(pdf));
      setAttrValue(valMvLogPdf, formatNumber(logPdf));
      setAttrValue(valMvExtra, formatNumber(math.sqrt(math.max(0.0, mahaSq))));
    } else if (def.id == 'dirichlet') {
      final dir = dist as DirichletDistribution;
      final x3 = math.max(0.0, 1.0 - mvEvalX1 - mvEvalX2);
      final pt = Vector<double>.fromList([
        mvEvalX1,
        mvEvalX2,
        x3,
      ], type: DataType.float64);
      final pdf = dir.probability(pt);
      final logPdf = dir.logProbability(pt);
      final alpha0 =
          currentParamValues[0] + currentParamValues[1] + currentParamValues[2];

      setAttrValue(
        valMvPoint,
        '(${mvEvalX1.toStringAsFixed(2)}, ${mvEvalX2.toStringAsFixed(2)}, ${x3.toStringAsFixed(2)})',
      );
      setAttrValue(valMvPdf, formatNumber(pdf));
      setAttrValue(valMvLogPdf, formatNumber(logPdf));
      setAttrValue(valMvExtra, formatNumber(alpha0));
    } else {
      final mult = dist as MultinomialDistribution;
      final n = mult.trials;
      final k1 = mvEvalX1.round().clamp(0, n);
      final k2 = mvEvalX2.round().clamp(0, n - k1);
      final k3 = n - k1 - k2;
      final pt = Vector<int>.fromList([k1, k2, k3], type: DataType.integer);
      final pmf = mult.probability(pt);
      final logPmf = mult.logProbability(pt);
      final p3 =
          1.0 -
          mult.probabilities.getUnchecked(0) -
          mult.probabilities.getUnchecked(1);

      setAttrValue(valMvPoint, '($k1, $k2, $k3)');
      setAttrValue(valMvPdf, formatNumber(pmf));
      setAttrValue(valMvLogPdf, formatNumber(logPmf));
      setAttrValue(valMvExtra, formatNumber(p3));
    }
  } catch (_) {
    setAttrValue(valMvPoint, '-');
    setAttrValue(valMvPdf, '-');
    setAttrValue(valMvLogPdf, '-');
    setAttrValue(valMvExtra, '-');
  }
}

/// Dynamic bounds estimation for graphing X-axis window.
Map<String, double> getGraphBounds() {
  final def = activeDef!;
  final dist = activeDist!;
  var minX = -5.0;
  var maxX = 5.0;

  final lower = dist.lowerBound;
  final upper = dist.upperBound;

  final lowerFinite =
      (lower is double && lower.isFinite) || (lower is int && lower > -100000);
  final upperFinite =
      (upper is double && upper.isFinite) || (upper is int && upper < 100000);

  var useExplicitBounds = false;
  if (lowerFinite && upperFinite) {
    final range = upper.toDouble() - lower.toDouble();
    if (range > 0 && range <= 250) {
      useExplicitBounds = true;
    }
  }

  if (useExplicitBounds) {
    minX = lower.toDouble();
    maxX = upper.toDouble();
  } else {
    final meanVal = safeGet(() => dist.mean)?.toDouble();
    final stdVal = safeGet(() => dist.standardDeviation)?.toDouble();

    if (meanVal != null &&
        stdVal != null &&
        meanVal.isFinite &&
        stdVal.isFinite &&
        stdVal > 1e-4) {
      minX = meanVal - 4 * stdVal;
      maxX = meanVal + 4 * stdVal;
    } else {
      final medianVal = safeGet(() => dist.median)?.toDouble();
      if (medianVal != null && medianVal.isFinite) {
        minX = medianVal - 6.0;
        maxX = medianVal + 6.0;
      }
    }

    if (lowerFinite) {
      minX = math.max(minX, lower.toDouble());
    }
    if (upperFinite) {
      maxX = math.min(maxX, upper.toDouble());
    }
  }

  final span = maxX - minX;
  final padding = span > 0 ? span * 0.08 : 1.0;
  if (!def.isContinuous) {
    final discretePadding = math.max(1.0, padding);
    minX -= discretePadding;
    maxX += discretePadding;
  } else {
    minX -= padding;
    maxX += padding;
  }

  if (maxX <= minX) {
    maxX = minX + 1.0;
  }
  if ((maxX - minX).abs() < 1e-4) {
    minX -= 1.0;
    maxX += 1.0;
  }

  return {'min': minX, 'max': maxX};
}

/// Renders active distribution visualization (univariate 2D or multivariate 2D/3D).
void drawCharts() {
  if (isMultivariateActive) {
    drawMultivariateChart();
    return;
  }
  final def = activeDef;
  final dist = activeDist;
  if (def == null || dist == null) return;

  final bounds = getGraphBounds();
  final minX = bounds['min']!;
  final maxX = bounds['max']!;

  final refs = <ReferenceLine>[];
  final meanVal = safeGet(() => dist.mean)?.toDouble();
  if (meanVal != null && meanVal.isFinite) {
    refs.add(
      ReferenceLine(
        value: meanVal,
        isVertical: true,
        label: 'Mean μ',
        color: 'rgba(239, 68, 68, 0.85)',
      ),
    );
  }
  final medianVal = safeGet(() => dist.median)?.toDouble();
  if (medianVal != null && medianVal.isFinite) {
    refs.add(
      ReferenceLine(
        value: medianVal,
        isVertical: true,
        label: 'Median',
        color: 'rgba(16, 185, 129, 0.85)',
      ),
    );
  }
  final modeVal = safeGet(() => dist.mode)?.toDouble();
  if (modeVal != null && modeVal.isFinite) {
    refs.add(
      ReferenceLine(
        value: modeVal,
        isVertical: true,
        label: 'Mode',
        color: 'rgba(168, 85, 247, 0.85)',
      ),
    );
  }

  final datasets = <Dataset2D>[];
  if (generatedSamples.isNotEmpty) {
    final n = generatedSamples.length;
    if (def.isContinuous) {
      const binCount = 20;
      final binWidth = (maxX - minX) / binCount;
      final bins = List<int>.filled(binCount, 0);
      for (final s in generatedSamples) {
        if (s >= minX && s <= maxX) {
          final idx = ((s - minX) / binWidth).floor().clamp(0, binCount - 1);
          bins[idx]++;
        }
      }
      datasets.add(
        Function2DDataset(
          id: 'hist',
          label: 'Empirical',
          xs: [for (var b = 0; b < binCount; b++) minX + (b + 0.5) * binWidth],
          ys: [for (var b = 0; b < binCount; b++) bins[b] / (n * binWidth)],
          color: '#a855f7',
          mode: CurveRenderMode.histogram,
        ),
      );
    } else {
      final iMin = minX.floor();
      final iMax = maxX.ceil();
      final freqMap = <int, int>{};
      for (final s in generatedSamples) {
        final val = s.toInt();
        if (val >= iMin && val <= iMax) {
          freqMap[val] = (freqMap[val] ?? 0) + 1;
        }
      }
      final sortedKeys = freqMap.keys.toList()..sort();
      if (sortedKeys.isNotEmpty) {
        datasets.add(
          Function2DDataset(
            id: 'hist',
            label: 'Empirical',
            xs: [for (final k in sortedKeys) k.toDouble()],
            ys: [for (final k in sortedKeys) freqMap[k]! / n],
            color: '#a855f7',
            mode: CurveRenderMode.histogram,
          ),
        );
      }
    }
  }

  if (def.id == 'degenerate_continuous') {
    final k = dist.lowerBound.toDouble();
    datasets.add(
      Function2DDataset(
        id: 'pdf',
        label: 'Impulse',
        xs: [k],
        ys: [1.0],
        color: '#3b82f6',
        mode: CurveRenderMode.stem,
      ),
    );
  } else if (def.isContinuous) {
    datasets.add(
      sampleFunction2D(
        id: 'pdf',
        label: 'PDF',
        fn: dist.probability,
        xMin: minX,
        xMax: maxX,
        color: '#3b82f6',
        fill: const AreaFill(color: '#3b82f6', opacity: 0.20),
      ),
    );
  } else {
    final iMin = minX.floor();
    final iMax = maxX.ceil();
    final span = iMax - iMin;
    final step = span > 500 ? (span / 500).ceil() : 1;
    final ks = <double>[];
    final ps = <double>[];
    for (var k = iMin; k <= iMax; k += step) {
      final p = evalDistProbability(k);
      if (p.isFinite && p >= 0.0) {
        ks.add(k.toDouble());
        ps.add(p);
      }
    }
    datasets.add(
      Function2DDataset(
        id: 'pmf',
        label: 'PMF',
        xs: ks,
        ys: ps,
        color: '#10b981',
        mode: CurveRenderMode.stem,
      ),
    );
  }

  if (def.isContinuous) {
    datasets.add(
      sampleFunction2D(
        id: 'cdf',
        label: 'CDF',
        fn: evalDistCumulativeProbability,
        xMin: minX,
        xMax: maxX,
        color: '#f59e0b',
        yAxis: YAxisSide.right,
      ),
    );
  } else {
    final iMin = minX.floor() - 1;
    final iMax = maxX.ceil() + 1;
    final span = iMax - iMin;
    final step = span > 500 ? (span / 500).ceil() : 1;
    final ks = <double>[];
    final cs = <double>[];
    for (var k = iMin; k <= iMax; k += step) {
      ks.add(k.toDouble());
      cs.add(evalDistCumulativeProbability(k));
    }
    datasets.add(
      Function2DDataset(
        id: 'cdf',
        label: 'CDF',
        xs: ks,
        ys: cs,
        color: '#f59e0b',
        mode: CurveRenderMode.step,
        yAxis: YAxisSide.right,
      ),
    );
  }

  final qVal = _evalQuantileAt(dist, currentEvalP);
  if (qVal != null &&
      qVal.isFinite &&
      qVal != DataType.integer.safeMin &&
      qVal != DataType.integer.safeMax) {
    final qx = qVal.toDouble();
    final cdfAtQ = evalDistCumulativeProbability(qVal);
    if (cdfAtQ.isFinite) {
      datasets.add(
        Function2DDataset(
          id: 'quantile-point',
          label: 'Quantile Q(p)',
          xs: const <double>[],
          ys: const <double>[],
          color: '#22c55e',
          mode: CurveRenderMode.scatter,
          yAxis: YAxisSide.right,
          markers: [
            PointMarker(
              x: qx,
              y: cdfAtQ,
              color: '#22c55e',
              radius: 5.5,
              label: 'Q(p)',
            ),
          ],
          references: [
            ReferenceLine(
              value: qx,
              isVertical: true,
              color: 'rgba(34, 197, 94, 0.70)',
            ),
            ReferenceLine(
              value: cdfAtQ,
              isVertical: false,
              color: 'rgba(34, 197, 94, 0.55)',
              label: 'p = ${formatNumber(currentEvalP, precision: 2)}',
            ),
          ],
        ),
      );
    }
  }

  final scene = Scene2D(
    datasets: datasets,
    xAxis: AxisConfig(min: minX, max: maxX, isInteger: !def.isContinuous),
    yAxis: AxisConfig(label: def.isContinuous ? 'PDF' : 'PMF', min: 0.0),
    y2Axis: const AxisConfig(label: 'CDF', min: 0.0, max: 1.0),
    references: refs,
  );
  _mountScene2D(scene);
}

void drawMultivariateChart() {
  final def = activeMvDef;
  final dist = activeMvDist;
  if (def == null || dist == null) return;

  late final Bounds2D domain;
  late final double Function(double x, double y) evalFn;
  late final String zLabel;
  var xLabel = 'x₁';
  var yLabel = 'x₂';
  var equalAspect = false;
  var gridCols = 88;
  var gridRows = 88;
  var surfNx = 52;
  var surfNy = 52;

  if (def.id == 'multivariate_normal') {
    final mvn = dist as MultivariateNormalDistribution;
    final mu1 = currentParamValues[0];
    final mu2 = currentParamValues[1];
    final s1 = math.max(0.2, currentParamValues[2]);
    final s2 = math.max(0.2, currentParamValues[3]);
    domain = Bounds2D(
      xMin: mu1 - 3.5 * s1,
      xMax: mu1 + 3.5 * s1,
      yMin: mu2 - 3.5 * s2,
      yMax: mu2 + 3.5 * s2,
    );
    evalFn = (x, y) => mvn.probability(
      Vector<double>.fromList([x, y], type: DataType.float64),
    );
    zLabel = 'f(x₁, x₂)';
  } else if (def.id == 'dirichlet') {
    final dir = dist as DirichletDistribution;
    domain = const Bounds2D(xMin: 0.0, xMax: 1.0, yMin: 0.0, yMax: 1.0);
    equalAspect = true;
    evalFn = (x, y) {
      final x3 = 1.0 - x - y;
      if (x < 0.0 || y < 0.0 || x3 < 0.0) return double.nan;
      const eps = 2e-3;
      final sx = math.max(eps, x);
      final sy = math.max(eps, y);
      final sz = math.max(eps, x3);
      final sum = sx + sy + sz;
      final val = dir.probability(
        Vector<double>.fromList([
          sx / sum,
          sy / sum,
          sz / sum,
        ], type: DataType.float64),
      );
      if (!val.isFinite) return 25.0;
      return math.min(val, 25.0);
    };
    zLabel = 'f(x₁, x₂, 1 − x₁ − x₂)';
  } else {
    final mult = dist as MultinomialDistribution;
    final n = mult.trials;
    xLabel = 'k₁';
    yLabel = 'k₂';
    equalAspect = true;
    domain = Bounds2D(xMin: -0.5, xMax: n + 0.5, yMin: -0.5, yMax: n + 0.5);
    final cellsPerUnit = n <= 16 ? 5 : 3;
    gridCols = math.min(120, (n + 1) * cellsPerUnit);
    gridRows = gridCols;
    surfNx = math.min(48, n + 1);
    surfNy = surfNx;
    evalFn = (x, y) {
      final k1 = x.round();
      final k2 = y.round();
      final k3 = n - k1 - k2;
      if (k1 < 0 || k2 < 0 || k3 < 0) return double.nan;
      return mult.probability(
        Vector<int>.fromList([k1, k2, k3], type: DataType.integer),
      );
    };
    zLabel = 'P(k₁, k₂, n − k₁ − k₂)';
  }

  if (mvView3d) {
    final xMin = def.id == 'multinomial' ? 0.0 : domain.xMin;
    final xMax = def.id == 'multinomial'
        ? (dist as MultinomialDistribution).trials.toDouble()
        : domain.xMax;
    final yMin = def.id == 'multinomial' ? 0.0 : domain.yMin;
    final yMax = def.id == 'multinomial'
        ? (dist as MultinomialDistribution).trials.toDouble()
        : domain.yMax;
    final surf = sampleSurface3D(
      id: 'mv3d',
      label: zLabel,
      fn: evalFn,
      xMin: xMin,
      xMax: xMax,
      yMin: yMin,
      yMax: yMax,
      nx: surfNx,
      ny: surfNy,
      colormap: Colormap.viridis,
      wireframe: true,
    );
    _mountScene3D(
      Scene3D(
        datasets: [surf],
        xAxis: AxisConfig(label: xLabel),
        yAxis: AxisConfig(label: yLabel),
        zAxis: AxisConfig(label: zLabel),
      ),
    );
    return;
  }

  final datasets = <Dataset2D>[
    sampleScalarField2D(
      id: 'mv-field',
      label: zLabel,
      fn: evalFn,
      domain: domain,
      cols: gridCols,
      rows: gridRows,
      colormap: Colormap.viridis,
    ),
  ];

  if (def.isSimplex) {
    final maxCoord = def.id == 'multinomial'
        ? (dist as MultinomialDistribution).trials.toDouble()
        : 1.0;
    datasets.add(
      Function2DDataset(
        id: 'simplex',
        label: 'Simplex',
        xs: [0.0, maxCoord, 0.0, 0.0],
        ys: [0.0, 0.0, maxCoord, 0.0],
        color: 'rgba(248, 250, 252, 0.65)',
        width: 1.5,
        dashed: true,
      ),
    );
  }

  if (generatedMvSamples.isNotEmpty) {
    datasets.add(
      Function2DDataset(
        id: 'mv-samples',
        label: 'Samples (${generatedMvSamples.length})',
        xs: [for (final v in generatedMvSamples) v.getUnchecked(0).toDouble()],
        ys: [for (final v in generatedMvSamples) v.getUnchecked(1).toDouble()],
        color: '#f8fafc',
        mode: CurveRenderMode.scatter,
      ),
    );
  }

  final meanVec = dist.mean;
  datasets.addAll([
    Function2DDataset(
      id: 'mv-mean',
      label: 'Mean μ',
      xs: const <double>[],
      ys: const <double>[],
      color: '#ef4444',
      mode: CurveRenderMode.scatter,
      markers: [
        PointMarker(
          x: meanVec.getUnchecked(0),
          y: meanVec.getUnchecked(1),
          color: '#ef4444',
          radius: 5.0,
          label: 'μ',
        ),
      ],
    ),
    Function2DDataset(
      id: 'mv-point',
      label: 'Point x',
      xs: const <double>[],
      ys: const <double>[],
      color: '#22c55e',
      mode: CurveRenderMode.scatter,
      markers: [
        PointMarker(
          x: mvEvalX1,
          y: mvEvalX2,
          color: '#22c55e',
          radius: 5.5,
          label: 'x',
        ),
      ],
    ),
  ]);

  _mountScene2D(
    Scene2D(
      datasets: datasets,
      xAxis: AxisConfig(
        label: xLabel,
        min: domain.xMin,
        max: domain.xMax,
        isInteger: !def.isContinuous,
      ),
      yAxis: AxisConfig(
        label: yLabel,
        min: domain.yMin,
        max: domain.yMax,
        isInteger: !def.isContinuous,
      ),
      equalAspect: equalAspect,
    ),
  );
}

void _mountScene2D(Scene2D scene) {
  if (distGraph == null) {
    distGraph = GraphWidget.view2d(scene, height: 360);
    distGraphHost.appendChild(distGraph!.element);
  } else {
    distGraph!.setScene2D(scene);
  }
}

void _mountScene3D(Scene3D scene) {
  if (distGraph == null) {
    distGraph = GraphWidget.view3d(scene, height: 360);
    distGraphHost.appendChild(distGraph!.element);
  } else {
    distGraph!.setScene3D(scene);
  }
}

// ==================== RANDOM SAMPLING ENGINE ====================

/// Draw N random samples from the active distribution.
void drawSamples(int count) {
  if (isMultivariateActive) {
    final mvDist = activeMvDist;
    if (mvDist == null) return;
    final newSamples = mvDist.samples().take(count).toList();
    generatedMvSamples.addAll(newSamples);
    sampleCountBadge.textContent = generatedMvSamples.length.toString();
    updateSamplesDisplay();
    updateEmpiricalStats();
    drawCharts();
    return;
  }

  final dist = activeDist;
  if (dist == null) return;
  final newSamples = dist
      .samples()
      .where((sample) => sample.isFinite)
      .take(count)
      .toList();
  generatedSamples.addAll(newSamples);
  sampleCountBadge.textContent = generatedSamples.length.toString();
  updateSamplesDisplay();
  updateEmpiricalStats();
  drawCharts();
}

/// Clear active samples context.
void clearSamples({bool redraw = true}) {
  generatedSamples.clear();
  generatedMvSamples.clear();
  sampleCountBadge.textContent = '0';
  setAttrValue(samplesText, '-');

  updateEmpiricalStats();
  if (redraw) {
    drawCharts();
  }
}

/// Update samples field with preview and full clipboard copy data.
void updateSamplesDisplay() {
  if (isMultivariateActive) {
    if (generatedMvSamples.isEmpty) {
      setAttrValue(samplesText, '-');
      return;
    }
    final isCont = activeMvDef!.isContinuous;
    final fullText = generatedMvSamples
        .map((v) {
          final comps = <String>[
            for (var i = 0; i < v.length; i++)
              if (isCont)
                v.getUnchecked(i).toDouble().toStringAsFixed(3)
              else
                v.getUnchecked(i).toInt().toString(),
          ];
          return '(${comps.join(', ')})';
        })
        .join(', ');
    setAttrValue(samplesText, fullText);
    return;
  }

  if (generatedSamples.isEmpty) {
    setAttrValue(samplesText, '-');
    return;
  }

  final fullText = generatedSamples
      .map(
        (s) => activeDef!.isContinuous
            ? s.toStringAsFixed(4)
            : s.toInt().toString(),
      )
      .join(', ');

  setAttrValue(samplesText, fullText);
}

/// Compute empirical statistics of drawn samples and update attributes.
void updateEmpiricalStats() {
  if (isMultivariateActive) {
    if (generatedMvSamples.isEmpty) {
      setAttrValue(eMean, '-');
      setAttrValue(eVariance, '-');
      setAttrValue(eStdDev, '-');
      return;
    }

    final n = generatedMvSamples.length;
    final d = activeMvDist!.dimensions;
    final means = List<double>.filled(d, 0.0);
    for (final v in generatedMvSamples) {
      for (var i = 0; i < d; i++) {
        means[i] += v.getUnchecked(i).toDouble();
      }
    }
    for (var i = 0; i < d; i++) {
      means[i] /= n;
    }

    final covRows = List<List<double>>.generate(
      d,
      (_) => List<double>.filled(d, 0.0),
    );
    if (n > 1) {
      for (final v in generatedMvSamples) {
        for (var i = 0; i < d; i++) {
          final di = v.getUnchecked(i).toDouble() - means[i];
          for (var j = 0; j < d; j++) {
            final dj = v.getUnchecked(j).toDouble() - means[j];
            covRows[i][j] += di * dj;
          }
        }
      }
      for (var i = 0; i < d; i++) {
        for (var j = 0; j < d; j++) {
          covRows[i][j] /= n - 1;
        }
      }
    }

    setAttrValue(
      eMean,
      '[${[for (final m in means) formatNumber(m, precision: 3)].join(', ')}]',
    );
    setAttrValue(
      eStdDev,
      '[${[for (var i = 0; i < d; i++) formatNumber(math.sqrt(math.max(0.0, covRows[i][i])), precision: 3)].join(', ')}]',
    );
    _setMatrixAttr(
      eVariance,
      Matrix<double>.fromRows(covRows, type: DataType.float64),
    );
    return;
  }

  if (generatedSamples.isEmpty) {
    setAttrValue(eMean, '-');
    setAttrValue(eVariance, '-');
    setAttrValue(eStdDev, '-');
    return;
  }

  final n = generatedSamples.length;

  var sum = 0.0;
  for (final s in generatedSamples) {
    sum += s;
  }
  final empiricalMean = sum / n;

  var sumSquares = 0.0;
  for (final s in generatedSamples) {
    sumSquares += math.pow(s - empiricalMean, 2);
  }
  final empiricalVar = n > 1 ? sumSquares / (n - 1) : 0.0;
  final empiricalStd = math.sqrt(empiricalVar);

  setAttrValue(eMean, formatVal(empiricalMean));
  setAttrValue(eVariance, formatVal(empiricalVar));
  setAttrValue(eStdDev, formatVal(empiricalStd));
}
