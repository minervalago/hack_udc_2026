import 'dart:io';

Future<String> saveSvgFile(String svgContent) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final downloadsDir = Directory('$home/Descargas');
  if (!downloadsDir.existsSync()) {
    final fallback = Directory('$home/Downloads');
    if (!fallback.existsSync()) fallback.createSync();
  }
  final dir =
      downloadsDir.existsSync() ? downloadsDir.path : '$home/Downloads';
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('$dir/grafica_$timestamp.svg');
  await file.writeAsString(svgContent);
  return file.path;
}
