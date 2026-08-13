import 'dart:io';
// ignore_for_file: avoid_print
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodeWebP(File('assets/splash.webp').readAsBytesSync())!;
  File('assets/splash.png').writeAsBytesSync(img.encodePng(src));
  print('OK: ${src.width} x ${src.height} -> assets/splash.png');
}
