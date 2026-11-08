import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../more_apps/data/models/app_model.dart';
import '../../../more_apps/presentation/providers/more_apps_providers.dart';
import '../providers/app_config_providers.dart';
import 'app_testing_gate_sheet.dart';

/// Modal bottom sheet presented when user taps an approval notification
/// or clicks "View Testing Apps" in Settings.
class BetaTestingAppsSheet extends ConsumerWidget {
  const BetaTestingAppsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BetaTestingAppsSheet(),
    );
  }

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $urlString';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Google Play Store: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mediaQuery = MediaQuery.of(context);
    final userEmail = ref.watch(userEmailProvider);
    final appsAsync = ref.watch(activeAppsStreamProvider);

    final double bottomInset = mediaQuery.viewInsets.bottom;
    final double safeBottomPadding = mediaQuery.padding.bottom;
    final double computedBottomPadding =
        bottomInset > 0 ? bottomInset + 16 : safeBottomPadding + 24;

    return Container(
      constraints: BoxConstraints(
        maxHeight: mediaQuery.size.height * 0.90,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: computedBottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 2. Header with Celebration Badge & Close button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006D5B), Color(0xFF00D084)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF006D5B).withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Beta Testing Access Granted!',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Universal access to all our closed testing apps',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3. CRITICAL Google Account Guidance Warning Box (#1 Reason for Play Store errors)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade500.withValues(alpha: isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.amber.shade600.withValues(alpha: isDark ? 0.45 : 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_rounded,
                  color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Important: Google Play Account Notice',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.amber.shade200 : Colors.amber.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                            height: 1.45,
                          ),
                          children: [
                            const TextSpan(
                              text:
                                  'Please make sure you are signed into Google Play Store with your approved account: ',
                            ),
                            TextSpan(
                              text: userEmail.isNotEmpty ? userEmail : '(your approved email)',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.amber.shade300 : const Color(0xFF006D5B),
                              ),
                            ),
                            const TextSpan(
                              text:
                                  '. If Google Play Store is switched to a different account, the app will show "Item not found" or will not be downloadable.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 4. Section Title
          Text(
            'Available Closed Testing Apps',
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),

          // 5. Scrollable Apps List
          Flexible(
            child: appsAsync.when(
              data: (apps) {
                final testingApps =
                    apps.where((app) => app.mode == 'testing').toList();

                if (testingApps.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 40,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'No new closed testing apps right now.',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'You will be notified whenever a new testing app arrives!',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: theme.colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: testingApps.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final app = testingApps[index];
                    return _buildTestingAppCard(context, app, theme, isDark);
                  },
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              ),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Failed to load testing apps: $e',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 6. Footer: Edit Details / Switch Email link
          Center(
            child: TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                AppTestingGateSheet.show(context, null, true);
              },
              icon: const Icon(Icons.edit_note_rounded, size: 16),
              label: Text(
                'Need to update your registered email?',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestingAppCard(
    BuildContext context,
    AppModel app,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
            : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          // App Icon
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: app.imageUrl,
              width: 52,
              height: 52,
              memCacheWidth: 140,
              memCacheHeight: 140,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 52,
                height: 52,
                color: Colors.grey[200],
                child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                width: 52,
                height: 52,
                color: theme.colorScheme.primaryContainer,
                child: Icon(
                  Icons.apps_rounded,
                  color: theme.colorScheme.primary,
                  size: 26,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Title & Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade500.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.amber.shade700.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Text(
                        'Beta',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.amber.shade300
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (app.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    app.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Direct Install on Play Store Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006D5B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            onPressed: () => _launchUrl(context, app.playStoreUrl),
            icon: const Icon(Icons.install_mobile_rounded, size: 16),
            label: Text(
              'Install',
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
