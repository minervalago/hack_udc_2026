import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

Future<String> saveSvgFile(String svgContent) async {
  final bytes = utf8.encode(svgContent);
  final blob = html.Blob([bytes], 'image/svg+xml');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  html.AnchorElement(href: url)
    ..setAttribute('download', 'grafica_$timestamp.svg')
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'grafica_$timestamp.svg';
}

Future<String> saveHtmlFile(String htmlContent) async {
  final bytes = utf8.encode(htmlContent);
  final blob = html.Blob([bytes], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  html.AnchorElement(href: url)
    ..setAttribute('download', 'informe_$timestamp.html')
    ..click();
  html.Url.revokeObjectUrl(url);
  return 'informe_$timestamp.html';
}

void openEmailCompose(String toEmail, String subject) {
  final uri = 'mailto:$toEmail?subject=${Uri.encodeComponent(subject)}';
  html.window.open(uri, '_self');
}
