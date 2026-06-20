import 'dart:io';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'database_service.dart';
import 'package:intl/intl.dart';

// ==================== سرویس ارسال ایمیل ====================
class EmailService {
  static final EmailService _instance = EmailService._internal();
  final DatabaseService _dbService = DatabaseService();

  factory EmailService() {
    return _instance;
  }

  EmailService._internal();

  // ارسال ایمیل برای تصویر واحد
  Future<bool> sendImageEmail({
    required ProcessedImage image,
    String? subject,
    String? body,
  }) async {
    try {
      final settings = await _dbService.getEmailSettings();
      if (settings == null) {
        throw Exception('تنظیمات ایمیل تنظیم نشده است');
      }

      final smtpServer = gmail(
        settings['senderEmail'] as String,
        settings['senderPassword'] as String,
      );

      final message = Message()
        ..from = Address(settings['senderEmail'] as String)
        ..recipients.add(settings['recipientEmail'] as String)
        ..subject = subject ?? 'نتیجه تشخیص حشره: ${image.commonName}'
        ..text = body ?? _buildEmailBody(image)
        ..attachments.add(FileAttachment(File(image.imagePath)));

      await send(message, smtpServer);
      await _dbService.markImageAsSent(image.id!);
      return true;
    } catch (e) {
      print('خطا در ارسال ایمیل: $e');
      return false;
    }
  }

  // ارسال چند تصویر در یک ایمیل
  Future<bool> sendBulkImages(List<ProcessedImage> images) async {
    try {
      final settings = await _dbService.getEmailSettings();
      if (settings == null) {
        throw Exception('تنظیمات ایمیل تنظیم نشده است');
      }

      final smtpServer = gmail(
        settings['senderEmail'] as String,
        settings['senderPassword'] as String,
      );

      final message = Message()
        ..from = Address(settings['senderEmail'] as String)
        ..recipients.add(settings['recipientEmail'] as String)
        ..subject = 'گزارش تشخیص حشرات - ${images.length} تصویر'
        ..html = _buildBulkEmailHtml(images);

      // اضافه کردن تمام تصاویر
      for (var image in images) {
        if (File(image.imagePath).existsSync()) {
          message.attachments.add(FileAttachment(File(image.imagePath)));
        }
      }

      await send(message, smtpServer);

      // علامت‌گذاری تمام تصاویر به عنوان ارسال‌شده
      for (var image in images) {
        await _dbService.markImageAsSent(image.id!);
      }

      return true;
    } catch (e) {
      print('خطا در ارسال ایمیل‌های متعدد: $e');
      return false;
    }
  }

  // ساختن محتوای ایمیل برای تصویر واحد
  String _buildEmailBody(ProcessedImage image) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    return '''
تشخیص حشره - نتیجه تحلیل
========================================

نام حشره: ${image.pestName}
نام رایج: ${image.commonName}
درصد اطمینان: ${(image.confidence * 100).toStringAsFixed(2)}%

تاریخ پردازش: ${dateFormat.format(image.processedAt)}
مسیر تصویر: ${image.imagePath}

اطلاعات کامل:
${image.jsonData}

========================================
تولید شده توسط: اپلیکیشن تشخیص حشرات استان چهارمحال و بختیاری
    ''';
  }

  // ساختن HTML ایمیل برای چند تصویر
  String _buildBulkEmailHtml(List<ProcessedImage> images) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
    final rows = images.map((image) => '''
      <tr>
        <td style="border: 1px solid #ddd; padding: 8px;">${image.commonName}</td>
        <td style="border: 1px solid #ddd; padding: 8px;">${(image.confidence * 100).toStringAsFixed(2)}%</td>
        <td style="border: 1px solid #ddd; padding: 8px;">${dateFormat.format(image.processedAt)}</td>
      </tr>
    ''').join();

    return '''
    <html dir="rtl">
    <head>
      <meta charset="utf-8">
      <style>
        body { font-family: Arial, sans-serif; direction: rtl; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th { background-color: #2E7D32; color: white; padding: 10px; text-align: right; }
        td { border: 1px solid #ddd; padding: 8px; text-align: right; }
      </style>
    </head>
    <body>
      <h2>گزارش تشخیص حشرات</h2>
      <p>تعداد حشرات تشناسایی‌شده: ${images.length}</p>
      
      <table>
        <tr>
          <th>نام حشره</th>
          <th>درصد اطمینان</th>
          <th>تاریخ</th>
        </tr>
        $rows
      </table>
      
      <p>تمام تصاویر به صورت پیوست ارسال شده‌اند.</p>
      <hr>
      <small>تولید شده توسط: اپلیکیشن تشخیص حشرات استان چهارمحال و بختیاری</small>
    </body>
    </html>
    ''';
  }

  // تست اتصال ایمیل
  Future<bool> testEmailConnection({
    required String email,
    required String password,
  }) async {
    try {
      final smtpServer = gmail(email, password);
      await send(
        Message()
          ..from = Address(email)
          ..recipients.add(email)
          ..subject = 'تست اتصال ایمیل'
          ..text = 'این یک تست است',
        smtpServer,
      );
      return true;
    } catch (e) {
      print('خطا در تست ایمیل: $e');
      return false;
    }
  }
}
