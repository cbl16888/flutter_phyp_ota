//
//  OTAManager.m
//  PHY
//
//  Created by Yang on 2018/10/13.
//  Copyright © 2018 phy. All rights reserved.
//

#import "OTAManager.h"
#import "JCDataConvert.h"
#import "DDFileReader.h"
#import "JCBluetoothManager.h"
#import "FileManager.h"
#import "Partition.h"
//#import "NSData+PHYOTA.h"

#define     kLoopCheckTime      0.04

NSUInteger const UPDATE_SYSTEM_TIME = 0x02;//更新系统时间
NSUInteger const START_OTA = 0x0102;//HEX OTA
NSUInteger const START_OTA_RES = 0x0103;//RES OTA
NSUInteger const REROOT = 0x04;//OTA REBOOT

//SLB OTA指令部分
UInt8 const MESG_HDER_SIZE = 4;
UInt8 const MESG_OPCO_ISSU_RAND_NUMB = 0x10;
UInt8 const MESG_OPCO_RESP_RAND_NUMB = 0x11;
UInt8 const MESG_OPCO_ISSU_AUTH_RSLT = 0x12;
UInt8 const MESG_OPCO_RESP_AUTH_RSLT = 0x13;
UInt8 const MESG_OPCO_ISSU_VERS_REQU = 0x20;//获取蓝牙设备固件版本信息
UInt8 const MESG_OPCO_RESP_VERS_REQU = 0x21;//返回蓝牙设备固件版本信息
UInt8 const MESG_OPCO_ISSU_OTAS_REQU = 0x22;//发送升级请求及固件信息
UInt8 const MESG_OPCO_RESP_OTAS_REQU = 0x23;//返回是否允许升级、上次传输大小以及是否支持快速升级模式
UInt8 const MESG_OPCO_ISSU_OTAS_SEGM = 0x2F;//发送升级包（OTA数据命令头）
UInt8 const MESG_OPCO_RESP_OTAS_SEGM = 0x24;//回复接收到的最后帧序号和已接收固件大小
UInt8 const MESG_OPCO_ISSU_OTAS_COMP = 0x25;//通知固件发送完成并进行校验
UInt8 const MESG_OPCO_RESP_OTAS_COMP = 0x26;//上报固件校验结果


NSUInteger csn = 0x00;

static OTAManager *_manager;

@interface OTAManager(){
    UInt16 mBinsFrsz;
    int smallPieceIndex;
}
//段落数组，元素为16*20个字节，每小段又有16段20个字节 的数据
@property(strong,nonatomic) NSMutableArray *partitionArray;

//OTA相关的变量
@property(nonatomic,strong) FileManager *fileManager;

@property(assign,nonatomic) int partitionIndex;
@property(assign,nonatomic) int blockIndex;
@property(assign,nonatomic) NSInteger flash_addr;
@property(assign,nonatomic) float totalSize;
@property(assign,nonatomic) float finshSize;

@property(assign,nonatomic) int mMesgNumb;

@property (nonatomic, strong) NSMutableArray *commandBuffer;            //指令缓存
@property (nonatomic, strong) NSTimer *sendCommandLoop;                 //发送指令定时器

//加密流程时需要用到的参数
@property (nonatomic, strong) NSString *randomStr;//APP端明文
@property (nonatomic, strong) NSData *bleKeyData;//固件端密文



@end

@implementation OTAManager

+ (OTAManager *)shareOTAManager{
    @synchronized(self) {
        if (!_manager) {
            _manager = [[OTAManager alloc] init];
            _manager.commandBuffer = [NSMutableArray array];
        }
    }
    return _manager;
}

- (void)startOTA{
    
    if (self.filePath.length == 0) {
        
        NSLog(@"在进行OTA之前，确定升级文件类型");
        return;
        
    }else if([self.filePath hasSuffix:@"res"]){
        
        NSString *commandStr = [JCDataConvert ToHex:(int)START_OTA_RES];
        [self sendDataUseCommand:commandStr];
        
    }else if([self.filePath hasSuffix:@"hex"]){
        
        NSString *commandStr = [JCDataConvert ToHex:(int)START_OTA];
        [self sendDataUseCommand:commandStr];
        
    }else if([self.filePath hasSuffix:@"hex16"]){
        
        NSString *commandStr = [JCDataConvert ToHex:(int)START_OTA];
        [self sendDataUseCommand:commandStr];
        
    }else if([self.filePath hasSuffix:@"hexe16"]){
        
        //加密OTA流程，应用模式下先发送0x05指令加16字节key
        self.randomStr = [JCDataConvert getRandomStr];
        NSData *key16 = [JCDataConvert hexToBytes:_AESKey];
        NSData *srcData = [JCDataConvert hexToBytes:self.randomStr];
//        NSData *encData = [srcData AES_ECB_EncryptWith:key16];
        NSData *encData = [JCDataConvert AES_ECB_EncryptWith:key16 original:srcData];
        
        NSString *commandStr = [NSString stringWithFormat:@"05%@",[JCDataConvert convertDataToHexStr:encData]];
        [self sendDataUseCommand:commandStr];
        return;
        
    }else {
        NSLog(@"不是正确的文件格式");
        return;
    }
    
    _otaState = OTANoInit;
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[JCBluetoothManager shareCBCentralManager] reScan];
    });
    
}

#pragma mark - 文件解析
- (void)updateOTAFirmwareConfirmPath{
    if(_maxPacketLength < 20 || self.filePath.length == 0) {
        return;
    }
    self.fileManager = [[FileManager alloc] firmWareFile:self.filePath length:(int)_maxPacketLength];
    self.totalSize = self.fileManager.length;
    [self initFileParameters];
    //01+位数+00
    NSString *commandStr = [NSString stringWithFormat:@"01%@00",[JCDataConvert ToHex:(int)self.fileManager.list.count]];
    [self sendDataUseCommand:commandStr];
    
}

- (void)initFileParameters{
    //OTA相关
    self.partitionIndex = 0;
    self.blockIndex = 0;//共用，SLB模式下代表OTA数据发送到哪个数据
    self.flash_addr = 0;
    self.finshSize = 0;
    
    mBinsFrsz = 0;//从蓝牙反馈数据中读取，一般为16
    self.mMesgNumb = 1;//SLB每个mBinsFrsz反馈内，当次数据的ID
    [_commandBuffer removeAllObjects];
}

#pragma mark - 轮询发送指令机制
/*
 *@开始轮询发送指令
 */
- (void)startLoopCheckCommandBuffer{
    NSLog(@"开启轮询发送指令");
    smallPieceIndex = 0;
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_sendCommandLoop = [NSTimer scheduledTimerWithTimeInterval:kLoopCheckTime target:self selector:@selector(loopCheckCommandBufferToSend) userInfo:nil repeats:YES];
    });
}

/*
 *@关闭轮询发送指令
 */
- (void)stopLoopCheckCommandBuffer{
    NSLog(@"关闭轮询发送指令");
    [_sendCommandLoop invalidate];
    _sendCommandLoop = nil;
    [_commandBuffer removeAllObjects];//清空指令缓存区
}

/*
 *@轮询发送指令  定时发送，每隔一段时间就发送
 */
- (void)loopCheckCommandBufferToSend{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (self->_commandBuffer.count > self->smallPieceIndex) { //如果有命令码存在就发送，如果没有就跳过
            
            NSData *cmd = [self->_commandBuffer objectAtIndex:self->smallPieceIndex];
            [[JCBluetoothManager shareCBCentralManager] sendOTAData:cmd];
            
            //实时更新进度条
            NSString *strcmd = [JCDataConvert convertDataToHexStr:cmd];
            if (self.isSLB) {
                self.finshSize += (strcmd.length-MESG_HDER_SIZE*2);//减去头部4字节，8个长度
            }else{
                self.finshSize += strcmd.length;
            }
            
            float num = self.finshSize *100/2/self.totalSize;
            NSLog(@"进度条：%.1f",num);
            dispatch_async(dispatch_get_main_queue(), ^{  //更新页面回到主线程
                if ([self.delegate respondsToSelector:@selector(updateOTAProgressDataback:feedBackInfo:)]){
                    [self.delegate updateOTAProgressDataback:self feedBackInfo:num];
                }
            });
            NSLog(@"发送的指令为：===> %@",strcmd);
            self->smallPieceIndex++;
            if (self->smallPieceIndex == self->_commandBuffer.count) {
                [self stopLoopCheckCommandBuffer];
            }
        }
        
    });
}

#pragma mark - 处理OTA数据
- (void)updateOTAData:(NSData *)data{
    @autoreleasepool {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //获取第一个字节的数据
            NSUInteger respondType = 0;
            NSString *tempStr = [JCDataConvert ConvertHexToString:data];
            if (data.length == 17&&([tempStr.uppercaseString hasPrefix:@"71"]||[tempStr.uppercaseString hasPrefix:@"72"]||[tempStr.uppercaseString hasPrefix:@"73"]||[tempStr.uppercaseString hasPrefix:@"8B"]||[tempStr.uppercaseString hasPrefix:@"8C"]||[tempStr.uppercaseString hasPrefix:@"8D"])) {
                respondType = [JCDataConvert oneByteToDecimalUint:[data subdataWithRange:NSMakeRange(0, 1)]];//16进制转10进制
            }else if (data.length>1) {
                respondType = [JCDataConvert twoBytesToDecimalUint:[data subdataWithRange:NSMakeRange(0, 2)]];//16进制转10进制
            }else if (data.length == 1 ) {
                respondType = [JCDataConvert oneByteToDecimalUint:[data subdataWithRange:NSMakeRange(0, 1)]];//16进制转10进制，
            }
            switch (respondType) {
                    //设置设备 OTA 状态//启动OTA模式，可以搜到OTA信号
                case 0x0081:{
                    NSLog(@"ota模式下启动OTA返回成功：81");
                    if ([self.filePath hasSuffix:@"res"]) {
                        NSString *tempStr = [self make_resource_cmd];
                        [[JCBluetoothManager shareCBCentralManager] sendOTACommand:[JCDataConvert hexToBytes:tempStr]];
                    }else {
                        [self stepOne];
                    }
                }
                    break;
                    
                    //OTA地址发送成功
                case 0x0084:
                {
                    [self stepTwo];
                }
                    break;
                case 0x0087:
                {
                    [self stepFour];
                }
                    break;
                    
                    
                    //0085  一个partition 数据发送成功，发送下一个partition命令
                case 0x0085:{
                    [self stepThree];
                }
                    break;
                    
                case 0x17:{
                    NSLog(@"XIP flash地址和run地址错误");
                    break;
                }
                case 0x06:{
                    NSLog(@"XIP flash地址和run地址错误??经验：改OTA Boot");
                    break;
                }
                    //0x0083 所有ota数据发送成功
                case 0x0083:{
                    
                    NSLog(@"发送数据成功：83");
                    if ([self.delegate respondsToSelector:@selector(updateOTAProgressDataback:isComplete:)]) {
                        [self.delegate updateOTAProgressDataback:self isComplete:true];
                    }
                    [self onOTAFinish];
                }
                    break;
                case 0x0089:{
                    [self stepOne];
                }
                    break;
                    //68 PPlus_ERR_OTA_DATA
                case 0x71:{
                    self.bleKeyData = [JCDataConvert hexToBytes:[[JCDataConvert convertDataToHexStr:data] substringFromIndex:2]];
                    NSString *commandStr = [NSString stringWithFormat:@"06%@",self.randomStr];
                    [self sendDataUseCommand:commandStr];
                }
                    break;
                case 0x72:{
                    NSData *key16 = [JCDataConvert hexToBytes:self->_AESKey];
                    NSData *jiemi = [JCDataConvert AES_ECB_DecryptWith:key16 src:self.bleKeyData];
                    if ([[JCDataConvert convertDataToHexStr:data].uppercaseString hasSuffix:[JCDataConvert convertDataToHexStr:jiemi].uppercaseString]) {
                        NSData *newKey = [JCDataConvert hexToBytes:self.randomStr];
                        NSData *encData = [JCDataConvert AES_ECB_EncryptWith:newKey original:jiemi];
                        NSData *secondEncData = [JCDataConvert AES_ECB_EncryptWith:key16 original:encData];
                        NSString *tempStr = [JCDataConvert ConvertHexToString:secondEncData];
                        NSString *commandStr = [NSString stringWithFormat:@"07%@",tempStr];
                        [self sendDataUseCommand:commandStr];
                    }else {
                        [self.delegate updateOTAErrorCallBack:self errorCode:0x777];
                    }
                }
                    break;
                case 0x73:{
                    NSString *commandStr = [JCDataConvert ToHex:(int)START_OTA];
                    [self sendDataUseCommand:commandStr];
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [[JCBluetoothManager shareCBCentralManager] reScan];
                    });
                }
                    break;
                case 0x8B:{
                    self.bleKeyData = [JCDataConvert hexToBytes:[[JCDataConvert convertDataToHexStr:data] substringFromIndex:2]];
                    NSString *commandStr = [NSString stringWithFormat:@"07%@",self.randomStr];
                    [self sendDataUseCommand:commandStr];
                }
                    break;
                case 0x8C:{
                    NSData *key16 = [JCDataConvert hexToBytes:self->_AESKey];
                    NSData *jiemi = [JCDataConvert AES_ECB_DecryptWith:key16 src:self.bleKeyData];
                    if ([[JCDataConvert convertDataToHexStr:data].uppercaseString hasSuffix:[JCDataConvert convertDataToHexStr:jiemi].uppercaseString]) {
                        NSData *newKey = [JCDataConvert hexToBytes:self.randomStr];
                        NSData *encData = [JCDataConvert AES_ECB_EncryptWith:newKey original:jiemi];
                        NSData *secondEncData = [JCDataConvert AES_ECB_EncryptWith:key16 original:encData];
                        NSString *tempStr = [JCDataConvert ConvertHexToString:secondEncData];
                        NSString *commandStr = [NSString stringWithFormat:@"08%@",tempStr];
                        [self sendDataUseCommand:commandStr];
                    }else {
                        [self.delegate updateOTAErrorCallBack:self errorCode:0x777];
                    }
                }
                    break;
                case 0x8D:{
                    [self updateOTAFirmwareConfirmPath];
                }
                    break;
                case 0x66:
                case 0x67:
                case 0x68:
                case 0x6887:{
                    //通知报错，发送数据错误
                    if ([self.delegate respondsToSelector:@selector(updateOTAErrorCallBack:errorCode:)]) {
                        [self.delegate updateOTAErrorCallBack:self errorCode:respondType];
                        [[JCBluetoothManager shareCBCentralManager] disConnectToPeripheral];
                        self.fileManager = nil;
                    }
                }
                    break;
                default: {
                    //其他错误码，报错
                    if ([self.delegate respondsToSelector:@selector(updateOTAErrorCallBack:errorCode:)]) {
                        [self.delegate updateOTAErrorCallBack:self errorCode:respondType];
                        [[JCBluetoothManager shareCBCentralManager] disConnectToPeripheral];
                        self.fileManager = nil;
                    }
                }
                    break;
            }
        });
    }
}

//收到返回的0x0081,开始发送升级文件信息，flash地址
- (void)stepOne{
    NSLog(@"当前文件:%@",self.filePath);
    if(self.fileManager == nil){
        [self updateOTAFirmwareConfirmPath];
        return;
    }
    Partition *partition = self.fileManager.list[self.partitionIndex];
    NSInteger temp_flash_addr = self.flash_addr;
    //run addr 在11000000 ~ 1107ffff， flash addr=run addr，其余的，flash addr从0开始递增
    if( (0x11000000 <= [JCDataConvert hexNumberStringToNumber:partition.address]) && ([JCDataConvert hexNumberStringToNumber:partition.address] <= 0x1107ffff)){
        temp_flash_addr = [JCDataConvert hexNumberStringToNumber:partition.address];
    }
    if ([self.filePath hasSuffix:@"res"]) {
        temp_flash_addr = 0;
        self.flash_addr = 0;
    }
    NSString *cmd = [self make_part_cmd:(int)self.partitionIndex flash_addr:(int)temp_flash_addr run_addr:partition.address size:(int)partition.partitionLength checksum:partition.checkSum];
    NSLog(@"stepOne====:%@",cmd);
    [[JCBluetoothManager shareCBCentralManager] sendOTACommand:[JCDataConvert hexToBytes:cmd]];
    
}

//收到0x0084
- (void)stepTwo{
    self.blockIndex = 0;
    [self stepFour];
}

//收到0x0087
- (void)stepFour{
    
    Partition *partition = self.fileManager.list[self.partitionIndex];
    NSArray *partitionArray = partition.partitionArray;
    if (self.blockIndex < partitionArray.count) {
        NSArray *cmdList = partitionArray[self.blockIndex];
        NSLog(@"装载第%d个Partition的第%d个段,包含个数%lu",self.partitionIndex,self.blockIndex,(unsigned long)cmdList.count);
        NSInteger cmdIndex = 0;
        while (cmdIndex < cmdList.count) {
            [self.commandBuffer addObject:[JCDataConvert hexToBytes:cmdList[cmdIndex]]];
            cmdIndex ++;
        }
        NSLog(@"当前缓存个数：%lu",(unsigned long)self.commandBuffer.count);
        self.blockIndex ++;
    }
    [self startLoopCheckCommandBuffer];
}

//收到0X0085
- (void)stepThree{
    NSLog(@"一组partition发送成功");
    self.partitionIndex++;
    if(self.partitionIndex < self.fileManager.list.count){
        //后面地址由前一个长度决定
        Partition *prePartition = self.fileManager.list[self.partitionIndex-1];
        
        //run addr 在11000000 ~ 1107ffff， flash addr=run addr，其余的，flash addr从0开始递增
        if( (0x11000000 > [JCDataConvert hexNumberStringToNumber:prePartition.address]) || ([JCDataConvert hexNumberStringToNumber:prePartition.address] > 0x1107ffff)){
            if ([self.filePath hasSuffix:@"hexe16"]) {
                self.flash_addr = self.flash_addr + prePartition.partitionLength + 4;
            }else {
                self.flash_addr = self.flash_addr + prePartition.partitionLength + 8;
            }
        }
        Partition *partition = self.fileManager.list[self.partitionIndex];
        NSInteger temp_flash_addr = self.flash_addr;
        //run addr 在11000000 ~ 1107ffff， flash addr=run addr，其余的，flash addr从0开始递增
        if( (0x11000000 <= [JCDataConvert hexNumberStringToNumber:partition.address]) && ([JCDataConvert hexNumberStringToNumber:partition.address] <= 0x1107ffff)){
            temp_flash_addr = [JCDataConvert hexNumberStringToNumber:partition.address];
        }
        if ([self.filePath hasSuffix:@"res"]) {
            temp_flash_addr = 0;
            self.flash_addr = 0;
        }
        NSString *cmd = [self make_part_cmd:self.partitionIndex flash_addr:(int)temp_flash_addr run_addr:partition.address size:(int)partition.partitionLength checksum:partition.checkSum];
        NSLog(@"stepThree====:%@",cmd);
        [[JCBluetoothManager shareCBCentralManager] sendOTACommand:[JCDataConvert hexToBytes:cmd]];
    }
}

- (NSString *) make_part_cmd:(int)index flash_addr:(int)flash_addr run_addr:(NSString *)run_addr size:(int)size checksum:(NSUInteger)checksum {
    NSString *fa = [self strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:flash_addr]] length:4 overturn:NO];
    NSString *ra = [self strAdd0:run_addr length:4 overturn:NO];
    NSString *sz = [self strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:size]] length:4 overturn:NO];
    NSString *cs;
    if ([self.filePath hasSuffix:@"hexe16"]) {
        cs = [self strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:checksum]] length:4 overturn:YES];
    }else {
        cs = [self strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:checksum]] length:2 overturn:NO];
    }
    
    NSString *Idindex = [self strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:index]] length:1 overturn:NO];
    return [NSString stringWithFormat:@"%@%@%@%@%@%@",@"02",Idindex,fa,ra,sz,cs];
}

- (NSString *)strAdd0:(NSString *)str length:(int)lenth overturn:(BOOL)overturn{
    //不足8位 ，高位补0
    NSInteger strLength = str.length;
    for (int i=0;i<lenth*2-strLength;i++){
        str = [NSString stringWithFormat:@"%@%@",@"0",str];
    }
    NSMutableData *mData = [NSMutableData data];
    for (int i = 0; i < lenth ; i++) {
        NSUInteger int1 = 0x00;
        Byte bytes = int1 & 0xff;
        [mData appendBytes:&bytes length:1];
    }
    //    NSLog(@"转换前mData:%@",mData);
    NSData *contentData = [JCDataConvert hexToBytes:str];
    
    Byte *byte= malloc(sizeof(Byte)*(lenth));
    [mData getBytes:byte length:lenth];
    Byte *contentByte = (Byte *)[contentData bytes];
    for (int j = 0; j < lenth; j++) {
        NSUInteger int1 = contentByte[lenth-j-1];
        if (overturn) {
            int1 = contentByte[j];
        }
        Byte bytes = int1 & 0xff;
        byte[j] = bytes;
    }
    
    NSData *data = [[NSData alloc] initWithBytes:byte length:lenth];
    //    NSLog(@"转换后mData:%@",data);
    NSString *contentStr = [JCDataConvert ConvertHexToString:data];//data转string
    //    NSLog(@"转换后字符串:%@",contentStr);
    return contentStr;
}

- (NSString *) make_resource_cmd{
    Partition *one = _fileManager.list[0];
    //    NSLog(@"partitionLength:%lu",(unsigned long)one.partitionLength);
    NSInteger size = 0;
    for (int i=0; i<_fileManager.list.count; i++) {
        Partition *temp = _fileManager.list[i];
        size += temp.partitionLength;
    }
    int a = size % 4096;
    if (a!=0) {
        size = size-a+4096;
    }
    //这里还有问题，one.address字节顺序要改变 11070000改为00000711
    NSString *sz = [self strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:(int)size]] length:4 overturn:NO];
    NSString *commandStr = [NSString stringWithFormat:@"05%@%@",[self reversalStr:one.address withLength:8],sz].lowercaseString;
    NSLog(@"发送05指令：%@",commandStr);
    return commandStr;
}

#pragma mark - 应用模式完毕后，切换到OTA模式，再进行一次Key交互的数据处理
- (void)securityOTAStart {
    self.randomStr = [JCDataConvert getRandomStr];
    NSData *key16 = [JCDataConvert hexToBytes:_AESKey];
    NSData *srcData = [JCDataConvert hexToBytes:self.randomStr];
    NSData *encData = [JCDataConvert AES_ECB_EncryptWith:key16 original:srcData];
    NSString *commandStr = [NSString stringWithFormat:@"06%@",[JCDataConvert convertDataToHexStr:encData]];
    [self sendDataUseCommand:commandStr];
}

#pragma mark - SLB模式的数据处理
//bin文件就是一个一维数组保存数据，按MTU大小封装成一个一个包，最后一个包可能不到MaxMTU
- (void)ParseBinFile {
    if(_maxPacketLength < 20) {
        NSLog(@"没有SLB OTA服务");
        return;
    }
    
    self.fileManager = [[FileManager alloc] firmWareFile:self.filePath length:(int)(_maxPacketLength-MESG_HDER_SIZE)];
    self.totalSize = self.fileManager.length;
    [self initFileParameters];
    
    //这里查询FED8特性isNotifying
    _otaState = OTAReady;
    //要考虑部分性能差的手机，必须要等Enable成功后再发0x22
    if (_SLBNotificationCharacteristic.isNotifying) {
        [self checkSLBOTA];
    }
}

- (void)setSLBNotificationCharacteristic:(CBCharacteristic *)SLBNotificationCharacteristic {
    if (_SLBNotificationCharacteristic != SLBNotificationCharacteristic) {
        _SLBNotificationCharacteristic = SLBNotificationCharacteristic;
        if(_otaState == OTAReady){
            [self checkSLBOTA];
        }
    }
}

- (void)checkSLBOTA {
    NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_VERS_REQU encr:NO data:[JCDataConvert hexToBytes:@"00"] totalSize:1 current:0];
    [[JCBluetoothManager shareCBCentralManager] sendOTACommand:commandData];
}

- (void)SLBOTAStart {
    _otaState = OTALoading;
    //00+版本号(4字节)+文件总大小(4字节)+crc16_ccitt(2字节)+00
    NSString *commandStr = [NSString stringWithFormat:@"0000000000%@%@00",[self reversalStr:[JCDataConvert ToHex:(int)self.fileManager.length] withLength:8],[self reversalStr:[JCDataConvert ToHex:[self cal_CRC16_CCITT:self.fileManager.list]] withLength:4]];
    NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_REQU encr:NO data:[JCDataConvert hexToBytes:commandStr] totalSize:1 current:0];
    [[JCBluetoothManager shareCBCentralManager] sendOTACommand:commandData];
    
}

- (NSData *)newSegmMesg:(UInt16)opco encr:(BOOL)encr data:(NSData*)data totalSize:(int)frag current:(int)current{
    
    int pksz = _maxPacketLength-MESG_HDER_SIZE;  // package size
    int frsz = MIN(data.length, pksz);  // actual  size,最后一包的大小可能不为pksz
    
    NSString *dataStr = [JCDataConvert convertDataToHexStr:data];
    NSString *resultStr;
    Byte mesg[4];
    mesg[0] = (Byte) (((encr?1:0)<<4)|((self.mMesgNumb & 0x0F)<<0)); // mesg id
    mesg[1] = (Byte) opco;
    mesg[2] = (Byte) ((((frag-1)&0x0F)<<4)|((current&0x0F)<<0));
    mesg[3] = (Byte) frsz;
    
    self.mMesgNumb += 1;
    self.mMesgNumb %= 16;
    
    NSDate *mesgData = [NSData dataWithBytes:mesg length:4];
    NSString *mesgStr = [JCDataConvert ConvertHexToString:mesgData];
    resultStr = [NSString stringWithFormat:@"%@%@",mesgStr,dataStr];
    
    NSData *resultData = [JCDataConvert hexToBytes:resultStr];
//    NSLog(@"要发的指令:%@",resultData);
    return resultData;
}

- (UInt16)cal_CRC16_CCITT:(NSArray *)dataArray {
    UInt16 rslt = 0xFFFF;
    UInt16 poly = 0x1021;
    for (int i = 0; i<dataArray.count; i++) {
        NSData *data = dataArray[i];
        for (int itr0 = 0; itr0 < data.length; itr0 += 1) {
            Byte *byteArray = (Byte *)[data bytes];
            rslt ^= (byteArray[itr0] << 8);
            for (int itr1 = 0; itr1 < 8; itr1 += 1) {
                if (0 != (rslt & 0x8000))
                    rslt = ((rslt << 1) ^ poly);
                else
                    rslt = (rslt << 1);
            }
        }
    }
    
    return rslt;
}

- (void)updateSLBOTAData:(NSData *)data{
    if(data.length < 1)return;
    UInt8 respondType = [JCDataConvert oneByteToDecimalUint:[data subdataWithRange:NSMakeRange(1, 1)]];
    switch (respondType) {
            //设置设备 OTA 状态//启动OTA模式，可以搜到OTA信号
            
        case MESG_OPCO_RESP_VERS_REQU:
            //这里比较版本号的逻辑视项目需要添加
            [self SLBOTAStart];
            break;
        case MESG_OPCO_RESP_OTAS_REQU:{
            NSLog(@"可以执行OTA操作");
            
            [self SLBStepOne:data];
            break;
        }
        case MESG_OPCO_RESP_OTAS_SEGM:{
            NSLog(@"收到数据包确认，开始下一段");
            int frameNumber = [self frameNumberCheck:data];
            if (frameNumber == -1) {
                NSLog(@"反馈数据发生错误");
            }else if(frameNumber == 0x0f){
                //反馈数据显示正常
                [self SLBStepTwo:data];
            }else {
                //反馈数据显示丢包
                [self reSendSLBData:frameNumber];
            }
            
            break;
        }
        case MESG_OPCO_RESP_OTAS_COMP:{
            [self SLBStepThree:data];
            break;
        }
            
    };
}

//检查是否发现异常，如果出现异常，则从丢包处重传
- (int)frameNumberCheck:(NSData *)data {
    if(data.length < 9) {
        return -1;//error
    }
    Byte *bytes = (Byte *)[data bytes];
    Byte frameField = bytes[4];
    int headFourBit = frameField & 0x0F;
    int footFourBit = (frameField >>4) & 0x0F;
    if (headFourBit == footFourBit) {
        return 0x0f;
    }
    return footFourBit;
}

//处理需要重传的数据
- (void)reSendSLBData:(int)frameIndex {
    self.blockIndex = self.blockIndex - mBinsFrsz + frameIndex - 1;
    if(self.commandBuffer.count > 0){
        [self stopLoopCheckCommandBuffer];
    }
    for(int i=frameIndex; i<mBinsFrsz; i++){
        NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_SEGM encr:NO data:self.fileManager.list[self.blockIndex] totalSize:mBinsFrsz current:i];
        [self.commandBuffer addObject:commandData];
        self.blockIndex++;
    }
    [self startLoopCheckCommandBuffer];
}

- (void)SLBStepOne:(NSData *)data{
    //mBinsFrsz指发多少次OTA数据之后，固件给确认反馈,都是16次再确认
    mBinsFrsz = [JCDataConvert oneByteToDecimalUint:[data subdataWithRange:NSMakeRange(9, 1)]];
    mBinsFrsz = (mBinsFrsz&0x0F) + 1;
    //计算剩下的升级文件与mBinsFrsz的大小，最后一包可能小于mBinsFrsz
    if (self.blockIndex+mBinsFrsz >self.fileManager.list.count) {
        mBinsFrsz = self.fileManager.list.count - self.blockIndex;
    }
    for(int i=0; i<mBinsFrsz; i++){
        NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_SEGM encr:NO data:self.fileManager.list[self.blockIndex] totalSize:mBinsFrsz current:i];
        [self.commandBuffer addObject:commandData];
        self.blockIndex++;
    }
    [self startLoopCheckCommandBuffer];
}

- (void)SLBStepTwo:(NSData *)data{
    //计算剩下的升级文件与mBinsFrsz的大小，最后一包可能小于mBinsFrsz
    if (self.blockIndex+mBinsFrsz >self.fileManager.list.count) {
        mBinsFrsz = self.fileManager.list.count - self.blockIndex;
    }
    for(int i=0; i<mBinsFrsz; i++){
        NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_SEGM encr:NO data:self.fileManager.list[self.blockIndex] totalSize:mBinsFrsz current:i];
        [self.commandBuffer addObject:commandData];
        self.blockIndex++;
    }
    if(mBinsFrsz == 0){
        NSLog(@"没有数据了，确认完成");
        NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_COMP encr:NO data:[JCDataConvert hexToBytes:@"01"] totalSize:1 current:0];
        [[JCBluetoothManager shareCBCentralManager] sendOTACommand:commandData];
    }else {
        [self startLoopCheckCommandBuffer];
    }
}

- (void)SLBStepThree:(NSData *)data{
    NSInteger SUCC = [JCDataConvert oneByteToDecimalUint:[data subdataWithRange:NSMakeRange(4, 1)]];
    if (SUCC == 1) {
        NSLog(@"收到固件端确认，升级成功");
        if ([self.delegate respondsToSelector:@selector(updateOTAProgressDataback:isComplete:)]) {
            [self.delegate updateOTAProgressDataback:self isComplete:true];
        }
        [self onOTAFinish];
    }else{
        NSLog(@"失败");
    }
    
}

#pragma mark - Others
- (NSString *)reversalStr:(NSString *)string withLength:(int)length {
    NSString *resultStr = @"";
    NSString *newStr = string;
    while (newStr.length < length) {
        newStr = [NSString stringWithFormat:@"0%@",newStr];
    }
    if (newStr.length % 2 == 0) {
        for (int i=0; i<newStr.length; i=i+2) {
            resultStr =  [NSString stringWithFormat:@"%@%@", resultStr, [newStr substringWithRange:NSMakeRange(newStr.length-i-2, 2)] ];
        }
    }
    return resultStr;
}

- (void)onOTAFinish{
    if (self.isSLB) {
        _otaState = OTAFinish;
    }else{
        [self reRoot];
    }
    
}

- (void)reRoot{
    NSString *commandStr = [JCDataConvert ToHex:REROOT];
    NSLog(@"发送reRoot指令:%@",commandStr);
    [[JCBluetoothManager shareCBCentralManager] sendOTACommand:[JCDataConvert hexToBytes:commandStr]];
}

/*
 *
 *OTA升级完成，重新连接设备成功，应用模式，更新系统时间
 */
- (void)updateSystemTime:(NSString *)date{
    [self sendDataUseCommand:UPDATE_SYSTEM_TIME dataStr:date];
}

- (void)sendDataUseCommand:(NSString *)commandStr {
    [[JCBluetoothManager shareCBCentralManager] sendOTACommand:[JCDataConvert hexToBytes:commandStr]];
}

- (void)sendDataUseCommand:(NSUInteger)command dataStr:(NSString *)dataStr{
    
    NSUInteger csn = self.getCSN;
    NSString *sendStr;
    if(dataStr == nil){
        //指令+CSN+校验码
        NSString *commandStr = [JCDataConvert ToHex:(int)command];
        NSUInteger verify = [self getVerifyByte:command csn:csn];
        sendStr = [commandStr stringByAppendingFormat:@"%@%@",[JCDataConvert ToHex:(int)csn],[JCDataConvert ToHex:(int)verify]];
    }else {
        //指令+ CSN+ 其他命令+ 校验码
        NSString *commandStr = [JCDataConvert ToHex:(int)command];
        NSUInteger verify = [self getVerifyByte:command csn:csn data:[JCDataConvert stringToHexData:dataStr]];
        sendStr = [commandStr stringByAppendingFormat:@"%@%@%@",[JCDataConvert ToHex:(int)csn],dataStr,[JCDataConvert ToHex:(int)verify]];
    }
    //打印出来看
    NSLog(@"转换前的结果：%@ \n 转换后的结果：%@",sendStr,[JCDataConvert hexToBytes:sendStr]);
    
    [[JCBluetoothManager shareCBCentralManager] sendData:[JCDataConvert hexToBytes:sendStr]];
    
}


//Byte 字节 Byte() 字节数组
- (NSUInteger)getCSN{
    if(csn < 0xff){
        csn += 1;
    }else{
        csn = 0x00;
    }
    return csn;
}
- (NSUInteger)getVerifyByte:(NSUInteger)command csn:(NSUInteger)csn {
    return command ^ csn;
}

- (NSUInteger)getVerifyByte:(NSUInteger)command csn:(NSUInteger)csn data:(NSData *)data {
    NSUInteger t = command ^ csn;
    Byte *otherCommand = (Byte *)[data bytes];
    for (int i=0 ; i<[data length]; i++) {
        NSLog(@"byte = %d",otherCommand[i]);
        t = t ^ otherCommand[i];
    }
    return t;
}
@end
