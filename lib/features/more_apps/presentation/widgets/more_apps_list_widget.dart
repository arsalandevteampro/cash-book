import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../features/app_config/presentation/widgets/app_testing_gate_sheet.dart';
import '../../../app_config/presentation/providers/app_config_providers.dart';
import '../providers/more_apps_providers.dart';

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
            content: Text('Could not open Play Store: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(activeAppsStreamProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Beta Access Request or Change Details Banner
        _buildBetaAccessBanner(context, ref),

        // Apps List
        appsAsync.when(
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

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                final isTesting = app.mode == 'testing';

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
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
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 46,
                                  height: 46,
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
                            // App Title & Beta Tag
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
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                      if (isTesting) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.amber.shade500.withValues(alpha: 0.18),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: Colors.amber.shade700.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.science_rounded, size: 10, color: Colors.amber.shade800),
                                              const SizedBox(width: 2),
                                              Text(
                                                'Beta',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber.shade900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  if (app.description.isNotEmpty) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      app.description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Trailing Play Store Link Icon
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.open_in_new_rounded,
                                size: 15,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
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
        ),
      ],
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

  Widget _buildBetaAccessBanner(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final userEmail = ref.watch(userEmailProvider);
    final requestAsync = ref.watch(appAccessRequestStreamProvider('cash-book'));
    final accessGrantedAsync = ref.watch(isSpecificAppAccessGrantedProvider('cash-book'));

    final request = requestAsync.value;
    final bool isApproved = (accessGrantedAsync.value ?? false) || (request?.isApproved ?? false);
    final bool isPending = request?.isPending ?? false;
    final bool isRejected = request?.isRejected ?? false;
    final bool hasRequest = userEmail.isNotEmpty && (request != null || isApproved);

    // Dynamic banner styling based on status
    Color accentColor = theme.colorScheme.primary;
    Color iconBgColor = theme.colorScheme.primary;
    IconData headerIcon = Icons.science_rounded;
    String statusTitle = 'Beta Testing Access';
    String subtitleText = '1-click request unlocks all beta apps';
    String? statusBadge;
    Color? badgeColor;
    bool showChangeDetails = false;

    if (hasRequest && isApproved) {
      accentColor = Colors.green;
      iconBgColor = Colors.green;
      headerIcon = Icons.check_circle_rounded;
      statusBadge = 'Access Granted';
      badgeColor = isDark ? Colors.green.shade300 : Colors.green.shade700;
      subtitleText = userEmail;
      showChangeDetails = true;
    } else if (hasRequest && isPending) {
      accentColor = Colors.orange;
      iconBgColor = Colors.orange;
      headerIcon = Icons.hourglass_top_rounded;
      statusBadge = 'Request Pending';
      badgeColor = isDark ? Colors.orange.shade300 : Colors.orange.shade800;
      subtitleText = request?.email.isNotEmpty == true ? request!.email : userEmail;
      showChangeDetails = true;
    } else if (hasRequest && isRejected) {
      accentColor = Colors.red;
      iconBgColor = Colors.red;
      headerIcon = Icons.cancel_rounded;
      statusBadge = 'Access Declined';
      badgeColor = isDark ? Colors.red.shade300 : Colors.red.shade700;
      subtitleText = request?.email.isNotEmpty == true ? request!.email : userEmail;
      showChangeDetails = true;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentColor.withValues(alpha: isDark ? 0.22 : 0.14),
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
                child: Icon(
                  headerIcon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statusTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: showChangeDetails
                            ? (isDark ? accentColor.withValues(alpha: 0.9) : accentColor)
                            : theme.colorScheme.primary,
                      ),
                    ),
                    if (statusBadge != null)
                      Row(
                        children: [
                          Text(
                            statusBadge,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeColor,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              ' • $subtitleText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        subtitleText,
                        style: TextStyle(
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
          SizedBox(
            width: double.infinity,
            child: showChangeDetails
                ? OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? accentColor.withValues(alpha: 0.95) : accentColor,
                      side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      AppTestingGateSheet.show(context);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 15),
                    label: const Text(
                      'Change Request Details',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 1,
                    ),
                    onPressed: () {
                      AppTestingGateSheet.show(context);
                    },
                    icon: const Icon(Icons.send_rounded, size: 15),
                    label: const Text(
                      'Request Access',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
