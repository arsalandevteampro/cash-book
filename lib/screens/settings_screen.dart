import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/settings_service.dart';

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

    final List<Map<String, String>> currencies = [
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

    bool isCurrentSymbolInList = currencies.any((c) => c['symbol'] == settingsService.currencySymbol);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General',
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  _buildCurrencySetting(context, settingsService, currencies, isCurrentSymbolInList),
                  const SizedBox(height: 24),
                  _buildThemeSetting(context, settingsService),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              subtitle: const Text('Version 1.0.0'),
              onTap: () {
                // Show about dialog
                 showAboutDialog(
                  context: context,
                  applicationName: 'Cash Book',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024 Your Company',
                  children: <Widget>[
                    const SizedBox(height: 15),
                    const Text('A simple app to manage your daily income and expenses.')
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencySetting(
    BuildContext context,
    SettingsService settingsService,
    List<Map<String, String>> currencies,
    bool isCurrentSymbolInList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Default Currency',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: isCurrentSymbolInList ? settingsService.currencySymbol : currencies.first['symbol'],
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.currency_rupee),
            border: OutlineInputBorder(),
          ),
          onChanged: (String? newSymbol) async {
            if (newSymbol != null) {
              try {
                await settingsService.setCurrency(newSymbol);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Currency updated successfully'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${settingsService.error ?? e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            }
          },
          items: currencies.map<DropdownMenuItem<String>>((Map<String, String> currency) {
            return DropdownMenuItem<String>(
              value: currency['symbol'],
              child: Text('${currency['name']} (${currency['symbol']})'),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThemeSetting(BuildContext context, SettingsService settingsService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Theme',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _buildThemeOption(
                context,
                settingsService,
                'light',
                'Light',
                Icons.light_mode,
              ),
              const Divider(height: 1),
              _buildThemeOption(
                context,
                settingsService,
                'dark',
                'Dark',
                Icons.dark_mode,
              ),
              const Divider(height: 1),
              _buildThemeOption(
                context,
                settingsService,
                'system',
                'System',
                Icons.brightness_auto,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    SettingsService settingsService,
    String value,
    String title,
    IconData icon,
  ) {
    final isSelected = settingsService.theme == value;
    
    return InkWell(
      onTap: () async {
        await _updateTheme(context, settingsService, value, title);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected 
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              )
            else
              Icon(
                Icons.radio_button_unchecked,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTheme(BuildContext context, SettingsService settingsService, String newTheme, String themeName) async {
    try {
      await settingsService.setTheme(newTheme);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Theme changed to $themeName'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${settingsService.error ?? e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
