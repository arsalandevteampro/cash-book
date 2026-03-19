import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:myapp/services/database_service.dart';
import 'package:myapp/services/google_drive_service.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen> {
  // Settings state
  String _frequency = 'Daily';

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

  Future<void> _runBackup() async {
    if (_signedInUser == null) {
      _showError('Please sign in to Google first.');
      return;
    }

    setState(() {
      _isBackingUp = true;
      _backupProgress = 0.0;
    });

    // Simulate progress while actual backup runs
    _simulateProgress();

    // Prepare real application data
    final backupData = DatabaseService.exportData();
    backupData['frequency'] = _frequency;
    backupData['timestamp'] = DateTime.now().toIso8601String();

    final result = await GoogleDriveService.backupToGoogleDrive(backupData);

    if (mounted) {
      setState(() {
        _isBackingUp = false;
        _backupProgress = 0.0;
      });

      _showSnack(result.message, success: result.success);
      if (result.success) _loadBackupInfo();
    }
  }

  void _simulateProgress() async {
    for (int i = 0; i <= 90; i += 5) {
      if (!mounted || !_isBackingUp) return;
      setState(() => _backupProgress = i / 100);
      await Future.delayed(const Duration(milliseconds: 120));
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

      if (result.success) {
        if (result.data != null) {
          try {
            await DatabaseService.importData(result.data!);
            setState(() {
              _frequency = result.data!['frequency'] ?? _frequency;
            });
            _showSnack('Data restored successfully!', success: true);
          } catch (e) {
            _showError('Error importing data: $e');
          }
        } else {
          _showSnack(
            'Data restored successfully (Empty backup)',
            success: true,
          );
        }
      } else {
        _showError(result.message);
      }
    }
  }

  Future<bool> _showRestoreConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
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
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildGoogleAccountCard(theme),
          const SizedBox(height: 16),
          _buildBackupStatusCard(theme),
          const SizedBox(height: 16),
          _buildSettingsCard(theme),
          const SizedBox(height: 16),
          _buildRestoreCard(theme),
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
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
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
                    backgroundColor: theme.dividerColor.withOpacity(0.1),
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
                  icon: const Icon(Icons.backup),
                  label: const Text('Back Up Now'),
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
            subtitle: Text(_frequency),
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
            title: const Text('Restore Data'),
            subtitle: Text(
              _driveBackupInfo != null
                  ? 'Restore from last backup'
                  : 'No backup available to restore',
            ),
            onTap: _isRestoring ? null : _runRestore,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _showFrequencySelectorDialog() {
    final options = ['Never', 'Daily', 'Weekly', 'Monthly'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Auto Backup Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options
              .map(
                (opt) => RadioListTile<String>(
                  title: Text(opt),
                  value: opt,
                  groupValue: _frequency,
                  onChanged: (val) {
                    setState(() => _frequency = val!);
                    Navigator.pop(ctx);
                  },
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
