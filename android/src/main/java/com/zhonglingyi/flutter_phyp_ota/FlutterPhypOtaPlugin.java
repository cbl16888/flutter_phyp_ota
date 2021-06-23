package com.zhonglingyi.flutter_phyp_ota;

import androidx.annotation.NonNull;

import com.phy.ota.sdk.OTASDKUtils;
import com.phy.ota.sdk.firware.UpdateFirewareCallBack;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.plugin.common.PluginRegistry.Registrar;

/** FlutterPhypOtaPlugin */
public class FlutterPhypOtaPlugin implements FlutterPlugin, MethodCallHandler, UpdateFirewareCallBack {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private OTASDKUtils otasdkUtils;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_phyp_ota");
    channel.setMethodCallHandler(this);
    otasdkUtils = new OTASDKUtils(flutterPluginBinding.getApplicationContext(), this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else if (call.method.equals("startOta")) {
      String address = call.argument("address");
      String filePath = call.argument("filePath");
      otasdkUtils.updateResource(address, filePath);
      result.success(true);
    } else {
      result.notImplemented();
    }
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  @Override
  public void onError(int i) {
    channel.invokeMethod("onOtaError", i);
  }

  @Override
  public void onProcess(float v) {
    channel.invokeMethod("onOtaProcess", v);
  }

  @Override
  public void onUpdateComplete() {
    channel.invokeMethod("onOtaSuccess", null);
  }
}
