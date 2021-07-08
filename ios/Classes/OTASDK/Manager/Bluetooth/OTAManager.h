//
//  OTAManager.h
//  PHY
//
//  Created by Yang on 2018/10/13.
//  Copyright © 2018 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN

//APP模式下服务和特性
#define SERVICE_UUID                                         @"0000ff01-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_WRITE_UUID                            @"0000ff02-0000-1000-8000-00805f9b34fb"

/**电量相关*/
#define SERVICE_BATTERY_UUID                                 @"0000180f-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_BATTERY_READ_UUID                     @"00002a19-0000-1000-8000-00805f9b34fb"

/**系统信息相关*/
#define SERVICE_DEVICE_INFO_UUID                             @"0000180A-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_MAC_READ_UUID                         @"00002A23-0000-1000-8000-00805f9b34fb"

/**OTA相关*/
#define SERVICE_OTA_UUID                                     @"5833ff01-9b8b-5191-6142-22a4536ef123"
#define CHARACTERISTIC_OTA_WRITE_UUID                        @"5833ff02-9b8b-5191-6142-22a4536ef123"//write
#define CHARACTERISTIC_OTA_INDICATE_UUID                     @"5833ff03-9b8b-5191-6142-22a4536ef123"//notify
#define CHARACTERISTIC_OTA_DATA_WRITE_UUID                   @"5833ff04-9b8b-5191-6142-22a4536ef123"

@class OTAManager;

extern NSUInteger const UPDATE_SYSTEM_TIME;//更新系统时间
extern NSUInteger const START_OTA;//OTA
extern NSUInteger const START_OTA_RES;//OTA RES
extern NSUInteger const REROOT;//OTA


//SLB OTA指令部分
extern UInt8 const MESG_HDER_SIZE;
extern UInt8 const MESG_OPCO_ISSU_RAND_NUMB;
extern UInt8 const MESG_OPCO_RESP_RAND_NUMB;
extern UInt8 const MESG_OPCO_ISSU_AUTH_RSLT;
extern UInt8 const MESG_OPCO_RESP_AUTH_RSLT;
extern UInt8 const MESG_OPCO_ISSU_VERS_REQU;
extern UInt8 const MESG_OPCO_RESP_VERS_REQU;
extern UInt8 const MESG_OPCO_ISSU_OTAS_REQU;
extern UInt8 const MESG_OPCO_RESP_OTAS_REQU;
extern UInt8 const MESG_OPCO_ISSU_OTAS_SEGM;
extern UInt8 const MESG_OPCO_RESP_OTAS_SEGM;
extern UInt8 const MESG_OPCO_ISSU_OTAS_COMP;
extern UInt8 const MESG_OPCO_RESP_OTAS_COMP;

typedef NS_ENUM(NSInteger, OTAState) {
    OTANoInit = 0,
    OTAReady = 1,
    OTALoading = 2,
    OTAFinish = 3,
    OTAError = 4
};

/**
 *  OTA协议
 */
@protocol OTAManagerDelegate <NSObject>

@optional

/**
 OTA progress
 
 @param manager 蓝牙管理中心
 @param progressValue 进度值
 */
- (void)updateOTAProgressDataback:(nullable OTAManager *) manager
                     feedBackInfo:(float)progressValue;

/**
 OTA 数据全部发送完成
 
 @param manager 蓝牙管理中心
 @param isComplete 完成
 */
- (void)updateOTAProgressDataback:(nullable OTAManager *) manager
                       isComplete:(BOOL)isComplete;

/**
 OTA 错误回传
 
 @param manager 蓝牙管理中心
 @param errorCode 错误码
 */
- (void)updateOTAErrorCallBack:(nullable OTAManager *) manager
                     errorCode:(NSUInteger)errorCode;

/**
 reboot成功之后
 
 @param manager 蓝牙管理中心
 @param result 返回的结果
 */
- (void)reBootOTASuccess:(nullable OTAManager *) manager
            feedBackInfo:(BOOL)result reconnectBluetoothType:(NSString *_Nullable)OTAOrAPPType;

@required

@end

@interface OTAManager : NSObject

@property (nonatomic, strong) NSString *filePath;//升级文件地址
@property (nonatomic, assign) NSInteger maxPacketLength;//数据包的最大长度

@property (nonatomic, assign) BOOL isSLB;//是否是Self boot
@property (nonatomic, strong) NSString *OTAOrAPPType;//当前设备是OTA模式还是应用模式
@property (nonatomic, weak, nullable) id <OTAManagerDelegate> delegate;
+ (OTAManager *)shareOTAManager;

@property (nonatomic, strong) NSString *bleKeyStr;//测试数据

@property (nonatomic, strong) NSString *AESKey;

@property (nonatomic, assign) OTAState otaState;

@property (nonatomic, weak) CBCharacteristic *SLBNotificationCharacteristic;

- (void)startOTA;
- (void)securityOTAStart;
- (void)updateOTAData:(NSData *)data;

/**
 OTA   发_Nullable送OTA文件发送确认命令  发送命令01xx00 xx为文件分成的段数
 */
- (void)updateOTAFirmwareConfirmPath;

//SLB模式下解析Bin文件
- (void)ParseBinFile;
//SLB模式下蓝牙特性返回数据处理
- (void)updateSLBOTAData:(NSData *)data;
/**
 OTA   reboot
 */
- (void)reRoot;

//OTA升级完成，重新连接设备成功，应用模式，更新系统时间
/*
 *date 年月日时分秒
 *
 */
- (void)updateSystemTime:(NSString *_Nullable)date;

@end

NS_ASSUME_NONNULL_END
