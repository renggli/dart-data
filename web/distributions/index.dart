import 'dart:js_interop';
import 'dart:math' as math;

import 'package:data/stats.dart';
import 'package:web/web.dart' as web;

import 'config.dart';

// Current states
late DistributionConfig activeDef;
late Distribution<num> activeDist;
List<double> currentParamValues = [];
final List<num> generatedSamples = [];
bool isAppInitialized = false;

// Canvas hover coordinates
double? pdfMouseX;
double? pdfMouseY;
double? cdfMouseX;
double? cdfMouseY;

// DOM references
late web.HTMLInputElement searchBox;
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

late web.HTMLButtonElement btnSample1;
late web.HTMLButtonElement btnSample10;
late web.HTMLButtonElement btnSample100;
late web.HTMLButtonElement btnSample1000;
late web.HTMLButtonElement btnSampleClear;
late web.HTMLButtonElement btnSampleCopyAll;

late web.HTMLElement sampleCountBadge;
late web.HTMLElement samplesChipsContainer;

late web.HTMLElement tMean;
late web.HTMLElement eMean;
late web.HTMLElement tVariance;
late web.HTMLElement eVariance;
late web.HTMLElement tStdDev;
late web.HTMLElement eStdDev;

/// Copy a given text to the clipboard.
void copyToClipboard(String text) {
  final navigator = web.window.navigator;
  final clipboard = navigator.clipboard;
  clipboard.writeText(text);
}

/// Prettily formats statistical results, handling NaN and Infinities gracefully.
String formatVal(double value) {
  if (value.isNaN) return 'undefined';
  if (value.isInfinite) return value.isNegative ? '-∞' : '∞';
  // Avoid negative zeroes e.g. -0.00
  if (value.abs() < 1e-6) return '0.00';
  return value.toStringAsFixed(4);
}

/// Initialize application and attach listeners.
void main() {
  // Grab standard UI hooks
  searchBox = web.document.querySelector('#search-box') as web.HTMLInputElement;
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
  btnSampleCopyAll = web.document.querySelector(
    '#btn-sample-copy-all',
  ) as web.HTMLButtonElement;
  sampleCountBadge =
      web.document.querySelector('#sample-count-badge') as web.HTMLElement;
  samplesChipsContainer =
      web.document.querySelector('#samples-chips') as web.HTMLElement;

  tMean = web.document.querySelector('#t-mean') as web.HTMLElement;
  eMean = web.document.querySelector('#e-mean') as web.HTMLElement;
  tVariance = web.document.querySelector('#t-variance') as web.HTMLElement;
  eVariance = web.document.querySelector('#e-variance') as web.HTMLElement;
  tStdDev = web.document.querySelector('#t-stddev') as web.HTMLElement;
  eStdDev = web.document.querySelector('#e-stddev') as web.HTMLElement;

  // Render Sidebar
  buildSidebar();

  // Attach search filtering
  searchBox.onInput.listen((_) => filterSidebar(searchBox.value.trim()));

  // Random Sampler Button bindings
  btnSample1.onClick.listen((_) => drawSamples(1));
  btnSample10.onClick.listen((_) => drawSamples(10));
  btnSample100.onClick.listen((_) => drawSamples(100));
  btnSample1000.onClick.listen((_) => drawSamples(1000));
  btnSampleClear.onClick.listen((_) => clearSamples());
  btnSampleCopyAll.onClick.listen((_) {
    if (generatedSamples.isNotEmpty) {
      final text = generatedSamples
          .map(
            (sample) => activeDef.isContinuous
                ? sample.toStringAsFixed(4)
                : sample.toInt().toString(),
          )
          .join('\n');
      copyToClipboard(text);
    }
  });

  // Click-to-copy setup for mathematical properties list
  final attrItems = web.document.querySelectorAll('.attr-item');
  for (var i = 0; i < attrItems.length; i++) {
    final item = attrItems.item(i) as web.HTMLElement;
    final valueSpan = item.querySelector('.attr-value') as web.HTMLElement?;
    final copyBtn = item.querySelector('.copy-btn') as web.HTMLElement?;
    if (valueSpan != null && copyBtn != null) {
      copyBtn.onClick.listen((_) {
        final text = valueSpan.textContent ?? '';
        if (text.isNotEmpty && text != '-') {
          copyToClipboard(text);
        }
      });
    }
  }

  // Listen to Window resizing for responsive graphics redraw
  web.window.addEventListener(
    'resize',
    (web.Event event) {
      drawCharts();
    }.toJS,
  );

  // Bind mouse hover listeners to PDF Canvas
  pdfCanvas.onMouseMove.listen((web.MouseEvent event) {
    final rect = pdfCanvas.getBoundingClientRect();
    pdfMouseX = event.clientX - rect.left;
    pdfMouseY = event.clientY - rect.top;
    drawCharts();
  });
  pdfCanvas.onMouseLeave.listen((_) {
    pdfMouseX = null;
    pdfMouseY = null;
    drawCharts();
  });

  // Bind mouse hover listeners to CDF Canvas
  cdfCanvas.onMouseMove.listen((web.MouseEvent event) {
    final rect = cdfCanvas.getBoundingClientRect();
    cdfMouseX = event.clientX - rect.left;
    cdfMouseY = event.clientY - rect.top;
    drawCharts();
  });
  cdfCanvas.onMouseLeave.listen((_) {
    cdfMouseX = null;
    cdfMouseY = null;
    drawCharts();
  });

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
    item.className = 'dist-item';
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

/// Filter sidebar items based on input.
void filterSidebar(String query) {
  final lowercaseQuery = query.toLowerCase();
  final items = web.document.querySelectorAll('.dist-item');

  for (var i = 0; i < items.length; i++) {
    final item = items.item(i) as web.HTMLElement;
    final id = item.getAttribute('data-id') ?? '';
    final def = distributions.firstWhere((d) => d.id == id);
    final matches =
        def.name.toLowerCase().contains(lowercaseQuery) ||
        def.description.toLowerCase().contains(lowercaseQuery);

    if (matches) {
      item.style.display = '';
    } else {
      item.style.display = 'none';
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
  final items = web.document.querySelectorAll('.dist-item');
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

  // Reset sampling lab
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

    final copyBtn = web.document.createElement('button') as web.HTMLElement;
    copyBtn.className = 'copy-btn';
    copyBtn.setAttribute('title', 'Copy value');
    copyBtn.innerHTML =
        '''
      <svg class="copy-icon" viewBox="0 0 24 24" width="12" height="12" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round">
        <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
        <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
      </svg>
    '''
            .toJS;

    copyBtn.onClick.listen((_) {
      final val = currentParamValues[index];
      copyToClipboard(param.isInt ? val.toInt().toString() : val.toString());
    });

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

    final def = distributions.firstWhere((d) => d.id == distId);
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
      targetDef ?? distributions.firstWhere((d) => d.id == 'normal');

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
  clearSamples(redraw: false);
  updateTelemetry();
  drawCharts();
  updateEmpiricalStats();
  updateUrlHash();
}

/// Update mathematical properties panel.
void updateTelemetry() {
  valMean.textContent = formatVal(activeDist.mean);
  valMedian.textContent = formatVal(activeDist.median);
  valMode.textContent = formatVal(activeDist.mode);
  valVariance.textContent = formatVal(activeDist.variance);
  valStdDev.textContent = formatVal(activeDist.standardDeviation);
  valSkewness.textContent = formatVal(activeDist.skewness);
  valKurtosis.textContent = formatVal(activeDist.kurtosisExcess);

  // Format bounds
  final lower = activeDist.lowerBound;
  final upper = activeDist.upperBound;
  var lStr = lower.toString();
  var uStr = upper.toString();
  if (lower is double) {
    if (lower.isInfinite) lStr = '-∞';
  } else if (lower is int) {
    if (lower <= -9007199254740991) lStr = '-∞';
  }
  if (upper is double) {
    if (upper.isInfinite) uStr = '∞';
  } else if (upper is int) {
    if (upper >= 9007199254740991) uStr = '∞';
  }

  valBounds.textContent = '[$lStr, $uStr]';

  // Update Theoretical labels in Sampler grid
  tMean.textContent = formatVal(activeDist.mean);
  tVariance.textContent = formatVal(activeDist.variance);
  tStdDev.textContent = formatVal(activeDist.standardDeviation);
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
    final meanVal = activeDist.mean;
    final stdVal = activeDist.standardDeviation;

    if (meanVal.isFinite && stdVal.isFinite && stdVal > 1e-4) {
      minX = meanVal - 4 * stdVal;
      maxX = meanVal + 4 * stdVal;
    } else {
      // Fallback to median
      final medianVal = activeDist.median;
      if (medianVal.isFinite) {
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
  final bounds = getGraphBounds();
  final minX = bounds['min']!;
  final maxX = bounds['max']!;

  renderCanvas(pdfCanvas, isCdf: false, minX: minX, maxX: maxX);

  renderCanvas(cdfCanvas, isCdf: true, minX: minX, maxX: maxX);
}

void renderCanvas(
  web.HTMLCanvasElement canvas, {
  required bool isCdf,
  required double minX,
  required double maxX,
}) {
  final rect = canvas.parentElement?.getBoundingClientRect();
  if (rect == null || rect.width == 0 || rect.height == 0) return;

  final dpr = web.window.devicePixelRatio;
  final width = rect.width;
  final height = rect.height;

  // Scale backing store dynamically for high-DPI crisp rendering
  canvas.width = (width * dpr).toInt();
  canvas.height = (height * dpr).toInt();
  canvas.style.width = '${width}px';
  canvas.style.height = '${height}px';

  final ctx = canvas.context2D;
  ctx.scale(dpr, dpr);

  ctx.clearRect(0, 0, width, height);

  // Set Margin guidelines
  const leftMargin = 55.0;
  const rightMargin = 20.0;
  const topMargin = 20.0;
  const bottomMargin = 36.0;

  final plotWidth = width - leftMargin - rightMargin;
  final plotHeight = height - topMargin - bottomMargin;

  // X & Y Converters
  double toPixelX(double x) =>
      leftMargin + (x - minX) * plotWidth / (maxX - minX);

  double fromPixelX(double px) =>
      minX + (px - leftMargin) * (maxX - minX) / plotWidth;

  // Calculate dynamic Y-axis maximum bounds
  const minY = 0.0;
  var maxY = 1.0;

  if (isCdf) {
    maxY = 1.0;
  } else {
    // Scan X intervals to capture maximum probability density/mass peak
    var peak = 0.0;
    if (activeDef.isContinuous) {
      const steps = 100;
      for (var s = 0; s <= steps; s++) {
        final x = minX + s * (maxX - minX) / steps;
        final p = activeDist.probability(x);
        if (p > peak) {
          peak = p;
        }
      }
    } else {
      // Discrete scanning
      final iMin = minX.floor();
      final iMax = maxX.ceil();
      for (var k = iMin; k <= iMax; k++) {
        final p = activeDist.probability(k.toDouble());
        if (p > peak) {
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

        for (var k = iMin; k <= iMax; k++) {
          final count = freqMap[k] ?? 0;
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

  double toPixelY(double y) =>
      topMargin + plotHeight - (y - minY) * plotHeight / (maxY - minY);

  // ==================== DRAW GRID & LABELS ====================
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.05)'.toJS;
  ctx.lineWidth = 1.0;
  ctx.fillStyle = '#64748b'.toJS;
  ctx.font = '10px Inter, sans-serif';

  // 1. Vertical lines & X ticks
  const xTicks = 6;
  for (var i = 0; i < xTicks; i++) {
    final xVal = minX + i * (maxX - minX) / (xTicks - 1);
    final px = toPixelX(xVal);

    // Line
    ctx.beginPath();
    ctx.moveTo(px, topMargin);
    ctx.lineTo(px, topMargin + plotHeight);
    ctx.stroke();

    // Text Label
    ctx.textAlign = 'center';
    final label = (xVal % 1 == 0)
        ? xVal.toInt().toString()
        : xVal.toStringAsFixed(2);
    ctx.fillText(label, px, topMargin + plotHeight + 15);
  }

  // 2. Horizontal lines & Y ticks
  const yTicks = 5;
  for (var i = 0; i < yTicks; i++) {
    final yVal = minY + i * (maxY - minY) / (yTicks - 1);
    final py = toPixelY(yVal);

    // Line
    ctx.beginPath();
    ctx.moveTo(leftMargin, py);
    ctx.lineTo(leftMargin + plotWidth, py);
    ctx.stroke();

    // Text Label
    ctx.textAlign = 'right';
    ctx.fillText(yVal.toStringAsFixed(3), leftMargin - 8, py + 3);
  }

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

      for (var k = iMin; k <= iMax; k++) {
        final count = freqMap[k] ?? 0;
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

      for (var k = iMin; k <= iMax; k++) {
        final cdfVal = activeDist.cumulativeProbability(k.toDouble());
        final pxStart = toPixelX(k.toDouble());
        final pxEnd = toPixelX((k + 1).toDouble());
        final py = toPixelY(cdfVal);

        // Horizontal step bar
        ctx.beginPath();
        ctx.moveTo(math.max(leftMargin, pxStart), py);
        ctx.lineTo(math.min(leftMargin + plotWidth, pxEnd), py);
        ctx.stroke();

        // Connect vertical jump
        if (k > iMin) {
          final prevCdfVal = activeDist.cumulativeProbability(
            (k - 1).toDouble(),
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
    // ---------------- PDF / PMF PLOTTING ----------------
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
      // Discrete PMF - lollipop lines (vertical line + terminal dot)
      final iMin = minX.floor();
      final iMax = maxX.ceil();

      for (var k = iMin; k <= iMax; k++) {
        final p = activeDist.probability(k.toDouble());
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

  // Draw chart border box boundaries
  ctx.strokeStyle = 'rgba(255, 255, 255, 0.1)'.toJS;
  ctx.lineWidth = 1.0;
  ctx.beginPath();
  ctx.rect(leftMargin, topMargin, plotWidth, plotHeight);
  ctx.stroke();

  // ==================== PLOT ATTRIBUTE REFERENCE LINES ====================
  ctx.save();
  ctx.lineWidth = 1.0;
  ctx.setLineDash([4.toJS, 4.toJS].toJS);

  final meanVal = activeDist.mean;
  if (meanVal.isFinite && meanVal >= minX && meanVal <= maxX) {
    final px = toPixelX(meanVal);
    ctx.strokeStyle = 'rgba(239, 68, 68, 0.7)'.toJS; // Coral Red
    ctx.beginPath();
    ctx.moveTo(px, topMargin);
    ctx.lineTo(px, topMargin + plotHeight);
    ctx.stroke();

    ctx.fillStyle = '#ef4444'.toJS;
    ctx.font = '9px monospace';
    ctx.textAlign = 'center';
    ctx.fillText('μ', px, topMargin - 4);
  }

  final medianVal = activeDist.median;
  if (medianVal.isFinite && medianVal >= minX && medianVal <= maxX) {
    final px = toPixelX(medianVal);
    ctx.strokeStyle = 'rgba(16, 185, 129, 0.7)'.toJS; // Emerald
    ctx.beginPath();
    ctx.moveTo(px, topMargin);
    ctx.lineTo(px, topMargin + plotHeight);
    ctx.stroke();

    ctx.fillStyle = '#10b981'.toJS;
    ctx.font = '9px monospace';
    ctx.textAlign = 'center';
    var yOffset = topMargin - 4;
    if (meanVal.isFinite &&
        (medianVal - meanVal).abs() < (maxX - minX) * 0.05) {
      yOffset = topMargin - 14; // Stack text slightly higher if they overlap
    }
    ctx.fillText('med', px, yOffset);
  }

  final modeVal = activeDist.mode;
  if (modeVal.isFinite && modeVal >= minX && modeVal <= maxX) {
    final px = toPixelX(modeVal);
    ctx.strokeStyle = 'rgba(168, 85, 247, 0.7)'.toJS; // Purple
    ctx.beginPath();
    ctx.moveTo(px, topMargin);
    ctx.lineTo(px, topMargin + plotHeight);
    ctx.stroke();

    ctx.fillStyle = '#a855f7'.toJS;
    ctx.font = '9px monospace';
    ctx.textAlign = 'center';
    var yOffset = topMargin - 4;
    final closeToMean =
        meanVal.isFinite && (modeVal - meanVal).abs() < (maxX - minX) * 0.05;
    final closeToMedian =
        medianVal.isFinite &&
        (modeVal - medianVal).abs() < (maxX - minX) * 0.05;
    if (closeToMean || closeToMedian) {
      yOffset = (closeToMean && closeToMedian)
          ? topMargin - 24
          : topMargin - 14;
    }
    ctx.fillText('mode', px, yOffset);
  }

  ctx.restore();

  // ==================== INTERACTIVE HOVER COORDINATES ====================
  final mouseX = isCdf ? cdfMouseX : pdfMouseX;
  final mouseY = isCdf ? cdfMouseY : pdfMouseY;

  if (mouseX != null && mouseY != null) {
    // Only show hover if mouse is inside the boundaries of the plotting area
    if (mouseX >= leftMargin &&
        mouseX <= leftMargin + plotWidth &&
        mouseY >= topMargin &&
        mouseY <= topMargin + plotHeight) {
      final xVal = fromPixelX(mouseX);

      // Determine discrete target k
      final k = xVal.round();
      final targetX = activeDef.isContinuous ? xVal : k.toDouble();

      final yVal = isCdf
          ? activeDist.cumulativeProbability(targetX)
          : activeDist.probability(targetX);
      final hasVal = yVal.isFinite && !yVal.isNaN && yVal >= 0.0;

      if (hasVal) {
        final px = toPixelX(targetX);
        final py = toPixelY(yVal).clamp(topMargin, topMargin + plotHeight);

        ctx.save();

        // 1. Draw glowing vertical crosshair line
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.25)'.toJS;
        ctx.lineWidth = 1.0;
        ctx.beginPath();
        ctx.moveTo(px, topMargin);
        ctx.lineTo(px, topMargin + plotHeight);
        ctx.stroke();

        // 2. Draw glowing dot on the curve
        final colorStr = isCdf
            ? '#f59e0b'
            : (activeDef.isContinuous ? '#3b82f6' : '#10b981');

        ctx.fillStyle = '${colorStr}3b'.toJS; // 23% opacity glow
        ctx.beginPath();
        ctx.arc(px, py, 6.0, 0.0, 2 * math.pi);
        ctx.fill();

        ctx.fillStyle = colorStr.toJS; // Solid dot
        ctx.beginPath();
        ctx.arc(px, py, 3.0, 0.0, 2 * math.pi);
        ctx.fill();

        // 3. Draw premium floating tooltip card
        const tooltipW = 125.0;
        const tooltipH = 50.0;

        // Offset card horizontally to avoid overlapping cursor
        var tooltipX = px + 12.0;
        if (tooltipX + tooltipW > leftMargin + plotWidth) {
          tooltipX = px - tooltipW - 12.0;
        }

        // Center card vertically relative to target dot, clamp inside margins
        var tooltipY = py - tooltipH - 12.0;
        if (tooltipY < topMargin) {
          tooltipY = py + 12.0;
        }
        if (tooltipY + tooltipH > topMargin + plotHeight) {
          tooltipY = topMargin + plotHeight - tooltipH;
        }

        // Draw card background (slate dark transparent glassmorphic)
        ctx.fillStyle = 'rgba(15, 23, 42, 0.88)'.toJS;
        ctx.strokeStyle = 'rgba(255, 255, 255, 0.12)'.toJS;
        ctx.lineWidth = 1.0;
        ctx.beginPath();
        ctx.rect(tooltipX, tooltipY, tooltipW, tooltipH);
        ctx.fill();
        ctx.stroke();

        // Write tooltip labels
        ctx.fillStyle = '#f8fafc'.toJS;
        ctx.font = 'bold 11px Inter, sans-serif';
        ctx.textAlign = 'left';

        final labelX = activeDef.isContinuous
            ? 'x: ${targetX.toStringAsFixed(4)}'
            : 'k: ${k.toInt()}';
        final labelY = isCdf
            ? 'F(x): ${yVal.toStringAsFixed(4)}'
            : (activeDef.isContinuous
                  ? 'f(x): ${yVal.toStringAsFixed(4)}'
                  : 'P(k): ${yVal.toStringAsFixed(4)}');

        ctx.fillText(labelX, tooltipX + 8.0, tooltipY + 18.0);

        ctx.fillStyle = 'rgba(248, 250, 252, 0.7)'.toJS;
        ctx.font = '10px Inter, sans-serif';
        ctx.fillText(labelY, tooltipX + 8.0, tooltipY + 36.0);

        ctx.restore();
      }
    }
  }
}

// ==================== RANDOM SAMPLING LAB ENGINE ====================

/// Draw N random samples from the active distribution.
void drawSamples(int count) {
  final newSamples = activeDist
      .samples()
      .where((sample) => sample.isFinite)
      .take(count)
      .toList();
  generatedSamples.addAll(newSamples);
  sampleCountBadge.textContent = generatedSamples.length.toString();
  btnSampleCopyAll.style.display = 'inline-flex';
  renderRecentChips(newSamples);
  updateEmpiricalStats();
  drawCharts();
}

/// Clear active samples context.
void clearSamples({bool redraw = true}) {
  generatedSamples.clear();
  sampleCountBadge.textContent = '0';
  btnSampleCopyAll.style.display = 'none';
  samplesChipsContainer.innerHTML = ''.toJS;

  final noSamplesMsg = web.document.createElement('span') as web.HTMLElement;
  noSamplesMsg.style.color = 'var(--text-muted)';
  noSamplesMsg.style.fontSize = '12px';
  noSamplesMsg.style.fontStyle = 'italic';
  noSamplesMsg.textContent =
      'No samples generated yet. Click above to start drawing!';
  samplesChipsContainer.appendChild(noSamplesMsg);

  updateEmpiricalStats();
  if (redraw) {
    drawCharts();
  }
}

/// Render samples as chips inside the list. Only shows up to 100.
void renderRecentChips(List<num> recentDraws) {
  // If first samples, clear placeholder message
  if (generatedSamples.length == recentDraws.length) {
    samplesChipsContainer.innerHTML = ''.toJS;
  }

  // Add the newly generated ones with a flash animation
  final int visibleRecent = math.min(recentDraws.length, 30);
  for (
    var i = recentDraws.length - visibleRecent;
    i < recentDraws.length;
    i++
  ) {
    final s = recentDraws[i];
    final chip = web.document.createElement('span') as web.HTMLElement;
    chip.className = 'sample-chip new';
    final formattedVal = activeDef.isContinuous
        ? s.toStringAsFixed(4)
        : s.toInt().toString();
    chip.textContent = formattedVal;
    chip.style.cursor = 'pointer';
    chip.title = 'Click to copy';
    chip.onClick.listen((_) {
      copyToClipboard(formattedVal);
    });

    // Prepend to display latest values first
    if (samplesChipsContainer.firstChild != null) {
      samplesChipsContainer.insertBefore(
        chip,
        samplesChipsContainer.firstChild,
      );
    } else {
      samplesChipsContainer.appendChild(chip);
    }
  }

  // Truncate list items inside container to prevent slow rendering
  final children = samplesChipsContainer.children;
  if (children.length > 100) {
    for (var i = children.length - 1; i >= 100; i--) {
      final child = children.item(i);
      if (child != null) {
        samplesChipsContainer.removeChild(child);
      }
    }
  }
}

/// Compute empirical statistics of drawn samples and update table.
void updateEmpiricalStats() {
  if (generatedSamples.isEmpty) {
    eMean.textContent = '-';
    eVariance.textContent = '-';
    eStdDev.textContent = '-';
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

  // Update UI Elements
  eMean.textContent = formatVal(empiricalMean);
  eVariance.textContent = formatVal(empiricalVar);
  eStdDev.textContent = formatVal(empiricalStd);
}
