import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;

import 'bridge_ffi.dart';

class YoloModel {
  final _completer = Completer<bool>();
  late final StreamSubscription<String>? _cppConsole;
  final bool printConsole;

  YoloModel({this.printConsole = false}) {
    _init();
  }

  void dispose() {
    _cppConsole?.cancel();
    closeModel();
  }

  Future<void> _init() async {
    try {
      if (Platform.isIOS || Platform.isMacOS) {
        await loadModel('packages/yolo_ffi/assets/yolo11n.mlmodel');
      } else {
        await loadNcnnModel('packages/yolo_ffi/assets/yolo11n.ncnn');
      }
      _cppConsole = printConsole
          ? PlatformChannel.getCppConsole.listen((msg) {
              debugPrint("\x1b[43m$msg\x1b[0m");
            })
          : null;
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
