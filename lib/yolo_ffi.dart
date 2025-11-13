import 'dart:async';
import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
  final double x1, y1, x2, y2, confidence;
  final int classId;

  BoundingBox({
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    required this.classId,
    required this.confidence,
  });

  @override
  String toString() {
    return 'BoundingBox(x: $x1, y: $y1, x2: $x2, y2: $y2, classId: $classId, confidence: $confidence)';
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
              x1: bbox[0],
              y1: bbox[1],
              x2: bbox[2],
              y2: bbox[3],
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

Future<ui.Image> convertImage({
  required int cameraFormat,
  required Uint8List plane0,
  Uint8List? plane1,
  Uint8List? plane2,
  required int bytesPerRow0,
  int bytesPerRow1 = 0,
  int bytesPerRow2 = 0,
  int bytesPerPixel1 = 0,
  int bytesPerPixel2 = 0,
  required int width,
  required int height,
  bool isAndroid = false,
}) async {
  return using((Arena arena) {
    final plane0Ptr = arena<Uint8>(plane0.length);
    plane0Ptr.asTypedList(plane0.length).setAll(0, plane0);

    Pointer<Uint8> plane1Ptr = nullptr;
    if (plane1 != null) {
      plane1Ptr = arena<Uint8>(plane1.length);
      plane1Ptr.asTypedList(plane1.length).setAll(0, plane1);
    }

    Pointer<Uint8> plane2Ptr = nullptr;
    if (plane2 != null) {
      plane2Ptr = arena<Uint8>(plane2.length);
      plane2Ptr.asTypedList(plane2.length).setAll(0, plane2);
    }

    final format = switch (cameraFormat) {
      1 => ImageFormat.YUV420,
      2 => ImageFormat.BGRA8888,
      4 => ImageFormat.NV21,
      _ => throw ArgumentError("Unknown camera format: $cameraFormat"),
    };

    final buffer = _bindings.convert_image(
      format,
      plane0Ptr,
      plane1Ptr,
      plane2Ptr,
      bytesPerRow0,
      bytesPerRow1,
      bytesPerRow2,
      bytesPerPixel1,
      bytesPerPixel2,
      width,
      height,
      isAndroid,
    );

    try {
      final bytes = Uint8List.fromList(buffer.asTypedList(width * height * 4));
      final Completer<ui.Image> completer = Completer();
      //There is a rotation of 90 degree on Android platform
      ui.decodeImageFromPixels(
        bytes,
        isAndroid ? height : width,
        isAndroid ? width : height,
        ui.PixelFormat.rgba8888,
        (ui.Image img) => completer.complete(img),
      );

      return completer.future;
    } finally {
      _bindings.free_rgba_buffer(buffer);
    }
  });
}
