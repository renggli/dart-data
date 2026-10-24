import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/stats.dart';
import 'package:web/web.dart' as web;

import '../shared/chart.dart';
import '../shared/utils.dart';
import 'config.dart';

// Current states
late DistributionConfig activeDef;
late Distribution<num> activeDist;
List<double> currentParamValues = [];
final List<num> generatedSamples = [];
bool isAppInitialized = false;

// Interactive chart controllers
late InteractiveChartController pdfController;
late InteractiveChartController cdfController;

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

late web.HTMLCanvasElement pdfCanvas;
late web.HTMLCanvasElement cdfCanvas;
late web.HTMLButtonElement btnPdfReset;
late web.HTMLButtonElement btnCdfReset;

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

  pdfCanvas =
      web.document.querySelector('#pdf-canvas') as web.HTMLCanvasElement;
  cdfCanvas =
      web.document.querySelector('#cdf-canvas') as web.HTMLCanvasElement;
  btnPdfReset =
      web.document.querySelector('#btn-pdf-reset') as web.HTMLButtonElement;
  btnCdfReset =
      web.document.querySelector('#btn-cdf-reset') as web.HTMLButtonElement;

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

  // Render Sidebar
  buildSidebar();

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

  void syncChartBounds(double newMinX, double newMaxX) {
    pdfController.setBounds(minX: newMinX, maxX: newMaxX);
    cdfController.setBounds(minX: newMinX, maxX: newMaxX);
    pdfController.hasUserPannedOrZoomed = true;
    cdfController.hasUserPannedOrZoomed = true;
  }

  void resetChartBounds() {
    final bounds = getGraphBounds();
    final minX = bounds['min']!;
    final maxX = bounds['max']!;
    pdfController.setBounds(
      minX: minX,
      maxX: maxX,
      asDefault: true,
      clearUserInteraction: true,
    );
    cdfController.setBounds(
      minX: minX,
      maxX: maxX,
      asDefault: true,
      clearUserInteraction: true,
    );
    drawCharts();
  }

  pdfController = InteractiveChartController(
    pdfCanvas,
    minX: -5.0,
    maxX: 5.0,
    panY: false,
    zoomY: false,
    onUpdate: drawCharts,
    onViewportChanged: (newMinX, newMaxX, _, _) =>
        syncChartBounds(newMinX, newMaxX),
    onReset: resetChartBounds,
  );

  cdfController = InteractiveChartController(
    cdfCanvas,
    minX: -5.0,
    maxX: 5.0,
    panY: false,
    zoomY: false,
    onUpdate: drawCharts,
    onViewportChanged: (newMinX, newMaxX, _, _) =>
        syncChartBounds(newMinX, newMaxX),
    onReset: resetChartBounds,
  );

  btnPdfReset.onClick.listen((_) => resetChartBounds());
  btnCdfReset.onClick.listen((_) => resetChartBounds());

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
      currentParamValues.add(parameterOverrides[p.name]!);
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
  web.window.location.hash = '${Uri.encodeComponent(id)}$queryString';
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
        final targetVal = targetOverrides?[p.name] ?? p.defaultValue;
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

/// Recreate the stats distribution using configured inputs.
void recreateDistribution() {
  activeDist = activeDef.creator(currentParamValues);
  final bounds = getGraphBounds();
  pdfController.setBounds(
    minX: bounds['min'],
    maxX: bounds['max'],
    asDefault: true,
    clearUserInteraction: true,
  );
  cdfController.setBounds(
    minX: bounds['min'],
    maxX: bounds['max'],
    asDefault: true,
    clearUserInteraction: true,
  );
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
  if (activeDef.isContinuous) {
    return (activeDist as Distribution<double>).probability(x.toDouble());
  } else {
    return (activeDist as Distribution<int>).probability(x.round());
  }
}

/// Update quantile and probability evaluation card.
void updateQuantileCalculator() {
  try {
    final q = activeDist.inverseCumulativeProbability(currentEvalP);
    setAttrValue(valQuantile, formatNumber(q));

    // Evaluate cumulative CDF at q
    final cdfAtQ = activeDist.cumulativeProbability(q);
    setAttrValue(valCdfEval, formatNumber(cdfAtQ));

    // Survival at q
    final survAtQ = activeDist.survival(q);
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

/// Custom Canvas Rendering Engine.
void drawCharts() {
  if (!pdfController.hasUserPannedOrZoomed) {
    final bounds = getGraphBounds();
    pdfController.setBounds(
      minX: bounds['min'],
      maxX: bounds['max'],
      asDefault: true,
    );
    cdfController.setBounds(
      minX: bounds['min'],
      maxX: bounds['max'],
      asDefault: true,
    );
  }
  final minX = pdfController.minX;
  final maxX = pdfController.maxX;

  renderCanvas(
    pdfCanvas,
    controller: pdfController,
    isCdf: false,
    minX: minX,
    maxX: maxX,
  );

  renderCanvas(
    cdfCanvas,
    controller: cdfController,
    isCdf: true,
    minX: minX,
    maxX: maxX,
  );
}

void renderCanvas(
  web.HTMLCanvasElement canvas, {
  required InteractiveChartController controller,
  required bool isCdf,
  required double minX,
  required double maxX,
}) {
  final setup = initCanvas(canvas);
  if (setup == null) return;
  final (ctx, width, height) = setup;

  // Calculate dynamic Y-axis maximum bounds
  const minY = 0.0;
  var maxY = 1.0;

  if (isCdf) {
    maxY = 1.0;
  } else {
    // Scan X intervals to capture maximum probability density peak
    var peak = 0.0;
    if (activeDef.isContinuous) {
      const steps = 100;
      for (var s = 0; s <= steps; s++) {
        final x = minX + s * (maxX - minX) / steps;
        final p = activeDist.probability(x);
        if (p.isFinite && p > peak) {
          peak = p;
        }
      }
    } else {
      // Discrete scanning
      final iMin = minX.floor();
      final iMax = maxX.ceil();
      final span = iMax - iMin;
      final step = span > 500 ? (span / 500).ceil() : 1;
      for (var k = iMin; k <= iMax; k += step) {
        final p = evalDistProbability(k);
        if (p.isFinite && p > peak) {
          peak = p;
        }
      }
    }

    // Capture empirical peaks to ensure generated samples fit the y-axis perfectly
    var empiricalPeak = 0.0;
    if (generatedSamples.isNotEmpty) {
      final n = generatedSamples.length;
      if (activeDef.isContinuous) {
        const binCount = 20;
        final binWidth = (maxX - minX) / binCount;
        final bins = List<int>.filled(binCount, 0);

        for (final s in generatedSamples) {
          if (s >= minX && s <= maxX) {
            final binIdx = ((s - minX) / binWidth).floor().clamp(
              0,
              binCount - 1,
            );
            bins[binIdx]++;
          }
        }

        for (var b = 0; b < binCount; b++) {
          final count = bins[b];
          if (count > 0) {
            final density = count / (n * binWidth);
            if (density > empiricalPeak) {
              empiricalPeak = density;
            }
          }
        }
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

        for (final count in freqMap.values) {
          if (count > 0) {
            final empiricalProb = count / n;
            if (empiricalProb > empiricalPeak) {
              empiricalPeak = empiricalProb;
            }
          }
        }
      }
    }
    peak = math.max(peak, empiricalPeak);

    maxY = peak * 1.15; // Provide 15% headroom
    if (maxY <= 0.0 || maxY.isNaN || !maxY.isFinite) {
      maxY = 1.0;
    }
  }

  final vp = controller.viewport(
    width,
    height,
    overrideMinY: minY,
    overrideMaxY: maxY,
  );
  final leftMargin = vp.leftMargin;
  final topMargin = vp.topMargin;
  final plotWidth = vp.plotWidth;
  final plotHeight = vp.plotHeight;
  double toPixelX(double x) => vp.toPixelX(x);
  double fromPixelX(double px) => vp.fromPixelX(px);
  double toPixelY(double y) => vp.toPixelY(y);

  // ==================== DRAW GRID & LABELS ====================
  drawGrid(ctx, vp, drawZeroAxes: false);

  // Clip inner plotting region so dragged/zoomed curves stay inside the axes box
  ctx.save();
  ctx.beginPath();
  ctx.rect(leftMargin, topMargin, plotWidth, plotHeight);
  ctx.clip();

  // ==================== OVERLAY EMPIRICAL HISTOGRAM ====================
  // For PDF, overlay a transparent histogram
  if (!isCdf && generatedSamples.isNotEmpty) {
    ctx.fillStyle = 'rgba(168, 85, 247, 0.18)'.toJS;
    ctx.strokeStyle = 'rgba(168, 85, 247, 0.45)'.toJS;
    ctx.lineWidth = 1.0;

    final n = generatedSamples.length;

    if (activeDef.isContinuous) {
      // Draw continuous bin intervals
      const binCount = 20;
      final binWidth = (maxX - minX) / binCount;
      final bins = List<int>.filled(binCount, 0);

      for (final s in generatedSamples) {
        if (s >= minX && s <= maxX) {
          final binIdx = ((s - minX) / binWidth).floor().clamp(0, binCount - 1);
          bins[binIdx]++;
        }
      }

      for (var b = 0; b < binCount; b++) {
        final count = bins[b];
        if (count == 0) continue;

        // Density = count / (n * binWidth)
        final density = count / (n * binWidth);
        final bMinX = minX + b * binWidth;
        final pxMin = toPixelX(bMinX);
        final pxMax = toPixelX(bMinX + binWidth);
        final py = toPixelY(density);

        ctx.beginPath();
        ctx.rect(pxMin, py, pxMax - pxMin, (topMargin + plotHeight) - py);
        ctx.fill();
        ctx.stroke();
      }
    } else {
      // Discrete empirical probabilities - overlay bars
      final iMin = minX.floor();
      final iMax = maxX.ceil();
      final freqMap = <int, int>{};

      for (final s in generatedSamples) {
        final val = s.toInt();
        if (val >= iMin && val <= iMax) {
          freqMap[val] = (freqMap[val] ?? 0) + 1;
        }
      }

      for (final entry in freqMap.entries) {
        final k = entry.key;
        final count = entry.value;
        if (count == 0) continue;

        final empiricalProb = count / n;
        final px = toPixelX(k.toDouble());
        final py = toPixelY(empiricalProb);

        // Slightly wide bar centered around integer k
        final barWidth = math.max(6.0, plotWidth / (maxX - minX) * 0.4);

        ctx.beginPath();
        ctx.rect(
          px - barWidth / 2,
          py,
          barWidth,
          (topMargin + plotHeight) - py,
        );
        ctx.fill();
        ctx.stroke();
      }
    }
  }

  // ==================== PLOT MATHEMATICAL CURVE ====================
  ctx.lineWidth = 2.0;

  if (isCdf) {
    // ---------------- CDF PLOTTING ----------------
    ctx.strokeStyle = '#f59e0b'.toJS; // Amber/Gold color

    if (activeDef.isContinuous) {
      // Continuous CDF - smooth path
      ctx.beginPath();
      var first = true;
      for (var px = 0.0; px <= plotWidth; px += 2.0) {
        final x = fromPixelX(leftMargin + px);
        final cdfVal = activeDist.cumulativeProbability(x);
        final py = toPixelY(cdfVal);
        if (first) {
          ctx.moveTo(leftMargin + px, py);
          first = false;
        } else {
          ctx.lineTo(leftMargin + px, py);
        }
      }
      ctx.stroke();
    } else {
      // Discrete CDF - step function representation (horizontal segments + dots)
      final iMin = minX.floor() - 1;
      final iMax = maxX.ceil() + 1;
      final span = iMax - iMin;
      final step = span > 500 ? (span / 500).ceil() : 1;

      for (var k = iMin; k <= iMax; k += step) {
        final cdfVal = activeDist.cumulativeProbability(k.toDouble());
        final pxStart = toPixelX(k.toDouble());
        final pxEnd = toPixelX((k + step).toDouble());
        final py = toPixelY(cdfVal);

        // Horizontal step bar
        ctx.beginPath();
        ctx.moveTo(math.max(leftMargin, pxStart), py);
        ctx.lineTo(math.min(leftMargin + plotWidth, pxEnd), py);
        ctx.stroke();

        // Connect vertical jump
        if (k > iMin) {
          final prevCdfVal = activeDist.cumulativeProbability(
            (k - step).toDouble(),
          );
          final pyPrev = toPixelY(prevCdfVal);
          ctx.strokeStyle =
              'rgba(245, 158, 11, 0.35)'.toJS; // Faint vertical jump line
          ctx.lineWidth = 1.0;
          ctx.beginPath();
          ctx.moveTo(pxStart, pyPrev);
          ctx.lineTo(pxStart, py);
          ctx.stroke();

          ctx.strokeStyle = '#f59e0b'.toJS; // Restore thickness
          ctx.lineWidth = 2.0;
        }
      }
    }
  } else {
    // ---------------- PDF PLOTTING ----------------
    if (activeDef.isContinuous) {
      // Continuous PDF - smooth curve
      ctx.strokeStyle = '#3b82f6'.toJS; // Ocean Blue

      // Let's create a gorgeous gradient fill under the curve!
      final gradient = ctx.createLinearGradient(
        0,
        topMargin,
        0,
        topMargin + plotHeight,
      );
      gradient.addColorStop(0, 'rgba(59, 130, 246, 0.2)');
      gradient.addColorStop(1, 'rgba(59, 130, 246, 0.0)');

      ctx.beginPath();
      var first = true;
      var lastX = leftMargin;

      for (var px = 0.0; px <= plotWidth; px += 1.5) {
        final x = fromPixelX(leftMargin + px);
        final p = activeDist.probability(x);
        final py = toPixelY(p).clamp(topMargin, topMargin + plotHeight);
        if (first) {
          ctx.moveTo(leftMargin + px, py);
          first = false;
        } else {
          ctx.lineTo(leftMargin + px, py);
        }
        lastX = leftMargin + px;
      }
      ctx.stroke();

      // Complete path to draw gradient fill
      if (!first) {
        ctx.lineTo(lastX, topMargin + plotHeight);
        ctx.lineTo(leftMargin, topMargin + plotHeight);
        ctx.closePath();
        ctx.fillStyle = gradient;
        ctx.fill();
      }
    } else {
      // Discrete PDF - lollipop lines (vertical line + terminal dot)
      final iMin = minX.floor();
      final iMax = maxX.ceil();
      final span = iMax - iMin;
      final step = span > 500 ? (span / 500).ceil() : 1;

      for (var k = iMin; k <= iMax; k += step) {
        final p = evalDistProbability(k);
        if (p.isNaN || p <= 0.0) continue;

        final px = toPixelX(k.toDouble());
        final py = toPixelY(p);

        // Lollipop stem
        ctx.strokeStyle = '#10b981'.toJS; // Emerald Green
        ctx.beginPath();
        ctx.moveTo(px, topMargin + plotHeight);
        ctx.lineTo(px, py);
        ctx.stroke();

        // Lollipop head dot
        ctx.fillStyle = '#10b981'.toJS;
        ctx.beginPath();
        ctx.arc(px, py, 3.5, 0.0, 2 * math.pi);
        ctx.fill();
      }
    }
  }

  ctx.restore();

  // ==================== PLOT ATTRIBUTE REFERENCE LINES ====================
  final meanVal = safeGet(() => activeDist.mean)?.toDouble();
  if (meanVal != null && meanVal.isFinite) {
    drawReferenceLine(
      ctx,
      vp,
      meanVal,
      color: 'rgba(239, 68, 68, 0.7)',
      label: 'μ',
    );
  }

  final medianVal = safeGet(() => activeDist.median)?.toDouble();
  if (medianVal != null && medianVal.isFinite) {
    var yOffset = 0.0;
    if (meanVal != null &&
        meanVal.isFinite &&
        (medianVal - meanVal).abs() < (maxX - minX) * 0.05) {
      yOffset = 10.0;
    }
    drawReferenceLine(
      ctx,
      vp,
      medianVal,
      color: 'rgba(16, 185, 129, 0.7)',
      label: 'Med',
      labelYOffset: yOffset,
    );
  }

  final modeVal = safeGet(() => activeDist.mode)?.toDouble();
  if (modeVal != null && modeVal.isFinite) {
    var yOffset = 0.0;
    final closeToMean =
        meanVal != null &&
        meanVal.isFinite &&
        (modeVal - meanVal).abs() < (maxX - minX) * 0.05;
    final closeToMedian =
        medianVal != null &&
        medianVal.isFinite &&
        (modeVal - medianVal).abs() < (maxX - minX) * 0.05;
    if (closeToMean || closeToMedian) {
      yOffset = (closeToMean && closeToMedian) ? 20.0 : 10.0;
    }
    drawReferenceLine(
      ctx,
      vp,
      modeVal,
      color: 'rgba(168, 85, 247, 0.7)',
      label: 'Mode',
      labelYOffset: yOffset,
    );
  }

  // ==================== INTERACTIVE HOVER COORDINATES ====================
  final mouseX = controller.hoverPixelX;
  final mouseY = controller.hoverPixelY;

  if (mouseX != null && mouseY != null && vp.containsPixel(mouseX, mouseY)) {
    final xVal = fromPixelX(mouseX);

    // Determine discrete target k
    final k = xVal.round();
    final targetX = activeDef.isContinuous ? xVal : k.toDouble();

    final yVal = isCdf
        ? activeDist.cumulativeProbability(targetX)
        : evalDistProbability(targetX);
    final hasVal = yVal.isFinite && !yVal.isNaN && yVal >= 0.0;

    if (hasVal) {
      final colorStr = isCdf
          ? '#f59e0b'
          : (activeDef.isContinuous ? '#3b82f6' : '#10b981');
      final labelX = activeDef.isContinuous
          ? 'x: ${targetX.toStringAsFixed(4)}'
          : 'k: ${k.toInt()}';
      final labelY = isCdf
          ? 'F(x): ${yVal.toStringAsFixed(4)}'
          : (activeDef.isContinuous
                ? 'f(x): ${yVal.toStringAsFixed(4)}'
                : 'P(k): ${yVal.toStringAsFixed(4)}');
      drawCrosshairAndTooltip(
        ctx,
        vp,
        targetX: targetX,
        targetY: yVal,
        tooltipLines: [labelX, labelY],
        color: colorStr,
      );
    }
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
