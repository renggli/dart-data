// coverage:ignore-file

import 'dart:ffi' as ffi;
import 'dart:io' show Platform;

import 'package:ffi/ffi.dart';

List<ffi.DynamicLibrary>? _cachedBlasLibs;
List<ffi.DynamicLibrary>? _cachedVdspLibs;
List<ffi.DynamicLibrary>? _cachedFftLibs;

/// Loads and caches platform BLAS/LAPACK dynamic libraries.
List<ffi.DynamicLibrary> get platformBlasLibraries =>
    _cachedBlasLibs ??= _loadBlasLibraries();

/// Loads and caches platform vDSP/vForce dynamic libraries.
List<ffi.DynamicLibrary> get platformVdspLibraries =>
    _cachedVdspLibs ??= _loadVdspLibraries();

/// Loads and caches platform FFT dynamic libraries (vDSP on Apple, FFTW on Linux/Android/Windows).
List<ffi.DynamicLibrary> get platformFftLibraries =>
    _cachedFftLibs ??= _loadFftLibraries();

/// Checks if [symbolName] exists across any of [libraries].
bool hasSymbol(String symbolName, List<ffi.DynamicLibrary> libraries) {
  for (final lib in libraries) {
    if (lib.providesSymbol(symbolName)) return true;
  }
  return false;
}

List<ffi.DynamicLibrary> _loadBlasLibraries() {
  final libs = <ffi.DynamicLibrary>[];
  void tryOpen(String name) {
    try {
      libs.add(ffi.DynamicLibrary.open(name));
      if (!Platform.isWindows) {
        using((arena) {
          final str = name.toNativeUtf8(allocator: arena);
          _posixDlopen(str.cast(), 1 | 0x100);
        });
      }
    } catch (_) {
      // Dynamic library probing: ignore missing candidate libraries.
    }
  }

  // Dynamic library candidate probing: catch failed opens across search paths.
  try {
    if (Platform.isMacOS || Platform.isIOS) {
      for (final name in [
        '/System/Library/Frameworks/Accelerate.framework/Accelerate',
        'libBLAS.dylib',
        'liblapack.dylib',
      ]) {
        tryOpen(name);
      }
    } else if (Platform.isLinux || Platform.isAndroid) {
      for (final name in [
        'libopenblas.so.0',
        'libopenblas.so',
        'liblapacke.so.3',
        'liblapacke.so',
        'libblas.so.3',
        'liblapack.so.3',
      ]) {
        tryOpen(name);
      }
    } else if (Platform.isWindows) {
      for (final name in [
        'openblas.dll',
        'libopenblas.dll',
        'liblapacke.dll',
        'lapack.dll',
      ]) {
        tryOpen(name);
      }
    }
  } catch (_) {
    // Dynamic library candidate probing: catch failed opens across search paths.
  }
  return libs;
}

List<ffi.DynamicLibrary> _loadVdspLibraries() {
  final libs = <ffi.DynamicLibrary>[];
  if (!Platform.isMacOS && !Platform.isIOS) return libs;

  // Dynamic library candidate probing: catch failed opens.
  try {
    libs.add(
      ffi.DynamicLibrary.open(
        '/System/Library/Frameworks/Accelerate.framework/Accelerate',
      ),
    );
  } catch (_) {
    // Dynamic library probing: ignore missing candidate library.
  }
  return libs;
}

List<ffi.DynamicLibrary> _loadFftLibraries() {
  final libs = <ffi.DynamicLibrary>[];
  void tryOpen(String name) {
    try {
      libs.add(ffi.DynamicLibrary.open(name));
      if (!Platform.isWindows) {
        using((arena) {
          final str = name.toNativeUtf8(allocator: arena);
          _posixDlopen(str.cast(), 1 | 0x100);
        });
      }
    } catch (_) {
      // Dynamic library probing: ignore missing candidate libraries.
    }
  }

  // Dynamic library candidate probing: catch failed opens across search paths.
  try {
    if (Platform.isMacOS || Platform.isIOS) {
      tryOpen('/System/Library/Frameworks/Accelerate.framework/Accelerate');
      for (final name in [
        '/opt/homebrew/lib/libfftw3.dylib',
        '/usr/local/lib/libfftw3.dylib',
        'libfftw3.dylib',
      ]) {
        tryOpen(name);
      }
    } else if (Platform.isLinux || Platform.isAndroid) {
      for (final name in ['libfftw3.so.3', 'libfftw3.so']) {
        tryOpen(name);
      }
    } else if (Platform.isWindows) {
      for (final name in ['libfftw3-3.dll', 'fftw3.dll']) {
        tryOpen(name);
      }
    }
  } catch (_) {
    // Dynamic library candidate probing: catch failed opens across search paths.
  }
  return libs;
}

@ffi.Native<ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>, ffi.Int32)>(
  symbol: 'dlopen',
  isLeaf: true,
)
external ffi.Pointer<ffi.Void> _posixDlopen(
  ffi.Pointer<ffi.Char> filename,
  int flags,
);
