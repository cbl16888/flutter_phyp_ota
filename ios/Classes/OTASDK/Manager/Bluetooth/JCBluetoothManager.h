//
//  JCBluetoothManager.h
//  Zebra
//
//  Created by on 2018/10/07.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "OTAManager.h"

typedef NS_ENUM(NSInteger, BluetoothOpenState) {
    /*!
     *  蓝牙打开
     */
    BluetoothOpenStateIsOpen = 0,
    /*!
     *  蓝牙关闭
     */
    BluetoothOpenStateIsClosed = 1
};


@class JCBluetoothManager;

/**
 *  蓝牙管理器中心协议
 */
@protocol JCBluetoothManagerDelegate <NSObject>

@optional

/*!
 *  蓝牙开启状态改变
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param openState -[in] 蓝牙开启状态
 */
- (void)bluetoothStateChange:(nullable JCBluetoothManager *)manager
                       state:(BluetoothOpenState)openState;

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
                   RSSI:(nullable NSNumber *)RSSI;

/*!
 *  蓝牙连接外设成功
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 连接成功的外设
 */
- (void)bluetoothManager:(nullable JCBluetoothManager*)manager
didSucceedConectPeripheral:(nullable CBPeripheral *)peripheral;

/*!
 *  蓝牙连接外设失败
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in] 连接失败的外设
 */
- (void)bluetoothManager:(nullable JCBluetoothManager*)manager
 didFailConectPeripheral:(nullable CBPeripheral *)peripheral;

- (void)bluetoothManager:(nullable JCBluetoothManager*)manager peripheral:(nullable CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(nonnull CBCharacteristic *)characteristic error:(nullable NSError *)error;

/*!
 *  收到已连接的外设传过来的数据
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param data -[in] 外设发过来的data数据
 */
- (void)receiveData:(nullable JCBluetoothManager *)manager
               data:(nullable NSData *)data;


/*!
 *  与外设的连接断开
 *
 *  @param manager -[in] 蓝牙管理中心
 *  @param peripheral -[in]   连接的外设
 *  @param error -[in]   错误信息
 */
- (void)bluetoothManager:(nullable JCBluetoothManager *)manager
 didDisconnectPeripheral:(nullable CBPeripheral *)peripheral
                   error:(nullable NSError *)error;

@required

@end


@interface JCBluetoothManager : NSObject<CBCentralManagerDelegate,CBPeripheralDelegate>

@property (nonatomic, strong, nullable) CBPeripheral   *currentPeripheral;
@property (nonatomic, assign) BluetoothOpenState bluetoothState;
@property (nonatomic, weak, nullable) id <JCBluetoothManagerDelegate> delegate;

//回传数据Block
typedef void (^successBlock)(id _Nullable respondObject);
typedef void (^failureBlock)(id _Nullable failureObject);
//将Block 声明成属性
@property (nonatomic,strong) successBlock _Nullable successBlock;
@property (nonatomic,strong) failureBlock _Nullable failureBlock;

@property (nonatomic, strong) CBCharacteristic * _Nullable writeOTAWithoutRespCharac;    //OTA写数据特性 无返回值

/*!
 *  创建全局蓝牙管理中心
 *
 *  @return 返回蓝牙管理中心对象单例
 */
+ (nullable JCBluetoothManager *)shareCBCentralManager;

/*!
 *  重新扫描外设
 *
 */
- (void)reScan;
/*!
 *  正在扫描外设
 *
 */
- (BOOL)isScanning;
/*!
 *  停止扫描外设
 *
 */
- (void)stopScan;

/*!
 *  连接到外设蓝牙
 *
 *  @param peripheral -[in] 要连接的外设
 */
- (void)connectToPeripheral:(CBPeripheral *_Nonnull)peripheral;

/*!
 *  断开与外设蓝牙连接
 */
- (void)disConnectToPeripheral;

/*!
 *  通过蓝牙发送字符串到外设
 *
 *  @param string -[in] 要发送的字符串
 */
- (void)sendString:(NSString *_Nonnull)string;

/*!
 *  通过蓝牙发送data数据到外设
 *
 *  @param data -[in] 要发送的字符串
 */
- (void)sendData:(NSData *_Nonnull)data;

- (void)sendOTACommand:(NSData *_Nonnull)data;

- (void)sendOTAData:( NSData *_Nonnull)data;

@end
