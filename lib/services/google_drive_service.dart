import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:encrypt/encrypt.dart' as encrypt_pkg;

/// HTTP client that injects Google OAuth2 headers
class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }

  @override
  void close() {
    _client.close();
    super.close();
  }
}

class GoogleDriveService {
  static const String _backupFolderName = 'CashBook Backups';
  static const String _backupFileName = 'cashbook_backup.json';

  // v6 API: use constructor with scopes
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveFileScope],
  );

  static GoogleSignInAccount? _currentUser;
  static GoogleSignInAccount? get currentUser => _currentUser;

  static const String _encryptionKey = 'CashBookSecureKey2024_0123456789';

  static String _encryptData(String plainText) {
    final key = encrypt_pkg.Key.fromUtf8(_encryptionKey);
    final iv = encrypt_pkg.IV.fromSecureRandom(16);
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String _decryptData(String encryptedText) {
    final parts = encryptedText.split(':');
    if (parts.length != 2) return encryptedText;
    final key = encrypt_pkg.Key.fromUtf8(_encryptionKey);
    final iv = encrypt_pkg.IV.fromBase64(parts[0]);
    final encrypter = encrypt_pkg.Encrypter(encrypt_pkg.AES(key));
    final encrypted = encrypt_pkg.Encrypted.fromBase64(parts[1]);
    return encrypter.decrypt(encrypted, iv: iv);
  }

  /// Sign in with Google — shows account picker
  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      _currentUser = account;
      return account;
    } catch (e) {
      debugPrint('Google Sign-In error: $e');
      return null;
    }
  }

  /// Sign out from Google
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Try to restore previous sign-in session silently
  static Future<GoogleSignInAccount?> signInSilently() async {
    try {
      final account = await _googleSignIn.signInSilently();
      _currentUser = account;
      return account;
    } catch (e) {
      debugPrint('Silent sign-in error: $e');
      return null;
    }
  }

  /// Get authenticated Drive API using authHeaders
  static Future<drive.DriveApi?> _getDriveApi(GoogleSignInAccount user) async {
    try {
      final authHeaders = await user.authHeaders;
      final client = _GoogleAuthClient(authHeaders);
      return drive.DriveApi(client);
    } catch (e) {
      debugPrint('Drive API auth error: $e');
      return null;
    }
  }

  /// Get or create the backup folder in Google Drive
  static Future<String?> _getOrCreateFolder(drive.DriveApi api) async {
    final result = await api.files.list(
      q: "name='$_backupFolderName' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      spaces: 'drive',
    );

    if (result.files != null && result.files!.isNotEmpty) {
      return result.files!.first.id;
    }

    final folder = await api.files.create(
      drive.File()
        ..name = _backupFolderName
        ..mimeType = 'application/vnd.google-apps.folder',
    );
    return folder.id;
  }

  /// Upload backup data to Google Drive
  static Future<BackupResult> backupToGoogleDrive(
    Map<String, dynamic> data,
  ) async {
    final user = _currentUser;
    if (user == null) {
      return BackupResult(success: false, message: 'Not signed in to Google');
    }

    try {
      final api = await _getDriveApi(user);
      if (api == null) {
        return BackupResult(
          success: false,
          message: 'Failed to connect to Google Drive',
        );
      }

      final folderId = await _getOrCreateFolder(api);
      if (folderId == null) {
        return BackupResult(
          success: false,
          message: 'Failed to create backup folder',
        );
      }

      final jsonString = jsonEncode(data);
      final encryptedString = _encryptData(jsonString);

      final payload = jsonEncode({
        'version': 2,
        'timestamp': DateTime.now().toIso8601String(),
        'data': encryptedString,
      });
      final bytes = utf8.encode(payload);
      final stream = Stream.value(bytes);

      // Check if file already exists → update, otherwise create
      final existing = await api.files.list(
        q: "name='$_backupFileName' and '$folderId' in parents and trashed=false",
        spaces: 'drive',
      );

      if (existing.files != null && existing.files!.isNotEmpty) {
        await api.files.update(
          drive.File()..name = _backupFileName,
          existing.files!.first.id!,
          uploadMedia: drive.Media(stream, bytes.length),
        );
      } else {
        await api.files.create(
          drive.File()
            ..name = _backupFileName
            ..parents = [folderId],
          uploadMedia: drive.Media(stream, bytes.length),
        );
      }

      return BackupResult(
        success: true,
        message: 'Backup completed successfully!',
        timestamp: DateTime.now(),
        sizeBytes: bytes.length,
      );
    } catch (e) {
      debugPrint('Backup error: $e');
      return BackupResult(success: false, message: 'Backup failed: $e');
    }
  }

  /// Download and restore data from Google Drive
  static Future<RestoreResult> restoreFromGoogleDrive() async {
    final user = _currentUser;
    if (user == null) {
      return RestoreResult(success: false, message: 'Not signed in to Google');
    }

    try {
      final api = await _getDriveApi(user);
      if (api == null) {
        return RestoreResult(
          success: false,
          message: 'Failed to connect to Google Drive',
        );
      }

      final folderId = await _getOrCreateFolder(api);
      if (folderId == null) {
        return RestoreResult(
          success: false,
          message: 'Backup folder not found',
        );
      }

      final existing = await api.files.list(
        q: "name='$_backupFileName' and '$folderId' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name,modifiedTime,size)',
      );

      if (existing.files == null || existing.files!.isEmpty) {
        return RestoreResult(
          success: false,
          message: 'No backup found in Google Drive',
        );
      }

      final file = existing.files!.first;
      final response =
          await api.files.get(
                file.id!,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final List<int> chunks = [];
      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
      }

      final jsonData = jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>;
      
      final version = jsonData['version'] as int? ?? 1;
      Map<String, dynamic>? dataMap;

      if (version == 2) {
        try {
          final encryptedString = jsonData['data'] as String;
          final decryptedString = _decryptData(encryptedString);
          dataMap = jsonDecode(decryptedString) as Map<String, dynamic>?;
        } catch (e) {
          return RestoreResult(
            success: false,
            message: 'Failed to decrypt backup data. The data might be corrupted.',
          );
        }
      } else {
        dataMap = jsonData['data'] as Map<String, dynamic>?;
      }

      return RestoreResult(
        success: true,
        message: 'Restore completed successfully!',
        data: dataMap,
        timestamp: file.modifiedTime,
      );
    } catch (e) {
      debugPrint('Restore error: $e');
      return RestoreResult(success: false, message: 'Restore failed: $e');
    }
  }

  /// Get info about the latest backup on Drive
  static Future<BackupInfo?> getLatestBackupInfo() async {
    final user = _currentUser;
    if (user == null) return null;

    try {
      final api = await _getDriveApi(user);
      if (api == null) return null;

      final folderId = await _getOrCreateFolder(api);
      if (folderId == null) return null;

      final existing = await api.files.list(
        q: "name='$_backupFileName' and '$folderId' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name,modifiedTime,size)',
      );

      if (existing.files == null || existing.files!.isEmpty) return null;

      final f = existing.files!.first;
      return BackupInfo(
        fileId: f.id!,
        modifiedTime: f.modifiedTime,
        sizeBytes: int.tryParse(f.size ?? '0') ?? 0,
      );
    } catch (e) {
      debugPrint('Get backup info error: $e');
      return null;
    }
  }
}

class BackupResult {
  final bool success;
  final String message;
  final DateTime? timestamp;
  final int? sizeBytes;

  BackupResult({
    required this.success,
    required this.message,
    this.timestamp,
    this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes == null || sizeBytes == 0) return '';
    if (sizeBytes! < 1024) return '$sizeBytes B';
    if (sizeBytes! < 1024 * 1024)
      return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class RestoreResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime? timestamp;

  RestoreResult({
    required this.success,
    required this.message,
    this.data,
    this.timestamp,
  });
}

class BackupInfo {
  final String fileId;
  final DateTime? modifiedTime;
  final int sizeBytes;

  BackupInfo({
    required this.fileId,
    this.modifiedTime,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024)
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
