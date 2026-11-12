import 'package:connectivity_plus/connectivity_plus.dart';

Future<bool> isDeviceOffline() async {
  try {
    final connections = await Connectivity().checkConnectivity();
    return connections
        .every((connection) => connection == ConnectivityResult.none);
  } catch (_) {
    return false;
  }
}
