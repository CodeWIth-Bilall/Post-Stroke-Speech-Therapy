import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:wav/wav.dart';

/// Pure-Dart MFCC feature extractor.
///
/// Extracts Mel-frequency cepstral coefficients from a WAV file,
/// matching standard librosa defaults so the features are compatible
/// with TFLite GRU models trained in Python.
class MfccExtractor {
  // ─── Default parameters (librosa defaults) ───
  final int sampleRate;
  final int nFft;
  final int hopLength;
  final int nMels;
  final int nMfcc;
  final double preEmphasis;

  const MfccExtractor({
    this.sampleRate = 16000,
    this.nFft = 2048,
    this.hopLength = 512,
    this.nMels = 128,
    this.nMfcc = 13,
    this.preEmphasis = 0.97,
  });

  /// Extract MFCC features from a WAV file on disk.
  ///
  /// Returns a 2D list: `[timeSteps][nMfcc]`.
  /// Throws if the file cannot be read.
  Future<List<List<double>>> extractFromFile(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException('WAV file not found', filePath);
    }

    // Read WAV
    final wav = await Wav.readFile(filePath);
    // Take first (mono) channel
    final samples = wav.channels[0];

    return extractFromSamples(samples);
  }

  /// Extract MFCC features from raw PCM samples (doubles, normalised -1..1).
  List<List<double>> extractFromSamples(List<double> rawSamples) {
    if (rawSamples.isEmpty) return [];

    // 1. Pre-emphasis
    final emphasised = _preEmphasise(rawSamples);

    // 2. Framing + Hamming window
    final frames = _frame(emphasised);
    if (frames.isEmpty) return [];

    // 3. FFT → power spectrum for each frame
    final powerSpectra = frames.map(_powerSpectrum).toList();

    // 4. Mel filterbank
    final melFilterbank = _melFilterbank();

    // 5. Apply filterbank → log → DCT → MFCC
    final mfccs = <List<double>>[];
    for (final spectrum in powerSpectra) {
      // Apply mel filters
      final melEnergies = List<double>.filled(nMels, 0.0);
      for (int m = 0; m < nMels; m++) {
        double sum = 0.0;
        for (int k = 0; k < melFilterbank[m].length; k++) {
          sum += melFilterbank[m][k] * spectrum[k];
        }
        melEnergies[m] = sum;
      }

      // Log compression (add small epsilon to avoid log(0))
      for (int m = 0; m < nMels; m++) {
        melEnergies[m] = log(melEnergies[m] + 1e-10);
      }

      // DCT-II (type 2) to get MFCCs
      final coefficients = _dctII(melEnergies, nMfcc);
      mfccs.add(coefficients);
    }

    return mfccs;
  }

  // ─── Pre-emphasis filter ───────────────────────────────────────────────
  List<double> _preEmphasise(List<double> samples) {
    final result = List<double>.filled(samples.length, 0.0);
    result[0] = samples[0];
    for (int i = 1; i < samples.length; i++) {
      result[i] = samples[i] - preEmphasis * samples[i - 1];
    }
    return result;
  }

  // ─── Framing with Hamming window ──────────────────────────────────────
  List<Float64List> _frame(List<double> samples) {
    final hammingWindow = _hammingWindow(nFft);
    final frames = <Float64List>[];
    int start = 0;

    while (start + nFft <= samples.length) {
      final frame = Float64List(nFft);
      for (int i = 0; i < nFft; i++) {
        frame[i] = samples[start + i] * hammingWindow[i];
      }
      frames.add(frame);
      start += hopLength;
    }

    // Handle last partial frame by zero-padding
    if (start < samples.length) {
      final frame = Float64List(nFft);
      final remaining = samples.length - start;
      for (int i = 0; i < remaining; i++) {
        frame[i] = samples[start + i] * hammingWindow[i];
      }
      // Rest is already zero
      frames.add(frame);
    }

    return frames;
  }

  Float64List _hammingWindow(int length) {
    final window = Float64List(length);
    for (int i = 0; i < length; i++) {
      window[i] = 0.54 - 0.46 * cos(2.0 * pi * i / (length - 1));
    }
    return window;
  }

  // ─── Power spectrum via FFT ───────────────────────────────────────────
  Float64List _powerSpectrum(Float64List frame) {
    // Radix-2 FFT
    final n = frame.length;
    final real = Float64List.fromList(frame);
    final imag = Float64List(n);
    _fft(real, imag);

    // Power spectrum: |X(k)|² / N, only first half + 1 (nFft/2 + 1 bins)
    final bins = n ~/ 2 + 1;
    final power = Float64List(bins);
    for (int k = 0; k < bins; k++) {
      power[k] = (real[k] * real[k] + imag[k] * imag[k]) / n;
    }
    return power;
  }

  /// In-place radix-2 Cooley-Tukey FFT.
  void _fft(Float64List real, Float64List imag) {
    final n = real.length;
    if (n <= 1) return;

    // Bit-reversal permutation
    int j = 0;
    for (int i = 0; i < n - 1; i++) {
      if (i < j) {
        double tmpR = real[i];
        double tmpI = imag[i];
        real[i] = real[j];
        imag[i] = imag[j];
        real[j] = tmpR;
        imag[j] = tmpI;
      }
      int m = n >> 1;
      while (m >= 1 && j >= m) {
        j -= m;
        m >>= 1;
      }
      j += m;
    }

    // Butterfly operations
    for (int size = 2; size <= n; size <<= 1) {
      final halfSize = size >> 1;
      final angle = -2.0 * pi / size;
      final wR = cos(angle);
      final wI = sin(angle);

      for (int start = 0; start < n; start += size) {
        double curR = 1.0;
        double curI = 0.0;

        for (int k = 0; k < halfSize; k++) {
          final evenIdx = start + k;
          final oddIdx = start + k + halfSize;

          final tR = curR * real[oddIdx] - curI * imag[oddIdx];
          final tI = curR * imag[oddIdx] + curI * real[oddIdx];

          real[oddIdx] = real[evenIdx] - tR;
          imag[oddIdx] = imag[evenIdx] - tI;
          real[evenIdx] += tR;
          imag[evenIdx] += tI;

          // Rotate twiddle factor
          final newCurR = curR * wR - curI * wI;
          curI = curR * wI + curI * wR;
          curR = newCurR;
        }
      }
    }
  }

  // ─── Mel filterbank ───────────────────────────────────────────────────
  List<Float64List> _melFilterbank() {
    final bins = nFft ~/ 2 + 1;
    final fMin = 0.0;
    final fMax = sampleRate / 2.0;

    final melMin = _hzToMel(fMin);
    final melMax = _hzToMel(fMax);

    // nMels + 2 equally spaced points in mel scale
    final melPoints = List<double>.generate(
      nMels + 2,
      (i) => melMin + i * (melMax - melMin) / (nMels + 1),
    );

    // Convert back to Hz then to FFT bin indices
    final hzPoints = melPoints.map(_melToHz).toList();
    final binIndices = hzPoints.map((hz) {
      return ((nFft + 1) * hz / sampleRate).floor();
    }).toList();

    // Create triangular filters
    final filterbank = <Float64List>[];
    for (int m = 0; m < nMels; m++) {
      final filter = Float64List(bins);
      final startBin = binIndices[m];
      final peakBin = binIndices[m + 1];
      final endBin = binIndices[m + 2];

      // Rising slope
      for (int k = startBin; k < peakBin && k < bins; k++) {
        if (peakBin != startBin) {
          filter[k] = (k - startBin) / (peakBin - startBin);
        }
      }

      // Falling slope
      for (int k = peakBin; k < endBin && k < bins; k++) {
        if (endBin != peakBin) {
          filter[k] = (endBin - k) / (endBin - peakBin);
        }
      }

      filterbank.add(filter);
    }

    return filterbank;
  }

  double _hzToMel(double hz) => 2595.0 * log(1.0 + hz / 700.0) / ln10;
  double _melToHz(double mel) => 700.0 * (pow(10.0, mel / 2595.0) - 1.0);

  // ─── DCT Type-II ─────────────────────────────────────────────────────
  List<double> _dctII(List<double> input, int numCoeffs) {
    final n = input.length;
    final result = List<double>.filled(numCoeffs, 0.0);

    for (int k = 0; k < numCoeffs; k++) {
      double sum = 0.0;
      for (int i = 0; i < n; i++) {
        sum += input[i] * cos(pi * k * (2 * i + 1) / (2 * n));
      }
      result[k] = sum;
    }

    return result;
  }
}
