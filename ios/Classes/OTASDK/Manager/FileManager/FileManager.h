//
//  FileManager.h
//  PHY
//
//  Created by Han on 2018/11/5.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface FileManager : NSObject
@property(nonatomic,assign) int code;
@property(nonatomic,strong) NSMutableArray *list; //元素为partition
@property(nonatomic,assign) long length;

- (instancetype)firmWareFile:(NSString *)filePath;
- (instancetype)firmWareFile:(NSString *)filePath  length:(int)length;
- (NSArray *)analyzeFile:(NSString *)path;
- (NSArray *)analyzeFile:(NSString *)path  length:(int)length;
- (long)getLength;

@end

NS_ASSUME_NONNULL_END
