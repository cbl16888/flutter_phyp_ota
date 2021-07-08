//
//  Partition.m
//  PHY
//
//  Created by Han on 2018/11/5.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "Partition.h"
#import "JCDataConvert.h"

@implementation Partition

+ (Partition *) partition:(NSString *)address data:(NSArray *)dataArray {
    return [Partition partition:address data:dataArray packetLength:20];
}

+ (Partition *) partition:(NSString *)address data:(NSArray *)dataArray packetLength:(int)pLength{
    Partition *partition = [[Partition alloc] init];
    partition.address = address;
    int length = 0;
    for (int i=0; i<dataArray.count; i++) {
        NSString *tempStr = dataArray[i];
        length += tempStr.length;
    }
    NSLog(@"partition.length:%d",length);
    partition.partitionLength = length/2;
    partition.partitionArray = [partition analyzePartition:dataArray length:pLength];
    partition.checkSum = [partition calculateCheckSum:dataArray];
    return partition;
}

+ (Partition *)securityPartition:(NSString *)address data:(NSArray *)dataArray packetLength:(int)pLength {
    Partition *partition = [[Partition alloc] init];
    partition.address = address;
    
    NSMutableArray *tempArray = [[NSMutableArray alloc] initWithArray:dataArray];
    NSString *lastStr = tempArray.lastObject;
    [tempArray removeLastObject];
    if (lastStr.length <= 8) {
        lastStr = [NSString stringWithFormat:@"%@%@",tempArray.lastObject,lastStr];
        [tempArray removeLastObject];
    }
    partition.checkSum = [JCDataConvert hexNumberStringToNumber:[lastStr substringFromIndex:lastStr.length-8] ];
    lastStr = [lastStr substringToIndex:lastStr.length-8];
    [tempArray addObject:lastStr];
    
    int length = 0;
    for (int i=0; i<dataArray.count; i++) {
        NSString *tempStr = dataArray[i];
        length += tempStr.length;
    }
    NSLog(@"securityPartition.length:%d",length);
    partition.partitionLength = length/2;
    partition.partitionArray = [partition analyzePartition:dataArray length:pLength];
    
    return partition;
}

//把数据分成若干小段
- (NSMutableArray *)analyzePartition:(NSArray *)dataArray {
    return [self analyzePartition:dataArray length:20];
}

//把数据分成若干小段
- (NSMutableArray *)analyzePartition:(NSArray *)dataArray length:(int)pLength{
    int index = 0;
    NSMutableArray *partitionArray = [NSMutableArray arrayWithCapacity:0];
    NSMutableArray *smallPieceData = nil;
    NSString *partitionStr = @"";
    for (int i=0; i<dataArray.count; i++) {
        partitionStr = [NSString stringWithFormat:@"%@%@",partitionStr,dataArray[i]];
        while (true) {
            if (index == 0) {//初始化16*length的数组
                smallPieceData = [[NSMutableArray alloc] init];
            }
            if (partitionStr.length == pLength*2) {
                //是按maxMtu的长度切的包
                [smallPieceData addObject:partitionStr];
                partitionStr = @"";
                index ++;
            }else if (partitionStr.length < pLength*2 && i<dataArray.count-1) {
                //数据不够
                break;
            }else if (partitionStr.length <= pLength*2 && i == dataArray.count-1) {
                //最后一包
                if (partitionStr.length >0) {
                    [smallPieceData addObject:partitionStr];
                }
                [partitionArray addObject:smallPieceData];//大的分段放小分段
                break;
            }else {
                //如果数据很长，一包切不完
                NSString *str = [partitionStr substringToIndex:pLength*2];
                partitionStr = [partitionStr substringFromIndex:pLength*2];
                [smallPieceData addObject:str];
                index ++;
            }
            //16个元素为一组，如果超过16，则重新开始
            if (smallPieceData.count == 16) {
                [partitionArray addObject:smallPieceData];
                index = 0;
            }
        }
    }
    return partitionArray;
}

//计算校验码
- (int)calculateCheckSum:(NSArray *)dataArray{
    int number = 0;
    for (int i=0; i<dataArray.count; i++) {
        NSData *data = [JCDataConvert hexToBytes:dataArray[i]];
        number = [JCDataConvert checkSum:number byte:data];
    }
    return number;
}


@end
