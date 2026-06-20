import 'package:connectivity_plus/connectivity_plus.dart';

// ==================== سرویس اتصال اینترنت ====================
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  final Connectivity _connectivity = Connectivity();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  // بررسی اتصال کنونی
  Future<bool> hasInternetConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('خطا در بررسی اتصال: $e');
      return false;
    }
  }

  // شنونده برای تغییرات اتصال
  Stream<bool> get connectionStatusStream {
    return _connectivity.onConnectivityChanged.map((result) {
      return result != ConnectivityResult.none;
    });
  }

  // نوع اتصال
  Future<ConnectivityResult> getConnectionType() async {
    return _connectivity.checkConnectivity();
  }

  // بررسی اتصال واقعی با ping
  Future<bool> isReallyConnected() async {
    try {
      // سعی برای اتصال به یک سایت قابل اعتماد
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }
}
