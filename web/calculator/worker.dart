import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'src/worker/protocol.dart';

@JS('self')
external web.DedicatedWorkerGlobalScope get _self;

void main() {
  final dispatcher = WorkerDispatcher();

  _self.onmessage = ((web.MessageEvent event) {
    final raw = (event.data as JSString).toDart;
    final jsonMap = (jsonDecode(raw) as Map).cast<String, Object?>();
    final request = WorkerRequest.fromJson(jsonMap);
    final response = dispatcher.handle(request);
    _self.postMessage(jsonEncode(response.toJson()).toJS);
  }).toJS;
}
