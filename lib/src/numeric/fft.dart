import 'package:more/number.dart' show Complex;

import '../acceleration/acceleration_manager.dart';

/// Computes the 1-dimensional Discrete Fourier Transform (FFT) of [input].
///
/// Conceptually, the Fast Fourier Transform acts like a prism:
/// it decomposes a signal measured over time into its constituent
/// sinusoidal frequencies and their corresponding amplitudes and phases.
/// Formally, it computes the discrete Fourier transform $X_k = \sum_{n=0}^{N-1} x_n e^{-2\pi i k n / N}$
/// using the Cooley-Tukey decimation-in-time radix-2 algorithm in $\mathcal{O}(N \log N)$ time,
/// with native vDSP hardware acceleration when available.
/// Inputs are zero-padded to the next power of 2 if needed.
///
/// ```dart
/// final signal = [Complex(1.0, 0.0), Complex(1.0, 0.0), Complex(0.0, 0.0), Complex(0.0, 0.0)];
/// final spectrum = fft(signal);
/// ```
List<Complex> fft(Iterable<Complex> input) => AccelerationManager.fft(input);

/// Computes the 1-dimensional Inverse Discrete Fourier Transform (IFFT) of [input].
///
/// Conceptually, this reverses the FFT, synthesizing the original time-domain
/// signal from its frequency spectrum.
/// Formally, it computes $x_n = \frac{1}{N} \sum_{k=0}^{N-1} X_k e^{2\pi i k n / N}$
/// satisfying $\text{ifft}(\text{fft}(x)) = x$.
///
/// ```dart
/// final signal = [Complex(1.0, 0.0), Complex(1.0, 0.0), Complex(0.0, 0.0), Complex(0.0, 0.0)];
/// final spectrum = fft(signal);
/// final reconstructed = ifft(spectrum);
/// ```
List<Complex> ifft(Iterable<Complex> input) => AccelerationManager.ifft(input);

/// Computes the 1-dimensional Discrete Fourier Transform for real-valued [input].
///
/// For purely real-valued input signals (such as audio samples),
/// this computes the frequency spectrum without requiring prior conversion to complex numbers.
/// Formally, it exploits Hermitian conjugate symmetry $X_{N-k} = X_k^*$
/// for real sequences, returning only non-redundant frequencies of length $N/2 + 1$.
///
/// ```dart
/// final realSignal = [1.0, 2.0, 3.0, 4.0];
/// final spectrum = rfft(realSignal);
/// ```
List<Complex> rfft(Iterable<num> input) => AccelerationManager.rfft(input);

/// Computes the Inverse Discrete Fourier Transform for real-valued signals from
/// positive frequency spectrum [input].
///
/// Conceptually, this reconstructs the original real-valued time-domain signal from its
/// one-sided frequency spectrum.
/// Formally, it synthesizes the full Hermitian symmetric spectrum and computes
/// the inverse DFT, discarding numerical imaginary roundoff artifacts.
///
/// If [n] is not provided, it defaults to $2 \times (\text{input.length} - 1)$.
///
/// ```dart
/// final realSignal = [1.0, 2.0, 3.0, 4.0];
/// final spectrum = rfft(realSignal);
/// final restored = irfft(spectrum, realSignal.length);
/// ```
List<double> irfft(List<Complex> input, [int? n]) =>
    AccelerationManager.irfft(input, n);

/// Computes the 2-dimensional Discrete Fourier Transform of [matrix].
///
/// Conceptually, 2D FFT analyzes 2D grids (such as images or spatial fields) to identify
/// directional wave patterns, textures, and spatial frequencies.
/// Formally, it computes the separable 2D DFT by transforming rows then columns
/// in $\mathcal{O}(M N \log(M N))$ time with hardware acceleration when available.
///
/// ```dart
/// final image = [
///   [Complex(1.0, 0.0), Complex(2.0, 0.0)],
///   [Complex(3.0, 0.0), Complex(4.0, 0.0)],
/// ];
/// final spectrum2d = fft2(image);
/// ```
List<List<Complex>> fft2(List<List<Complex>> matrix) =>
    AccelerationManager.fft2(matrix);

/// Computes the 2-dimensional Inverse Discrete Fourier Transform of [matrix].
///
/// Conceptually, this reconstructs a 2D spatial grid or image from its 2D frequency spectrum.
/// Formally, it applies the 2D inverse DFT satisfying $\text{ifft2}(\text{fft2}(A)) = A$.
///
/// ```dart
/// final image = [
///   [Complex(1.0, 0.0), Complex(2.0, 0.0)],
///   [Complex(3.0, 0.0), Complex(4.0, 0.0)],
/// ];
/// final restored = ifft2(fft2(image));
/// ```
List<List<Complex>> ifft2(List<List<Complex>> matrix) =>
    AccelerationManager.ifft2(matrix);
