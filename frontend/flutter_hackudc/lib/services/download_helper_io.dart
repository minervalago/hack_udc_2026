import 'dart:io';

Future<String> saveSvgFile(String svgContent) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final dir = _downloadsDir(home);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('$dir/grafica_$timestamp.svg');
  await file.writeAsString(svgContent);
  return file.path;
}

Future<String> saveHtmlFile(String htmlContent) async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final dir = _downloadsDir(home);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final file = File('$dir/informe_$timestamp.html');
  await file.writeAsString(htmlContent);
  return file.path;
}

void openEmailCompose(String toEmail, String subject) {}

String _downloadsDir(String home) {
  final descargas = Directory('$home/Descargas');
  if (descargas.existsSync()) return descargas.path;
  final downloads = Directory('$home/Downloads');
  if (!downloads.existsSync()) downloads.createSync();
  return downloads.path;
}
