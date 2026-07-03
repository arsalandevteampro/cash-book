import 'package:flutter/material.dart';

import '../services/rating_service.dart';

/// Shows a star-rating dialog and redirects happy users to the Play Store.
Future<void> showRatingDialog(BuildContext context) async {
  if (!context.mounted) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => const _RatingDialog(),
  );
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _selectedStars = 0;
  bool _isSubmitting = false;

  Future<void> _submitRating() async {
    if (_selectedStars == 0 || _isSubmitting) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      if (_selectedStars >= 4) {
        await RatingService.markRated();
        await RatingService.openStoreListing();
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      await RatingService.markDismissed();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your feedback. We will keep improving Cash Book.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _maybeLater() async {
    await RatingService.markDismissed();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF006D5B).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: Color(0xFF00D084),
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Enjoying Cash Book?',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF006D5B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap a star to rate us on the Play Store.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                final isSelected = starIndex <= _selectedStars;

                return IconButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() => _selectedStars = starIndex),
                  icon: Icon(
                    isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isSelected
                        ? const Color(0xFFFFB300)
                        : Colors.grey.shade400,
                    size: 36,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedStars == 0 || _isSubmitting ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006D5B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _selectedStars >= 4
                            ? 'Rate on Play Store'
                            : 'Submit Rating',
                      ),
              ),
            ),
            TextButton(
              onPressed: _isSubmitting ? null : _maybeLater,
              child: const Text('Maybe Later'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Checks usage thresholds and shows the rating dialog when appropriate.
Future<void> maybeShowRatingPrompt(BuildContext context) async {
  await RatingService.trackAppLaunch();

  final shouldShow = await RatingService.shouldShowRatingPrompt();
  if (!shouldShow || !context.mounted) {
    return;
  }

  await Future<void>.delayed(const Duration(seconds: 2));
  if (!context.mounted) {
    return;
  }

  final stillShouldShow = await RatingService.shouldShowRatingPrompt();
  if (!stillShouldShow || !context.mounted) {
    return;
  }

  await showRatingDialog(context);
}
