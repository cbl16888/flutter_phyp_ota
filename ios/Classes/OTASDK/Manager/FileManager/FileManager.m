//
//  FileManager.m
//  PHY
//
//  Created by Han on 2018/11/5.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "FileManager.h"
#import "DDFileReader.h"
#import "JCDataConvert.h"
#import "Partition.h"

@interface FileManager()

@end

@implementation FileManager

- (instancetype)firmWareFile:(NSString *)filePath{
    return [self firmWareFile:filePath length:20];
}

- (instancetype)firmWareFile:(NSString *)filePath length:(int)length{
    FileManager *file = [[FileManager alloc] init];
    file.list = [NSMutableArray arrayWithCapacity:0];
    file.list = [[self analyzeFile:filePath length:length] copy];
    self.list = [NSMutableArray arrayWithCapacity:0];
    self.list = file.list;
    if ([filePath hasSuffix:@"bin"]) {
        file.length = [self getBinFileLength:filePath];
    }else {
        file.length = [self getLength];
    }
    
    return file;
}

- (NSArray *)analyzeFile:(NSString *)path{
    return [self analyzeFile:path length:20];
}

- (NSArray *)analyzeFile:(NSString *)path length:(int)length{
    if ([path hasSuffix:@"bin"]) {
        return [self readBinFile:path length:length];
    }
    DDFileReader * reader = [[DDFileReader alloc] initWithFilePath:path];
    int size = 0;
    NSString *result = @"";
    NSMutableArray *tempArray = [NSMutableArray new];
    int flag = 0;
    NSString *address = @"";
    NSMutableArray *list = [NSMutableArray arrayWithCapacity:0];
    NSString * readline = nil;
    
    while ((readline = [reader readLine])) {
        NSLog(@"readline:%@",readline);
        NSString *hexSize = [readline substringWithRange:NSMakeRange(1, 2)];
        size = [JCDataConvert hexNumberStringToNumber:hexSize];
        
        if ([[readline substringWithRange:NSMakeRange(7, 2)] isEqualToString:@"04"]) {
            if (tempArray.count>0) {
                if (result.length >0)[tempArray addObject:result];
                Partition *partition;
                if([path hasSuffix:@"hexe16"]){
                    partition = [Partition securityPartition:address data:tempArray packetLength:length];
                }else{
                    partition = [Partition partition:address data:tempArray packetLength:length];
                }
                [list addObject:partition];
                [tempArray removeAllObjects];
            }
            address = [readline substringWithRange:NSMakeRange(9, 4)];
            flag = 0;
            result = @"";
            continue;
        }
        
        if ([[readline substringWithRange:NSMakeRange(7, 2)] isEqualToString:@"05"] || [[readline substringWithRange:NSMakeRange(7, 2)] isEqualToString:@"01"]) {
            if (result.length >0)[tempArray addObject:result];
            
            Partition *partition;
            if([path hasSuffix:@"hexe16"]){
                partition = [Partition securityPartition:address data:tempArray packetLength:length];
            }else{
                partition = [Partition partition:address data:tempArray packetLength:length];
            }
            [list addObject:partition];
            [tempArray removeAllObjects];
            break;
        }
        
        if (flag == 0) {
            flag = 1;
            NSString *str = [readline substringWithRange:NSMakeRange(3, 4)];
            address = [NSString stringWithFormat:@"%@%@",address,str];
        }
        
        NSString *resultStr = [readline substringWithRange:NSMakeRange(9, size*2)];
        result = [NSString stringWithFormat:@"%@%@",result,resultStr];
        //        NSLog(@"长度：%d",(int)result.length);
        if (result.length >= length*2) {
            [tempArray addObject:[result substringToIndex:length*2]];
            result = [result substringFromIndex:length*2];
        }
    }
    return list;
}


- (NSArray *)readBinFile:(NSString *)path length:(int)length{
    DDFileReader * reader = [[DDFileReader alloc] initWithFilePath:path];
    NSMutableArray *list = [NSMutableArray arrayWithCapacity:0];
    NSData * readOneTime = nil;
    //读length长度的数据，只要不为0，就将读到的数据放到list。
    while ( (readOneTime = [reader readBinFileWithLength:length]) && readOneTime.length>0) {
        //        NSLog(@"readOneTime:%@",readOneTime);
        [list addObject:readOneTime];
    }
    return list;
}

- (long)getLength {
    long size = 0;
    for (Partition *partition in self.list) {
        //        size += partition.partitionArray.count;
        if([partition isKindOfClass:[Partition class]])
            size += partition.partitionLength;
    }
    return size;
}

- (long)getBinFileLength:(NSString *)path{
    DDFileReader * reader = [[DDFileReader alloc] initWithFilePath:path];
    return [reader getTotalFileLength];
}

@end
