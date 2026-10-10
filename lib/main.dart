import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'src/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Right-drag pans the canvas, so keep the browser's menu out of the way.
  if (kIsWeb) unawaited(BrowserContextMenu.disableContextMenu());
  runApp(const PixelPaintApp());
}
