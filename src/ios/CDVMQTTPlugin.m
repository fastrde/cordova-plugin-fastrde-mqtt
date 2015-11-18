#import "CDVMQTTPlugin.h"
#import "MQTTClient.h"

@implementation CDVMQTTPlugin{
	MQTTSession *session;	
}

- (void)pluginInitialize{
    NSLog(@"MQTT Initialized");
		session = [[MQTTSession alloc] init];
		[session setDelegate:self]
}
- (void)connect:(CDVInvokedUrlCommand*)command{

	NSDictionary* options = nil;
	NSDictionary* will = nil;

	NSString* host 		= [command.arguments objectAtIndex:0];
	int 			port 		= [command.arguments objectAtIndex:1];
	if (!port){
		port = 1883;
	}

	if (![[command.arguments objectAtIndex:2] isKindOfClass:[NSNull class]]){
		options = [command.arguments objectAtIndex:2];
		will = [options objectForKey:@"will"]; 
	}
		
	session.clientId					= ( [options objectForKey:@"clientId"] ) ? [options objectForKey:@"clientId"] : session.clientId;
	session.userName      		= ( [options objectForKey:@"userName"] ) ? [options objectForKey:@"userName"] : session.userName;
	session.password					= ( [options objectForKey:@"password"] ) ? [options objectForKey:@"password"] : session.password;
	session.keepAliveInterval = ( [options objectForKey:@"keepAliveInterval"] ) ? [options objectForKey:@"keepAliveInterval"] : session.keepAliveInterval;
	session.cleanSessionFlag	= ( [options objectForKey:@"clean"]   ) ? [options objectForKey:@"clean"] : session.cleanSessionFlag; 

	if (will){
		session.willFlag       = TRUE; 
		session.willTopic      = [will objectForKey:@"topic"];
		session.willMsg        = [will objectForKey:@"message"];
		session.willQoS        = [will objectForKey:@"qos"];
		session.willRetainFlag = [will objectForKey:@"retain"];
	}	
	session.protocolLevel 		= ( [options objectForKey:@"protocolVersion"]   ) ? [options objectForKey:@"protocolVersion"] : session.protocolLevel; 

	[session connectToHost:host port:port usingSSL:[options objectForKey:@"ssl"]];

}

- (void)disconnect:(CDVInvokedUrlCommand*)command{
	[session close];	
}

- (void)publish:(CDVInvokedUrlCommand*)command{
	NSString* topic			= [command.arguments objectAtIndex:0];
	NSString* msg 			= [command.arguments objectAtIndex:1];
	int 			qos 			= [command.arguments objectAtIndex:2];
	bool	 		retained 	= [command.arguments objectAtIndex:3];
	
	[session publishData:[msg dataUsingEncoding:NSUTF8StringEncoding]
    topic:topic
    retain:(retained)?YES:NO
    qos:qos];
}

- (void)subscribe:(CDVInvokedUrlCommand*)command{
	NSString* topic			= [command.arguments objectAtIndex:0];
	int 			qos 			= [command.arguments objectAtIndex:1];

	[session subscribeToTopic:topic atLevel:qos];

}

- (void)unsubscribe:(CDVInvokedUrlCommand*)command{
	NSString* topic			= [command.arguments objectAtIndex:0];
	
	[session unsubscribeTopic:topic];
}

- (void)session:(MQTTSession *)session handleEvent:(MQTTSessionEvent)eventCode{

}	
- (void) session:(MQTTSession *)session newMessage:(NSData *)data onTopic:(NSString *)topic{
 
}	

}

@end
