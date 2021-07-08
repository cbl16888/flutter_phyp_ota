//
//  ErrorCode.m
//  OTASDK
//
//  Created by Yang on 2018/10/27.
//  Copyright © 2018 phy. All rights reserved.
//

#import "ErrorCode.h"

@implementation ErrorCode

//文件解析错误
NSUInteger const FILE_ERROR = 0x64;//100;

//进入OTA状态后连接错误
NSUInteger const OTA_CONNTEC_ERROR = 0x65;//101;

//OTA数据发送service未找到
NSUInteger const OTA_DATA_SERVICE_NOT_FOUND = 0x66;//102;

//OTA命令发送service未找到
NSUInteger const OTA_SERVICE_NOT_FOUND = 0x67;//103;

//OTA数据写入错误
NSUInteger const OTA_DATA_WRITE_ERROR = 0x68;//104;

//OTA响应错误
NSUInteger const OTA_RESPONSE_ERROR = 0x69;//105;

//断开连接
NSUInteger const CONNECT_ERROR = 0x6a;//106;

//设备未连接
NSUInteger const DEVICE_NOT_CONNECT = 0x6b;//107;

//设备不在OTA状态
NSUInteger const DEVICE_NOT_IN_OTA = 0x6c;//108;

@end
