//
//  DDFileReader.h
//  PHY
//
//  Created by Han on 2018/11/5.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@interface DDFileReader : NSObject {
    NSFileHandle * fileHandle;
    unsigned long long currentOffset;
    unsigned long long totalFileLength;
    NSString * lineDelimiter;
    NSUInteger chunkSize;
}
@property (nonatomic, copy) NSString * lineDelimiter;
@property (nonatomic) NSUInteger chunkSize;

- (id) initWithFilePath:(NSString *)aPath;
- (NSString *) readLine;
- (NSData *) readBinFileWithLength:(int)length;
- (NSString *) readTrimmedLine;
- (long)getTotalFileLength;

#if NS_BLOCKS_AVAILABLE
- (void) enumerateLinesUsingBlock:(void(^)(NSString*, BOOL *))block;
#endif

@end

NS_ASSUME_NONNULL_END
