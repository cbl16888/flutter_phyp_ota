//
//  OTAManager.h
//  PHY
//
//  Created by Yang on 2018/10/13.
//  Copyright © 2018 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

@class OTAManager;
/**
 *  OTA协议
 */
@protocol OTAManagerDelegate <NSObject>

@optional

/**
 取消更新

 @param manager OTA管理中心
 @param result 返回的结果
 */
-(void)cancelOTASuccess:(nullable OTAManager *) manager
           feedBackInfo:(BOOL)result;

/**
 进入OTA更新页

 @param manager OTA管理中心
 @param result 返回的结果
 */
-(void)isInOTAPageUpdate:(nullable OTAManager *) manager
           feedBackInfo:(BOOL)result;

@required

@end

@interface OTAManager : NSObject
@property (nonatomic, weak, nullable) id <OTAManagerDelegate> delegate;
+ (OTAManager *)shareOTAManager;
-(void)cacelOTAUpdate:(BOOL)isCancel;
-(void)isInOTAPageUpdate:(BOOL)isCancel;

@end

NS_ASSUME_NONNULL_END
