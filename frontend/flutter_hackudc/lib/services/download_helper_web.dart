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
