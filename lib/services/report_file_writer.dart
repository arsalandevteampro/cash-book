import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<String> writeReportFile({
  required String directoryPath,
  required String fileName,
  required Uint8List bytes,
}) async {
  final file = File('$directoryPath/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<String> saveReportFile({
  required String fileName,
  required Uint8List bytes,
}) async {
  Directory? targetDir;
  if (Platform.isAndroid) {
    final downloadDir = Directory('/storage/emulated/0/Download');
    if (await downloadDir.exists()) {
      targetDir = downloadDir;
    } else {
      targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
    }
  } else if (Platform.isIOS) {
    targetDir = await getApplicationDocumentsDirectory();
  } else {
    targetDir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
  }

  final file = File('${targetDir.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
