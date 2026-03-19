import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:background_sms/background_sms.dart';
import 'package:url_launcher/url_launcher.dart';

class SmsService {
  static Future<void> sendViaIntent(String message, String phone) async {
    if (!Platform.isAndroid) return;

    final encodedBody = Uri.encodeComponent(message);

    await launchUrl(
      Uri.parse('sms:$phone?body=$encodedBody'),
    );
  }

  static Future<void> sendDirect(String message, String recipient) async {
    if (!Platform.isAndroid) return;

    var status = await Permission.sms.status;
    if (!status.isGranted) {
      var result = await Permission.sms.request();
      if (!result.isGranted) return;
    }

    const int smsChunkLimit = 153;

    for (int i = 0; i < message.length; i += smsChunkLimit) {
      int end = (i + smsChunkLimit < message.length)
          ? i + smsChunkLimit
          : message.length;

      await BackgroundSms.sendMessage(
        phoneNumber: recipient,
        message: message.substring(i, end),
      );

      await Future.delayed(const Duration(milliseconds: 400));
    }
  }
}
