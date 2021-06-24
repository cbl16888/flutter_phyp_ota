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


typedef NS_ENUM(BOOL, SkateBoardPowerState) {
    /*!
     *  关机、待机
     */
    SkateBoardPowerOff = NO,
    /*!
     *  开机
     */
    SkateBoardPowerOn = YES
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

#pragma mark -- 新增的内容

/**
 OTA progress

 @param manager 蓝牙管理中心
 @param progressValue 进度值
 */
- (void)updateOTAProgressDataback:(nullable JCBluetoothManager *) manager
                           feedBackInfo:(float)progressValue;


/**
 准备OTA模式返回的结果

 @param manager 蓝牙管理中心
 @param result 返回的结果
 */
-(void)startOTASuccess:(nullable JCBluetoothManager *) manager
          feedBackInfo:(BOOL)result reconnectBluetoothType:(NSString *)OTAOrAPPType;


/**
 reboot成功之后

 @param manager 蓝牙管理中心
 @param result 返回的结果
 */
-(void)reBootOTASuccess:(nullable JCBluetoothManager *) manager
          feedBackInfo:(BOOL)result reconnectBluetoothType:(NSString *)OTAOrAPPType;

/**
 OTA 数据全部发送完成

 @param manager 蓝牙管理中心
 @param isComplete 完成
 */
- (void)updateOTAProgressDataback:(nullable JCBluetoothManager *) manager
                     isComplete:(BOOL)isComplete;


/**
 OTA 错误回传

 @param manager 蓝牙管理中心
 @param errorCode 错误码
 */
- (void)updateOTAErrorCallBack:(nullable JCBluetoothManager *) manager
                       errorCode:(NSUInteger)errorCode;

@required

@end


@interface JCBluetoothManager : NSObject<
                                            CBCentralManagerDelegate,       //作为中央设备
                                            CBPeripheralDelegate,            //外设代理
                                            OTAManagerDelegate
                                        >

@property (nonatomic, strong, nullable) CBPeripheral   *currentPeripheral;
@property (nonatomic, assign) BluetoothOpenState bluetoothState;
@property (nonatomic, weak, nullable) id <JCBluetoothManagerDelegate> delegate;

//回传数据Block
typedef void (^successBlock)(id respondObject);
typedef void (^failureBlock)(id failureObject);
//将Block 声明成属性
@property (nonatomic,strong) successBlock successBlock;
@property (nonatomic,strong) failureBlock failureBlock;

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
- (void)connectToPeripheral:(nullable CBPeripheral *)peripheral;

/*!
 *  断开与外设蓝牙连接
 *
 *  @param peripheral -[in] 要断开的外设
 */
- (void)disConnectToPeripheral:(nullable CBPeripheral *)peripheral;

/*!
 *  通过蓝牙发送字符串到外设
 *
 *  @param string -[in] 要发送的字符串
 */
- (void)sendString:(nullable NSString *)string;

/*!
 *  通过蓝牙发送data数据到外设
 *
 *  @param data -[in] 要发送的字符串
 */
- (void)sendData:(nullable NSData *)data;

/*!
 *  通过协议发送数据到外设
 *
 *  @param command  -[in] 指令
 *  @param dataStr 指令
 */
- (void)sendDataUseCommand:(NSUInteger)command
                   dataStr:(NSString *)dataStr;


#pragma mark -- OTA相关

/**
 OTA   设置升级模式
 */
- (void)setUpdateMode:(BOOL)mode;



/**
 OTA   设置设备 OTA 状态  发送命令0102  已连接的设备名称改变，Mac地址+1
 */
- (void)startOTA;


// 连接OTA设备


/**
 OTA   发送OTA文件发送确认命令  发送命令01xx00 xx为文件分成的段数
 */
- (void)updateOTAFirmwareConfirmOrder:(NSArray *)partitionArray andPath:(NSString *)path;

/**
 OTA   reboot
 */
- (void)reRoot;

//OTA升级完成，重新连接设备成功，应用模式，更新系统时间
/*
 *date 年月日时分秒
 *
 */
- (void)updateSystemTime:(NSString *)date;

@end
