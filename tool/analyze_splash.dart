import 'dart:io';
// ignore_for_file: avoid_print
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/splash1.png').readAsBytesSync())!;
  final w = src.width, h = src.height;

  // dół: napis. znajdź wiersze z dużą zmiennością (litery) poniżej y=700
  for (var y = 700; y < h; y += 40) {
    final row = <String>[];
    for (var x = 0; x < w; x += 30) {
      final p = src.getPixel(x, y);
      row.add('(${p.r.toInt()},${p.g.toInt()},${p.b.toInt()})');
    }
    print('y=$y: ${row.join(' ')}');
    if (y > 1100) break;
  }
}
