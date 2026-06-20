import 'database_service.dart';
import 'email_service.dart';
import 'connectivity_service.dart';

// ==================== سرویس همگام‌سازی ====================
class SyncService {
  static final SyncService _instance = SyncService._internal();
  final DatabaseService _dbService = DatabaseService();
  final EmailService _emailService = EmailService();
  final ConnectivityService _connectivityService = ConnectivityService();

  factory SyncService() {
    return _instance;
  }

  SyncService._internal();

  // شروع شنونده اتصال
  void startConnectivityListener(Function(bool) onConnectionChanged) {
    _connectivityService.connectionStatusStream.listen((isConnected) {
      onConnectionChanged(isConnected);
      if (isConnected) {
        print('اتصال برقرار شد - شروع همگام‌سازی');
        syncUnsentImages();
      }
    });
  }

  // همگام‌سازی تصاویر ارسال‌نشده
  Future<SyncResult> syncUnsentImages() async {
    final result = SyncResult();

    try {
      // بررسی اتصال
      final hasConnection = await _connectivityService.hasInternetConnection();
      if (!hasConnection) {
        result.status = SyncStatus.noInternet;
        return result;
      }

      // دریافت تصاویر ارسال‌نشده
      final unsentImages = await _dbService.getUnsentImages();
      if (unsentImages.isEmpty) {
        result.status = SyncStatus.success;
        result.message = 'هیچ تصویری برای ارسال وجود ندارد';
        return result;
      }

      // ارسال ایمیل‌های متعدد
      final emailSettings = await _dbService.getEmailSettings();
      if (emailSettings == null) {
        result.status = SyncStatus.missingSettings;
        result.message = 'تنظیمات ایمیل تنظیم نشده است';
        return result;
      }

      // ارسال تصاویر
      bool success;
      if (unsentImages.length == 1) {
        success = await _emailService.sendImageEmail(
          image: unsentImages.first,
        );
      } else {
        success = await _emailService.sendBulkImages(unsentImages);
      }

      if (success) {
        result.status = SyncStatus.success;
        result.message = '${unsentImages.length} تصویر با موفقیت ارسال شد';
        result.sentCount = unsentImages.length;
      } else {
        result.status = SyncStatus.failed;
        result.message = 'خطا در ارسال تصاویر';
      }
    } catch (e) {
      result.status = SyncStatus.error;
      result.message = 'خطا: $e';
    }

    return result;
  }

  // دریافت وضعیت همگام‌سازی
  Future<SyncStatus> getSyncStatus() async {
    final unsentCount = await _dbService.getUnsentImageCount();
    final hasConnection = await _connectivityService.hasInternetConnection();

    if (unsentCount == 0) return SyncStatus.success;
    if (!hasConnection) return SyncStatus.noInternet;
    return SyncStatus.pending;
  }

  // دریافت اطلاعات تفصیلی
  Future<SyncInfo> getSyncInfo() async {
    final unsentImages = await _dbService.getUnsentImages();
    final hasConnection = await _connectivityService.hasInternetConnection();
    final settings = await _dbService.getEmailSettings();

    return SyncInfo(
      unsentCount: unsentImages.length,
      hasConnection: hasConnection,
      hasSettings: settings != null,
      lastImage: unsentImages.isNotEmpty ? unsentImages.first : null,
    );
  }
}

// ==================== مدل نتایج ====================
enum SyncStatus {
  success,
  failed,
  pending,
  noInternet,
  missingSettings,
  error,
}

class SyncResult {
  SyncStatus status = SyncStatus.pending;
  String message = '';
  int sentCount = 0;
}

class SyncInfo {
  final int unsentCount;
  final bool hasConnection;
  final bool hasSettings;
  final ProcessedImage? lastImage;

  SyncInfo({
    required this.unsentCount,
    required this.hasConnection,
    required this.hasSettings,
    this.lastImage,
  });

  bool get canSync => hasConnection && hasSettings && unsentCount > 0;

  String get statusMessage {
    if (!hasSettings) {
      return 'تنظیمات ایمیل نیاز است';
    }
    if (!hasConnection) {
      return 'اتصال اینترنت موجود نیست';
    }
    if (unsentCount == 0) {
      return 'همه تصاویر ارسال شده‌اند';
    }
    return '$unsentCount تصویر در انتظار ارسال';
  }
}
