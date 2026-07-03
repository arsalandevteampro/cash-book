import 'dart:typed_data';

Future<String> writeReportFile({
  required String directoryPath,
  required String fileName,
  required Uint8List bytes,
}) async {
  throw UnsupportedError('File writing is handled in-memory on web.');
}
