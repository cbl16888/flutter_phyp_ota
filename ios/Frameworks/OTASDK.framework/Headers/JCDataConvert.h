//
//  JCDataConvert.h
//  Zebra
//
//  Created by han on 2018/10/13.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCDataConvert : NSObject

/*!
 *  @将字符串中制定字符删除
 *  @str -[in] 需要处理的字符串
 *  @deleChar -[in] 需要删除的字符
 *  @return -[out] 转换后的字符
 */
+(NSString *)stringDeleteString:(NSString *)str by:(unichar)deleChar;

/*!
 *  @将十六进制数据转换成字符串
 *  @needConvertHex -[in] 需要转换的Hex
 *  @return -[out] 转换后的字符串
 */
+ (NSString *)ConvertHexToString:(NSData *)needConvertHex;

/*!
 *  @字符串转data（十六进制）
 *  @str -[in] 需要转换的字符串
 *  @return -[out] 转换后的字符串(十六进制)
 */
+ (NSData*)hexToBytes:(NSString *)str;

+ (NSString *)stringToHexData:(NSString *)hexString;
/*!
 *  @将十进制转化为十六进制
 *  @tmpid -[in] 需要转换的数字
 *  @return -[out] 转换后的字符串
 */
+ (NSString *)ToHex:(int)tmpid;

/*!
 *  @将十六进制转化为十进制
 *  @tmpid -[in] 需要转换的十六进制
 *  @return -[out] 转换后的整数
 */
+ (NSInteger)ToInteger:(NSData *)hexData;


//10进制int转NSData
+(NSData *)intToData:(int)i;

//NSData转int(10进制)
+(int)dataToInt:(NSData *)data;

//将NSData转化为16进制字符串
+ (NSString *)convertDataToHexStr:(NSData *)data;

//16进制字符串转10进制int
+ (int)hexNumberStringToNumber:(NSString *)hexNumberString;

//16进制字符串转NSData
//+ (NSData *)hexToBytes:(NSString *)str;

//普通字符串,转NSData
+ (NSData *)stringToBytes:(NSString *)str;

//大端与小端互转
+(NSData *)dataTransfromBigOrSmall:(NSData *)data;
+(NSString*)dataChangeToString:(NSData*)data;
+(NSMutableData*)HexStringToData:(NSString*)str;




#pragma mark --- NSUinteger 截取

/**
 * @brief 截取NSUInteger 的最后一个字节  再 转成一个长度为1的 NSData
 */
+ (NSData *)getInstructionData1L:(NSUInteger)integer;

/**
 * @brief 截取NSUInteger 的最后两个字节  再 转成一个长度为2的NSData
 */
+ (NSData *)getInstructionData2L:(NSUInteger)integer;

+ (NSData *)getInstructionData2L1:(NSUInteger)integer;

/**
 * @brief 截取NSUInteger 的最后三个字节  再 转成一个长度为3NSData
 */
+ (NSData *)getInstructionData3L:(NSUInteger)integer;

/**
 * @brief 将一个NSUInteger  转成一个NSData
 */
+ (NSData *)getInstructionData4L:(NSUInteger)integer;

/**
 * @brief 16个字符表示的十六进制 转 NSData
 * @return NSData
 */
+ (NSData *)hexStrToData:(NSString *)twoHexStr;

#pragma mark ---  时间

/**
 * @brief 得到时间  yyyy/month/day week hh:mm:secend
 * @return NSData 指定格式的时间的Data 类型
 */
+ (NSData *)getDataOfDateTime;

/**
 * @brief 根据字符串得到时间 字符串格式：@"yyyy-MM-dd HH:mm"
 * @prama NSString dateString
 * @return NSData
 */
//- (NSData *)getDateFromDateString:(NSString *)dateString;


/**
 * @brief 网关时间校准() 转成NSData 类型
 *
 */
+ (NSData *)getDataOfDateWithFormateYYMMDDHHmmss;

/**
 * @brief    将25个时区对应到 0-24 之间的数字 并返回当前时区的 NSData 表示
手机时区
 0-11   西1到西12
 12     0时区
 13-24  东1到东12
 */
+ (NSData *)getDataOfTimeZone;

/**
 * @brief 一个字节的NSData 转成 NSUInteger
 * @param data 一个字节长度
 */
+ (NSUInteger)oneByteToDecimalUint:(NSData *)data;

/**
 * @brief 一个字节的NSData 转成 NSUInteger
 * @param data 2个字节长度
 */
+ (NSUInteger)twoBytesToDecimalUint:(NSData *)data;
/**
 * @brief 一个字节的NSData 转成 NSUInteger
 * @param data 3个字节长度
 */
+ (NSUInteger)threeBytesToDecimalUnit:(NSData *)data;

/**
 * @brief 一个字节的NSData 转成 NSUInteger
 * @param data 4个字节长度
 */
+ (NSUInteger)fourBytesToDecimalUnit:(NSData *)data;

/**
 * @brief 一个字节的NSData 转成 int
 * @param data 4个字节长度
 */
+ (int)dataToInt4:(NSData *)data;
/**
 * @brief 一个字节转成 二进制的字符串
 * @return NSString
 */
+ (NSString *)dataToBinaryString:(NSData *)data;

/**
 * @brief 十进制数转 二进制字符串
 */
+ (NSString *)decimalTOBinary:(NSUInteger)tmpid backLength:(int)length;

/**
 二进制转换成十六进制
 
 @param binary 二进制数
 @return 十六进制数
 */
+ (NSString *)getHexByBinary:(NSString *)binary;

/**
 * @brief CRC校验 按照新协议修改后
 */
+ (NSData *)crcVerify:(NSData *)data;


+ (uint16_t)crc16:(NSData *)data;

+ (int) checkSum:(int)crc byte:(NSData *)data;
/**
 * @brief 批量添加分组灯开始 0x0054 获取所有灯具MAC 地址的CRC 验证码
 */
+ (NSData *)getCrcVerifyCode:(NSData *)data;
#pragma mark --- 针对表示MAC地址的字节数组 转成字符串

/**
 * @brief NSData 转成十六进制字符串 用“:”分隔
 * @param data 长度为8字节的NSata
 * @rerurn 用冒号分隔的字符串 MAC 地址的格式
 */
+ (NSString *)dataToHexStringMac:(NSData *)data;
/**
 * @brief NSData 转成十六进制字符串 不分隔
 * @param data 长度为8字节的NSata
 * @rerurn 字符串 MAC 地址的格式
 */
+ (NSString *)dataToHexStringMacNoSplit:(NSData *)data;
/**
 * @brief merger two NSData
 */
+ (NSData *)merger2Data:(NSData *)firData secData:(NSData *)secData;

//合并 或者拼接指令（网关MAC + 命令码 + 灯具地址）
/**
 * @brief 合并三个NSData
 */
+ (NSData *)merger3Data:(NSData *)firData secData:(NSData *)secondData thiData:(NSData *)thirdData;


/**
 * @brief 合并三个NSData
 */
+ (NSData *)merger4Data:(NSData *)firData secData:(NSData *)secondData thiData:(NSData *)thirdData  fouData:(NSData *)fouData;


/**
 * @brief 合并五个NSData
 */
+ (NSData *)merger5Data:(NSData *)firData secData:(NSData *)secData thiData:(NSData *)thiData fouData:(NSData *)fouData fivData:(NSData *)fivData;

@end
