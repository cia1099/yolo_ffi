import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:yolo_ffi/yolo_ffi.dart';

import 'frosted_button.dart';
import 'painters.dart';

class DevPage extends StatefulWidget {
  const DevPage({super.key});

  @override
  State<DevPage> createState() => _DevPageState();
}

class _DevPageState extends State<DevPage> {
  late final ortYolo = YoloModel(printConsole: true);
  final boxes = PaintingBoxes();
  Timer? timer;
  final streamController = StreamController<ui.Image>();
  late final image = dartDecodeImage("assets/bus.jpg", context).then((img) {
    streamController.add(img);
    return img;
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text("Detecting Object"),
        //   leading: FutureBuilder(
        //     future: OnnxRuntime().getAvailableProviders(),
        //     builder: (context, snapshot) {
        //       if (!snapshot.hasData) return SizedBox.shrink();
        //       return MenuBar(
        //         children: [
        //           SubmenuButton(
        //             menuChildren: snapshot.data!.map((p) {
        //               return Text(p.name);
        //             }).toList(),
        //             child: Text("EP"),
        //           ),
        //         ],
        //       );
        //     },
        //   ),
      ),
      child: Stack(
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
                    isAndroid: false,
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
              onPressed: () async {
                timer?.cancel();
                final sw = Stopwatch()..start();
                boxes << await ortYolo(await image);
                // print("\x1b[43mDetect objects: ${boxes.length}\x1b[0m");
                debugPrint(
                  "\x1b[33mElapsed time: ${(sw..stop()).elapsedMilliseconds}ms\x1b[0m",
                );
                timer = Timer(Durations.extralong4 * 2, () => boxes << []);
              },
              icon: CupertinoIcons.play,
              size: 100,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    ortYolo.dispose();
    timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() async {
    super.didChangeDependencies();
    await image;
    final documentsDirectory = await getApplicationDocumentsDirectory();
    debugPrint("Application directory: $documentsDirectory");
  }
}

Future<ui.Image> dartDecodeImage(String path, [BuildContext? context]) async {
  /**
   * ref. https://stackoverflow.com/questions/65439889/flutter-canvas-drawimage-draws-a-pixelated-image
   * ref. https://blog.csdn.net/jia635/article/details/108155213
   */
  ImageStream imgStream;
  if (path.substring(0, 4) == 'http') {
    imgStream = NetworkImage(path).resolve(
      context == null
          ? ImageConfiguration.empty
          : createLocalImageConfiguration(context),
    );
  } else {
    imgStream = AssetImage(path).resolve(
      context == null
          ? ImageConfiguration.empty
          : createLocalImageConfiguration(context),
    );
  }
  final completer = Completer<ui.Image>();
  imgStream.addListener(
    ImageStreamListener((image, synchronousCall) {
      completer.complete(image.image);
    }),
  );
  return completer.future;
}
