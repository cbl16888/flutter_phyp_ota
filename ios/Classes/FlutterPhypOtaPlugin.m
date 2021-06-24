#import "FlutterPhypOtaPlugin.h"
#import <OTASDK/OTASDK.h>
#import <OTASDK/OTAManager.h>
#import <OTASDK/JCBluetoothManager.h>

@interface FlutterPhypOtaPlugin() <JCBluetoothManagerDelegate>

@property (nonatomic, strong) FlutterMethodChannel* channel;
@property(nonatomic,strong) JCBluetoothManager* manager;
@property (nonatomic, strong) NSString *address;
@property (nonatomic, strong) NSString *filePath;
@property (nonatomic, assign) bool isAvailable;
@property (nonatomic, assign) bool needScan;
@property (nonatomic, assign) bool isFound;

@end

@implementation FlutterPhypOtaPlugin

- (JCBluetoothManager *)manager{
    if (!_manager) {
        _manager = [JCBluetoothManager shareCBCentralManager];
        _manager.delegate = self;
    }
    return _manager;
}


+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_phyp_ota"
                                     binaryMessenger:[registrar messenger]];
    FlutterPhypOtaPlugin* instance = [[FlutterPhypOtaPlugin alloc] init];
    instance.channel = channel;
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"startOta" isEqualToString:call.method]) {
        self.address = call.arguments[@"address"];
        self.filePath = call.arguments[@"filePath"];
        if (self.isAvailable) {
            [self startScan];
        } else {
            self.needScan = true;
        }
        [self manager];
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
        [self.channel invokeMethod:@"onOtaError" arguments:@(-1)];
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
    if ([self.manager isScanning]) {
        [self.manager stopScan];
    }
    [self.manager reScan];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(10 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!self.isFound) {
            [self.manager stopScan];
            NSLog(@"扫描设备超时");
            [self.channel invokeMethod:@"onOtaError" arguments:@(-1)];
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
    if ([peripheral.identifier.UUIDString isEqualToString:self.address]) {
        self.isFound = true;
        [self.manager stopScan];
        NSLog(@"发现设置,停止扫描,开始连接");
        [self.manager connectToPeripheral:peripheral];
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
    self.manager.currentPeripheral = peripheral;
    [self.manager setUpdateMode: true];
    [self.manager startOTA];
    NSLog(@"开始OTA升级");
//    self.manager updateOTAFirmwareConfirmOrder:<#(NSArray *)#> andPath:<#(NSString *)#>
}

/*!
 *  蓝牙连接外设失败
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 连接失败的外设
 */
- (void)bluetoothManager:(nullable JCBluetoothManager*)manager
 didFailConectPeripheral:(nullable CBPeripheral *)peripheral {
    [self.channel invokeMethod:@"onOtaError" arguments:@(-1)];
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

#pragma mark -- 新增的内容

/**
 OTA progress
 
 @param manager 蓝牙管理中心
 @param progressValue 进度值
 */
- (void)updateOTAProgressDataback:(nullable JCBluetoothManager *) manager
                     feedBackInfo:(float)progressValue {
    [self.channel invokeMethod:@"onOtaProcess" arguments:@(progressValue)];
}


/**
 准备OTA模式返回的结果
 
 @param manager 蓝牙管理中心
 @param result 返回的结果
 */
-(void)startOTASuccess:(nullable JCBluetoothManager *) manager
          feedBackInfo:(BOOL)result reconnectBluetoothType:(NSString *)OTAOrAPPType {
    NSLog(@"准备OTA模式, %@", OTAOrAPPType);
}


/**
 reboot成功之后
 
 @param manager 蓝牙管理中心
 @param result 返回的结果
 */
-(void)reBootOTASuccess:(nullable JCBluetoothManager *) manager
           feedBackInfo:(BOOL)result reconnectBluetoothType:(NSString *)OTAOrAPPType {
    NSLog(@"reboot成功之后, %@", OTAOrAPPType);
    [self.channel invokeMethod:@"onOtaSuccess" arguments:nil];
}

/**
 OTA 数据全部发送完成
 
 @param manager 蓝牙管理中心
 @param isComplete 完成
 */
- (void)updateOTAProgressDataback:(nullable JCBluetoothManager *) manager
                       isComplete:(BOOL)isComplete {
    if (isComplete) {
        NSLog(@"OTA 数据全部发送完成, %d", isComplete);
    } else {
        NSLog(@"OTA 数据全部发送完成, %d", isComplete);
        [self.channel invokeMethod:@"onOtaError" arguments:@(-1)];
    }
    
}


/**
 OTA 错误回传
 
 @param manager 蓝牙管理中心
 @param errorCode 错误码
 */
- (void)updateOTAErrorCallBack:(nullable JCBluetoothManager *) manager
                     errorCode:(NSUInteger)errorCode {
    [self.channel invokeMethod:@"onOtaError" arguments:@(errorCode)];
}

@end
