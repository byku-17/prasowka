import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/splash1.png').readAsBytesSync())!;
  final w = src.width, h = src.height;
  print('source: $w x $h');

  // 1. usuń wbudowane ciemne tło (flood fill od krawędzi)
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

  const tol = 18;
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

  // 2. oznacz zachowane piksele
  final kept = List.generate(h, (_) => List<bool>.filled(w, false));
  var keptCount = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      kept[y][x] = !removed[y][x];
      if (kept[y][x]) keptCount++;
    }
  }
  print('kept after bg removal: $keptCount');

  // 3. usuń izolowane drobiny (connected components < minSize px)
  final minSize = 100;
  final labels = List.generate(h, (_) => List<int>.filled(w, -1));
  var compId = 0;
  final compSizes = <int, int>{};

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (!kept[y][x] || labels[y][x] != -1) continue;
      final q = Queue<(int, int)>();
      q.add((x, y));
      labels[y][x] = compId;
      var size = 0;
      while (q.isNotEmpty) {
        final (cx, cy) = q.removeFirst();
        size++;
        for (final (nx, ny) in [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]) {
          if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
          if (!kept[ny][nx] || labels[ny][nx] != -1) continue;
          labels[ny][nx] = compId;
          q.add((nx, ny));
        }
      }
      compSizes[compId] = size;
      compId++;
    }
  }

  var removedDust = 0;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (kept[y][x] && compSizes[labels[y][x]]! < minSize) {
        kept[y][x] = false;
        removedDust++;
      }
    }
  }
  print('dust removed: $removedDust, components: $compId');

  // 4. pełny bbox zachowanej treści (nic nie ucinamy)
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (kept[y][x]) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  final cw = maxX - minX + 1;
  final ch = maxY - minY + 1;
  print('content bbox: $cw x $ch at ($minX,$minY)');

  // 5. nowy obraz z przezroczystym tłem (tylko treść)
  final out = img.Image(width: w, height: h, numChannels: 4);
  out.clear(img.ColorRgba8(0, 0, 0, 0));
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (kept[y][x]) {
        final p = src.getPixel(x, y);
        out.setPixelRgba(x, y, p.r.toInt(), p.g.toInt(), p.b.toInt(), 255);
      }
    }
  }

  // 6. przeskaluj na większe płótno, żeby treść zmieściła się w okręgu (0.80)
  final crop = img.copyCrop(out, x: minX, y: minY, width: cw, height: ch);
  final halfDiag = math.sqrt((cw / 2) * (cw / 2) + (ch / 2) * (ch / 2));
  final best = ((3 * halfDiag) / 0.80).ceil();
  print('canvas: $best x $best (content $cw x $ch)');

  final canvas = img.Image(width: best, height: best, numChannels: 4);
  canvas.clear(img.ColorRgba8(0, 0, 0, 0));
  final offX = (best - cw) ~/ 2;
  final offY = (best - ch) ~/ 2;
  img.compositeImage(canvas, crop, dstX: offX, dstY: offY);

  File('assets/splash.png').writeAsBytesSync(img.encodePng(canvas));
  print('saved assets/splash.png, content at ($offX,$offY)');
}
