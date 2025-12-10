import 'package:flutter/cupertino.dart';
import 'package:statsfl/statsfl.dart';

import 'detect_page.dart';

void main() {
  // It's recommended to call this before runApp to ensure Flutter bindings are initialized.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    StatsFl(
      align: Alignment(1, -.9),
      isEnabled: true,
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        // home: const DevPage(),
        home: const CameraPage(printConsole: false),
      ),
    ),
  );
}
