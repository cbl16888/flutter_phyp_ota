import 'dart:async';

import 'package:flutter/services.dart';

class FlutterPhypOta {
  static const MethodChannel _channel = const MethodChannel('flutter_phyp_ota');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }

  static Future<bool> startOta(String? address, String? filePath, {bool fileInAsset = false, PhypOtaProcessListener? listener}) async {
    assert(address != null, "address can not be null");
    assert(filePath != null, "file can not be null");
    _channel.setMethodCallHandler((MethodCall call) {
      switch (call.method) {
        case "onOtaError":
          listener?.onOtaError(call.arguments);
          break;
        case "onOtaProcess":
          listener?.onOtaProcess(call.arguments);
          break;
        case "onOtaSuccess":
          listener?.onOtaSuccess();
          break;
        default:
          break;
      }
      return Future.value(true);
    });

    return await _channel.invokeMethod('startOta', <String, dynamic>{
      'address': address,
      'filePath': filePath,
      'fileInAsset': fileInAsset
    });
  }

  static Future stopOta() async {
    _channel.setMethodCallHandler((MethodCall call) {
      return Future.value(true);
    });
  }
}

class PhypOtaProcessListener {
  final void Function(int code) onOtaError;
  final void Function(double progress) onOtaProcess;
  final void Function() onOtaSuccess;

  PhypOtaProcessListener({required this.onOtaError, required this.onOtaProcess, required this.onOtaSuccess});
}
