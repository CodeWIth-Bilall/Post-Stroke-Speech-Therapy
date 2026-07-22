import 'dart:developer' as dev;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'mfcc_extractor.dart';

/// Service for running the GRU-based fluency TFLite model.
///
/// Loads `final_wordcount_model.tflite`, auto-detects its input/output
/// tensor shapes, and runs inference on MFCC features to produce a
/// normalised fluency score (0–100).
class FluencyModelService {
  static const String _modelAsset = 'assets/models/final_wordcount_model.tflite';

  Interpreter? _interpreter;
  bool _isLoaded = false;

  // Discovered tensor shapes (populated on load)
  List<int> _inputShape = [];
  List<int> _outputShape = [];

  final MfccExtractor _mfccExtractor;

  bool get isLoaded => _isLoaded;

  FluencyModelService({MfccExtractor? mfccExtractor})
      : _mfccExtractor = mfccExtractor ?? const MfccExtractor();

  /// Load the TFLite model and discover its tensor shapes.
  Future<bool> loadModel() async {
    if (_isLoaded) return true;

    try {
      _interpreter = await Interpreter.fromAsset(_modelAsset);

      // Discover input tensor shape
      final inputTensors = _interpreter!.getInputTensors();
      if (inputTensors.isNotEmpty) {
        _inputShape = inputTensors.first.shape;
        dev.log(
          'FluencyModel input tensor: shape=$_inputShape, '
          'type=${inputTensors.first.type}',
          name: 'FluencyModelService',
        );
      }

      // Discover output tensor shape
      final outputTensors = _interpreter!.getOutputTensors();
      if (outputTensors.isNotEmpty) {
        _outputShape = outputTensors.first.shape;
        dev.log(
          'FluencyModel output tensor: shape=$_outputShape, '
          'type=${outputTensors.first.type}',
          name: 'FluencyModelService',
        );
      }

      _isLoaded = true;
      dev.log('FluencyModel loaded successfully', name: 'FluencyModelService');
      return true;
    } catch (e) {
      dev.log(
        'Failed to load FluencyModel: $e',
        name: 'FluencyModelService',
        error: e,
      );
      _isLoaded = false;
      return false;
    }
  }

  /// Run inference on the audio file at [audioPath].
  ///
  /// Returns a fluency score in the range 0.0–100.0.
  /// If the model is not loaded or inference fails, returns -1.0 to indicate
  /// that the fluency score is unavailable (screens should handle gracefully).
  Future<double> runInference(String audioPath) async {
    if (!_isLoaded || _interpreter == null) {
      dev.log('Model not loaded, skipping inference', name: 'FluencyModelService');
      return -1.0;
    }

    if (audioPath.isEmpty) {
      dev.log('No audio path provided, skipping inference', name: 'FluencyModelService');
      return -1.0;
    }

    try {
      // 1. Extract MFCC features from the audio file
      final mfccFeatures = await _mfccExtractor.extractFromFile(audioPath);

      if (mfccFeatures.isEmpty) {
        dev.log('No MFCC features extracted', name: 'FluencyModelService');
        return -1.0;
      }

      // 2. Prepare input tensor matching model's expected shape
      final inputTensor = _prepareInput(mfccFeatures);

      // 3. Prepare output buffer
      final outputBuffer = _prepareOutput();

      // 4. Run inference
      _interpreter!.run(inputTensor, outputBuffer);

      // 5. Interpret output as fluency score
      final score = _interpretOutput(outputBuffer);

      dev.log(
        'Fluency inference complete: raw_output=$outputBuffer, score=$score',
        name: 'FluencyModelService',
      );

      return score;
    } catch (e) {
      dev.log(
        'Inference failed: $e',
        name: 'FluencyModelService',
        error: e,
      );
      return -1.0;
    }
  }

  /// Prepare input tensor from MFCC features.
  ///
  /// The model expects shape `[batch, timeSteps, features]`.
  /// We pad or truncate to match the model's expected time steps.
  dynamic _prepareInput(List<List<double>> mfccFeatures) {
    // Model input shape is typically [1, timeSteps, nFeatures]
    if (_inputShape.length < 3) {
      // Fallback: try to use the features as-is
      dev.log(
        'Unexpected input shape $_inputShape, attempting flat input',
        name: 'FluencyModelService',
      );
      return [mfccFeatures];
    }

    final expectedTimeSteps = _inputShape[1];
    final expectedFeatures = _inputShape[2];

    // Create the properly shaped input tensor
    final input = List.generate(
      expectedTimeSteps,
      (t) {
        if (t < mfccFeatures.length) {
          final frame = mfccFeatures[t];
          // Pad or truncate features dimension
          return List.generate(expectedFeatures, (f) {
            return f < frame.length ? frame[f] : 0.0;
          });
        } else {
          // Zero-pad time steps beyond available data
          return List<double>.filled(expectedFeatures, 0.0);
        }
      },
    );

    return [input]; // Add batch dimension [1, timeSteps, features]
  }

  /// Create output buffer matching the model's output shape.
  dynamic _prepareOutput() {
    if (_outputShape.isEmpty) {
      // Fallback: single scalar output
      return [
        [0.0]
      ];
    }

    // Build nested list matching the output shape
    if (_outputShape.length == 1) {
      return List.filled(_outputShape[0], 0.0);
    }

    if (_outputShape.length == 2) {
      return List.generate(
        _outputShape[0],
        (_) => List.filled(_outputShape[1], 0.0),
      );
    }

    // For higher dimensions, use reshape approach
    final totalElements = _outputShape.reduce((a, b) => a * b);
    final flat = List.filled(totalElements, 0.0);

    // Reshape to match output
    dynamic result = flat;
    for (int dim = _outputShape.length - 1; dim >= 1; dim--) {
      final size = _outputShape[dim];
      final chunks = <List<double>>[];
      for (int i = 0; i < (result as List).length; i += size) {
        chunks.add(List<double>.from(result.sublist(i, i + size)));
      }
      result = chunks;
    }

    return result;
  }

  /// Interpret the model output as a fluency score (0–100).
  ///
  /// Handles various output shapes:
  /// - Single value: normalize to 0-100
  /// - Multiple values (classification): use max probability
  double _interpretOutput(dynamic output) {
    // Flatten output to a list of doubles
    final values = _flattenOutput(output);

    if (values.isEmpty) return 0.0;

    if (values.length == 1) {
      // Single scalar output — could be a regression value
      final raw = values[0];

      // If output is already in 0-1 range (sigmoid), scale to 0-100
      if (raw >= 0.0 && raw <= 1.0) {
        return (raw * 100.0).clamp(0.0, 100.0);
      }

      // If output is already in 0-100 range, use directly
      if (raw >= 0.0 && raw <= 100.0) {
        return raw.clamp(0.0, 100.0);
      }

      // Otherwise, try to normalise assuming it's an unbounded score
      // Use sigmoid to squash into 0-100
      final sigmoid = 1.0 / (1.0 + _safeExp(-raw));
      return (sigmoid * 100.0).clamp(0.0, 100.0);
    }

    // Multi-class output — find max probability and use it
    // Higher max probability indicates more confident/clearer speech
    double maxVal = values[0];
    for (final v in values) {
      if (v > maxVal) maxVal = v;
    }

    // If values look like probabilities (sum ≈ 1), use max prob as score
    final sum = values.fold<double>(0.0, (a, b) => a + b);
    if (sum > 0.5 && sum < 1.5) {
      return (maxVal * 100.0).clamp(0.0, 100.0);
    }

    // Fallback: normalise max value
    if (maxVal >= 0.0 && maxVal <= 1.0) {
      return (maxVal * 100.0).clamp(0.0, 100.0);
    }

    return maxVal.clamp(0.0, 100.0);
  }

  /// Recursively flatten nested output to a flat list of doubles.
  List<double> _flattenOutput(dynamic output) {
    if (output is double) return [output];
    if (output is int) return [output.toDouble()];
    if (output is Float32List) return output.map((e) => e.toDouble()).toList();
    if (output is List) {
      final flat = <double>[];
      for (final item in output) {
        flat.addAll(_flattenOutput(item));
      }
      return flat;
    }
    return [0.0];
  }

  /// Safe exponential to avoid overflow.
  double _safeExp(double x) {
    if (x > 500) return double.maxFinite;
    if (x < -500) return 0.0;
    return math.exp(x);
  }

  /// Dispose the interpreter to free resources.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isLoaded = false;
  }
}
