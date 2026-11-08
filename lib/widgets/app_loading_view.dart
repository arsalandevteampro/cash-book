import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Premium branded loading view featuring the app icon logo,
/// breathing pulse animation, typography, and an animated emerald 0-100% loading bar.
class AppLoadingView extends StatefulWidget {
  final String message;
  final double? progress; // 0.0 to 1.0, or null for indeterminate

  const AppLoadingView({
    super.key,
    this.message = 'Loading your ledger...',
    this.progress,
  });

  @override
  State<AppLoadingView> createState() => _AppLoadingViewState();
}

class _AppLoadingViewState extends State<AppLoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.45).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    const primaryTeal = Color(0xFF006D5B);
    const accentGreen = Color(0xFF00D084);
    final bgColor = isDark ? const Color(0xFF070D0C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF0A2B27);
    final textMuted = isDark ? Colors.grey.shade400 : const Color(0xFF5A726E);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Center content: Logo, Title, Tagline, Loading Bar with 0-100% progress
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated App Logo with Pulse & Subtle Glow
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: primaryTeal.withValues(
                                    alpha: _glowAnimation.value,
                                  ),
                                  blurRadius: 30,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.asset(
                                'assets/icon.png',
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: primaryTeal,
                                    child: const Center(
                                      child: Icon(
                                        Icons.account_balance_wallet_rounded,
                                        color: Colors.white,
                                        size: 50,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // App Title
                    Text(
                      'Cash Book',
                      style: GoogleFonts.outfit(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Tagline
                    Text(
                      'Smart Daily Khata & Ledger',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: textMuted,
                        letterSpacing: 0.2,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // 0% to 100% Animated Loading Bar with Percentage
                    if (widget.progress != null) ...[
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(
                          begin: 0.0,
                          end: widget.progress!.clamp(0.0, 1.0),
                        ),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedVal, _) {
                          final percentInt = (animatedVal * 100).toInt();

                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Progress Bar Track
                              SizedBox(
                                width: 220,
                                height: 8,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Stack(
                                    children: [
                                      // Background track
                                      Container(
                                        color: primaryTeal.withValues(
                                          alpha: 0.15,
                                        ),
                                      ),
                                      // Animated gradient progress
                                      FractionallySizedBox(
                                        widthFactor:
                                            animatedVal.clamp(0.02, 1.0),
                                        alignment: Alignment.centerLeft,
                                        child: Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                primaryTeal,
                                                accentGreen,
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Message & Percentage Chip
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    widget.message,
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryTeal.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: primaryTeal.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      '$percentInt%',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? accentGreen
                                            : primaryTeal,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ] else ...[
                      // Indeterminate fallback
                      SizedBox(
                        width: 200,
                        height: 6,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            backgroundColor:
                                primaryTeal.withValues(alpha: 0.12),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              accentGreen,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.message,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Footer at bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 20,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: primaryTeal.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '100% Offline & Secure',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'v1.1.1',
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: textMuted.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
