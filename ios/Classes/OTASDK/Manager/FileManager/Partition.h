//
//  Partition.h
//  PHY
//
//  Created by Han on 2018/11/5.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface Partition : NSObject

@property (strong, nonatomic) NSString *address;
@property (assign, nonatomic) NSUInteger partitionLength;
@property (assign, nonatomic) NSUInteger checkSum;
//段落数组，元素为16*最大包长个字节，第一代6202每小段有16段20个字节的数据
@property (strong, nonatomic) NSMutableArray *partitionArray;

+ (Partition *)partition:(NSString *)address data:(NSArray *)dataArray;
+ (Partition *)partition:(NSString *)address data:(NSArray *)dataArray packetLength:(int)pLength;
+ (Partition *)securityPartition:(NSString *)address data:(NSArray *)dataArray packetLength:(int)pLength;

- (NSMutableArray *)analyzePartition:(NSArray *)dataArray;
- (NSMutableArray *)analyzePartition:(NSArray *)dataArray length:(int)pLength;

@end

NS_ASSUME_NONNULL_END
