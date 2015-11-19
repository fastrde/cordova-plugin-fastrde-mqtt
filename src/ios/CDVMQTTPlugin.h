#import <Cordova/CDV.h>
#import "MQTTClient/MQTTClient.h"

@interface CDVMQTTPlugin : CDVPlugin<MQTTSessionDelegate>
	
- (void)connect:(CDVInvokedUrlCommand*)command;
- (void)publish:(CDVInvokedUrlCommand*)command;
- (void)subscribe:(CDVInvokedUrlCommand*)command;
- (void)unsubscribe:(CDVInvokedUrlCommand*)command;
- (void)disconnect:(CDVInvokedUrlCommand*)command;

- (void)connected:(MQTTSession *)session; 	

@end
