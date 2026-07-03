import 'dart:io';
import 'dart:typed_data';

Future<String> writeReportFile({
  required String directoryPath,
  required String fileName,
  required Uint8List bytes,
}) async {
  final file = File('$directoryPath/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
