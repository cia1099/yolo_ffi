import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:statsfl/statsfl.dart';
import 'package:yolo_ffi/yolo_ffi.dart' as yolo_ffi;

import 'dev_page.dart';

void main() {
  // It's recommended to call this before runApp to ensure Flutter bindings are initialized.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    StatsFl(
      align: Alignment(1, -.9),
      isEnabled: true,
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        // home: const GetInputNamePage(),
        home: const DevPage(),
        // home: const CameraPage(),
      ),
    ),
  );
}

class GetInputNamePage extends StatefulWidget {
  const GetInputNamePage({super.key});

  @override
  State<GetInputNamePage> createState() => _GetInputNamePageState();
}

class _GetInputNamePageState extends State<GetInputNamePage> {
  String _displayMessage = 'Click the button to load the model from assets.';
  // IMPORTANT: Replace this with the actual name of your model file in example/assets/
  final String _modelAssetPath = 'assets/models/yolo11n.ort';

  @override
  void dispose() {
    // Close the model when the app is closed.
    yolo_ffi.closeModel();
    super.dispose();
  }

  Future<void> _loadModelAndGetInputName() async {
    setState(() {
      _displayMessage = 'Loading model from $_modelAssetPath...';
    });

    try {
      await yolo_ffi.loadModel(_modelAssetPath);
      final inputName = yolo_ffi.getModelInputName();
      setState(() {
        _displayMessage = 'Model loaded successfully!\nInput Name: $inputName';
      });
    } catch (e) {
      setState(() {
        _displayMessage =
            'Error: ${e.toString()}\n\n'
            'Please ensure you have placed your model file at $_modelAssetPath '
            'and that it is a valid ONNX model.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('ONNX Runtime FFI Demo'),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _displayMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadModelAndGetInputName,
                child: const Text('Load Model from Asset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
