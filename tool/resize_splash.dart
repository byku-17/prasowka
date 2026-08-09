import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodeWebP(File('assets/logo.webp').readAsBytesSync())!;
  final ow = src.width;
  final oh = src.height;

  // Nowy rozmiar: sowa zajmie ~65% szerokości, reszta to przezroczysty margines.
  final newW = (ow / 0.65).round();
  final newH = (oh / 0.65).round();

  final canvas = img.Image(width: newW, height: newH);

  final scaled = img.copyResize(src, width: ow, height: oh);
  final offsetX = ((newW - ow) / 2).round();
  final offsetY = ((newH - oh) / 2).round();
  img.compositeImage(canvas, scaled, dstX: offsetX, dstY: offsetY);

  File('assets/logo.png').writeAsBytesSync(img.encodePng(canvas));
  print('OK: $ow x $oh -> $newW x $newH (PNG)');
}
