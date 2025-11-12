import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

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

/// Represents a single detected object.
class BoundingBox {
  final double x, y, w, h, confidence;
  final int classId;

  BoundingBox({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.classId,
    required this.confidence,
  });

  @override
  String toString() {
    return 'BoundingBox(x: $x, y: $y, w: $w, h: $h, classId: $classId, confidence: $confidence)';
  }
}

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

/// Detects objects in an image.
///
/// [imageData] is the raw RGBA image data.
/// [height] and [width] are the dimensions of the image.
/// [confThreshold] is the confidence threshold for filtering detections.
/// [nmsThreshold] is the non-maximum suppression threshold.
List<BoundingBox> yoloDetect({
  required Uint8List imageData,
  required int height,
  required int width,
  double confThreshold = 0.25,
  double nmsThreshold = 0.45,
}) {
  return using((Arena arena) {
    // Allocate memory for the image data and copy it.
    final imagePtr = arena<Uint8>(imageData.length);
    imagePtr.asTypedList(imageData.length).setAll(0, imageData);

    // Call the C function.
    final result = _bindings.yolo_detect(
      imagePtr,
      height,
      width,
      confThreshold,
      nmsThreshold,
    );

    // return result.bboxes.asTypedList(result.count * 6);

    return using((arena) {
      final detections = <BoundingBox>[];
      try {
        for (var i = 0; i < result.count && result.bboxes != nullptr; i++) {
          final bbox = result.bboxes + i * 6;
          detections.add(
            BoundingBox(
              x: bbox[0],
              y: bbox[1],
              w: bbox[2],
              h: bbox[3],
              classId: bbox[4].round(),
              confidence: bbox[5],
            ),
          );
        }
      } finally {
        // Free the memory allocated by the C function.
        _bindings.free_result(result);
      }

      return detections;
    });
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
