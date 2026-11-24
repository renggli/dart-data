import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/stats.dart';
import 'package:web/web.dart' as web;

import '../shared/graph/model/axis.dart';
import '../shared/graph/model/dataset_2d.dart';
import '../shared/graph/sampling/sampler_2d.dart';
import '../shared/graph/ui/graph_widget.dart';
import '../shared/utils.dart';
import 'config.dart';

// Current states
late DistributionConfig activeDef;
late Distribution<num> activeDist;
List<double> currentParamValues = [];
final List<num> generatedSamples = [];
final List<void Function()> _paramSyncCallbacks = [];
bool isAppInitialized = false;

// Interactive graph widgets
GraphWidget? pdfGraph;
GraphWidget? cdfGraph;

// DOM references
late web.HTMLElement continuousGroup;
late web.HTMLElement discreteGroup;
late web.HTMLElement distTitle;
late web.HTMLElement distTypeBadge;
late web.HTMLElement distDescription;
late web.HTMLElement configInputsContainer;

late web.HTMLElement valMean;
late web.HTMLElement valMedian;
late web.HTMLElement valMode;
late web.HTMLElement valVariance;
late web.HTMLElement valStdDev;
late web.HTMLElement valSkewness;
late web.HTMLElement valKurtosis;
late web.HTMLElement valBounds;

late web.HTMLElement pdfGraphHost;
late web.HTMLElement cdfGraphHost;

late web.HTMLButtonElement btnSample1;
late web.HTMLButtonElement btnSample10;
late web.HTMLButtonElement btnSample100;
late web.HTMLButtonElement btnSample1000;
late web.HTMLButtonElement btnSampleClear;

late web.HTMLElement sampleCountBadge;
late web.HTMLElement samplesText;

late web.HTMLElement eMean;
late web.HTMLElement eVariance;
late web.HTMLElement eStdDev;

// Quantile & Probability interactive calculator
late web.HTMLInputElement calcPSlider;
late web.HTMLInputElement calcPInput;
late web.HTMLElement valQuantile;
late web.HTMLElement valCdfEval;
late web.HTMLElement valSurvivalEval;
late web.HTMLElement valPdfEval;
double currentEvalP = 0.50;

/// Prettily formats statistical results.
String formatVal(num value) => formatNumber(value);

/// Initialize application and attach listeners.
void main() {
  // Grab standard UI hooks
  continuousGroup =
      web.document.querySelector('#continuous-group') as web.HTMLElement;
  discreteGroup =
      web.document.querySelector('#discrete-group') as web.HTMLElement;
  distTitle = web.document.querySelector('#dist-title') as web.HTMLElement;
  distTypeBadge =
      web.document.querySelector('#dist-type-badge') as web.HTMLElement;
  distDescription =
      web.document.querySelector('#dist-description') as web.HTMLElement;
  configInputsContainer =
      web.document.querySelector('#config-inputs-container') as web.HTMLElement;

  valMean = web.document.querySelector('#val-mean') as web.HTMLElement;
  valMedian = web.document.querySelector('#val-median') as web.HTMLElement;
  valMode = web.document.querySelector('#val-mode') as web.HTMLElement;
  valVariance = web.document.querySelector('#val-variance') as web.HTMLElement;
  valStdDev = web.document.querySelector('#val-stddev') as web.HTMLElement;
  valSkewness = web.document.querySelector('#val-skewness') as web.HTMLElement;
  valKurtosis = web.document.querySelector('#val-kurtosis') as web.HTMLElement;
  valBounds = web.document.querySelector('#val-bounds') as web.HTMLElement;

  pdfGraphHost = web.document.querySelector('#pdf-graph') as web.HTMLElement;
  cdfGraphHost = web.document.querySelector('#cdf-graph') as web.HTMLElement;

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

  eMean = web.document.querySelector('#e-mean') as web.HTMLElement;
  eVariance = web.document.querySelector('#e-variance') as web.HTMLElement;
  eStdDev = web.document.querySelector('#e-stddev') as web.HTMLElement;

  calcPSlider =
      web.document.querySelector('#calc-p-slider') as web.HTMLInputElement;
  calcPInput =
      web.document.querySelector('#calc-p-input') as web.HTMLInputElement;
  valQuantile = web.document.querySelector('#val-quantile') as web.HTMLElement;
  valCdfEval = web.document.querySelector('#val-cdf-eval') as web.HTMLElement;
  valSurvivalEval =
      web.document.querySelector('#val-survival-eval') as web.HTMLElement;
  valPdfEval = web.document.querySelector('#val-pdf-eval') as web.HTMLElement;

  void updateEvalP(double p) {
    currentEvalP = p.clamp(0.0, 1.0);
    calcPSlider.value = currentEvalP.toString();
    calcPInput.value = currentEvalP.toStringAsFixed(2);
    updateQuantileCalculator();
  }

  calcPSlider.onInput.listen((_) {
    final val = double.tryParse(calcPSlider.value) ?? 0.50;
    updateEvalP(val);
  });

  calcPInput.onInput.listen((_) {
    final val = double.tryParse(calcPInput.value) ?? 0.50;
    updateEvalP(val);
  });

  // Initialize universal copy handler
  initGlobalCopyHandler();

  // Render Sidebar & Setup Collapse Toggle
  buildSidebar();
  setupSidebarToggle(
    onToggled: () {
      pdfGraph?.resize();
      cdfGraph?.resize();
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
}

/// Change active distribution.
void selectDistribution(
  DistributionConfig def, {
  Map<String, double>? parameterOverrides,
}) {
  activeDef = def;

  // Highlight active item in sidebar
  final items = web.document.querySelectorAll('.sidebar-item');
  for (var i = 0; i < items.length; i++) {
    final item = items.item(i) as web.HTMLElement;
    if (item.getAttribute('data-id') == def.id) {
      item.classList.add('active');
    } else {
      item.classList.remove('active');
    }
  }

  // Update Header details
  distTitle.textContent = def.name;
  distDescription.textContent = def.description;
  distTypeBadge.textContent = def.isContinuous ? 'Continuous' : 'Discrete';
  distTypeBadge.className =
      'badge ${def.isContinuous ? 'badge-continuous' : 'badge-discrete'}';

  // Instantiate parameters (with overrides if provided, otherwise defaults)
  currentParamValues = [];
  for (final p in def.parameters) {
    if (parameterOverrides != null && parameterOverrides.containsKey(p.name)) {
      var val = parameterOverrides[p.name]!;
      if (!val.isFinite) {
        val = p.defaultValue;
      } else {
        val = val.clamp(p.min, p.max);
        if (p.isInt) val = val.roundToDouble();
      }
      currentParamValues.add(val);
    } else {
      currentParamValues.add(p.defaultValue);
    }
  }

  // Reset sampling
  clearSamples(redraw: false);

  // Re-build config deck
  rebuildConfigInputs();

  // Create distribution & Refresh UI
  recreateDistribution();
  isAppInitialized = true;
}

/// Rebuild configuration slider and text nodes inside panel.
void rebuildConfigInputs() {
  configInputsContainer.innerHTML = ''.toJS;
  _paramSyncCallbacks.clear();

  if (activeDef.parameters.isEmpty) {
    final emptyMsg = web.document.createElement('div') as web.HTMLElement;
    emptyMsg.style.color = 'var(--text-muted)';
    emptyMsg.style.fontSize = '13px';
    emptyMsg.style.fontStyle = 'italic';
    emptyMsg.textContent = 'This distribution does not require any parameters.';
    configInputsContainer.appendChild(emptyMsg);
    return;
  }

  for (var i = 0; i < activeDef.parameters.length; i++) {
    final param = activeDef.parameters[i];
    final index = i;

    final group = web.document.createElement('div') as web.HTMLElement;
    group.className = 'parameter-input-group';

    // Label and Value row
    final labelRow = web.document.createElement('div') as web.HTMLElement;
    labelRow.className = 'parameter-label-row';

    final labelContainer = web.document.createElement('div') as web.HTMLElement;
    labelContainer.style.display = 'flex';
    labelContainer.style.alignItems = 'center';
    labelContainer.style.gap = '6px';

    final nameSpan = web.document.createElement('span') as web.HTMLElement;
    nameSpan.className = 'parameter-name';
    nameSpan.textContent = param.label;

    final copyBtn = createCopyButton(title: 'Copy value');
    void updateCopyData() {
      final val = currentParamValues[index];
      copyBtn.setAttribute(
        'data-copy',
        param.isInt ? val.toInt().toString() : val.toString(),
      );
    }

    updateCopyData();

    labelContainer.appendChild(nameSpan);
    labelContainer.appendChild(copyBtn);
    labelRow.appendChild(labelContainer);

    group.appendChild(labelRow);

    // Controls Row
    final controlsRow = web.document.createElement('div') as web.HTMLElement;
    controlsRow.className = 'parameter-control-row';

    // Slider
    final slider = web.document.createElement('input') as web.HTMLInputElement;
    slider.type = 'range';
    slider.className = 'custom-slider';
    slider.min = param.min.toString();
    slider.max = param.max.toString();
    slider.step = param.step.toString();
    slider.value = currentParamValues[index].toString();
    controlsRow.appendChild(slider);

    // Manual Number Input
    final numInput =
        web.document.createElement('input') as web.HTMLInputElement;
    numInput.type = 'number';
    numInput.className = 'custom-number-input';
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

    // Connect slider <-> number input events
    void updateVal(double newVal) {
      // Constraints validation & snapping
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
      recreateDistribution();
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
  final id = activeDef.id;
  final queryParams = <String>[];
  for (var i = 0; i < activeDef.parameters.length; i++) {
    final param = activeDef.parameters[i];
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
  Map<String, double>? targetOverrides;

  var hash = web.window.location.hash;
  if (hash.startsWith('#')) {
    hash = hash.substring(1);
  }

  if (hash.isNotEmpty) {
    final parts = hash.split('?');
    final distId = Uri.decodeComponent(parts[0].trim());

    final def = distributions.where((d) => d.id == distId).firstOrNull;
    targetDef = def;

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

  final defToLoad =
      targetDef ?? distributions.firstWhere((d) => d.isContinuous);

  if (!isAppInitialized) {
    selectDistribution(defToLoad, parameterOverrides: targetOverrides);
  } else {
    // Only reload if the selection or parameters actually differ to prevent circular navigation loops
    var isDifferent = activeDef.id != defToLoad.id;
    if (!isDifferent) {
      for (var i = 0; i < activeDef.parameters.length; i++) {
        final p = activeDef.parameters[i];
        final currentVal = currentParamValues[i];
        var targetVal = targetOverrides?[p.name] ?? p.defaultValue;
        if (!targetVal.isFinite) {
          targetVal = p.defaultValue;
        } else {
          targetVal = targetVal.clamp(p.min, p.max);
          if (p.isInt) targetVal = targetVal.roundToDouble();
        }
        if ((currentVal - targetVal).abs() > 1e-6) {
          isDifferent = true;
          break;
        }
      }
    }

    if (isDifferent) {
      selectDistribution(defToLoad, parameterOverrides: targetOverrides);
    }
  }
}

void _syncCrossParameters() {
  if (activeDef.id == 'uniform_continuous' && currentParamValues.length >= 2) {
    if (currentParamValues[1] < currentParamValues[0] + 0.1) {
      currentParamValues[1] = (currentParamValues[0] + 0.1).clamp(
        activeDef.parameters[1].min,
        activeDef.parameters[1].max,
      );
    }
  } else if (activeDef.id == 'uniform_discrete' &&
      currentParamValues.length >= 2) {
    if (currentParamValues[1] < currentParamValues[0]) {
      currentParamValues[1] = currentParamValues[0].clamp(
        activeDef.parameters[1].min,
        activeDef.parameters[1].max,
      );
    }
  } else if (activeDef.id == 'hypergeometric' &&
      currentParamValues.length >= 3) {
    final pop = currentParamValues[0];
    if (currentParamValues[1] > pop) currentParamValues[1] = pop;
    if (currentParamValues[2] > pop) currentParamValues[2] = pop;
  }
}

/// Recreate the stats distribution using configured inputs.
void recreateDistribution() {
  _syncCrossParameters();
  for (final cb in _paramSyncCallbacks) {
    cb();
  }
  activeDist = activeDef.creator(currentParamValues);
  clearSamples(redraw: false);
  updateTelemetry();
  updateQuantileCalculator();
  drawCharts();
  updateEmpiricalStats();
  updateUrlHash();
}

/// Update mathematical properties panel.
void updateTelemetry() {
  setAttrValue(valMean, formatProperty(() => activeDist.mean));
  setAttrValue(valMedian, formatProperty(() => activeDist.median));
  setAttrValue(valMode, formatProperty(() => activeDist.mode));
  setAttrValue(valVariance, formatProperty(() => activeDist.variance));
  setAttrValue(valStdDev, formatProperty(() => activeDist.standardDeviation));
  setAttrValue(valSkewness, formatProperty(() => activeDist.skewness));
  setAttrValue(valKurtosis, formatProperty(() => activeDist.excessKurtosis));

  // Format bounds
  try {
    final buffer = StringBuffer();
    buffer.write(activeDist.isLowerBoundOpen ? '(' : '[');
    buffer.write(formatNumber(activeDist.lowerBound));
    buffer.write(', ');
    buffer.write(formatNumber(activeDist.upperBound));
    buffer.write(activeDist.isUpperBoundOpen ? ')' : ']');
    setAttrValue(valBounds, buffer.toString());
  } catch (_) {
    setAttrValue(valBounds, '[-]');
  }
}

/// Evaluates probability density (continuous) or mass (discrete) correctly
/// handling generic type requirements.
double evalDistProbability(num x) {
  if (x == double.negativeInfinity || x == double.infinity) return 0.0;
  if (activeDef.isContinuous) {
    final val = (activeDist as Distribution<double>).probability(x.toDouble());
    return val.isNaN ? 0.0 : val;
  } else {
    if (!x.isFinite) return 0.0;
    return (activeDist as Distribution<int>).probability(x.round());
  }
}

/// Evaluates cumulative probability distribution (CDF) correctly
/// handling generic type requirements.
double evalDistCumulativeProbability(num x) {
  if (x == double.negativeInfinity) return 0.0;
  if (x == double.infinity) return 1.0;
  if (activeDef.isContinuous) {
    final val = (activeDist as Distribution<double>).cumulativeProbability(
      x.toDouble(),
    );
    return val.isNaN ? (x < 0 ? 0.0 : 1.0) : val;
  } else {
    if (!x.isFinite) return x < 0 ? 0.0 : 1.0;
    return (activeDist as Distribution<int>).cumulativeProbability(x.floor());
  }
}

/// Evaluates survival function correctly handling generic type requirements.
double evalDistSurvival(num x) {
  if (x == double.negativeInfinity) return 1.0;
  if (x == double.infinity) return 0.0;
  if (activeDef.isContinuous) {
    final val = (activeDist as Distribution<double>).survival(x.toDouble());
    return val.isNaN ? (x < 0 ? 1.0 : 0.0) : val;
  } else {
    if (!x.isFinite) return x < 0 ? 1.0 : 0.0;
    return (activeDist as Distribution<int>).survival(x.floor());
  }
}

/// Update quantile and probability evaluation card.
void updateQuantileCalculator() {
  try {
    num q;
    if (currentEvalP == 0.0 && activeDist.isLowerBoundOpen) {
      q = activeDist.lowerBound;
    } else if (currentEvalP == 1.0 && activeDist.isUpperBoundOpen) {
      q = activeDist.upperBound;
    } else {
      q = activeDist.inverseCumulativeProbability(currentEvalP);
    }
    setAttrValue(valQuantile, formatNumber(q));

    // Evaluate cumulative CDF at q
    final cdfAtQ = evalDistCumulativeProbability(q);
    setAttrValue(valCdfEval, formatNumber(cdfAtQ));

    // Survival at q
    final survAtQ = evalDistSurvival(q);
    setAttrValue(valSurvivalEval, formatNumber(survAtQ));

    // Density / Mass at q
    final pdfAtQ = evalDistProbability(q);
    setAttrValue(valPdfEval, formatNumber(pdfAtQ));
  } catch (_) {
    setAttrValue(valQuantile, '-');
    setAttrValue(valCdfEval, '-');
    setAttrValue(valSurvivalEval, '-');
    setAttrValue(valPdfEval, '-');
  }
}

/// Dynamic bounds estimation for graphing X-axis window.
Map<String, double> getGraphBounds() {
  var minX = -5.0;
  var maxX = 5.0;

  final lower = activeDist.lowerBound;
  final upper = activeDist.upperBound;

  // Check if bounds are finite and narrow
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
    // Rely on moments if defined
    final meanVal = safeGet(() => activeDist.mean)?.toDouble();
    final stdVal = safeGet(() => activeDist.standardDeviation)?.toDouble();

    if (meanVal != null &&
        stdVal != null &&
        meanVal.isFinite &&
        stdVal.isFinite &&
        stdVal > 1e-4) {
      minX = meanVal - 4 * stdVal;
      maxX = meanVal + 4 * stdVal;
    } else {
      // Fallback to median
      final medianVal = safeGet(() => activeDist.median)?.toDouble();
      if (medianVal != null && medianVal.isFinite) {
        minX = medianVal - 6.0;
        maxX = medianVal + 6.0;
      }
    }

    // Clip back to actual bounds where applicable
    if (lowerFinite) {
      minX = math.max(minX, lower.toDouble());
    }
    if (upperFinite) {
      maxX = math.min(maxX, upper.toDouble());
    }
  }

  // Add padding around bounds so boundary points, lollipops, and jumps are clearly visible
  final span = maxX - minX;
  final padding = span > 0 ? span * 0.08 : 1.0;
  if (!activeDef.isContinuous) {
    final discretePadding = math.max(1.0, padding);
    minX -= discretePadding;
    maxX += discretePadding;
  } else {
    minX -= padding;
    maxX += padding;
  }

  // Sanity check
  if (maxX <= minX) {
    maxX = minX + 1.0;
  }
  if ((maxX - minX).abs() < 1e-4) {
    minX -= 1.0;
    maxX += 1.0;
  }

  return {'min': minX, 'max': maxX};
}

/// Renders PDF/PMF and CDF scenes into [GraphWidget] instances.
void drawCharts() {
  final bounds = getGraphBounds();
  final minX = bounds['min']!;
  final maxX = bounds['max']!;

  final refs = <ReferenceLine>[];
  final meanVal = safeGet(() => activeDist.mean)?.toDouble();
  if (meanVal != null && meanVal.isFinite) {
    refs.add(
      ReferenceLine(
        value: meanVal,
        isVertical: true,
        label: 'μ',
        color: 'rgba(239, 68, 68, 0.7)',
      ),
    );
  }
  final medianVal = safeGet(() => activeDist.median)?.toDouble();
  if (medianVal != null && medianVal.isFinite) {
    refs.add(
      ReferenceLine(
        value: medianVal,
        isVertical: true,
        label: 'Med',
        color: 'rgba(16, 185, 129, 0.7)',
      ),
    );
  }
  final modeVal = safeGet(() => activeDist.mode)?.toDouble();
  if (modeVal != null && modeVal.isFinite) {
    refs.add(
      ReferenceLine(
        value: modeVal,
        isVertical: true,
        label: 'Mode',
        color: 'rgba(168, 85, 247, 0.7)',
      ),
    );
  }

  final pdfDatasets = <Dataset2D>[];
  if (generatedSamples.isNotEmpty) {
    final n = generatedSamples.length;
    if (activeDef.isContinuous) {
      const binCount = 20;
      final binWidth = (maxX - minX) / binCount;
      final bins = List<int>.filled(binCount, 0);
      for (final s in generatedSamples) {
        if (s >= minX && s <= maxX) {
          final idx = ((s - minX) / binWidth).floor().clamp(0, binCount - 1);
          bins[idx]++;
        }
      }
      pdfDatasets.add(
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
        pdfDatasets.add(
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

  if (activeDef.id == 'degenerate_continuous') {
    final k = activeDist.lowerBound.toDouble();
    pdfDatasets.add(
      Function2DDataset(
        id: 'pdf',
        label: 'Impulse',
        xs: [k],
        ys: [1.0],
        color: '#3b82f6',
        mode: CurveRenderMode.stem,
      ),
    );
  } else if (activeDef.isContinuous) {
    pdfDatasets.add(
      sampleFunction2D(
        id: 'pdf',
        label: 'PDF',
        fn: (x) => activeDist.probability(x),
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
    pdfDatasets.add(
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

  final pdfScene = Scene2D(
    datasets: pdfDatasets,
    xAxis: AxisConfig(min: minX, max: maxX, isInteger: !activeDef.isContinuous),
    yAxis: const AxisConfig(min: 0.0),
    references: refs,
  );
  if (pdfGraph == null) {
    pdfGraph = GraphWidget.view2d(pdfScene, height: 270);
    pdfGraphHost.appendChild(pdfGraph!.element);
  } else {
    pdfGraph!.setScene2D(pdfScene);
  }

  final cdfDatasets = <Dataset2D>[];
  if (activeDef.isContinuous) {
    cdfDatasets.add(
      sampleFunction2D(
        id: 'cdf',
        label: 'CDF',
        fn: evalDistCumulativeProbability,
        xMin: minX,
        xMax: maxX,
        color: '#f59e0b',
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
    cdfDatasets.add(
      Function2DDataset(
        id: 'cdf',
        label: 'CDF',
        xs: ks,
        ys: cs,
        color: '#f59e0b',
        mode: CurveRenderMode.step,
      ),
    );
  }

  final cdfScene = Scene2D(
    datasets: cdfDatasets,
    xAxis: AxisConfig(min: minX, max: maxX, isInteger: !activeDef.isContinuous),
    yAxis: const AxisConfig(min: 0.0, max: 1.0),
    references: refs,
  );
  if (cdfGraph == null) {
    cdfGraph = GraphWidget.view2d(cdfScene, height: 270);
    cdfGraphHost.appendChild(cdfGraph!.element);
  } else {
    cdfGraph!.setScene2D(cdfScene);
  }
}

// ==================== RANDOM SAMPLING ENGINE ====================

/// Draw N random samples from the active distribution.
void drawSamples(int count) {
  final newSamples = activeDist
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
  sampleCountBadge.textContent = '0';
  setAttrValue(samplesText, '-');

  updateEmpiricalStats();
  if (redraw) {
    drawCharts();
  }
}

/// Update samples field with preview and full clipboard copy data.
void updateSamplesDisplay() {
  if (generatedSamples.isEmpty) {
    setAttrValue(samplesText, '-');
    return;
  }

  final fullText = generatedSamples
      .map(
        (s) => activeDef.isContinuous
            ? s.toStringAsFixed(4)
            : s.toInt().toString(),
      )
      .join(', ');

  setAttrValue(samplesText, fullText);
}

/// Compute empirical statistics of drawn samples and update attributes.
void updateEmpiricalStats() {
  if (generatedSamples.isEmpty) {
    setAttrValue(eMean, '-');
    setAttrValue(eVariance, '-');
    setAttrValue(eStdDev, '-');
    return;
  }

  final n = generatedSamples.length;

  // 1. Empirical Mean
  var sum = 0.0;
  for (final s in generatedSamples) {
    sum += s;
  }
  final empiricalMean = sum / n;

  // 2. Empirical Variance (unbiased sample variance divided by n - 1)
  var sumSquares = 0.0;
  for (final s in generatedSamples) {
    sumSquares += math.pow(s - empiricalMean, 2);
  }
  final empiricalVar = n > 1 ? sumSquares / (n - 1) : 0.0;
  final empiricalStd = math.sqrt(empiricalVar);

  // Update UI Elements with setAttrValue for copy handler integration
  setAttrValue(eMean, formatVal(empiricalMean));
  setAttrValue(eVariance, formatVal(empiricalVar));
  setAttrValue(eStdDev, formatVal(empiricalStd));
}
