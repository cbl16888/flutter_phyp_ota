package com.zhonglingyi.flutter_phyp_ota;

import android.content.Context;
import android.os.Looper;

import androidx.annotation.NonNull;

import com.phy.ota.sdk.OTASDKUtils;
import com.phy.ota.sdk.firware.UpdateFirewareCallBack;

import java.util.UUID;
import android.os.Handler;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

/** FlutterPhypOtaPlugin */
public class FlutterPhypOtaPlugin implements FlutterPlugin, MethodCallHandler, UpdateFirewareCallBack {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private MethodChannel channel;
  private OTASDKUtils otasdkUtils;
  private FlutterAssets flutterAssets;
  private Context mContext;
  private Handler handler;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    flutterAssets = flutterPluginBinding.getFlutterAssets();
    mContext = flutterPluginBinding.getApplicationContext();
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "flutter_phyp_ota");
    channel.setMethodCallHandler(this);
    otasdkUtils = new OTASDKUtils(mContext, this);
    handler = new Handler(Looper.getMainLooper());
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("getPlatformVersion")) {
      result.success("Android " + android.os.Build.VERSION.RELEASE);
    } else if (call.method.equals("startOta")) {
      String address = call.argument("address");
      String filePath = call.argument("filePath");
      Boolean fileInAsset = call.argument("fileInAsset");

      if (address == null || filePath == null) {
        result.error("Abnormal parameter", "address and filePath are required", null);
        return;
      }
      if (fileInAsset) {
        filePath = flutterAssets.getAssetFilePathByName(filePath);
        String tempFileName = PathUtils.getExternalAppCachePath(mContext)
                + "phypota";
        ResourceUtils.copyFileFromAssets(filePath, tempFileName, mContext);
        filePath = tempFileName;
      }
      otasdkUtils.updateFirware(address, filePath);
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
  public void onError(final int i) {
    handler.post(new Runnable() {
      @Override
      public void run() {
        channel.invokeMethod("onOtaError", i);
      }
    });
  }

  @Override
  public void onProcess(final float v) {
    handler.post(new Runnable() {
      @Override
      public void run() {
        channel.invokeMethod("onOtaProcess", v);
      }
    });
  }

  @Override
  public void onUpdateComplete() {
    handler.post(new Runnable() {
      @Override
      public void run() {
        channel.invokeMethod("onOtaSuccess", null);
      }
    });
  }
}
