import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show debugPrint;

import 'bridge_ffi.dart';

class IsolateYolo {
  final void Function(List<BoundingBox> bBoxes) detectedCallback;
  late final StreamSubscription<String>? _cppConsole;
  final bool printConsole;
  final _outputWatcher = ReceivePort();
  late final Isolate? _isolate;
  late final SendPort _input;
  final _isolateReady = Completer<bool>();

  IsolateYolo({required this.detectedCallback, this.printConsole = false}) {
    _init();
  }

  Future<bool> get isReady => _isolateReady.future;

  Future<void> _init() async {
    try {
      // await loadModel('packages/yolo_ffi/assets/yolo11n.ort');
      await loadNcnnModel('packages/yolo_ffi/assets/yolo11n.ncnn');
      _cppConsole = printConsole
          ? PlatformChannel.getCppConsole.listen((msg) {
              debugPrint("\x1b[43m$msg\x1b[0m");
            })
          : null;

      _outputWatcher.listen(_handleResponseFromIsolate);
      _isolate = await Isolate.spawn(
        _startRemoteIsolate,
        _outputWatcher.sendPort,
      );
    } catch (e) {
      _isolateReady.completeError(e);
    }
  }

  void _handleResponseFromIsolate(res) {
    if (res is SendPort) {
      _input = res;
      _isolateReady.complete(true);
    } else if (res is List<BoundingBox>) {
      detectedCallback(res);
    } else if (res is String) {
      debugPrint("\x1b[43m$res\x1b[0m");
    }
  }

  Future<void> call(ui.Image frame) async {
    if (await _isolateReady.future) {
      final bytes = await frame.toByteData();
      if (bytes == null) return;
      _input.send(bytes.buffer.asUint8List());
      // _input.send(frame);
    }
  }

  void dispose() {
    _input.send(null);
    _outputWatcher.close();
    _isolate?.kill(priority: Isolate.immediate);
    _cppConsole?.cancel();
    closeModel();
  }
}

@pragma('vm:entry-point')
void _startRemoteIsolate(SendPort output) {
  final inputListener = ReceivePort();
  output.send(inputListener.sendPort);

  inputListener.listen((frame) async {
    if (frame is Uint8List) {
      // final bytes = await frame.toByteData();
      // if (bytes == null) return;
      final bBoxes = yoloDetect(
        imageData: frame, //bytes.buffer.asUint8List(),
        height: 640,
        width: 640,
      );
      output.send(bBoxes);
    } else if (frame == null) {
      inputListener.close();
    }
  });
}
