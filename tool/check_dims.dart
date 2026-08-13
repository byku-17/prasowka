import 'dart:io';
// ignore_for_file: avoid_print
import 'package:image/image.dart' as img;

void main() {
  final bytes = File('assets/splash.webp').readAsBytesSync();
  final src = img.decodeWebP(bytes);
  if (src == null) {
    print('decodeWebP returned null');
    return;
  }
  print('width=${src.width} height=${src.height} frames=${src.frames.length}');
}
