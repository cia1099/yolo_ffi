import 'dart:async';
import 'dart:ui' as ui;

import 'package:yolo_ffi/yolo_ffi.dart';

class OrtYoloFfi {
  final _completer = Completer<bool>();

  OrtYoloFfi() {
    _init();
  }

  void dispose() {
    closeModel();
  }

  Future<void> _init() async {
    try {
      await loadModel('packages/yolo_ffi/assets/yolo11n.ort');
      _completer.complete(true);
    } catch (e) {
      _completer.completeError(e);
    }
  }

  Future<bool> get isReady => _completer.future;

  Future<List<BoundingBox>> detect({
    required ui.Image image,
    double confThreshold = .25,
    double nmsThreshold = .45,
  }) async {
    if (!await isReady) return [];
    final bytes = await image.toByteData();
    if (bytes == null) return [];
    return yoloDetect(
      imageData: bytes.buffer.asUint8List(),
      height: image.height,
      width: image.width,
      confThreshold: confThreshold,
      nmsThreshold: nmsThreshold,
    );
  }

  Future<List<BoundingBox>> call(
    ui.Image image, {
    double confThreshold = .25,
    double nmsThreshold = .45,
  }) {
    return detect(
      image: image,
      confThreshold: confThreshold,
      nmsThreshold: nmsThreshold,
    );
  }

  static const int inputSize = 640;
}
