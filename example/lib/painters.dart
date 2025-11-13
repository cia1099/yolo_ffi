import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:yolo_ffi/ort_yolo_ffi.dart';
import 'package:yolo_ffi/yolo_ffi.dart' show BoundingBox;

class CameraPainter extends CustomPainter {
  final ui.Image frame;
  final bool isAndroid;
  // final CameraDescription? camera;

  CameraPainter({required this.frame, required this.isAndroid});
  // , this.camera});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();

    // if (isAndroid) {
    //   // 移动画布原点到中心（旋转围绕中心）
    //   canvas.translate(size.width / 2, size.height / 2);

    //   // 旋转 90°（顺时针为正，逆时针传负值）
    //   canvas.rotate((camera?.sensorOrientation ?? 90) * math.pi / 180);

    //   // 再把坐标系移回去（因为前面移动了中心）
    //   canvas.translate(-size.height / 2, -size.width / 2);
    // }

    final srcRect = Rect.fromLTWH(
      0,
      0,
      frame.width.toDouble(),
      frame.height.toDouble(),
    );

    // 注意：此时宽高对调，因为旋转 90° 后，w/h 会交换
    final dstRect = Rect.fromLTWH(
      0,
      0,
      isAndroid ? size.height : size.width, // <— 旋转后宽高互换
      isAndroid ? size.width : size.height,
    );

    canvas.drawImageRect(frame, srcRect, dstRect, Paint());

    canvas.restore();
  }

  // @override
  // void paint(Canvas canvas, Size size) {
  //   final srcRect = Rect.fromLTWH(
  //     0,
  //     0,
  //     frame.width.toDouble(),
  //     frame.height.toDouble(),
  //   );
  //   final dstRect = Offset.zero & size;
  //   canvas.drawImageRect(frame, srcRect, dstRect, Paint());
  // }

  @override
  bool shouldRepaint(covariant CameraPainter oldDelegate) =>
      frame != oldDelegate.frame;
}

// MARK: - BoxesPainter
class BoxesPainter extends CustomPainter {
  final PaintingBoxes? boxes;

  BoxesPainter({this.boxes}) : super(repaint: boxes);

  @override
  void paint(Canvas canvas, Size size) {
    if (boxes == null || boxes!.isEmpty) return;
    final scaleX = size.width / OrtYoloFfi.inputSize;
    final scaleY = size.height / OrtYoloFfi.inputSize;
    for (final box in boxes!) {
      final rect = Rect.fromLTRB(
        box.x1 * scaleX,
        box.y1 * scaleY,
        box.x2 * scaleX,
        box.y2 * scaleY,
      );
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      final textPainter = TextPainter(
        text: TextSpan(
          text:
              "${kCocoClasses[box.classId]}: ${box.confidence.toStringAsFixed(2)}",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final labelTL = rect.topLeft - Offset(0, textPainter.height);
      canvas.drawRect(
        labelTL & textPainter.size,
        Paint()
          ..color = Colors.green
          ..style = PaintingStyle.fill,
      );
      textPainter.paint(canvas, labelTL);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// MARK: - PaintingBoxes

class PaintingBoxes with ChangeNotifier, IterableMixin<BoundingBox> {
  List<BoundingBox> boxes = [];

  void setBoxes(List<BoundingBox> newBoxes) {
    boxes = newBoxes;
    notifyListeners();
  }

  @override
  int get length => boxes.length;
  @override
  bool get isEmpty => boxes.isEmpty;
  BoundingBox operator [](int index) => boxes[index];
  void operator <<(List<BoundingBox> newBoxes) => setBoxes(newBoxes);
  @override
  Iterator<BoundingBox> get iterator => boxes.iterator;
}

const kCocoClasses = [
  "person",
  "bicycle",
  "car",
  "motorcycle",
  "airplane",
  "bus",
  "train",
  "truck",
  "boat",
  "traffic light",
  "fire hydrant",
  "stop sign",
  "parking meter",
  "bench",
  "bird",
  "cat",
  "dog",
  "horse",
  "sheep",
  "cow",
  "elephant",
  "bear",
  "zebra",
  "giraffe",
  "backpack",
  "umbrella",
  "handbag",
  "tie",
  "suitcase",
  "frisbee",
  "skis",
  "snowboard",
  "sports ball",
  "kite",
  "baseball bat",
  "baseball glove",
  "skateboard",
  "surfboard",
  "tennis racket",
  "bottle",
  "wine glass",
  "cup",
  "fork",
  "knife",
  "spoon",
  "bowl",
  "banana",
  "apple",
  "sandwich",
  "orange",
  "broccoli",
  "carrot",
  "hot dog",
  "pizza",
  "donut",
  "cake",
  "chair",
  "couch",
  "potted plant",
  "bed",
  "dining table",
  "toilet",
  "tv",
  "laptop",
  "mouse",
  "remote",
  "keyboard",
  "cell phone",
  "microwave",
  "oven",
  "toaster",
  "sink",
  "refrigerator",
  "book",
  "clock",
  "vase",
  "scissors",
  "teddy bear",
  "hair drier",
  "toothbrush",
];
