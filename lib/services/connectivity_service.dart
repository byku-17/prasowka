import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  /// Czy jesteśmy na stabilnym połączeniu traktowanym jak Wi-Fi
  /// (Wi-Fi lub Ethernet). Gdy pakiet nie działa — zwraca true, by nie blokować.
  Future<bool> isOnWifi() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result == ConnectivityResult.wifi || result == ConnectivityResult.ethernet;
    } catch (e) {
      return true;
    }
  }
}
