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

List<ffi.DynamicLibrary> _openLibraries(List<String> names) {
  final libs = <ffi.DynamicLibrary>[];
  final rtldFlags = (Platform.isMacOS || Platform.isIOS)
      ? (0x1 | 0x8) // RTLD_LAZY | RTLD_GLOBAL on Darwin
      : (0x1 | 0x100); // RTLD_LAZY | RTLD_GLOBAL on Linux/Android
  for (final name in names) {
    try {
      libs.add(ffi.DynamicLibrary.open(name));
      if (!Platform.isWindows) {
        using((arena) {
          final str = name.toNativeUtf8(allocator: arena);
          _posixDlopen(str.cast(), rtldFlags);
        });
      }
    } catch (_) {
      // Dynamic library probing: ignore missing candidate libraries.
    }
  }
  return libs;
}

List<ffi.DynamicLibrary> _loadBlasLibraries() {
  try {
    if (Platform.isMacOS || Platform.isIOS) {
      return _openLibraries(const [
        '/System/Library/Frameworks/Accelerate.framework/Accelerate',
        'libBLAS.dylib',
        'liblapack.dylib',
      ]);
    } else if (Platform.isLinux || Platform.isAndroid) {
      return _openLibraries(const [
        'libopenblas.so.0',
        'libopenblas.so',
        'liblapacke.so.3',
        'liblapacke.so',
        'libblas.so.3',
        'liblapack.so.3',
      ]);
    } else if (Platform.isWindows) {
      return _openLibraries(const [
        'openblas.dll',
        'libopenblas.dll',
        'liblapacke.dll',
        'lapack.dll',
      ]);
    }
  } catch (_) {
    // Dynamic library candidate probing: catch failed opens across search paths.
  }
  return <ffi.DynamicLibrary>[];
}

List<ffi.DynamicLibrary> _loadVdspLibraries() {
  if (!Platform.isMacOS && !Platform.isIOS) return <ffi.DynamicLibrary>[];
  return _openLibraries(const [
    '/System/Library/Frameworks/Accelerate.framework/Accelerate',
  ]);
}

List<ffi.DynamicLibrary> _loadFftLibraries() {
  try {
    if (Platform.isMacOS || Platform.isIOS) {
      return _openLibraries(const [
        '/System/Library/Frameworks/Accelerate.framework/Accelerate',
        '/opt/homebrew/lib/libfftw3.dylib',
        '/usr/local/lib/libfftw3.dylib',
        'libfftw3.dylib',
      ]);
    } else if (Platform.isLinux || Platform.isAndroid) {
      return _openLibraries(const ['libfftw3.so.3', 'libfftw3.so']);
    } else if (Platform.isWindows) {
      return _openLibraries(const ['libfftw3-3.dll', 'fftw3.dll']);
    }
  } catch (_) {
    // Dynamic library candidate probing: catch failed opens across search paths.
  }
  return <ffi.DynamicLibrary>[];
}

@ffi.Native<ffi.Pointer<ffi.Void> Function(ffi.Pointer<ffi.Char>, ffi.Int32)>(
  symbol: 'dlopen',
  isLeaf: true,
)
external ffi.Pointer<ffi.Void> _posixDlopen(
  ffi.Pointer<ffi.Char> filename,
  int flags,
);
