import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../features/app_config/presentation/widgets/app_testing_gate_sheet.dart';
import '../../../../features/app_config/presentation/widgets/beta_testing_apps_sheet.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../providers/more_apps_providers.dart';
import '../../data/models/app_model.dart';

class MoreAppsListWidget extends ConsumerWidget {
  const MoreAppsListWidget({super.key});

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
    final appsAsync = ref.watch(activeAppsStreamProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return appsAsync.when(
      data: (apps) {
        if (apps.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Text(
                'No apps available.',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              ),
            ),
          );
        }

        final productionApps = apps.where((a) => a.mode == 'production').toList();
        final testingApps = apps.where((a) => a.mode == 'testing').toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────────
            // SECTION 1: PUBLIC / LIVE PLAY STORE APPS (Zero Request Barrier)
            // ─────────────────────────────────────────────────────────────
            if (productionApps.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                child: Row(
                  children: [
                    const Icon(
                      Icons.storefront_rounded,
                      size: 16,
                      color: Color(0xFF006D5B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Our Apps on Google Play',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: productionApps.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final app = productionApps[index];
                  return _buildProductionAppCard(context, app, theme, isDark);
                },
              ),
              const SizedBox(height: 20),
            ],

            // ─────────────────────────────────────────────────────────────
            // SECTION 2: CLOSED TESTING / BETA APPS (With Guidance Hub)
            // ─────────────────────────────────────────────────────────────
            _buildBetaTestingSection(context, ref, testingApps, theme, isDark),
          ],
        );
      },
      loading: () => _buildLoadingSkeleton(),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          children: [
            const Text(
              'Failed to load apps.',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(activeAppsStreamProvider);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  /// Card for Public / Production Play Store Apps
  Widget _buildProductionAppCard(
    BuildContext context,
    AppModel app,
    ThemeData theme,
    bool isDark,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _launchUrl(context, app.playStoreUrl),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                // App Icon
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: app.imageUrl,
                    width: 46,
                    height: 46,
                    memCacheWidth: 120,
                    memCacheHeight: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 46,
                      height: 46,
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 46,
                      height: 46,
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.apps_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
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
                      Text(
                        app.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      if (app.description.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          app.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Direct Install on Play Store Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006D5B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _launchUrl(context, app.playStoreUrl),
                  icon: const Icon(Icons.install_mobile_rounded, size: 14),
                  label: Text(
                    'Install',
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Beta Testing Section with Status Card & Direct Testing Apps Hub
  Widget _buildBetaTestingSection(
    BuildContext context,
    WidgetRef ref,
    List<AppModel> testingApps,
    ThemeData theme,
    bool isDark,
  ) {
    final userEmail = ref.watch(userEmailProvider);
    final requestAsync = ref.watch(appAccessRequestStreamProvider('cash-book'));
    final accessGrantedAsync =
        ref.watch(isSpecificAppAccessGrantedProvider('cash-book'));

    final request = requestAsync.value;
    final bool isApproved =
        (accessGrantedAsync.value ?? false) || (request?.isApproved ?? false);
    final bool isPending = request?.isPending ?? false;
    final bool isRejected = request?.isRejected ?? false;
    final bool hasRequest =
        userEmail.isNotEmpty && (request != null || isApproved);

    Color accentColor = const Color(0xFF006D5B);
    Color iconBgColor = const Color(0xFF006D5B);
    IconData headerIcon = Icons.science_rounded;
    String statusTitle = 'Join Beta Testing Program';
    String subtitleText =
        '1-time request gives you access to all upcoming unreleased apps';

    if (hasRequest && isApproved) {
      accentColor = const Color(0xFF10B981);
      iconBgColor = const Color(0xFF10B981);
      headerIcon = Icons.verified_rounded;
      statusTitle = 'Beta Access Granted!';
      subtitleText = 'Approved for: $userEmail';
    } else if (hasRequest && isPending) {
      accentColor = Colors.orange;
      iconBgColor = Colors.orange;
      headerIcon = Icons.hourglass_top_rounded;
      statusTitle = 'Beta Request Pending';
      subtitleText = 'Waiting for developer approval ($userEmail)';
    } else if (hasRequest && isRejected) {
      accentColor = Colors.red;
      iconBgColor = Colors.red;
      headerIcon = Icons.cancel_rounded;
      statusTitle = 'Access Declined';
      subtitleText = 'Contact developer or re-submit request';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              Icon(
                Icons.science_rounded,
                size: 16,
                color: isDark ? Colors.amber.shade300 : Colors.amber.shade800,
              ),
              const SizedBox(width: 6),
              Text(
                'Beta & Upcoming Apps',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: Colors.amber.shade500.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'Early Access',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.amber.shade300 : Colors.amber.shade900,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Main Beta Status Banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                accentColor.withValues(alpha: isDark ? 0.08 : 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accentColor.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(headerIcon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusTitle,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitleText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Button depending on state
              SizedBox(
                width: double.infinity,
                child: isApproved
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () {
                          BetaTestingAppsSheet.show(context);
                        },
                        icon: const Icon(Icons.rocket_launch_rounded, size: 16),
                        label: Text(
                          testingApps.isNotEmpty
                              ? 'View & Install Testing Apps (${testingApps.length})'
                              : 'Open Testing Apps Hub',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : isPending
                        ? OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? accentColor.withValues(alpha: 0.95)
                                  : accentColor,
                              side: BorderSide(
                                  color: accentColor.withValues(alpha: 0.6)),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              AppTestingGateSheet.show(context, null, true);
                            },
                            icon: const Icon(Icons.edit_rounded, size: 15),
                            label: Text(
                              'Change Request Details',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006D5B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              AppTestingGateSheet.show(context);
                            },
                            icon: const Icon(Icons.send_rounded, size: 15),
                            label: Text(
                              'Request Beta Access',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),

        // Always list the testing apps so users can see which beta apps are available!
        if (testingApps.isNotEmpty) ...[
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: testingApps.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final app = testingApps[index];
              return _buildTestingAppCard(
                context: context,
                app: app,
                theme: theme,
                isDark: isDark,
                isApproved: isApproved,
              );
            },
          ),
        ],
      ],
    );
  }

  /// Card for testing apps (handles both approved & non-approved states)
  Widget _buildTestingAppCard({
    required BuildContext context,
    required AppModel app,
    required ThemeData theme,
    required bool isDark,
    required bool isApproved,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            if (isApproved) {
              _launchUrl(context, app.playStoreUrl);
            } else {
              AppTestingGateSheet.show(context, app);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: app.imageUrl,
                    width: 46,
                    height: 46,
                    memCacheWidth: 120,
                    memCacheHeight: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 46,
                      height: 46,
                      color: Colors.grey[200],
                      child: const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 46,
                      height: 46,
                      color: theme.colorScheme.primaryContainer,
                      child: Icon(
                        Icons.science_rounded,
                        color: theme.colorScheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade500.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(5),
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
                        const SizedBox(height: 2),
                        Text(
                          app.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isApproved)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _launchUrl(context, app.playStoreUrl),
                    icon: const Icon(Icons.install_mobile_rounded, size: 14),
                    label: Text(
                      'Install',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006D5B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => AppTestingGateSheet.show(context, app),
                    icon: const Icon(Icons.lock_open_rounded, size: 13),
                    label: Text(
                      'Get Access',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 2,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey[200],
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.grey[350],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Colors.grey[350],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
