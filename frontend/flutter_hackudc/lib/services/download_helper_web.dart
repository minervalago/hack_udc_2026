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

Future<void> printAsPdf(String htmlContent) async {
  // Inject auto-print script if not already present, then open in new tab.
  // The browser print dialog lets the user save as PDF.
  String printable = htmlContent;
  if (!htmlContent.contains('window.print')) {
    printable = htmlContent.replaceFirst(
      '</body>',
      '<script>window.onload=function(){window.print();}</script></body>',
    );
    if (!printable.contains('window.print')) {
      // Fallback: append before closing html tag or just append
      printable = '$printable<script>window.onload=function(){window.print();}</script>';
    }
  }
  final bytes = utf8.encode(printable);
  final blob = html.Blob([bytes], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.window.open(url, '_blank');
  // Delay revoke so the new window has time to load the blob
  Future.delayed(const Duration(seconds: 10), () => html.Url.revokeObjectUrl(url));
}

void openEmailCompose(String toEmail, String subject) {
  final uri = 'mailto:$toEmail?subject=${Uri.encodeComponent(subject)}';
  html.window.open(uri, '_self');
}
