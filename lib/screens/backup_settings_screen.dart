import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/services/google_drive_service.dart';
import 'package:myapp/services/settings_service.dart';
import 'package:myapp/services/transaction_service.dart';
import 'package:myapp/services/goals_service.dart';
import 'package:myapp/services/follow_up_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  // Google Account
  GoogleSignInAccount? _signedInUser;
  bool _isSigningIn = false;

  // Backup state
  double _backupProgress = 0.0;
  bool _isBackingUp = false;
  bool _isRestoring = false;
  BackupInfo? _driveBackupInfo;

  @override
  void initState() {
    super.initState();
    _initAccount();
  }

  Future<void> _initAccount() async {
    final account = await GoogleDriveService.signInSilently();
    if (mounted) {
      setState(() => _signedInUser = account);
      if (account != null) _loadBackupInfo();
    }
  }

  Future<void> _loadBackupInfo() async {
    final info = await GoogleDriveService.getLatestBackupInfo();
    if (mounted) {
      setState(() => _driveBackupInfo = info);
    }
  }

  Future<void> _signIn() async {
    setState(() => _isSigningIn = true);
    final account = await GoogleDriveService.signIn();
    if (mounted) {
      setState(() {
        _signedInUser = account;
        _isSigningIn = false;
      });
      if (account != null) _loadBackupInfo();
    }
  }

  Future<void> _signOut() async {
    await GoogleDriveService.signOut();
    if (mounted) {
      setState(() {
        _signedInUser = null;
        _driveBackupInfo = null;
      });
    }
  }

  Future<void> _runBackup({bool forceOverwrite = false}) async {
    if (_signedInUser == null) {
      _showError('Please sign in to Google first.');
      return;
    }

    // Safety Guard: Check if local transactions are 0 while cloud backup has existing data
    if (!forceOverwrite && _driveBackupInfo != null && _driveBackupInfo!.sizeBytes > 0) {
      final txCount = Provider.of<TransactionService>(context, listen: false).transactions.length;
      if (txCount == 0) {
        final shouldProceed = await _showEmptyBackupWarningDialog();
        if (!shouldProceed) return;
        forceOverwrite = true;
      }
    }

    if (!mounted) return;
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    final backupFrequency = settingsService.backupFrequency;

    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.0;
    });

    // Simulate progress while actual backup runs
    _simulateProgress();

    // Prepare real application data
    final backupData = await DatabaseService.exportDataAsync();
    backupData['frequency'] = backupFrequency;
    backupData['timestamp'] = DateTime.now().toIso8601String();

    final result = await GoogleDriveService.backupToGoogleDrive(
      backupData,
      forceOverwrite: forceOverwrite,
    );

    if (mounted) {
      if (result.success) {
        final settingsService = Provider.of<SettingsService>(context, listen: false);
        await settingsService.setLastBackupTimestamp(DateTime.now().millisecondsSinceEpoch);
      }

      setState(() {
        _isBackingUp = false;
        _backupProgress = 0.0;
      });

      if (result.isSafetyBlocked) {
        _showSafetyBlockedDialog();
      } else {
        _showSnack(result.message, success: result.success);
      }
      if (result.success) _loadBackupInfo();
    }
  }

  void _showSafetyBlockedDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.shield_outlined, color: Colors.amber, size: 36),
              ),
              const SizedBox(height: 14),
              const Text(
                'Backup Protected',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Your Google Drive contains an existing backup with records, but your phone currently has 0 transactions.\n\nTo prevent accidental data loss, the backup was stopped.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  fontSize: 13,
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _runRestore();
                  },
                  icon: const Icon(Icons.restore_rounded, size: 20),
                  label: const Text(
                    'Restore Data Now',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _showEmptyBackupWarningDialog() async {
    final driveDate = _driveBackupInfo?.modifiedTime;
    final driveDateStr = driveDate != null
        ? DateFormat('d MMM yyyy, h:mm a').format(driveDate.toLocal())
        : 'Existing';
    final driveSize = _driveBackupInfo?.formattedSize ?? '';

    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          contentPadding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 36),
              ),
              const SizedBox(height: 14),
              const Text(
                'Overwrite Warning',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              // Cloud backup summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.cloud_done_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Google Drive Backup Found',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.hintColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$driveDateStr • $driveSize',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Your app currently has NO records (0 transactions). Backing up now will overwrite your cloud data with empty records.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.4,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Did you mean to Restore your previous data instead?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.hintColor,
                ),
              ),
              const SizedBox(height: 20),
              // Primary Action: Restore Instead
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx, false);
                    _runRestore();
                  },
                  icon: const Icon(Icons.restore_rounded, size: 20),
                  label: const Text(
                    'Restore Instead',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Secondary Actions Row: Cancel & Overwrite Anyway
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyMedium?.color?.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(
                        backgroundColor: theme.colorScheme.error.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: theme.colorScheme.error,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Overwrite Anyway',
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ) ?? false;
  }

  void _simulateProgress() async {
    for (int i = 0; i <= 90; i += 5) {
      if (!mounted || !_isBackingUp) return;
      setState(() => _backupProgress = i / 100);
      await Future.delayed(const Duration(milliseconds: 120));
    }
  }

  Future<void> _applyRestoredData(RestoreResult result) async {
    if (result.success) {
      if (result.data != null) {
        try {
          await DatabaseService.importData(result.data!);

          if (!mounted) return;
          final settingsService = Provider.of<SettingsService>(context, listen: false);
          final restoreTime = result.timestamp?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch;
          await settingsService.setLastBackupTimestamp(restoreTime);

          if (result.data!['frequency'] != null) {
            await settingsService.setBackupFrequency(result.data!['frequency']);
          }
          await settingsService.initialize();
          if (!mounted) return;
          await Provider.of<TransactionService>(context, listen: false).initialize();
          if (!mounted) return;
          await Provider.of<GoalsService>(context, listen: false).initialize();
          if (!mounted) return;
          await Provider.of<FollowUpService>(context, listen: false).loadFollowUps();
          if (!mounted) return;

          final count = result.transactionCount;
          final countText = (count != null && count > 0) ? ' ($count records restored)' : '';
          _showSnack('Data restored successfully$countText!', success: true);
        } catch (e) {
          _showError('Error importing data: $e');
        }
      } else {
        _showSnack(
          'Backup file was empty (0 records found)',
          success: false,
        );
      }
    } else {
      _showError(result.message);
    }
  }

  Future<void> _runRestore() async {
    if (_signedInUser == null) {
      _showError('Please sign in to Google first.');
      return;
    }

    final confirmed = await _showRestoreConfirmDialog();
    if (!confirmed) return;

    setState(() => _isRestoring = true);
    final result = await GoogleDriveService.restoreFromGoogleDrive();

    if (mounted) {
      setState(() => _isRestoring = false);
      await _applyRestoredData(result);
    }
  }

  Future<void> _restoreSpecificRevision(BackupRevision rev) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Restore Version'),
        content: Text(
          'Restore records from:\n'
          '📅 ${DateFormat('d MMM yyyy, h:mm a').format(rev.modifiedTime?.toLocal() ?? DateTime.now())}\n'
          '📦 Size: ${rev.formattedSize}\n\n'
          'This will restore all transactions and settings from this specific backup. Proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Restore This Version'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirmed) return;

    setState(() => _isRestoring = true);
    final result = await GoogleDriveService.restoreRevision(rev.fileId, rev.revisionId);
    if (mounted) {
      setState(() => _isRestoring = false);
      await _applyRestoredData(result);
    }
  }

  void _showVersionHistoryBottomSheet() {
    if (_signedInUser == null) {
      _showError('Please sign in to Google first.');
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: FutureBuilder<List<BackupRevision>>(
            future: GoogleDriveService.getBackupRevisions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Checking Google Drive version history...'),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError || snapshot.data == null || snapshot.data!.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 48, color: Colors.grey),
                    const SizedBox(height: 12),
                    const Text(
                      'No Previous Versions Found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Only the latest backup is currently available in Google Drive.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }

              final revisions = snapshot.data!;
              final theme = Theme.of(context);

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          size: 20,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Backup Version History',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${revisions.length} ${revisions.length == 1 ? 'version' : 'versions'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.hintColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select an older backup to restore if your recent backup was empty or overwritten.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.hintColor,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: revisions.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final rev = revisions[index];
                        final isLatest = index == 0;
                        final dateStr = rev.modifiedTime != null
                            ? DateFormat(
                                'd MMM yyyy, h:mm a',
                              ).format(rev.modifiedTime!.toLocal())
                            : 'Unknown Date';

                        final cardBg = theme.brightness == Brightness.light
                            ? const Color(0xFFF7F9FB)
                            : theme.cardColor;

                        final borderColor = isLatest
                            ? const Color(0xFF00D084).withValues(alpha: 0.35)
                            : theme.dividerColor.withValues(alpha: 0.12);

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: borderColor,
                              width: isLatest ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isLatest
                                      ? const Color(
                                          0xFF00D084,
                                        ).withValues(alpha: 0.12)
                                      : Colors.blue.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isLatest
                                      ? Icons.cloud_done_rounded
                                      : Icons.history_rounded,
                                  color: isLatest
                                      ? const Color(0xFF00D084)
                                      : Colors.blue,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Size: ${rev.formattedSize}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.hintColor,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (isLatest) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF00D084,
                                              ).withValues(alpha: 0.15),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'Latest',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF00D084),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.pop(sheetContext);
                                  _restoreSpecificRevision(rev);
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF006D5B),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Restore',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _showRestoreConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Restore Backup'),
            content: const Text(
              'This will replace your current data with the data from Google Drive. Are you sure you want to proceed?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Restore'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txService = Provider.of<TransactionService>(context);
    final localTxCount = txService.transactions.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Backup & Restore',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).brightness == Brightness.light 
                ? const Color(0xFF006D5B)
                : const Color(0xFF00D084),
            fontSize: 20,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            if (localTxCount == 0 && _driveBackupInfo != null && _driveBackupInfo!.sizeBytes > 0)
              _buildCloudBackupFoundBanner(theme),
            _buildGoogleAccountCard(theme),
            const SizedBox(height: 16),
            _buildBackupStatusCard(theme),
            const SizedBox(height: 16),
            _buildSettingsCard(theme),
            const SizedBox(height: 16),
            _buildRestoreCard(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudBackupFoundBanner(ThemeData theme) {
    final driveDate = _driveBackupInfo?.modifiedTime;
    final driveDateStr = driveDate != null
        ? DateFormat('d MMM yyyy, h:mm a').format(driveDate.toLocal())
        : '';
    final driveSize = _driveBackupInfo?.formattedSize ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF006D5B).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF006D5B).withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.cloud_download_rounded, color: Color(0xFF006D5B), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cloud Backup Found',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    if (driveDateStr.isNotEmpty)
                      Text(
                        '$driveDateStr • $driveSize',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF006D5B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Your app currently has no transactions. Restore your records now to bring back your business data.',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRestoring ? null : _runRestore,
              icon: const Icon(Icons.restore_rounded),
              label: const Text('Restore Data Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006D5B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleAccountCard(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Google Account', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            if (_signedInUser == null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.account_circle,
                    color: theme.colorScheme.primary,
                  ),
                ),
                title: const Text('Not signed in'),
                subtitle: const Text('Connect to Google Drive'),
                trailing: _isSigningIn
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: _signIn,
                        child: const Text('Sign in'),
                      ),
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundImage: _signedInUser!.photoUrl != null
                      ? NetworkImage(_signedInUser!.photoUrl!)
                      : null,
                  backgroundColor: theme.colorScheme.primary,
                  child: _signedInUser!.photoUrl == null
                      ? Text(
                          _signedInUser!.displayName?[0].toUpperCase() ?? 'G',
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Text(_signedInUser!.displayName ?? 'Google Account'),
                subtitle: Text(_signedInUser!.email),
                trailing: TextButton(
                  onPressed: _signOut,
                  child: Text(
                    'Sign out',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupStatusCard(ThemeData theme) {
    final driveDate = _driveBackupInfo?.modifiedTime;
    final driveDateStr = driveDate != null
        ? DateFormat('d MMM yyyy, h:mm a').format(driveDate.toLocal())
        : 'No backup found';
    final driveSize = _driveBackupInfo?.formattedSize ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Last Backup', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driveSize.isNotEmpty
                            ? '$driveDateStr • $driveSize'
                            : driveDateStr,
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Google Drive',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isBackingUp)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _backupProgress,
                    backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Backing up... ${(_backupProgress * 100).toInt()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _runBackup,
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: const Text('Back Up Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D084),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Settings', style: theme.textTheme.titleMedium),
          ),
          ListTile(
            title: const Text('Auto Backup Schedule'),
            subtitle: Text(Provider.of<SettingsService>(context).backupFrequency),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showFrequencySelectorDialog(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildRestoreCard(ThemeData theme) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Restore', style: theme.textTheme.titleMedium),
          ),
          ListTile(
            leading: _isRestoring
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.restore, color: theme.colorScheme.primary),
            title: const Text('Restore Latest Backup'),
            subtitle: Text(
              _driveBackupInfo != null
                  ? 'Restore from last backup (${_driveBackupInfo!.formattedSize})'
                  : 'No backup available to restore',
            ),
            onTap: _isRestoring ? null : _runRestore,
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          ListTile(
            leading: Icon(Icons.history_rounded, color: theme.colorScheme.primary),
            title: const Text('Restore from Version History'),
            subtitle: const Text('Recover older backups if recent backup was overwritten'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _isRestoring ? null : _showVersionHistoryBottomSheet,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showFrequencySelectorDialog() {
    final options = ['Never', 'Immediately', 'Daily', 'Weekly', 'Monthly'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto Backup Schedule'),
        content: Consumer<SettingsService>(
          builder: (context, settingsService, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: options
                  .map(
                    (opt) => RadioListTile<String>(
                      title: Text(opt),
                      value: opt,
                      groupValue: settingsService.backupFrequency,
                      onChanged: (val) async {
                        await settingsService.setBackupFrequency(val!);
                        if (context.mounted) Navigator.pop(ctx);
                      },
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ),
    );
  }
}
