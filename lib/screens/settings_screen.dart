import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';
import '../services/app_lock_service.dart';
import 'backup_settings_screen.dart';
import 'app_lock_screen.dart';
import '../features/more_apps/presentation/widgets/more_apps_list_widget.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final textTheme = Theme.of(context).textTheme;

    final List<Map<String, String>> defaultCurrencies = [
      {'name': 'Pakistani Rupee', 'symbol': 'Rs'},
      {'name': 'Indian Rupee', 'symbol': '₹'},
      {'name': 'US Dollar', 'symbol': '\$'},
      {'name': 'Euro', 'symbol': '€'},
      {'name': 'British Pound', 'symbol': '£'},
      {'name': 'Japanese Yen', 'symbol': '¥'},
      {'name': 'Russian Ruble', 'symbol': '₽'},
      {'name': 'UAE Dirham', 'symbol': 'د.إ'},
      {'name': 'Australian Dollar', 'symbol': 'A\$'},
      {'name': 'Canadian Dollar', 'symbol': 'C\$'},
      {'name': 'Swiss Franc', 'symbol': 'Fr'},
      {'name': 'Malaysian Ringgit', 'symbol': 'RM'},
    ];

    final Set<String> seenSymbols = {};
    final allCurrencies = <Map<String, String>>[];

    for (var c in defaultCurrencies) {
      if (seenSymbols.add(c['symbol']!)) {
        allCurrencies.add(c);
      }
    }

    for (var c in settingsService.customCurrencies) {
      if (seenSymbols.add(c['symbol']!)) {
        allCurrencies.add(c);
      }
    }

    if (!seenSymbols.contains(settingsService.currencySymbol)) {
      allCurrencies.add({
        'name': 'Custom Currency',
        'symbol': settingsService.currencySymbol,
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'General Settings',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),
            _buildCurrencySetting(context, settingsService, allCurrencies),
            const SizedBox(height: 20),
            _buildThemeSetting(context, settingsService),
            const SizedBox(height: 20),
            _buildBackupSetting(context),
            const SizedBox(height: 20),
            _buildSecuritySetting(context),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            Text(
              'More Apps',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            const MoreAppsListWidget(),

            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 8),

            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data != null
                    ? 'Version ${snapshot.data!.version} (${snapshot.data!.buildNumber})'
                    : 'Version 1.1.0';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  title: const Text('About Cash Book'),
                  subtitle: Text(version),
                  onTap: () {
                    showAboutDialog(
                      context: context,
                      applicationName: 'Cash Book',
                      applicationVersion: snapshot.data?.version ?? '1.1.0',
                      applicationLegalese: '© 2024 Your Company',
                      children: <Widget>[
                        const SizedBox(height: 15),
                        const Text(
                          'A simple app to manage your daily income and expenses.',
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySetting(
    BuildContext context,
    SettingsService settingsService,
    List<Map<String, String>> currencies,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Currency', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: settingsService.currencySymbol,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: currencies.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['symbol'],
                    child: Text(
                      '${c['name']} (${c['symbol']})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    settingsService.setCurrency(value);
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddCurrencyDialog(context, settingsService),
              tooltip: 'Add Custom Currency',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeSetting(BuildContext context, SettingsService settingsService) {
    final theme = Theme.of(context);
    final currentTheme = settingsService.theme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('App Theme', style: theme.textTheme.titleMedium),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildThemeOption(
                context,
                title: 'System',
                icon: Icons.brightness_auto_rounded,
                value: 'system',
                currentValue: currentTheme,
                onTap: () => settingsService.setTheme('system'),
              ),
              _buildThemeOption(
                context,
                title: 'Light',
                icon: Icons.light_mode_rounded,
                value: 'light',
                currentValue: currentTheme,
                onTap: () => settingsService.setTheme('light'),
              ),
              _buildThemeOption(
                context,
                title: 'Dark',
                icon: Icons.dark_mode_rounded,
                value: 'dark',
                currentValue: currentTheme,
                onTap: () => settingsService.setTheme('dark'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String value,
    required String currentValue,
    required VoidCallback onTap,
  }) {
    final isSelected = value == currentValue;
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 5),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCurrencyDialog(BuildContext context, SettingsService settingsService) {
    final nameController = TextEditingController();
    final symbolController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Currency'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Currency Name',
                  hintText: 'e.g. Bitcoin',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: symbolController,
                decoration: const InputDecoration(
                  labelText: 'Symbol',
                  hintText: 'e.g. BTC',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await settingsService.addCustomCurrency(
                  nameController.text,
                  symbolController.text,
                );
                await settingsService.setCurrency(symbolController.text);
                if (context.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupSetting(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data Management', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.cloud_done_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          title: const Text('Backup & Restore'),
          subtitle: const Text('Manage your data on Google Drive'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const BackupSettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSecuritySetting(BuildContext context) {
    final lockService = Provider.of<AppLockService>(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Security & App Lock', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.security_rounded,
              color: theme.colorScheme.primary,
              size: 20,
            ),
          ),
          title: const Text('App Lock'),
          subtitle: Text(
            lockService.isLockEnabled
                ? 'Protected with ${lockService.lockType.toUpperCase()}'
                : 'Protect app with PIN, Pattern, or Fingerprint',
          ),
          value: lockService.isLockEnabled,
          onChanged: (bool enabled) async {
            if (enabled) {
              if (!lockService.hasPin && !lockService.hasPattern) {
                _showLockTypeSetupSheet(context, lockService);
              } else {
                await lockService.setLockEnabled(true);
              }
            } else {
              await lockService.setLockEnabled(false);
            }
          },
        ),
        if (lockService.isLockEnabled) ...[
          const Divider(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              lockService.lockType == 'pattern' ? Icons.pattern_rounded : Icons.pin_rounded,
              color: theme.colorScheme.primary,
            ),
            title: const Text('Lock Method'),
            subtitle: Text(lockService.lockType == 'pattern' ? 'Pattern Lock' : '4-Digit PIN Code'),
            trailing: OutlinedButton(
              onPressed: () => _showLockTypeSetupSheet(context, lockService),
              child: const Text('Change'),
            ),
          ),
          FutureBuilder<bool>(
            future: lockService.canCheckBiometrics(),
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();

              return SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  Icons.fingerprint_rounded,
                  color: theme.colorScheme.primary,
                ),
                title: const Text('Unlock with Fingerprint'),
                subtitle: const Text('Use biometrics for fast 1-touch unlock'),
                value: lockService.isBiometricEnabled,
                onChanged: (bool value) {
                  lockService.setBiometricEnabled(value);
                },
              );
            },
          ),
        ],
      ],
    );
  }

  void _showLockTypeSetupSheet(BuildContext context, AppLockService lockService) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose Lock Method',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text('Select how you want to lock and protect Cash Book.'),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.pin_rounded, size: 28),
                title: const Text('4-Digit PIN Code'),
                subtitle: const Text('Enter a numeric 4-digit code'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AppLockScreen(
                        mode: AppLockMode.createPin,
                      ),
                    ),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.pattern_rounded, size: 28),
                title: const Text('Pattern Lock'),
                subtitle: const Text('Draw a 3x3 dot pattern'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AppLockScreen(
                        mode: AppLockMode.createPattern,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}
