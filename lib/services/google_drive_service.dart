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
    Map<String, dynamic> data, {
    bool forceOverwrite = false,
  }) async {
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
        $fields: 'files(id,name,size,modifiedTime)',
      );

      if (existing.files != null && existing.files!.isNotEmpty) {
        final existingFile = existing.files!.first;
        final existingSizeBytes = int.tryParse(existingFile.size ?? '0') ?? 0;

        // Safety Guard: If not forced, prevent overwriting an existing larger backup
        // with an empty/freshly initialized backup (< 1000 bytes vs > 2000 bytes)
        if (!forceOverwrite && bytes.length < 1000 && existingSizeBytes > 2000) {
          return BackupResult(
            success: false,
            message: 'Existing cloud backup contains records ($existingSizeBytes bytes). Overwriting with empty data was prevented for safety.',
            isSafetyBlocked: true,
            sizeBytes: bytes.length,
          );
        }

        await api.files.update(
          drive.File()..name = _backupFileName,
          existingFile.id!,
          uploadMedia: drive.Media(stream, bytes.length),
          keepRevisionForever: true,
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

  /// Internal helper to parse and decrypt backup bytes
  static RestoreResult _parseBackupBytes(List<int> bytes, DateTime? timestamp) {
    try {
      final jsonData = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
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

      int txCount = 0;
      if (dataMap != null) {
        if (dataMap.containsKey('transactionsByBook')) {
          final txByBook = dataMap['transactionsByBook'];
          if (txByBook is Map) {
            for (final list in txByBook.values) {
              if (list is List) txCount += list.length;
            }
          }
        } else if (dataMap.containsKey('transactions')) {
          final list = dataMap['transactions'];
          if (list is List) txCount += list.length;
        }
      }

      return RestoreResult(
        success: true,
        message: 'Restore completed successfully!',
        data: dataMap,
        timestamp: timestamp,
        transactionCount: txCount,
      );
    } catch (e) {
      return RestoreResult(
        success: false,
        message: 'Failed to read backup data: $e',
      );
    }
  }

  /// Download and restore data from the latest backup in Google Drive
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

      return _parseBackupBytes(chunks, file.modifiedTime);
    } catch (e) {
      debugPrint('Restore error: $e');
      return RestoreResult(success: false, message: 'Restore failed: $e');
    }
  }

  /// Get list of all versions/revisions of the backup file stored on Google Drive
  static Future<List<BackupRevision>> getBackupRevisions() async {
    final user = _currentUser;
    if (user == null) return [];

    try {
      final api = await _getDriveApi(user);
      if (api == null) return [];

      final folderId = await _getOrCreateFolder(api);
      if (folderId == null) return [];

      final existing = await api.files.list(
        q: "name='$_backupFileName' and '$folderId' in parents and trashed=false",
        spaces: 'drive',
        $fields: 'files(id,name)',
      );

      if (existing.files == null || existing.files!.isEmpty) return [];

      final fileId = existing.files!.first.id!;
      final revList = await api.revisions.list(
        fileId,
        $fields: 'revisions(id,modifiedTime,size,keepForever)',
      );

      final list = <BackupRevision>[];
      for (final r in revList.revisions ?? []) {
        list.add(
          BackupRevision(
            revisionId: r.id!,
            fileId: fileId,
            modifiedTime: r.modifiedTime,
            sizeBytes: int.tryParse(r.size ?? '0') ?? 0,
          ),
        );
      }

      // Sort newest first
      list.sort(
        (a, b) => (b.modifiedTime ?? DateTime(0)).compareTo(
          a.modifiedTime ?? DateTime(0),
        ),
      );
      return list;
    } catch (e) {
      debugPrint('Error getting revisions: $e');
      return [];
    }
  }

  /// Restore a specific historical revision from Google Drive
  static Future<RestoreResult> restoreRevision(
    String fileId,
    String revisionId,
  ) async {
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

      final rev =
          await api.revisions.get(
                fileId,
                revisionId,
                $fields: 'id,modifiedTime',
              )
              as drive.Revision;

      final response =
          await api.revisions.get(
                fileId,
                revisionId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final List<int> chunks = [];
      await for (final chunk in response.stream) {
        chunks.addAll(chunk);
      }

      return _parseBackupBytes(chunks, rev.modifiedTime);
    } catch (e) {
      debugPrint('Error restoring revision: $e');
      return RestoreResult(
        success: false,
        message: 'Failed to restore revision: $e',
      );
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
  final bool isSafetyBlocked;

  BackupResult({
    required this.success,
    required this.message,
    this.timestamp,
    this.sizeBytes,
    this.isSafetyBlocked = false,
  });

  String get formattedSize {
    if (sizeBytes == null || sizeBytes == 0) return '';
    if (sizeBytes! < 1024) return '$sizeBytes B';
    if (sizeBytes! < 1024 * 1024) {
      return '${(sizeBytes! / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class RestoreResult {
  final bool success;
  final String message;
  final Map<String, dynamic>? data;
  final DateTime? timestamp;
  final int? transactionCount;

  RestoreResult({
    required this.success,
    required this.message,
    this.data,
    this.timestamp,
    this.transactionCount,
  });
}

class BackupRevision {
  final String revisionId;
  final String fileId;
  final DateTime? modifiedTime;
  final int sizeBytes;

  BackupRevision({
    required this.revisionId,
    required this.fileId,
    this.modifiedTime,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
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
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

