import 'dart:collection';
// ignore_for_file: avoid_print
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/splash.png').readAsBytesSync())!;
  final w = src.width, h = src.height;

  final removed = List.generate(h, (_) => List<bool>.filled(w, false));
  final queue = Queue<(int, int)>();

  void seed(int x, int y) {
    if (removed[y][x]) return;
    removed[y][x] = true;
    queue.add((x, y));
  }

  for (var x = 0; x < w; x++) {
    seed(x, 0);
    seed(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    seed(0, y);
    seed(w - 1, y);
  }

  const tol = 18; // gradient-aware: max diff per channel vs current pixel

  bool isDarkEnough(int r, int g, int b) => r <= 70 && g <= 70 && b <= 70;

  while (queue.isNotEmpty) {
    final (x, y) = queue.removeFirst();
    final c = src.getPixel(x, y);
    final cr = c.r.toInt(), cg = c.g.toInt(), cb = c.b.toInt();
    for (final (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]) {
      if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      if (removed[ny][nx]) continue;
      final p = src.getPixel(nx, ny);
      final pr = p.r.toInt(), pg = p.g.toInt(), pb = p.b.toInt();
      final diff = (pr - cr).abs() + (pg - cg).abs() + (pb - cb).abs();
      if (diff <= tol && isDarkEnough(pr, pg, pb)) {
        removed[ny][nx] = true;
        queue.add((nx, ny));
      }
    }
  }

  var count = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (removed[y][x]) {
        final p = src.getPixel(x, y);
        p.a = 0;
        src.setPixel(x, y, p);
        count++;
      }
    }
  }

  print('removed background pixels: $count / ${w * h}');
  File('assets/splash.png').writeAsBytesSync(img.encodePng(src));
  print('saved assets/splash.png');
}
