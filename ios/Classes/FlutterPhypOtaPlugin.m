#import "FlutterPhypOtaPlugin.h"
#import <OTASDK/OTASDK.h>
#import <OTASDK/OTAManager.h>

@interface FlutterPhypOtaPlugin()

//@property(nonatomic,strong)CBLEOTAMnger    *otaMnger;
//@property(nonatomic,strong)CBLEOTAReboot   *otaReboot;

@end

@implementation FlutterPhypOtaPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    FlutterMethodChannel* channel = [FlutterMethodChannel
                                     methodChannelWithName:@"flutter_phyp_ota"
                                     binaryMessenger:[registrar messenger]];
    FlutterPhypOtaPlugin* instance = [[FlutterPhypOtaPlugin alloc] init];
    [registrar addMethodCallDelegate:instance channel:channel];
}

- (void)handleMethodCall:(FlutterMethodCall*)call result:(FlutterResult)result {
    if ([@"getPlatformVersion" isEqualToString:call.method]) {
        result([@"iOS " stringByAppendingString:[[UIDevice currentDevice] systemVersion]]);
    } else if ([@"startOta" isEqualToString:call.method]) {
        NSString *address = call.arguments[@"address"];
        NSString *filePath = call.arguments[@"filePath"];
        result([NSNumber numberWithBool:true]);
    } else {
        result(FlutterMethodNotImplemented);
    }
}

@end
