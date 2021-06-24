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
@property(strong,nonatomic) NSString *address;
@property(strong,nonatomic) NSString *dataStr;
@property(assign,nonatomic) unsigned long partitionLength;
@property(strong,nonatomic)NSMutableArray *partitionArray;//段落数组，元素为16*20个字节，每小段又有16段20个字节 的数据

+ (Partition *)partition:(NSString *)address data:(NSString *)dataStr;
-(NSMutableArray *)analyzePartition:(NSString *)data;
@end

NS_ASSUME_NONNULL_END
