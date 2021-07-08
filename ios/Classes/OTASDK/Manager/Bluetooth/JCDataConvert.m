//
//  JCDataConvert.m
//  Zebra
//
//  Created by han on 2018/10/13.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "JCDataConvert.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation JCDataConvert

//删除字符串中的制定字符
+ (NSString *) stringDeleteString:(NSString *)str by:(unichar)deleChar{
    NSMutableString *str1 = [NSMutableString stringWithString:str];
    for (int i = 0; i < str1.length; i++) {
        unichar c = [str1 characterAtIndex:i];
        NSRange range = NSMakeRange(i, 1);
        if ( c == deleChar ) { //此处可以是任何字符
            [str1 deleteCharactersInRange:range];
            --i;
        }
    }
    NSString *newstr = [NSString stringWithString:str1];
    return newstr;
}

//data转字符串
+ (NSString *)ConvertHexToString:(NSData *)needConvertHex{
    NSString *str = nil;
    const char *valueString = [[needConvertHex description] cStringUsingEncoding: NSUTF8StringEncoding];
    str = [[NSString alloc]initWithCString:valueString encoding:NSUTF8StringEncoding];
    str = [str substringWithRange:NSMakeRange(1, str.length - 2)];
    str = [JCDataConvert stringDeleteString:str by:' '];
    if ([UIDevice currentDevice].systemVersion.floatValue >= 13.0 && [str containsString:@"length"]&& [str containsString:@"bytes"]) {
        NSRange rangeTemp = [str rangeOfString:@"0x"];
        str = [str substringFromIndex:rangeTemp.location+rangeTemp.length];
        str = [str stringByReplacingOccurrencesOfString:@"{" withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"}" withString:@""];
    }
    return str;
}

//字符串转data 不带0x
+ (NSData*)hexToBytes:(NSString *)str
{
    NSMutableData* data = [NSMutableData data];
    int idx;
    for (idx = 0; idx+2 <= str.length; idx+=2) {
        NSRange range = NSMakeRange(idx, 2);
        NSString* hexStr = [str substringWithRange:range];
        NSScanner* scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
    }
    return data;
}
//16进制字符串转data
+ (NSData *) stringToHexData:(NSString *)hexStr {
    NSInteger len = [hexStr length] / 2;    // Target length
    unsigned char *buf = malloc(len);
    unsigned char *whole_byte = buf;
    char byte_chars[3] = {'\0','\0','\0'};
    
    int i;
    for (i=0; i < [hexStr length] / 2; i++) {
        byte_chars[0] = [hexStr characterAtIndex:i*2];
        byte_chars[1] = [hexStr characterAtIndex:i*2+1];
        *whole_byte = strtol(byte_chars, NULL, 16);
        whole_byte++;
    }
    
    NSData *data = [NSData dataWithBytes:buf length:len];
    free( buf );
    return data;
}

//将十进制转化为十六进制
+ (NSString *)ToHex:(NSInteger)tmpid {
    NSString *nLetterValue;
    NSString *str =@"";
    int ttmpig;
    for (int i = 0; i<9; i++) {
        ttmpig=tmpid%16;
        tmpid=tmpid/16;
        switch (ttmpig)
        {
            case 10:
                nLetterValue =@"A";break;
            case 11:
                nLetterValue =@"B";break;
            case 12:
                nLetterValue =@"C";break;
            case 13:
                nLetterValue =@"D";break;
            case 14:
                nLetterValue =@"E";break;
            case 15:
                nLetterValue =@"F";break;
            default:
                nLetterValue = [NSString stringWithFormat:@"%u",ttmpig];
                
        }
        str = [nLetterValue stringByAppendingString:str];
        if (tmpid == 0) {
            break;
        }
    }
    if(str.length == 1 || str.length%2){
        return [NSString stringWithFormat:@"0%@",str];
    }else{
        return str;
    }
}

//将十六进制转换成十进制
+ (NSInteger)ToInteger:(NSData *)hexData{
    return (strtoul([[JCDataConvert ConvertHexToString:hexData] UTF8String], 0, 16));
}

//int转data
+ (NSData *)intToData:(int)i {
    NSData *data = [NSData dataWithBytes: &i length: sizeof(i)];
    return data;
}

//data转int
+ (int)dataToInt:(NSData *)data {
    int i;
    [data getBytes:&i length:sizeof(i)];
    return i;
}

//将NSData转化为16进制字符串
+ (NSString *)convertDataToHexStr:(NSData *)data {
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length]];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%x", (dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [string appendString:hexStr];
            } else {
                [string appendFormat:@"0%@", hexStr];
            }
        }
    }];
    return string;
}

//16进制字符串转10进制
+ (NSUInteger)hexNumberStringToNumber:(NSString *)hexNumberString
{
    NSString * temp10 = [NSString stringWithFormat:@"%lu",strtoul([hexNumberString UTF8String],0,16)];
    //转成数字
    NSUInteger cycleNumber = [temp10 integerValue];
    return cycleNumber;
}

//普通字符串,转NSData
+ (NSData *)stringToBytes:(NSString *)str {
    return [str dataUsingEncoding:NSASCIIStringEncoding];
}

//大端与小端互转
+ (NSData *)dataTransfromBigOrSmall:(NSData *)data {
    NSString *tmpStr = [self dataChangeToString:data];
    NSMutableArray *tmpArra = [NSMutableArray array];
    for (int i = 0 ;i<data.length*2 ;i+=2) {
        NSString *str = [tmpStr substringWithRange:NSMakeRange(i, 2)];
        [tmpArra addObject:str];
    }
    
    NSArray *lastArray = [[tmpArra reverseObjectEnumerator] allObjects];
    NSMutableString *lastStr = [NSMutableString string];
    for (NSString *str in lastArray) {
        [lastStr appendString:str];
    }
    
    NSData *lastData = [self HexStringToData:lastStr];
    return lastData;
}

+ (NSString*)dataChangeToString:(NSData*)data {
    NSString * string = [NSString stringWithFormat:@"%@",data];
    string = [string stringByReplacingOccurrencesOfString:@"<" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@">" withString:@""];
    string = [string stringByReplacingOccurrencesOfString:@" " withString:@""];
    return string;
}

+ (NSMutableData*)HexStringToData:(NSString*)str {
    NSString *command = str;
    command = [command stringByReplacingOccurrencesOfString:@" " withString:@""];
    NSMutableData *commandToSend= [[NSMutableData alloc] init];
    unsigned char whole_byte;
    char byte_chars[3] = {'\0','\0','\0'};
    int i;
    for (i=0; i < [command length]/2; i++) {
        byte_chars[0] = [command characterAtIndex:i*2];
        byte_chars[1] = [command characterAtIndex:i*2+1];
        whole_byte = strtol(byte_chars, NULL, 16);
        [commandToSend appendBytes:&whole_byte length:1];
    }
    return commandToSend;
}

#pragma mark --- NSUinteger 截取
/**
 * @brief 截取NSUInteger 的最后一个字节  再 转成一个长度为1的 NSData
 */
+ (NSData *)getInstructionData1L:(NSUInteger)integer {
    NSData *integerData = [NSData dataWithBytes:&integer length:sizeof(integer)];
    NSData *integerData1L = [integerData subdataWithRange:NSMakeRange(0, 1)];
    return integerData1L;
}

/**
 * @brief 截取NSUInteger 的最后两个字节  再 转成一个长度为2的NSData
 */
+ (NSData *)getInstructionData2L:(NSUInteger)integer {
    NSData *integerData = [NSData dataWithBytes:&integer length:sizeof(integer)];
    NSData *data1 = [integerData subdataWithRange:NSMakeRange(0, 1)];
    NSData *data2 = [integerData subdataWithRange:NSMakeRange(1, 1)];
    NSMutableData *mData = [NSMutableData data];
    [mData appendData:data2];
    [mData appendData:data1];
    return mData;
}

+ (NSData *)getInstructionData2L1:(NSUInteger)integer {
    NSString *strInt = [ NSString stringWithFormat:@"%lu",(unsigned long)integer];
    NSMutableData *mData = [NSMutableData data];
    for (int i = 0; i < 2 ; i++) {
        NSString *subStr = [strInt substringWithRange:NSMakeRange(i, 1)];
        NSUInteger int1 = subStr.integerValue;
        NSLog(@"inti :%lu",(unsigned long)int1);
        Byte bytes = int1 & 0xff;
        [mData appendBytes:&bytes length:1];
        
    }
    NSLog(@"mData  2:%@",mData);
    return mData;
}

/**
 * @brief 截取NSUInteger 的最后三个字节  再 转成一个长度为3NSData
 */
+ (NSData *)getInstructionData3L:(NSUInteger)integer {
    NSData *integerData = [NSData dataWithBytes:&integer length:sizeof(integer)];
    NSData *data1 = [integerData subdataWithRange:NSMakeRange(0, 1)];
    NSData *data2 = [integerData subdataWithRange:NSMakeRange(1, 1)];
    NSData *data3 = [integerData subdataWithRange:NSMakeRange(2, 1)];
    NSMutableData *mData = [NSMutableData data];
    [mData appendData:data3];
    [mData appendData:data2];
    [mData appendData:data1];
    return mData;
}

/**
 * @brief 将一个NSUInteger  转成一个NSData
 */
+ (NSData *)getInstructionData4L:(NSUInteger)integer {
    NSData *integerData = [NSData dataWithBytes:&integer length:sizeof(integer)];
    NSData *data1 = [integerData subdataWithRange:NSMakeRange(0, 1)];
    NSData *data2 = [integerData subdataWithRange:NSMakeRange(1, 1)];
    NSData *data3 = [integerData subdataWithRange:NSMakeRange(2, 1)];
    NSData *data4 = [integerData subdataWithRange:NSMakeRange(3, 1)];
    NSMutableData *mData = [NSMutableData data];
    [mData appendData:data4];
    [mData appendData:data3];
    [mData appendData:data2];
    [mData appendData:data1];
    return mData;
}

/**
 * @brief 16个字符表示的十六进制 转 NSData
 * @return NSData
 */
+ (NSData *)hexStrToData:(NSString *)twoHexStr {
    NSMutableData *mData = [NSMutableData data];
    for(int i=0;i<twoHexStr.length;i++) {
        int int_ch = 0;  /// 两位16进制数转化后的10进制数
        unichar hex_char1 = [twoHexStr characterAtIndex:i]; ////两位16进制数中的第一位(高位*16)
        int int_ch1;
        if(hex_char1 >= '0' && hex_char1 <='9')
            int_ch1 = (hex_char1-48)*16;   //// 0 的Ascll - 48
        else if(hex_char1 >= 'A' && hex_char1 <='F')
            int_ch1 = (hex_char1-55)*16; //// A 的Ascll - 65
        else
            int_ch1 = (hex_char1-87)*16; //// a 的Ascll - 97
        i++;
        unichar hex_char2 = [twoHexStr characterAtIndex:i]; ///两位16进制数中的第二位(低位)
        int int_ch2;
        if(hex_char2 >= '0' && hex_char2 <='9')
            int_ch2 = (hex_char2-48); //// 0 的Ascll - 48
        else if(hex_char1 >= 'A' && hex_char1 <='F')
            int_ch2 = hex_char2-55; //// A 的Ascll - 65
        else
            int_ch2 = hex_char2-87; //// a 的Ascll - 97
        
        int_ch = int_ch1+int_ch2;
        
        [mData appendData:[self getInstructionData1L:(NSUInteger)int_ch]];
        
    }
    return mData;
}

#pragma mark ---  时间

/**
 * @brief 得到时间  yyyy/month/day week hh:mm:secend
 * @return NSData 指定格式的时间的Data 类型
 */
+ (NSData *)getDataOfDateTime{
    NSDate *date = [NSDate date];
    NSLog(@"%@",date);
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    NSDate *localeDate = [date  dateByAddingTimeInterval: interval];
    NSLog(@"%@", localeDate);
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] ;
    
    //ios 8 之前
    /*
     NSDate *now = [NSDate date];
     NSCalendar *cal = [NSCalendar currentCalendar];
     unsigned int unitFlags = NSWeekdayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
     NSDateComponents *dd = [cal components:unitFlags fromDate:now];
     int week = [dd weekday];
     int hour = [dd hour];
     int minute = [dd minute];
     second = [dd second];
     */
    //iOS 8之后支持的枚举类型
    NSInteger unitFlags =   NSCalendarUnitYear |
    NSCalendarUnitMonth |
    NSCalendarUnitDay |
    NSCalendarUnitWeekday |
    NSCalendarUnitHour |
    NSCalendarUnitSecond |
    NSCalendarUnitSecond;
    NSDateComponents *comps = [calendar components:unitFlags fromDate:date];
    NSUInteger week = [comps weekday];
    NSUInteger year=[comps year];
    NSUInteger month = [comps month];
    NSUInteger day = [comps day];
    //[formatter setDateStyle:NSDateFormatterMediumStyle];
    //This sets the label with the updated time.
    NSUInteger hour = [comps hour];
    NSUInteger min = [comps minute];
    NSUInteger sec = [comps second];
    
    NSData *yearData = [self getInstructionData2L:year];
    NSData *monthData = [self getInstructionData1L:month];
    NSData *dayData = [self getInstructionData1L:day];
    NSData *weekData = [self getInstructionData1L:week];
    NSData *hourData = [self getInstructionData1L:hour];
    NSData *minuteData = [self getInstructionData1L:min];
    NSData *secondData = [self getInstructionData1L:sec];
    
    NSData *data5 = [self merger5Data:yearData secData:monthData thiData:dayData fouData:weekData fivData:hourData];
    NSData *data7 = [self merger3Data:data5 secData:minuteData thiData:secondData];
    
    return data7;
}

/**
 * @brief 网关时间校准() 转成NSData 类型
 *
 */
+ (NSData *)getDataOfDateWithFormateYYMMDDHHmmss {
    NSDate *date = [NSDate date];
    NSLog(@"%@",date);
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    
    NSDate *localeDate = [date  dateByAddingTimeInterval: interval];
    
    NSLog(@"%@", localeDate);
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSCalendar *calendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian] ;
    
    //iOS 8之后支持的枚举类型
    NSInteger unitFlags =   NSCalendarUnitYear |
    NSCalendarUnitMonth |
    NSCalendarUnitDay |
    NSCalendarUnitWeekday |
    NSCalendarUnitHour |
    NSCalendarUnitMinute |
    NSCalendarUnitSecond;
    NSDateComponents *comps = [calendar components:unitFlags fromDate:date];
    //NSUInteger week = [comps weekday];
    NSUInteger year=[comps year];
    NSUInteger month = [comps month];
    NSUInteger day = [comps day];
    //[formatter setDateStyle:NSDateFormatterMediumStyle];
    //This sets the label with the updated time.
    NSUInteger hour = [comps hour];
    NSUInteger min = [comps minute];
    NSUInteger sec = [comps second];
    
    NSData *yearData = [self getInstructionData2L:year];
    //NSMutableData *mData = [NSMutableData data];
    //mData = [mData appendData:yearData];
    NSData *monthData = [self getInstructionData1L:month];
    NSData *dayData = [self getInstructionData1L:day];
    //NSData *weekData = [self getInstructionData1L:week];
    NSData *hourData = [self getInstructionData1L:hour];
    NSData *minuteData = [self getInstructionData1L:min];
    NSData *secondData = [self getInstructionData1L:sec];
    NSData *data4 = [self merger4Data:yearData secData:monthData thiData:dayData fouData:hourData];
    NSData *data7 = [self merger3Data:data4 secData:minuteData thiData:secondData];
    
    return data7;
}

/**
 * @brief    将25个时区对应到 0-24 之间的数字 并返回当前时区的 NSData 表示
 手机时区
 0-11   西1到西12
 12     0时区
 13-24  东1到东12
 */
+ (NSData *)getDataOfTimeZone {
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger zoneSecond = [zone secondsFromGMT];
    NSInteger zoneInt = zoneSecond/3600;
    NSUInteger finalInt;
    if (zoneInt == 0) {
        finalInt = 12;
    }else if (zoneInt < 0){
        finalInt = -zoneInt -1;
    }else {
        finalInt = zoneInt + 12;
    }
    
    NSData *data = [self getInstructionData1L:finalInt*2];
    return data;
}

/**
 * @brief 一个字节的NSData 转成 NSUInteger
 * @param data 一个字节长度
 */
+ (NSUInteger)oneByteToDecimalUint:(NSData *)data {
    Byte *bytes = (Byte *)[data bytes];
    NSUInteger value = 0;
    if (data.length == 1) {
        NSString *strDec = [NSString stringWithFormat:@"%d",bytes[0]];
        NSNumber *number = [NSNumber numberWithLongLong:strDec.longLongValue];
        value = number.unsignedIntegerValue;
    }
    return value;
}

/**
 * @brief 2个字节的NSData 转成 NSUInteger
 * @param data 2个字节长度
 */
+ (NSUInteger)twoBytesToDecimalUint:(NSData *)data {
    Byte *bytes = (Byte *)[data bytes];
    NSUInteger value = 0;
    if (data.length == 2) {
        for (int i = 0 ; i < 2 ; i++) {
            NSString *strDec = [NSString stringWithFormat:@"%d",bytes[i]];
            NSNumber *number = [NSNumber numberWithLongLong:strDec.longLongValue];
            NSUInteger valueTemp = number.unsignedIntegerValue;
            value =  value + valueTemp*pow(256, 1-i);
        }
    }
    return value;
}

/**
 * @brief 一个字节的NSData 转成 NSUInteger
 * @param data 3个字节长度
 */
+ (NSUInteger)threeBytesToDecimalUnit:(NSData *)data {
    Byte *bytes = (Byte *)[data bytes];
    NSUInteger value = 0;
    if (data.length == 3) {
        for (int i = 0 ; i < 3 ; i++) {
            NSString *strDec = [NSString stringWithFormat:@"%d",bytes[i]];
            NSNumber *number = [NSNumber numberWithLongLong:strDec.longLongValue];
            NSUInteger valueTemp = number.unsignedIntegerValue;
            value =  value + valueTemp*pow(256, 2-i);
        }
    }
    return value;
}

/**
 * @brief 一个字节的NSData 转成 NSUInteger
 * @param data 4个字节长度
 */
+ (NSUInteger)fourBytesToDecimalUnit:(NSData *)data {
    Byte *bytes = (Byte *)[data bytes];
    NSUInteger value = 0;
    if (data.length == 4) {
        for (int i = 0 ; i < 4 ; i++) {
            NSString *strDec = [NSString stringWithFormat:@"%d",bytes[i]];
            NSNumber *number = [NSNumber numberWithLongLong:strDec.longLongValue];
            NSUInteger valueTemp = number.unsignedIntegerValue;
            value =  value + valueTemp*pow(256, 3-i);
        }
    }
    return value;
}

/**
 * @brief 一个字节转成 二进制的字符串
 * @return NSString
 */
+ (NSString *)dataToBinaryString:(NSData *)data {
    //    Byte bytes[] = (Byte *)[data getBytes:data length:sizeof(data)];
    const char *chars = (char *)[data bytes];
    NSMutableString *hexString = [[NSMutableString alloc] init];
    for (NSUInteger i = 0 ; i < data.length; i ++) {
        [hexString appendString:[NSString stringWithFormat:@"%0.2hhx",chars[i]]];
    }
    NSLog(@"data:%@-----BinaryStr:%@",data,hexString);
    return hexString;
}

+ (int)dataToInt4:(NSData *)data {
    Byte byte[4] = {};
    [data getBytes:byte length:4];
    int value;
    value = (int) ((byte[0] & 0xff) | (byte[1] & 0xff)<<8 | (byte[2] & 0xff)<<16 | (byte[3] & 0xff)<<24);
    return value;
}

/**
 * @brief 十进制数转 二进制字符串
 */
+ (NSString *)decimalTOBinary:(NSUInteger)tmpid backLength:(int)length
{
    NSString *a = @"";
    while (tmpid) {
        a = [[NSString stringWithFormat:@"%lu",(unsigned long)tmpid%2] stringByAppendingString:a];
        if (tmpid/2 < 1) {
            break;
        }
        tmpid = tmpid/2 ;
    }
    
    if (a.length <= length) {
        NSMutableString *b = [[NSMutableString alloc]init];;
        for (int i = 0; i < length - a.length; i++) {
            [b appendString:@"0"];
        }
        a = [b stringByAppendingString:a];
    }
    NSLog(@"binary:%@",a);
    return a;
}

/**
 二进制转换成十六进制
 @param binary 二进制数
 @return 十六进制数
 */
+ (NSString *)getHexByBinary:(NSString *)binary {
    NSMutableDictionary *binaryDic = [[NSMutableDictionary alloc] initWithCapacity:16];
    [binaryDic setObject:@"0" forKey:@"0000"];
    [binaryDic setObject:@"1" forKey:@"0001"];
    [binaryDic setObject:@"2" forKey:@"0010"];
    [binaryDic setObject:@"3" forKey:@"0011"];
    [binaryDic setObject:@"4" forKey:@"0100"];
    [binaryDic setObject:@"5" forKey:@"0101"];
    [binaryDic setObject:@"6" forKey:@"0110"];
    [binaryDic setObject:@"7" forKey:@"0111"];
    [binaryDic setObject:@"8" forKey:@"1000"];
    [binaryDic setObject:@"9" forKey:@"1001"];
    [binaryDic setObject:@"A" forKey:@"1010"];
    [binaryDic setObject:@"B" forKey:@"1011"];
    [binaryDic setObject:@"C" forKey:@"1100"];
    [binaryDic setObject:@"D" forKey:@"1101"];
    [binaryDic setObject:@"E" forKey:@"1110"];
    [binaryDic setObject:@"F" forKey:@"1111"];
    
    if (binary.length % 4 != 0) {
        
        NSMutableString *mStr = [[NSMutableString alloc]init];;
        for (int i = 0; i < 4 - binary.length % 4; i++) {
            
            [mStr appendString:@"0"];
        }
        binary = [mStr stringByAppendingString:binary];
    }
    NSString *hex = @"";
    for (int i=0; i<binary.length; i+=4) {
        
        NSString *key = [binary substringWithRange:NSMakeRange(i, 4)];
        NSString *value = [binaryDic objectForKey:key];
        if (value) {
            
            hex = [hex stringByAppendingString:value];
        }
    }
    return hex;
}

/**
 * @brief CRC校验 按照新协议修改后
 */
+ (NSData *)crcVerify:(NSData *)data {
    int crcWord = 0x0000ffff;
    NSUInteger length =  data.length +4;
    NSData *dataLength = [self getInstructionData2L:length];
    Byte *dataArray = (Byte *)[data bytes];
    for (int i = 0; i < data.length; i++) {
        Byte byte = dataArray[i];
        crcWord ^= (int)byte & 0x000000ff;
        for (int j = 0; j < 8; j++) {
            if ((crcWord & 0x00000001) == 1) {
                crcWord = crcWord>>1;
                crcWord = crcWord ^ 0x0000A001;
            }else {
                crcWord = (crcWord >> 1);
            }
        }
    }
    
    Byte crcH = (Byte)0xff&(crcWord>>8);
    Byte crcL = (Byte)0xff&crcWord;
    Byte arraycrc[]={crcH,crcL};
    NSData *datacrc = [[NSData alloc] initWithBytes:arraycrc length:sizeof(arraycrc)];
    
    NSData *data3 = [self merger3Data:dataLength secData:data thiData:datacrc];
    return data3;
}

/**
 * @brief MAC 地址的CRC 验证码
 */
+ (NSData *)getCrcVerifyCode:(NSData *)data {
    int crcWord = 0x0000ffff;
    
    Byte *dataArray = (Byte *)[data bytes];
    for (int i = 0; i < data.length; i++) {
        Byte byte = dataArray[i];
        crcWord ^= (int)byte & 0x000000ff;
        for (int j = 0; j < 8; j++) {
            if ((crcWord & 0x00000001) == 1) {
                crcWord = crcWord>>1;
                crcWord = crcWord ^ 0x0000A001;
            }else {
                crcWord = (crcWord >> 1);
            }
        }
    }
    
    Byte crcH = (Byte)0xff&(crcWord>>8);
    Byte crcL = (Byte)0xff&crcWord;
    Byte arraycrc[]={crcH,crcL};
    NSData *datacrc = [[NSData alloc] initWithBytes:arraycrc length:sizeof(arraycrc)];
    
    return datacrc;
}

+ (uint16_t)crc16:(NSData *)data {
    Byte *dataArray = (Byte *)[data bytes];
    const uint8_t *byte = (const uint8_t *)dataArray;
    uint16_t length = (uint16_t)16;
    return gen_crc16(byte, length);
}

#define PLOY 0X1021
uint16_t gen_crc16(const uint8_t *data, uint16_t size) {
    uint16_t crc = 0;
    uint8_t i;
    for (; size > 0; size--) {
        crc = crc ^ (*data++ <<8);
        for (i = 0; i < 8; i++) {
            if (crc & 0X8000) {
                crc = (crc << 1) ^ PLOY;
            }else {
                crc <<= 1;
            }
        }
        crc &= 0XFFFF;
    }
    return crc;
}

+ (int) checkSum:(int)crc byte:(NSData *)data {
    NSUInteger length = data.length;
    Byte *buf= malloc(sizeof(Byte)*(length));
    [data getBytes:buf length:length];
    for (int pos = 0; pos < length; pos++) {
        if (buf[pos] < 0) {
            crc ^= (int) buf[pos] + 256; // XOR byte into least sig. byte of
            // crc
        } else {
            crc ^= (int) buf[pos]; // XOR byte into least sig. byte of crc
        }
        for (int i = 8; i != 0; i--) { // Loop over each bit
            if ((crc & 0x0001) != 0) { // If the LSB is set
                crc >>= 1; // Shift right and XOR 0xA001
                crc ^= 0xA001;
            } else{
                // Else LSB is not set
                crc >>= 1; // Just shift right
            }
        }
    }
    
    return crc;
}

#pragma mark --- 针对表示MAC地址的字节数组 转成字符串

/**
 * @brief NSData 转成十六进制字符串 用“:”分隔
 * @param data 长度为8字节的NSata
 * @rerurn 用冒号分隔的字符串 MAC 地址的格式
 */
+ (NSString *)dataToHexStringMac:(NSData *)data {
    Byte *bytes = (Byte *)[data bytes];
    NSString *hexString = @"";
    NSString *stringFinal = @"";
    for (int i = 0 ; i < data.length; i++) {
        NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]];
        if ([newHexStr length] == 1) {
            hexString = [NSString stringWithFormat:@"%@0%@:",hexString,newHexStr];
        }else{
            hexString = [NSString stringWithFormat:@"%@%@:",hexString,newHexStr];
        }
    }
    if ([hexString hasSuffix:@":"]) {
        stringFinal = [hexString substringToIndex:(hexString.length - 1)];
    }
    return stringFinal;
}

/**
 * @brief NSData 转成十六进制字符串 不分隔
 * @param data 长度为8字节的NSata
 * @rerurn 字符串 MAC 地址的格式
 */
+ (NSString *)dataToHexStringMacNoSplit:(NSData *)data {
    Byte *bytes = (Byte *)[data bytes];
    NSString *hexString = @"";
    for (int i = 0 ; i < data.length; i++) {
        NSString *newHexStr = [NSString stringWithFormat:@"%x",bytes[i]];
        if ([newHexStr length] == 1) {
            hexString = [NSString stringWithFormat:@"%@0%@",hexString,newHexStr];
        }else{
            hexString = [NSString stringWithFormat:@"%@%@",hexString,newHexStr];
        }
    }
    
    return hexString;
}

/**
 * @brief merger two NSData
 */
+ (NSData *)merger2Data:(NSData *)firData secData:(NSData *)secData {
    NSMutableData *mergerData = [NSMutableData data];
    if (firData != nil && secData != nil) {
        [mergerData appendData:firData];
        [mergerData appendData:firData];
    }
    return mergerData;
}

//合并 或者拼接指令
/**
 * @brief 合并三个NSData
 */
+ (NSData *)merger3Data:(NSData *)firData secData:(NSData *)secondData thiData:(NSData *)thirdData {
    NSMutableData *mergerData = [NSMutableData data];
    if (firData != nil) {
        [mergerData appendData:firData];
    }
    if (secondData != nil) {
        [mergerData appendData:secondData];
    }
    if (thirdData != nil) {
        [mergerData appendData:thirdData];
    }
    return mergerData;
}


/**
 * @brief 合并四个NSData
 */
+ (NSData *)merger4Data:(NSData *)firData secData:(NSData *)secondData thiData:(NSData *)thirdData  fouData:(NSData *)fouData {
    NSMutableData *mergerData = [NSMutableData data];
    if (firData != nil) {
        [mergerData appendData:firData];
    }
    if (secondData != nil) {
        [mergerData appendData:secondData];
    }
    if (thirdData != nil) {
        [mergerData appendData:thirdData];
    }
    if (fouData != nil) {
        [mergerData appendData:fouData];
    }
    return mergerData;
}


/**
 * @brief 合并五个NSData
 */
+ (NSData *)merger5Data:(NSData *)firData secData:(NSData *)secData thiData:(NSData *)thiData fouData:(NSData *)fouData fivData:(NSData *)fivData {
    NSMutableData *mergerData = [NSMutableData data];
    if (firData != nil) {
        [mergerData appendData:firData];
    }
    if (secData != nil) {
        [mergerData appendData:secData];
    }
    if (thiData != nil) {
        [mergerData appendData:thiData];
    }
    if (fouData != nil) {
        [mergerData appendData:fouData];
    }
    if (fivData != nil) {
        [mergerData appendData:fivData];
    }
    return mergerData;
}

+ (NSString *)convertOriginalToMacString:(NSObject *)object {
    if([object isKindOfClass:[NSString class]]) {
        NSString *value = [NSString stringWithFormat:@"%@",object];
        if ([UIDevice currentDevice].systemVersion.floatValue >= 13.0 && [value containsString:@"length"]&& [value containsString:@"bytes"]) {
            NSRange rangeTemp = [value rangeOfString:@"0x"];
            value = [value substringFromIndex:rangeTemp.location+rangeTemp.length];
            value = [value stringByReplacingOccurrencesOfString:@"{" withString:@""];
            value = [value stringByReplacingOccurrencesOfString:@"}" withString:@""];
        }
        value = [value stringByReplacingOccurrencesOfString:@" " withString:@""];
        value = [value stringByReplacingOccurrencesOfString:@"<" withString:@""];
        value = [value stringByReplacingOccurrencesOfString:@">" withString:@""];
        if (value.length < 16) {
            return @"";
        }
        NSMutableString*macString = [[NSMutableString alloc]init];
        [macString appendString:[[value substringWithRange:NSMakeRange(14,2)]uppercaseString]];
        [macString appendString:@":"];
        [macString appendString:[[value substringWithRange:NSMakeRange(12,2)]uppercaseString]];
        [macString appendString:@":"];
        [macString appendString:[[value substringWithRange:NSMakeRange(10,2)]uppercaseString]];
        [macString appendString:@":"];
        [macString appendString:[[value substringWithRange:NSMakeRange(4,2)]uppercaseString]];
        [macString appendString:@":"];
        [macString appendString:[[value substringWithRange:NSMakeRange(2,2)]uppercaseString]];
        [macString appendString:@":"];
        [macString appendString:[[value substringWithRange:NSMakeRange(0,2)]uppercaseString]];
        return macString;
    }else if (![object isKindOfClass: [NSArray class]]){
        const char *valueString = [[object description] cStringUsingEncoding: NSUTF8StringEncoding];
        if (valueString != NULL) {//如果为空，则跳过，解决出现空指针bug
            NSString *value = [NSString stringWithFormat:@"%s",valueString];
            if ([UIDevice currentDevice].systemVersion.floatValue >= 13.0 && [value containsString:@"length"]&& [value containsString:@"bytes"]) {
                NSRange rangeTemp = [value rangeOfString:@"0x"];
                value = [value substringFromIndex:rangeTemp.location+rangeTemp.length];
                value = [value stringByReplacingOccurrencesOfString:@"{" withString:@""];
                value = [value stringByReplacingOccurrencesOfString:@"}" withString:@""];
            }
            value = [value stringByReplacingOccurrencesOfString:@" " withString:@""];
            value = [value stringByReplacingOccurrencesOfString:@"<" withString:@""];
            value = [value stringByReplacingOccurrencesOfString:@">" withString:@""];
            return value;
        }
    }
    
    
    return @"";
}

+ (NSString *)getOriginalToDataString:(NSString *)value {
    value = [value stringByReplacingOccurrencesOfString:@" " withString:@""];
    value = [value stringByReplacingOccurrencesOfString:@"<" withString:@""];
    value = [value stringByReplacingOccurrencesOfString:@">" withString:@""];
    if ([UIDevice currentDevice].systemVersion.floatValue >= 13.0 && [value containsString:@"length"]&& [value containsString:@"bytes"]) {
        NSRange rangeTemp = [value rangeOfString:@"0x"];
        value = [value substringFromIndex:rangeTemp.location+rangeTemp.length];
        value = [value stringByReplacingOccurrencesOfString:@"{" withString:@""];
        value = [value stringByReplacingOccurrencesOfString:@"}" withString:@""];
    }
    return value;
}

+ (NSString *)getPeripheralMac:(NSString *)macStr {
    NSMutableString*macString = [[NSMutableString alloc]init];
    if (macStr.length < 16) {
        return @"";
    }
    [macString appendString:[[macStr substringWithRange:NSMakeRange(14,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[macStr substringWithRange:NSMakeRange(12,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[macStr substringWithRange:NSMakeRange(10,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[macStr substringWithRange:NSMakeRange(8,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[macStr substringWithRange:NSMakeRange(6,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[macStr substringWithRange:NSMakeRange(4,2)]uppercaseString]];
    NSLog(@"macStr:%@,macString:%@",macStr,macString);
    return macString;
}

+ (NSData *)AES_ECB_EncryptWith:(NSData *)key original:(NSData *)data
{
    NSData *retData = nil;
    NSUInteger dataLength = [data length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    bzero(buffer, bufferSize);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128,
                                          ccNoPadding|kCCOptionECBMode,
                                          key.bytes, key.length,
                                          NULL,
                                          data.bytes, data.length,
                                          buffer, bufferSize,
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        retData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
    }
    free(buffer);
    return retData;
}

+ (NSData *)AES_ECB_DecryptWith:(NSData *)key src:(NSData *)data
{
    NSData *retData = nil;
    NSUInteger dataLength = [data length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    bzero(buffer, bufferSize);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128,
                                          ccNoPadding|kCCOptionECBMode,
                                          key.bytes, key.length,
                                          NULL,
                                          data.bytes, data.length,
                                          buffer, bufferSize,
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        retData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
    }
    free(buffer);
    return retData;
}


+ (NSString *)getRandomStr
{
    static int kNumber = 32;
    NSString *sourceStr = @"0123456789ABCDEF";
    NSMutableString *resultStr = [[NSMutableString alloc] init];
    for (int i = 0; i < kNumber; i++)
    {
        unsigned index = arc4random() % [sourceStr length];
        NSString *oneStr = [sourceStr substringWithRange:NSMakeRange(index, 1)];
        [resultStr appendString:oneStr];
    }
    return resultStr;

}

@end
