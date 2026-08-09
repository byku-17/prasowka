import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  /// Czy jesteśmy na stabilnym połączeniu traktowanym jak Wi-Fi
  /// (Wi-Fi lub Ethernet). Gdy pakiet nie działa — zwraca true, by nie blokować.
  Future<bool> isOnWifi() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.any((r) => r == ConnectivityResult.wifi || r == ConnectivityResult.ethernet);
    } catch (e) {
      return true;
    }
  }
}
