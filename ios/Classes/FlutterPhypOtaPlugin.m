#import "FlutterPhypOtaPlugin.h"
#import "OTASDK.h"
//#import <OTASDK/OTAManager.h>
//#import <OTASDK/JCBluetoothManager.h>

@interface FlutterPhypOtaPlugin() <JCBluetoothManagerDelegate, OTAManagerDelegate>

@property (nonatomic, strong) FlutterMethodChannel* channel;
@property(nonatomic, strong) JCBluetoothManager* bluetoothManager;
@property(nonatomic, strong) OTAManager *otaManager;
@property (nonatomic, strong) NSString *originUUID;
@property (nonatomic, strong) NSString *macAddress;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, assign) bool isAvailable;
@property (nonatomic, assign) bool needScan;
@property (nonatomic, assign) bool isFound;
@property (nonatomic, strong) NSObject<FlutterPluginRegistrar>* registrar;
@property (assign, nonatomic) BOOL isFirstConnectionOTA;//判断首次连接的网络是否是OTA
@property (strong, nonatomic) NSString *OTAOrAPPType;//重新连接蓝牙时是OTA模式还是应用模式

@end

@implementation FlutterPhypOtaPlugin

- (JCBluetoothManager *)bluetoothManager{
    if (!_bluetoothManager) {
        _bluetoothManager = [JCBluetoothManager shareCBCentralManager];
        _bluetoothManager.delegate = self;
//        self.OTAOrAPPType = @"APP";
    }
    return _bluetoothManager;
}

- (OTAManager *)otaManager {
    if (!_otaManager) {
        _otaManager = [OTAManager shareOTAManager];
        _otaManager.delegate = self;
    }
    return _otaManager;
}


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_phyp_ota"
                                     binaryMessenger:[registrar messenger]];
    FlutterPhypOtaPlugin* instance = [[FlutterPhypOtaPlugin alloc] init];
    instance.channel = channel;
    instance.registrar = registrar;
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"startOta" isEqualToString:call.method]) {
        NSString *originUUID = call.arguments[@"address"];
        if (self.originUUID == nil || ![originUUID isEqualToString:self.originUUID]) {
            self.macAddress = nil;
            self.OTAOrAPPType = @"APP";
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            NSString *macString = [defaults objectForKey:[NSString stringWithFormat:@"MacAdress%@", originUUID]];
            if (nil != macString && [macString isKindOfClass:[NSString class]]) {
                self.macAddress = macString;
                if (nil != self.macAddress) {
                    self.OTAOrAPPType = @"OTA";
                }
            }
        }
        self.originUUID = originUUID;
        self.filePath = call.arguments[@"filePath"];
        BOOL fileInAsset = call.arguments[@"fileInAsset"] == 1;
        if (fileInAsset) {
            NSString *key = [self.registrar lookupKeyForAsset:self.filePath];
            self.filePath = [[NSBundle mainBundle] pathForResource:key ofType:nil];
        }
        if (self.isAvailable) {
            [self startScan];
        } else {
            self.needScan = true;
        }
        [self bluetoothManager];
        result([NSNumber numberWithBool:true]);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

/*!
 *  蓝牙开启状态改变
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param openState -[in] 蓝牙开启状态
 */
- (void)bluetoothStateChange:(nullable JCBluetoothManager *)manager
                       state:(BluetoothOpenState)openState {
    if (openState == BluetoothOpenStateIsClosed) {
        [self.channel invokeMethod:@"onOtaError" arguments:@(-4)];
        self.isAvailable = false;
    } else {
        self.isAvailable = true;
        if (self.needScan) {
            [self startScan];
        }
    }
}

- (void)startScan {
    self.isFound = false;
    self.needScan = false;
    if ([self.bluetoothManager isScanning]) {
        [self.bluetoothManager stopScan];
    }
    [self.bluetoothManager reScan];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isFound) {
            [self.bluetoothManager stopScan];
            MLDLog(@"扫描设备超时");
            [self.channel invokeMethod:@"onOtaError" arguments:@(-1)];
            if ([self.OTAOrAPPType isEqualToString:@"APP"]) {
                self.OTAOrAPPType = @"OTA";
            } else {
                self.OTAOrAPPType = @"APP";
            }
        }
    });
}

/*!
 *  发现新设备
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 发现的外设
 *  @param advertisementData -[in] 外设中的广播包
 *  @param RSSI -[in] 外设信号强度
 */
- (void)foundPeripheral:(nullable JCBluetoothManager *)manager
             peripheral:(nullable CBPeripheral *)peripheral
      advertisementData:(nullable NSDictionary *)advertisementData
                   RSSI:(nullable NSNumber *)RSSI {
    if (peripheral.name.length < 1) {
        return;
    }
    MLDLog(@"发现的设备广播中2：：%@ %@",peripheral.identifier.UUIDString,peripheral.name);

    //如果是dual Bank,又没有广播出MAC地址，可以直接通过名称或其他判断条件直接连接
    if ([@"T20-620205130513" isEqualToString:peripheral.name]) {
        [self.bluetoothManager connectToPeripheral:peripheral];
        return;
    }
    //应用模式下根据UUID自动连接
    if ([self.OTAOrAPPType isEqualToString:@"APP"]) {
        if (self.isFirstConnectionOTA) {
            //首次进入已经连接了OTA模式的蓝牙，提醒手动连接
            self.isFirstConnectionOTA = NO;
            return;
        }
        if ([peripheral.identifier.UUIDString isEqualToString:self.originUUID]) {
            self.isFound = true;
            [self.bluetoothManager stopScan];
            MLDLog(@"发现设备,停止扫描,开始连接");
//            NSObject *value = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
//            self.macAddress = [JCDataConvert convertOriginalToMacString:value];
            [self.bluetoothManager connectToPeripheral:peripheral];
        }
    } else if ([self.OTAOrAPPType isEqualToString:@"OTA"]) {
        if ([peripheral.identifier.UUIDString isEqualToString:self.originUUID]) {
            self.OTAOrAPPType = @"APP";
            self.isFound = true;
            [self.bluetoothManager stopScan];
            MLDLog(@"发现设备,停止扫描,开始连接");
//            NSObject *value = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
//            self.macAddress = [JCDataConvert convertOriginalToMacString:value];
            [self.bluetoothManager connectToPeripheral:peripheral];
            return;
        }
        // 2 -解析广播数据
        NSObject *value = [advertisementData objectForKey:@"kCBAdvDataManufacturerData"];
        NSString *macStr = nil;
        if (![value isKindOfClass: [NSArray class]]){
            const char *valueString = [[value description] cStringUsingEncoding: NSUTF8StringEncoding];
            if (valueString != NULL) {

                //获得ota模式下的Mac地址
                NSString *tempStr = [NSString stringWithFormat:@"%s",valueString];
                macStr = [JCDataConvert getOriginalToDataString:tempStr]; //获取到的mac地址
                macStr = [JCDataConvert getPeripheralMac:macStr];
                NSString * lastMac = [macStr componentsSeparatedByString:@":"].lastObject;
                NSInteger targetValue = [JCDataConvert hexNumberStringToNumber:lastMac] - 1;

                const char *pConstChar = [self.macAddress UTF8String];
                tempStr = [NSString stringWithFormat:@"%s",pConstChar];
                lastMac = [tempStr componentsSeparatedByString:@":"].lastObject;
                if (targetValue == [JCDataConvert hexNumberStringToNumber:lastMac]) {
                    if ([[macStr substringToIndex:macStr.length - 3] isEqualToString:[tempStr substringToIndex:tempStr.length - 3]]) {
                        MLDLog(@"重新连接APP模式首位地址前：%@",macStr);
                        [self.bluetoothManager connectToPeripheral:peripheral];
                    }
                }
            }
        }
    }
}

/*!
 *  蓝牙连接外设成功
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 连接成功的外设
 */
- (void)bluetoothManager:(nullable JCBluetoothManager*)manager
didSucceedConectPeripheral:(nullable CBPeripheral *)peripheral {

}

- (void)bluetoothManager:(nullable JCBluetoothManager*)manager peripheral:(nullable CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    //获取MAC地址
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_MAC_READ_UUID]]) {
        NSString *value = [NSString stringWithFormat:@"%@",characteristic.value];
        NSString *macString = [JCDataConvert convertOriginalToMacString:value];
        if ([macString containsString:@":"] && [peripheral.identifier.UUIDString isEqualToString:self.originUUID]) {
            self.macAddress = macString;
            NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
            [defaults setObject:macString forKey:[NSString stringWithFormat:@"MacAdress%@", self.originUUID]];
            [defaults synchronize];
        }
//        MLDLog(@"读取到的MAC特性 : %@, \n mac地址为value : %@", characteristic, macString);
    }
    if (self.macAddress != nil && error == nil) {
        if (self.bluetoothManager.currentPeripheral != nil) {
            [self startOTAUpdate];
            MLDLog(@"开始OTA升级");
        }
    }

}

- (void)startOTAUpdate{
    MLDLog(@"startOTAUpdate ~~");
    self.otaManager.filePath = self.filePath;

    if (self.otaManager.isSLB) {
        [self.otaManager ParseBinFile];
    }
    else if (self.bluetoothManager.writeOTAWithoutRespCharac != nil ){
        [self.otaManager updateOTAFirmwareConfirmPath];
    }
    else if([self.bluetoothManager.currentPeripheral.name hasSuffix:@"OTA"]) {
        self.isFirstConnectionOTA = true;
        if([self.otaManager.filePath hasSuffix:@"hexe16"]){
            [self.otaManager securityOTAStart];
        }else {
            [self.otaManager updateOTAFirmwareConfirmPath];
        }

    } else {
        [self.otaManager startOTA];//开始OTA
        self.OTAOrAPPType = @"OTA";
    }

}


#pragma mark - 蓝牙及相关设置初始化

/*!
 *  蓝牙连接外设失败
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 连接失败的外设
 */
- (void)bluetoothManager:(nullable JCBluetoothManager*)manager
 didFailConectPeripheral:(nullable CBPeripheral *)peripheral {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.channel invokeMethod:@"onOtaError" arguments:@(-2)];
    });
}

/*!
 *  收到已连接的外设传过来的数据
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param data -[in] 外设发过来的data数据
 */
- (void)receiveData:(nullable JCBluetoothManager *)manager
               data:(nullable NSData *)data {

}


/*!
 *  与外设的连接断开
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in]   连接的外设
 *  @param error -[in]   错误信息
 */
- (void)bluetoothManager:(nullable JCBluetoothManager *)manager
 didDisconnectPeripheral:(nullable CBPeripheral *)peripheral
                   error:(nullable NSError *)error {

}

#pragma mark -- OTA

/**
 OTA progress

 @param manager 蓝牙管理中心
 @param progressValue 进度值
 */
- (void)updateOTAProgressDataback:(nullable OTAManager *) manager
                     feedBackInfo:(float)progressValue {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.channel invokeMethod:@"onOtaProcess" arguments:@(progressValue)];
    });
}


/**
 准备OTA模式返回的结果

 @param manager 蓝牙管理中心
 @param result 返回的结果
 */
-(void)startOTASuccess:(nullable JCBluetoothManager *) manager
          feedBackInfo:(BOOL)result reconnectBluetoothType:(NSString *)OTAOrAPPType {
    MLDLog(@"准备OTA模式, %@", OTAOrAPPType);
}


/**
 reboot成功之后

 @param manager 蓝牙管理中心
 @param result 返回的结果
 */
- (void)reBootOTASuccess:(nullable OTAManager *) manager
            feedBackInfo:(BOOL)result reconnectBluetoothType:(NSString *_Nullable)OTAOrAPPType {
    MLDLog(@"reboot成功之后, %@", OTAOrAPPType);
}

/**
 OTA 数据全部发送完成

 @param manager 蓝牙管理中心
 @param isComplete 完成
 */
- (void)updateOTAProgressDataback:(nullable OTAManager *) manager
                       isComplete:(BOOL)isComplete {
    if (isComplete) {
        MLDLog(@"OTA 数据全部发送完成, %d", isComplete);
        [self.bluetoothManager stopScan];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.channel invokeMethod:@"onOtaSuccess" arguments:nil];
        });
    } else {
        MLDLog(@"OTA 数据全部发送失败, %d", isComplete);
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.channel invokeMethod:@"onOtaError" arguments:@(-3)];
        });
    }
    
}


/**
 OTA 错误回传
 
 @param manager 蓝牙管理中心
 @param errorCode 错误码
 */
- (void)updateOTAErrorCallBack:(nullable OTAManager *) manager
                     errorCode:(NSUInteger)errorCode {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.channel invokeMethod:@"onOtaError" arguments:@(errorCode)];
    });
}

@end
