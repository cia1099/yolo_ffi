import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yolo_ffi/yolo_ffi.dart';

import 'frosted_button.dart';
import 'painters.dart';
import 'yuv2rgba_converter.dart';

class DetectPage extends StatefulWidget {
  final CameraDescription camera;
  final bool printConsole;

  const DetectPage({
    super.key,
    required this.camera,
    this.printConsole = false,
  });

  @override
  State<DetectPage> createState() => _DetectPageState();
}

class _DetectPageState extends State<DetectPage> {
  late final yoloModel = YoloModel(printConsole: widget.printConsole);
  // late final yoloModel = IsolateYolo(
  //   detectedCallback: (bBoxes) => boxes << bBoxes,
  //   printConsole: widget.printConsole,
  // );
  final boxes = PaintingBoxes();
  late final isAndroid = Theme.of(context).platform == TargetPlatform.android;
  late final controller = CameraController(
    widget.camera,
    ResolutionPreset.medium,
  );
  late final isReady = controller.initialize().then((_) async {
    if (!(await yoloModel.isReady)) {
      throw Exception("Failed to load YOLO model");
    }

    controller.startImageStream((cameraImage) async {
      // final sw = Stopwatch()..start();
      final frame = await converter.convert(cameraImage);
      // await frame.androidResize(frame.width, frame.height);
      // final dartConvert = (sw..stop()).elapsedMilliseconds;
      // (sw..reset()).start();
      // final plane0 = cameraImage.planes[0];
      // final plane1 = cameraImage.planes.elementAtOrNull(1);
      // final plane2 = cameraImage.planes.elementAtOrNull(2);
      // final frame = await convertImage(
      //   cameraFormat: cameraImage.format.group.index,
      //   plane0: plane0.bytes,
      //   plane1: plane1?.bytes,
      //   plane2: plane2?.bytes,
      //   bytesPerRow0: plane0.bytesPerRow,
      //   bytesPerRow1: plane1?.bytesPerRow,
      //   bytesPerRow2: plane2?.bytesPerRow,
      //   bytesPerPixel1: plane1?.bytesPerPixel,
      //   bytesPerPixel2: plane2?.bytesPerPixel,
      //   width: cameraImage.width,
      //   height: cameraImage.height,
      //   isAndroid: isAndroid,
      // );
      // final ffiConvert = (sw..stop()).elapsedMilliseconds;
      // print(
      //   "\x1b[32mDart convert = ${dartConvert}ms, FFI convert = ${ffiConvert}ms\x1b[0m",
      // );
      streamController.add(frame);
      if (isDetect) {
        final infSw = Stopwatch()..start();
        if (isAndroid) {
          // await yoloModel(await frame.androidResize(640, 640));
          boxes << await yoloModel(await frame.androidResize(640, 640));
        } else {
          // yoloModel(frame);
          boxes << await yoloModel(frame);
        }
        debugPrint(
          "\x1b[32mElapsed time: infer = ${(infSw..stop()).elapsedMilliseconds}ms\x1b[0m",
        );
      } else if (boxes.isNotEmpty) {
        boxes << [];
      }
    });
  });
  final streamController = StreamController<ui.Image>();
  final converter = YUV2RGBAConverter();
  var isDetect = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text("Detecting Object")),
      child: SafeArea(
        top: false,
        child: FutureBuilder(
          future: isReady,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CupertinoActivityIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: colorScheme.error),
                ),
              );
            }
            // return controller.buildPreview();
            return Stack(
              children: [
                StreamBuilder(
                  stream: streamController.stream,
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return const Center(child: CupertinoActivityIndicator());
                    }
                    return RepaintBoundary(
                      child: CustomPaint(
                        painter: CameraPainter(
                          frame: snapshot.data!,
                          // camera: widget.camera,
                          isAndroid: isAndroid,
                        ),
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: BoxesPainter(boxes: boxes),
                            size: Size.infinite,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment(0, .9),
                  child: FrostedButton(
                    onPressed: () => setState(() {
                      isDetect ^= true;
                    }),
                    icon: isDetect ? CupertinoIcons.stop : CupertinoIcons.play,
                    iconColor: isDetect
                        ? CupertinoColors.systemRed.resolveFrom(context)
                        : null,
                    size: 100,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    controller.stopImageStream().whenComplete(() {
      controller.dispose();
    });
    yoloModel.dispose();
    streamController.close();
    super.dispose();
  }
}

class CameraPage extends StatefulWidget {
  final bool printConsole;
  const CameraPage({super.key, this.printConsole = false});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  var cameras = <CameraDescription>[];
  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        middle: Text("YOLO Demo"),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Open Camera to detect objects'),
            FrostedButton(
              onPressed: () async {
                cameras = await availableCameras();
                print("We have cameras: ${cameras.length}");
                print("Lens rotated: ${cameras.last.sensorOrientation}");
                if (cameras.isNotEmpty && context.mounted) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => DetectPage(
                        camera: cameras.firstWhere(
                          (c) => c.lensDirection == CameraLensDirection.back,
                        ),
                        printConsole: widget.printConsole,
                      ),
                      fullscreenDialog: true,
                      settings: RouteSettings(name: "detect"),
                    ),
                  );
                }
              },
              icon: CupertinoIcons.camera,
              size: 100,
            ),
          ],
        ),
      ),
    );
  }
}

extension YoloImage on ui.Image {
  Future<ui.Image> androidResize(int width, int height) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // 移动画布原点到中心（旋转围绕中心）
    canvas.translate(width / 2, height / 2);

    // 旋转 90°（顺时针为正，逆时针传负值）
    canvas.rotate(90 * math.pi / 180);

    // 再把坐标系移回去（因为前面移动了中心）
    canvas.translate(-height / 2, -width / 2);

    final srcRect =
        Offset.zero & Size(this.width.toDouble(), this.height.toDouble());
    // 注意：此时宽高对调，因为旋转 90° 后，w/h 会交换
    final dstRect = Rect.fromLTWH(0, 0, height.toDouble(), width.toDouble());

    canvas.drawImageRect(this, srcRect, dstRect, Paint());
    final picture = recorder.endRecording();
    return picture.toImage(width, height);
  }
}
