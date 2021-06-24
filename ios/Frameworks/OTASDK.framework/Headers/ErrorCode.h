//
//  ErrorCode.h
//  OTASDK
//
//  Created by Yang on 2018/10/27.
//  Copyright © 2018 phy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ErrorCode : NSObject

//文件解析错误
extern NSUInteger const FILE_ERROR;

//进入OTA状态后连接错误
extern NSUInteger const OTA_CONNTEC_ERROR;

//OTA数据发送service未找到
extern NSUInteger const OTA_DATA_SERVICE_NOT_FOUND;

//OTA命令发送service未找到
extern NSUInteger const OTA_SERVICE_NOT_FOUND;

//OTA数据写入错误
extern NSUInteger const OTA_DATA_WRITE_ERROR;

//OTA响应错误
extern NSUInteger const OTA_RESPONSE_ERROR;

//断开连接
extern NSUInteger const CONNECT_ERROR;

//设备未连接
extern NSUInteger const DEVICE_NOT_CONNECT;

//设备不在OTA状态
extern NSUInteger const DEVICE_NOT_IN_OTA;

@end

NS_ASSUME_NONNULL_END
