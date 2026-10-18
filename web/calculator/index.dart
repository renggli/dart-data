import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'src/ui/app.dart';

void main() {
  final app = CalculatorApp();
  unawaited(app.init());
  _registerServiceWorker();
}

void _registerServiceWorker() {
  try {
    final host = web.window.location.hostname;
    if (host == 'localhost' || host == '127.0.0.1' || host == '[::1]') {
      return;
    }
    final sw = web.window.navigator.serviceWorker;
    sw.register('sw.js'.toJS);
  } catch (_) {
    // Ignore in environments without ServiceWorker support
  }
}
