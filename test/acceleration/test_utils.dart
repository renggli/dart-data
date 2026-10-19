import 'dart:async';

import 'package:checks/checks.dart';
import 'package:data/acceleration.dart';
import 'package:meta/meta.dart';
import 'package:test/test.dart';

/// Runs [body] under different [AccelerationMode] settings in separate tests
/// within a group named [description].
///
/// - [AccelerationMode.auto]: normal successful test run.
/// - [AccelerationMode.dart]: normal successful test run.
/// - [AccelerationMode.accelerated]: normal successful test run if acceleration
///   is supported, or asserts that an [AccelerationUnavailableError] is thrown if not supported.
@isTestGroup
void accelerationTest(
  String description,
  FutureOr<void> Function() body, {
  bool? isSupported,
}) {
  group(description, () {
    test('auto', () async {
      final previousMode = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.auto;
        final result = body();
        if (result is Future) {
          await result;
        }
      } finally {
        AccelerationManager.mode = previousMode;
      }
    });

    test('dart', () async {
      final previousMode = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.dart;
        final result = body();
        if (result is Future) {
          await result;
        }
      } finally {
        AccelerationManager.mode = previousMode;
      }
    });

    test('accelerated', () async {
      final previousMode = AccelerationManager.mode;
      try {
        AccelerationManager.mode = AccelerationMode.accelerated;
        final supported = isSupported ?? AccelerationManager.isAccelerated;
        if (supported) {
          final result = body();
          if (result is Future) {
            await result;
          }
        } else {
          await check(Future.sync(body)).throws<AccelerationUnavailableError>();
        }
      } finally {
        AccelerationManager.mode = previousMode;
      }
    });
  });
}
