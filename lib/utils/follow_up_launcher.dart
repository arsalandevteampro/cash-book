import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/follow_up.dart';

class FollowUpLauncher {
  static const MethodChannel _channel =
      MethodChannel('com.arsalandev.cashbook/whatsapp_launcher');

  /// Cleans phone number by removing non-digits and ensuring country code
  static String formatPhoneNumber(String rawPhone) {
    var cleanPhone = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      // Local Pakistani number (03xx) -> 923xx
      cleanPhone = '92${cleanPhone.substring(1)}';
    }
    return cleanPhone;
  }

  /// Builds standardized reminder message
  static String buildReminderMessage({
    required FollowUp followUp,
    required String currencySymbol,
  }) {
    final dateFormatted =
        DateFormat('dd MMM yyyy, hh:mm a').format(followUp.dueDate);
    final amountFormatted =
        '$currencySymbol ${followUp.amount.toStringAsFixed(0)}';

    return followUp.type == FollowUpType.toReceive
        ? 'Assalam-o-Alaikum ${followUp.contactName},\n\nYeh Cash Book ki taraf se polite payment reminder hai: $amountFormatted ki payment $dateFormatted ko scheduled hai.\n\nBarah-e-karam check kar lein. Shukriya!'
        : 'Assalam-o-Alaikum ${followUp.contactName},\n\nCash Book reminder: $amountFormatted ki payment $dateFormatted tak transfer karni hai. Shukriya!';
  }

  /// Opens the default Android system app chooser ("Open with...") showing only WhatsApp & WhatsApp Business
  static Future<void> openWhatsApp(
    BuildContext context, {
    required FollowUp followUp,
    required String currencySymbol,
  }) async {
    final rawPhone = followUp.phoneNumber?.trim() ?? '';
    if (rawPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No phone number provided for this follow-up.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final cleanPhone = formatPhoneNumber(rawPhone);
    final message = buildReminderMessage(
      followUp: followUp,
      currencySymbol: currencySymbol,
    );

    final isAndroid = !kIsWeb && Platform.isAndroid;
    if (isAndroid) {
      try {
        final bool? success = await _channel.invokeMethod<bool>(
          'openWhatsAppChooser',
          {
            'phone': cleanPhone,
            'message': message,
            'title': 'Open with',
          },
        );
        if (success == true) {
          return;
        }
      } catch (e) {
        debugPrint('Native chooser failed, falling back to url_launcher: $e');
      }
    }

    // Fallback for non-Android or if native chooser fails
    if (context.mounted) {
      await _launchUrlFallback(context, cleanPhone, message);
    }
  }

  static Future<void> _launchUrlFallback(
    BuildContext context,
    String cleanPhone,
    String message,
  ) async {
    final uri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch WhatsApp.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching WhatsApp: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Makes a standard phone call
  static Future<void> makePhoneCall(
    BuildContext context,
    String phoneNumber,
  ) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid phone number.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final uri = Uri.parse('tel:$cleanPhone');
    try {
      final launched = await launchUrl(uri);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone dialer.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Copies reminder text to clipboard
  static void copyReminder(
    BuildContext context, {
    required FollowUp followUp,
    required String currencySymbol,
  }) {
    final message = buildReminderMessage(
      followUp: followUp,
      currencySymbol: currencySymbol,
    );

    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Reminder copied to clipboard!'),
        backgroundColor: Color(0xFF006D5B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
