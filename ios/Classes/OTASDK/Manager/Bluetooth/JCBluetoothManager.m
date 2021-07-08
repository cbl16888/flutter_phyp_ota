//
//  JCBluetoothManager.m
//  Zebra
//
//  Created by han on 2018/10/05.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "JCBluetoothManager.h"
#import "JCDataConvert.h"


#define BluetoothGetMacAddress                      @"BluetoothGetMacAddress" //获取外设的系统信息Mac地址
#define IsConnectToPeripheral                       @"isConnectToPeripheral"//是否连接外设，成功或断开

static JCBluetoothManager *_manager;
static CBCentralManager *_myCentralManager;


@interface JCBluetoothManager (){
    
}
@property (nonatomic, strong) CBCharacteristic *readCharacteristic;     //读取数据特性
@property (nonatomic, strong) CBCharacteristic *writeNotifyCharacteristic;    //写数据特性
@property (nonatomic, strong) CBCharacteristic *writeOTAWithRespCharac;    //OTA写数据特性 有返回值



@property (nonatomic, strong) NSString *originalMacAddress;//原始mac地址,用于OTA模式重连
@property (nonatomic, weak) OTAManager *otaManager;


@end

@implementation JCBluetoothManager

#pragma mark 【1】创建单例蓝牙管理中心
+ (JCBluetoothManager *)shareCBCentralManager{
    @synchronized(self) {
        if (!_manager) {
            _manager = [[JCBluetoothManager alloc]init];
            _myCentralManager = [[CBCentralManager alloc] initWithDelegate:_manager queue:nil];//如果设置为nil，默认在主线程中跑
            
            //新增的遵循其他协议
            _manager.otaManager = [OTAManager shareOTAManager];
        }
    }
    return _manager;
}

#pragma mark 【2】监测蓝牙状态
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state){
        case CBCentralManagerStateUnknown:
            break;
        case CBCentralManagerStateUnsupported:
            NSLog(@"模拟器不支持蓝牙调试");
            break;
        case CBCentralManagerStateUnauthorized:
            break;
        case CBCentralManagerStatePoweredOff:{
            NSLog(@"蓝牙处于关闭状态");
            self.bluetoothState = BluetoothOpenStateIsClosed;
            _currentPeripheral = nil;
            _readCharacteristic = nil;
            _writeNotifyCharacteristic = nil;
            
            _writeOTAWithRespCharac = nil;
            _writeOTAWithoutRespCharac = nil;
            
            if ([self.delegate respondsToSelector:@selector(bluetoothStateChange:state:)]) {
                [self.delegate bluetoothStateChange:self state:BluetoothOpenStateIsClosed];
            }
        }
            break;
        case CBCentralManagerStateResetting:
            break;
        case CBCentralManagerStatePoweredOn:
        {
            self.bluetoothState = BluetoothOpenStateIsOpen;
            if ([self.delegate respondsToSelector:@selector(bluetoothStateChange:state:)]) {
                [self.delegate bluetoothStateChange:self state:BluetoothOpenStateIsOpen];
            }
            NSLog(@"蓝牙已开启");
        }
            break;
    }
}

#pragma mark 【3】发现外部设备
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    if (![peripheral.name isEqual:[NSNull null]]) {
        if ([self.delegate respondsToSelector:@selector(foundPeripheral:peripheral:advertisementData:RSSI:)]) {
            [self.delegate foundPeripheral:self peripheral:peripheral advertisementData:advertisementData RSSI:RSSI];
        }
    }
}

#pragma mark 【4】连接外部蓝牙设备
- (void)connectToPeripheral:(CBPeripheral *)peripheral {
    if (!peripheral) {
        return;
    }
    [_myCentralManager connectPeripheral:peripheral options:nil];//连接蓝牙
    _currentPeripheral = peripheral;
}

#pragma mark 【5】连接外部蓝牙设备成功
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    _currentPeripheral = peripheral;
    peripheral.delegate = self;
    NSLog(@"连接成功，开始寻找服务和特征");
    //外围设备开始寻找服务
    [peripheral discoverServices:nil];
    NSLog(@"\n\n连接成功：%@\n\n",self.currentPeripheral);
    
    if ([self.delegate respondsToSelector:@selector(bluetoothManager:didSucceedConectPeripheral:)]) {
        [self.delegate bluetoothManager:self didSucceedConectPeripheral:peripheral];
    }
}

#pragma mark 连接外部蓝牙设备失败
- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    if ([self.delegate respondsToSelector:@selector(bluetoothManager:didFailConectPeripheral:)]) {
        [self.delegate bluetoothManager:self didFailConectPeripheral:peripheral];
    }
    _currentPeripheral = nil;
}

#pragma mark 【6】寻找蓝牙服务
//外围设备寻找到服务后
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    if(error){
        NSLog(@"外围设备寻找服务过程中发生错误，错误信息：%@",error.localizedDescription);
    }
    //遍历查找到的服务
    CBUUID *serviceUUID = [CBUUID UUIDWithString:SERVICE_UUID]; //指定服务
    
    CBUUID *serviceOTAUUID = [CBUUID UUIDWithString:SERVICE_OTA_UUID]; //指定服务
    for (CBService *service in peripheral.services) {
        NSLog(@"服务=========%@",service);
        
        if([service.UUID isEqual:[CBUUID UUIDWithString:SERVICE_DEVICE_INFO_UUID]]) {
            //获取mac 地址
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CHARACTERISTIC_MAC_READ_UUID]] forService:service];
        }else if([service.UUID isEqual:serviceUUID]){
            //外围设备查找指定服务中的特征
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CHARACTERISTIC_MAC_READ_UUID],[CBUUID UUIDWithString:CHARACTERISTIC_WRITE_UUID]] forService:service];
        }else if([service.UUID isEqual:serviceOTAUUID]){
            //OTA
            [peripheral discoverCharacteristics:@[[CBUUID UUIDWithString:CHARACTERISTIC_OTA_WRITE_UUID],[CBUUID UUIDWithString:CHARACTERISTIC_OTA_INDICATE_UUID],[CBUUID UUIDWithString:CHARACTERISTIC_OTA_DATA_WRITE_UUID]] forService:service];
        }else {
            //其他服务
            [peripheral discoverCharacteristics:nil forService:service];
        }
        
    }
}

#pragma mark 【7】寻找蓝牙服务中的特性
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    
    //报错直接返回退出
    if (error) {
        NSLog(@"didDiscoverCharacteristicsForService error : %@", [error localizedDescription]);
        return;
    }
    
    //遍历服务中的所有特性
    for (CBCharacteristic *characteristic in service.characteristics) {
        
        //mac地址
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_MAC_READ_UUID]]) {
            NSLog(@"读取MAC地址特性：%@",[characteristic.UUID UUIDString]);
            [peripheral readValueForCharacteristic:characteristic];
        }
        
        //Single Bank模式下写特性
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_WRITE_UUID]]) {
            // 订阅, 实时接收
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];//订阅其特性（这个特性只有订阅方式）
            _writeNotifyCharacteristic = characteristic;
            NSLog(@"写操作特性：%@",[characteristic.UUID UUIDString]);
        }
        
        //OTA Notify
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_OTA_INDICATE_UUID]]) {
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
        
        //OTA Command WRITE
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_OTA_WRITE_UUID]]) {
            _writeOTAWithRespCharac = characteristic;
        }
        
        //OTA Data Write
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_OTA_DATA_WRITE_UUID]]) {
            _writeOTAWithoutRespCharac = characteristic;
            NSInteger _maxLengthNoRes = 20;
            _maxLengthNoRes = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
            _otaManager.maxPacketLength = _maxLengthNoRes;
            
            NSLog(@"-----当前蓝牙是OTA模式！！！！！！最大支持响应长度：%ld",(long)_maxLengthNoRes);
            if ([_otaManager.filePath hasSuffix:@"hexe16"]) {
                [_otaManager securityOTAStart];
            }else if(_otaManager.filePath.length > 0){
                [_otaManager updateOTAFirmwareConfirmPath];
            }
        }
        
        //SLB OTA的特性
        if([[characteristic.UUID UUIDString] isEqualToString:@"FED7"]){
            _writeOTAWithoutRespCharac = characteristic;
            NSInteger _maxLengthNoRes = 0;
            
            _maxLengthNoRes = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
            _otaManager.maxPacketLength = _maxLengthNoRes;
            
            NSLog(@"SLB模式！最大支持响应长度：%ld",(long)_maxLengthNoRes);
            if (_otaManager.filePath) {
                [_otaManager ParseBinFile];
            }
        }
        
        if([[characteristic.UUID UUIDString] isEqualToString:@"FED5"]){
            _writeOTAWithRespCharac = characteristic;
        }
        
        if([[characteristic.UUID UUIDString] isEqualToString:@"FED8"]){
            [peripheral setNotifyValue:YES forCharacteristic:characteristic];
        }
    }
}

//等特性Notification成功之后再发送数据进行交互
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error {
    NSLog(@"特性enable成功：%@",[characteristic.UUID UUIDString]);
    if([[characteristic.UUID UUIDString] isEqualToString:@"FED8"]){
        _otaManager.SLBNotificationCharacteristic = characteristic;
    }
//    else if([@"5833FF03-9B8B-5191-6142-22A4536EF123" isEqualToString:[characteristic.UUID UUIDString]]){
//        //如果是dual bank
//        [_otaManager updateOTAFirmwareConfirmPath];
//    }
}

#pragma mark 【8】直接读取特征值被更新后  **********读数据*********
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error{
    if (error) {
        //这个错误无所谓。
        return;
    }
    //获取电量
    if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_BATTERY_READ_UUID]]) {
        NSData *data = characteristic.value;
        NSInteger value = [JCDataConvert ToInteger:data];
        NSLog(@"characteristic(读取到的) : %@, data : %@, \n电量为value : %ld%%", characteristic, data, (long)value);
    }
    
    //获取MAC地址
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_MAC_READ_UUID]]) {
        NSString *value = [NSString stringWithFormat:@"%@",characteristic.value];
        NSString *macString = [JCDataConvert convertOriginalToMacString:value];
        self.originalMacAddress = value;
        NSString *uuid = _currentPeripheral.identifier.UUIDString;
        NSDictionary *classDic = @{
            @"macAddress" : macString,@"originalMacAddress":value,@"originalUUID":uuid
        };
        [[NSNotificationCenter defaultCenter] postNotificationName:BluetoothGetMacAddress object:nil userInfo:classDic];
        
        NSLog(@"读取到的MAC特性 : %@, \n mac地址为value : %@", characteristic, macString);
        if ([self.delegate respondsToSelector:@selector(bluetoothManager:peripheral:didUpdateNotificationStateForCharacteristic:error:)]) {
            [self.delegate bluetoothManager:self peripheral:peripheral didUpdateNotificationStateForCharacteristic:characteristic error:error];
        }
    }
    
    if([characteristic.UUID isEqual:[CBUUID UUIDWithString:CHARACTERISTIC_OTA_INDICATE_UUID]]){
        if (characteristic.value) {
            NSData *data = characteristic.value;
            NSLog(@"ota服务特征值(读取到的)data: %@", data);
            [_otaManager updateOTAData:data];
        }else{
            NSLog(@"未发现特征值.");
        }
    }
    
    
    if([[characteristic.UUID UUIDString] isEqualToString:@"FED8"]){
        NSData *data = characteristic.value;
        NSLog(@"SLB 反馈数据 %@ : %@ ",characteristic, data);
        [_otaManager updateSLBOTAData:data];
    }
    
}

#pragma mark 蓝牙外设连接断开，自动重连
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error{
    NSLog(@"断开连接");
    
    if (_otaManager.otaState > 1 && [self.delegate respondsToSelector:@selector(bluetoothManager:didDisconnectPeripheral:error:)]) {
        [self.delegate bluetoothManager:self didDisconnectPeripheral:peripheral error:error];
    }
    _otaManager.maxPacketLength = 0;
    [OTAManager shareOTAManager].filePath = nil;
}

/*!
 *  通过蓝牙发送data数据到外设
 *
 *  @param data -[in] 要发送的字符串
 */
- (void)sendData:(NSData *_Nonnull)data {
    if (_currentPeripheral.state == CBPeripheralStateConnected && _writeNotifyCharacteristic!=nil){
        [self.currentPeripheral writeValue:data forCharacteristic:_writeNotifyCharacteristic type:CBCharacteristicWriteWithResponse];
    }else {
        NSLog(@"sendData数据发送不成功：%@",data);
    }
}

// 发送数据 string类型转成data发送
- (void)sendString:(NSString *_Nonnull)string {
    if (_currentPeripheral.state == CBPeripheralStateConnected && _writeNotifyCharacteristic!=nil){
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
        [_currentPeripheral writeValue:data forCharacteristic:_writeNotifyCharacteristic type:CBCharacteristicWriteWithResponse];
    }else {
        NSLog(@"sendString数据发送不成功：%@",string);
    }
}


#pragma mark 发送数据 ota
- (void)sendOTACommand:(NSData *_Nonnull)data {
    if (_currentPeripheral.state == CBPeripheralStateConnected && _writeOTAWithRespCharac != nil ){
        NSLog(@"sendDataUseCommand发送指令:%@",data);
        [self.currentPeripheral writeValue:data forCharacteristic:_writeOTAWithRespCharac type:CBCharacteristicWriteWithResponse];
    }else {
        NSLog(@"sendOTACommand 数据发送不成功：%@",data);
    }
}

- (void)sendOTAData:(NSData *_Nonnull)data {
    if (_currentPeripheral.state == CBPeripheralStateConnected && _writeOTAWithoutRespCharac != nil && data != nil){
        [self.currentPeripheral writeValue:data forCharacteristic:_writeOTAWithoutRespCharac type:CBCharacteristicWriteWithoutResponse];
    }else {
        NSLog(@"sendOTAData 数据发送不成功：确认特性是否获得");
    }
}



#pragma mark 重新扫描外设
- (void)reScan{
    if (_currentPeripheral) {
        [_myCentralManager cancelPeripheralConnection:_currentPeripheral];//断开连接
        _currentPeripheral = nil;
        _readCharacteristic = nil;
        _writeNotifyCharacteristic = nil;
        
        _writeOTAWithRespCharac = nil;
        _writeOTAWithoutRespCharac = nil;
    }
    //-------- TODO:设置 SERVICE_UUID
    //连接指定外设，就是通过UUID连接的，这个UUID被连接的设备要广播出来，这样BLE才能搜索到并且连接。
    //其中的uuid就是被连接设备广播出来的UUID字符串。
    //services为nil时是全扫描
    [_myCentralManager scanForPeripheralsWithServices:nil//@[[CBUUID UUIDWithString:SERVICE_UUID]]
                                              options:@{CBCentralManagerScanOptionAllowDuplicatesKey:[NSNumber numberWithBool:NO]}];
    
}

- (void)discoverANCS:(CBPeripheral *)peripheral{
    [self centralManager:_myCentralManager didDiscoverPeripheral:peripheral advertisementData:[NSDictionary dictionary] RSSI:@(0)];
}


#pragma mark 停止扫描外设
- (void)stopScan{
    [_myCentralManager stopScan];
}

#pragma mark 正在扫描外设
- (BOOL)isScanning{
    if([_myCentralManager isScanning]){
        return YES;
    }
    return NO;
}

#pragma mark 断开外设连接
- (void)disConnectToPeripheral{
    if (_currentPeripheral) {
        [_myCentralManager cancelPeripheralConnection:_currentPeripheral];
        _currentPeripheral = nil;
        _readCharacteristic = nil;
        _writeNotifyCharacteristic = nil;
        
        _writeOTAWithRespCharac = nil;
        _writeOTAWithoutRespCharac = nil;
    }
}


@end
