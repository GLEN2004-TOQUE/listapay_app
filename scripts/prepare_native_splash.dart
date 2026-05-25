import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const sourcePath = 'assets/images/splash_screen.png';
  const outputPath = 'assets/images/splash_screen_native.png';
  const canvasSize = 1152;
  const contentMaxWidth = 720;
  const contentMaxHeight = 540;

  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Missing source image: $sourcePath');
    exitCode = 1;
    return;
  }

  final decoded = img.decodeImage(sourceFile.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('Unable to decode image: $sourcePath');
    exitCode = 1;
    return;
  }

  final fitted = img.copyResize(
    decoded,
    width: decoded.width >= decoded.height ? contentMaxWidth : null,
    height: decoded.height > decoded.width ? contentMaxHeight : null,
    interpolation: img.Interpolation.average,
  );

  final canvas = img.Image(
    width: canvasSize,
    height: canvasSize,
    numChannels: 4,
  );
  img.fill(canvas, color: img.ColorRgba8(255, 255, 255, 0));

  final dx = ((canvas.width - fitted.width) / 2).round();
  final dy = ((canvas.height - fitted.height) / 2).round();
  img.compositeImage(canvas, fitted, dstX: dx, dstY: dy);

  File(outputPath).writeAsBytesSync(img.encodePng(canvas, level: 6));
  stdout.writeln('Wrote $outputPath');
}
