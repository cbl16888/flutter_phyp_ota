import 'dart:io';

import 'package:bluetooth_helper/bluetooth_device.dart';
import 'package:bluetooth_helper/bluetooth_helper.dart';
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_phyp_ota/flutter_phyp_ota.dart';
import 'package:flutter_phyp_ota_example/debug_log.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  BluetoothDevice _device;
  String _commandReadNotifyCharacter;
  String _commandReadWriteCharacter;
  String _otaCharacter;
  bool _isConnected = false;
  bool _isOta = false;
  var deviceName = "ZLY_2012080145697";
  static const String serviceId = "00001523-39cb-4c61-a082-38bfd3717074";
  static const String commandReadNotifyCharactersId =
      "00001526-39cb-4c61-a082-38bfd3717074";
  static const String commandReadWriteCharactersId =
      "00001525-39cb-4c61-a082-38bfd3717074";

  static const String otaCharactersId = "5833ff01-9b8b-5191-6142-22a4536ef123";
  // public static final String CHARACTERISTIC_OTA_WRITE_UUID = "5833ff02-9b8b-5191-6142-22a4536ef123";
  // public static final String CHARACTERISTIC_OTA_INDICATE_UUID = "5833ff03-9b8b-5191-6142-22a4536ef123";
  // public static final String CHARACTERISTIC_OTA_DATA_WRITE_UUID = "5833ff04-9b8b-5191-6142-22a4536ef123";

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      platformVersion = await FlutterPhypOta.platformVersion;
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Phy+ OTA'),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Center(
                child: Text(deviceName),
              ),
            ),
            Center(
              child: Text('${_isConnected ? "?????????" : "?????????"}'),
            ),
            RaisedButton(
                child: Text('????????????'),
                onPressed: () async {
                  if (_isOta) {
                    DebugLog.logDebug("??????ota??????....");
                    return;
                  }
                  if (_isConnected) {
                    DebugLog.logDebug("???????????????");
                    return;
                  }
                  await _device?.disconnect();
                  DebugLog.logDebug("??????????????????...");
                  await BluetoothHelper.me
                      .scan(
                          deviceName: deviceName,
                          timeout: 10,
                          serviceId: serviceId)
                      .then((_scanResult) {
                    for (var _item in _scanResult) {
                      if (deviceName == _item.deviceName) {
                        _device = _item;
                        break;
                      }
                    }
                    if (null != _device) {
                      return _connect();
                    } else {
                      DebugLog.logDebug("??????????????????");
                    }
                  }).catchError((onError) {
                    DebugLog.logDebug("??????????????????: $onError");
                  });
                }),
            RaisedButton(child: Text('????????????'), onPressed: _disconnectDevice),
            RaisedButton(child: Text('OTA??????'), onPressed: _otaDevice),
          ],
        ),
      ),
    );
  }

  _connect({int timeout = 5}) async {
    DebugLog.logDebug("???????????????????????????: ?????????");
    try {
      bool isSuccess = await _device.connect(timeout).then((value) {
        if (value) {
          DebugLog.logDebug("??????????????????");
          _device.eventCallback = (BluetoothEvent event) {
            if (event is BluetoothEventNotifyData) {
              return;
            } else if (event is BluetoothEventDeviceStateChange) {
              if (BluetoothEventDeviceStateChange.STATE_DISCONNECTED ==
                  event.state) {
                _disconnectDevice();
                return;
              }
            } else if (event is BluetoothEventStateChange) {
              if (BluetoothEventStateChange.STATE_OFF == event.state) {
                _disconnectDevice();
                return;
              }
            }
          };
          return _discoverServices();
        } else {
          DebugLog.logDebug("??????????????????: ??????");
        }
      }).catchError((onError) {
        DebugLog.logDebug("??????????????????: $onError");
      });
      return isSuccess;
    } catch (error) {
      DebugLog.logDebug("??????????????????: $error");
    }
  }

  _discoverServices() async {
    await _device.discoverCharacteristics().then((characteristics) async {
      for (String _characteristic in characteristics) {
        if (_characteristic.toLowerCase() == commandReadNotifyCharactersId) {
          _commandReadNotifyCharacter = _characteristic;
        } else if (_characteristic.toLowerCase() ==
            commandReadWriteCharactersId) {
          _commandReadWriteCharacter = _characteristic;
        } else if (_characteristic.toLowerCase() == otaCharactersId) {
          _otaCharacter = _characteristic;
        }
      }
      if (null == _commandReadNotifyCharacter ||
          null == _commandReadWriteCharacter) {
        DebugLog.logDebug("??????????????????: ????????????");
        await _disconnectDevice();
      } else {
        setState(() {
          _isConnected = true;
        });
        DebugLog.logDebug("??????????????????");
      }
    }).catchError((onError) async {
      DebugLog.logDebug("??????????????????: $onError");
      await _disconnectDevice();
    });
  }

  _disconnectDevice() async {
    if (_isOta) {
      DebugLog.logDebug("??????ota??????....");
      return;
    }
    await _device?.disconnect();
    _device?.eventCallback = null;
    setState(() {
      _isConnected = false;
    });
  }

  _otaDevice() async {
    if (!_isConnected) {
      _isOta = false;
      DebugLog.logDebug("????????????????????????");
      return;
    }
    var address = _device.deviceId;
    if (Platform.isIOS) {
      await _disconnectDevice();
    }
    _isOta = true;
    FlutterPhypOta.startOta(address, "assets/hrs_2.02.hex",
        fileInAsset: true,
        listener: PhypOtaProcessListener(onOtaError: (code) {
          _isOta = false;
          DebugLog.logDebug("??????????????????,?????????: $code");
        }, onOtaSuccess: () {
          _isOta = false;
          DebugLog.logDebug("??????????????????");
        }, onOtaProcess: (progress) {
          _isOta = false;
          DebugLog.logDebug("???????????????, $progress");
        }));
  }
}
