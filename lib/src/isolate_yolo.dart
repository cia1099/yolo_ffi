import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;
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

      _outputWatcher.listen(_handleOutputFromIsolate);
      _isolate = await Isolate.spawn(
        _startRemoteIsolate,
        _outputWatcher.sendPort,
      );
    } catch (e) {
      _isolateReady.completeError(e);
    }
  }

  void _handleOutputFromIsolate(export) {
    if (export is SendPort && !_isolateReady.isCompleted) {
      _input = export;
      _isolateReady.complete(true);
    } else if (export is List<BoundingBox>) {
      detectedCallback(export);
    }
  }

  Future<void> call(
    ui.Image frame, {
    double confThreshold = .25,
    double nmsThreshold = .45,
  }) async {
    if (await _isolateReady.future) {
      final bytes = await frame.toByteData();
      if (bytes == null) return;
      _input.send(
        _YoloInput(
          imageData: bytes.buffer.asUint8List(),
          width: frame.width,
          height: frame.height,
          confThreshold: confThreshold,
          nmsThreshold: nmsThreshold,
        ),
      );
    }
  }

  void dispose() {
    _input.send(null);
    _outputWatcher.close();
    _cppConsole?.cancel();
    _isolate?.kill(); //(priority: Isolate.immediate);
  }
}

@pragma('vm:entry-point')
void _startRemoteIsolate(SendPort output) async {
  final inputListener = ReceivePort();
  output.send(inputListener.sendPort);
  final inputs = FixedQueue<_YoloInput>(1);
  var isListening = true;

  inputListener.listen((input) {
    if (input is _YoloInput) {
      inputs.add(input);
    } else if (input == null) {
      inputListener.close();
      inputs.clear();
      isListening = false;
    }
  }, onDone: () => debugPrint("\x1b[35mshut down YOLO isolate\x1b[0m"));
  while (isListening) {
    final input = inputs.pop();
    if (input == null) {
      await Future.delayed(const Duration(milliseconds: 100));
      continue;
    }

    final bBoxes = yoloDetect(
      imageData: input.imageData,
      height: input.height,
      width: input.width,
      confThreshold: input.confThreshold,
      nmsThreshold: input.nmsThreshold,
    );
    output.send(bBoxes);
  }
  closeModel();
}

class FixedQueue<T> {
  final int maxSize;
  final ListQueue<T> _queue;

  FixedQueue(this.maxSize) : _queue = ListQueue<T>();

  void add(T value) {
    if (_queue.length >= maxSize) {
      _queue.removeFirst(); // 移除最旧的元素
    }
    _queue.addLast(value); // 加入新元素
  }

  T? pop() => _queue.isNotEmpty ? _queue.removeFirst() : null;
  void clear() => _queue.clear();

  List<T> toList() => _queue.toList();

  int get length => _queue.length;
  bool get isEmpty => _queue.isEmpty;
  bool get isNotEmpty => _queue.isNotEmpty;

  @override
  String toString() => _queue.toString();
}

class _YoloInput {
  final Uint8List imageData;
  final int width;
  final int height;
  final double confThreshold;
  final double nmsThreshold;

  _YoloInput({
    required this.imageData,
    required this.width,
    required this.height,
    required this.confThreshold,
    required this.nmsThreshold,
  });
}
