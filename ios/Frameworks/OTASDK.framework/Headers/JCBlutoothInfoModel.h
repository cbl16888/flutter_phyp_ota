//
//  JCBlutoothInfoModel.h
//  Turing
//
//  Created by han on 2018/10/13.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface JCBlutoothInfoModel : NSObject
@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSDictionary *advertisementData;
@property (nonatomic, strong) NSNumber *RSSI;
@property (nonatomic, copy) NSString *adverMacAddr;
@end
