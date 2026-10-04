import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/follow_ups_screen.dart';
import '../services/follow_up_service.dart';
import '../services/settings_service.dart';

class HomeFollowUpsBanner extends StatelessWidget {
  const HomeFollowUpsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final followUpService = context.watch<FollowUpService>();
    final pending = followUpService.pendingFollowUps;
    if (pending.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currencySymbol = context.watch<SettingsService>().currencySymbol;

    final overdueCount = followUpService.overdueFollowUps.length;
    final todayCount = followUpService.todayFollowUps.length;
    final urgentCount = overdueCount + todayCount;

    final receivable = followUpService.totalReceivablePending;
    final payable = followUpService.totalPayablePending;

    final bannerColor = urgentCount > 0 ? const Color(0xFFFF5F5F) : const Color(0xFF006D5B);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: bannerColor.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (ctx) => const FollowUpsScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Icon / Avatar with alert pulse or badge
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: bannerColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(
                        urgentCount > 0
                            ? Icons.notifications_active_rounded
                            : Icons.event_note_rounded,
                        color: bannerColor,
                        size: 22,
                      ),
                      if (urgentCount > 0)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFF5F5F),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),

                // Title and Amount info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            urgentCount > 0
                                ? '$urgentCount Urgent Follow-up${urgentCount > 1 ? "s" : ""}'
                                : '${pending.length} Follow-up${pending.length > 1 ? "s" : ""} Pending',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: urgentCount > 0
                                  ? const Color(0xFFFF5F5F)
                                  : (isDark ? Colors.white : const Color(0xFF1F2937)),
                            ),
                          ),
                          if (overdueCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF5F5F).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$overdueCount overdue',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF5F5F),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (receivable > 0)
                            Text(
                              'Collect: $currencySymbol ${receivable.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00D084),
                              ),
                            ),
                          if (receivable > 0 && payable > 0)
                            const Text('  •  ', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          if (payable > 0)
                            Text(
                              'Pay: $currencySymbol ${payable.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF5F5F),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
