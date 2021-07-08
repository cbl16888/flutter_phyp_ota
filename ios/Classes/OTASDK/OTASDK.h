//
//  OTASDK.h
//  OTASDK
//
//  Created by Han on 2018/10/25.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <UIKit/UIKit.h>


#import "JCBluetoothManager.h"
#import "JCBlutoothInfoModel.h"
#import "JCDataConvert.h"
#import "OTAManager.h"
#import "Partition.h"
#import "ErrorCode.h"

/**
 *  配置自定义的测试Log
 */
#ifdef DEBUG
    #define MLDLog(format, ...)  NSLog(format, ## __VA_ARGS__)
#else
    #define MLDLog(format, ...)
#endif
