import 'dart:async';

import 'package:flutter/services.dart';

class FlutterPhypOta {
  static const MethodChannel _channel = const MethodChannel('flutter_phyp_ota');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
