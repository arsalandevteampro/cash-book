import 'dart:html' as html;
import 'dart:typed_data';

Future<String> writeReportFile({
  required String directoryPath,
  required String fileName,
  required Uint8List bytes,
}) async {
  throw UnsupportedError('File writing is handled in-memory on web.');
}

Future<String> saveReportFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return fileName;
}
