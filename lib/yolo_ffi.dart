import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'yolo_ffi_bindings_generated.dart';

const String _libName = 'yolo_ffi';

final DynamicLibrary _dylib = () {
  if (Platform.isMacOS || Platform.isIOS) {
    return DynamicLibrary.open('$_libName.framework/$_libName');
  }
  if (Platform.isAndroid || Platform.isLinux) {
    return DynamicLibrary.open('lib$_libName.so');
  }
  if (Platform.isWindows) {
    return DynamicLibrary.open('$_libName.dll');
  }
  throw UnsupportedError('Unknown platform: ${Platform.operatingSystem}');
}();

final YoloFfiBindings _bindings = YoloFfiBindings(_dylib);

/// Loads an ONNX model from an asset path.
///
/// This function copies the asset to a temporary file and then loads the model
/// from that file.
Future<void> loadModel(String assetPath) async {
  final tempDir = await getTemporaryDirectory();
  final tempPath = p.join(tempDir.path, p.basename(assetPath));
  final file = File(tempPath);

  // Copy asset to temporary file.
  final byteData = await rootBundle.load(assetPath);
  await file.writeAsBytes(
    byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
  );

  // Load the model from the temporary file path.
  loadModelFromPath(tempPath);
}

/// Loads an ONNX model from a file path.
void loadModelFromPath(String modelPath) {
  using((Arena arena) {
    final modelPathC = modelPath.toNativeUtf8(allocator: arena);
    _bindings.load_model(modelPathC.cast());
  });
}

String getModelInputName() {
  final inputNamePtr = _bindings.get_model_input_name();

  if (inputNamePtr == nullptr) {
    throw StateError(
      "Failed to get input name. Ensure a model is loaded and valid.",
    );
  }

  try {
    final inputName = inputNamePtr.cast<Utf8>().toDartString();
    return inputName;
  } finally {
    _bindings.free_string(inputNamePtr.cast());
  }
}

void closeModel() {
  _bindings.close_model();
}
