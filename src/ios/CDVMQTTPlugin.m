#import "CDVMQTTPlugin.h"

@implementation CDVMQTTPlugin{
  MQTTSession* session;  
  NSString* onConnectCallbackId;
	NSMutableDictionary* messages;
}

- (void)pluginInitialize{
  NSLog(@"MQTT Initialized");
  session = [[MQTTSession alloc] init];
  session.delegate = self; // setDelegate:self];
	session.persistence.persistent = PERSISTENT;

	messages = [[NSMutableDictionary alloc] init];
}

- (void)connect:(CDVInvokedUrlCommand*)command{

  onConnectCallbackId = command.callbackId;

  [self.commandDelegate runInBackground:^{
  NSDictionary* options = nil;
  NSDictionary* will = nil;

  NSString* host = [command.arguments objectAtIndex:0];
  int port = (int) [[command.arguments objectAtIndex:1] integerValue];
  if (!port){
    port = 1883;
  }
  BOOL ssl = NO;

  if (![[command.arguments objectAtIndex:2] isKindOfClass:[NSNull class]]){
    options = [command.arguments objectAtIndex:2];
    will = [options objectForKey:@"will"]; 
  }

  if ([options objectForKey:@"clientId"]) session.clientId = [options objectForKey:@"clientId"];
  if ([options objectForKey:@"userName"]) session.userName = [options objectForKey:@"userName"];
  if ([options objectForKey:@"password"]) session.password = [options objectForKey:@"password"];
  if ([options objectForKey:@"keepAlive"]) session.keepAliveInterval = [[options objectForKey:@"keepAlive"] integerValue];
  if ([[options allKeys] containsObject:@"cleanSession"]) session.cleanSessionFlag = [[options objectForKey:@"cleanSession"] boolValue] ? YES : NO;
  if ([options objectForKey:@"protocol"]) session.protocolLevel = [[options objectForKey:@"protocol"] integerValue];
  if ([options objectForKey:@"ssl"]) ssl = [[options objectForKey:@"ssl"] boolValue] ? YES : NO;

  if (will){
    session.willFlag = TRUE;
    session.willTopic = [will objectForKey:@"topic"];
    session.willMsg = [will objectForKey:@"message"];
    session.willQoS = [[will objectForKey:@"qos"] integerValue];
    session.willRetainFlag = [will objectForKey:@"retain"];
  }  

  NSLog(@"connect %@:%d", host, port);
  NSLog(@"==================");
  NSLog(@"clientId: %@", session.clientId);
  NSLog(@"userName: %@", session.userName);
  NSLog(@"password: %@", session.password);
  NSLog(@"keepAlive: %d", session.keepAliveInterval);
  NSLog(@"cleanSession: %d", session.cleanSessionFlag);
  NSLog(@"protocol: %d", session.protocolLevel);
  NSLog(@"ssl: %d", ssl);

  [session connectToHost:host port:port usingSSL:ssl];
  }];
}

- (void)disconnect:(CDVInvokedUrlCommand*)command{
  [session close];  
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)publish:(CDVInvokedUrlCommand*)command{
  [self.commandDelegate runInBackground:^{
    NSString* topic  = [command.arguments objectAtIndex:0];
    NSString* msg = [command.arguments objectAtIndex:1];
    int qos = [[command.arguments objectAtIndex:2] integerValue];
    BOOL retained = [[command.arguments objectAtIndex:3] boolValue]? YES : NO;
  
      UInt16 msgID = [session publishData:[msg dataUsingEncoding:NSUTF8StringEncoding]
      onTopic:topic
      retain:retained
      qos:qos];
		
    NSLog(@"publish %@ %@ %d %d", topic, msg, qos, retained);
  	NSDictionary *message= @{
     	@"topic" : topic,
     	@"message" : [[NSString alloc] initWithData:msg encoding:NSUTF8StringEncoding],
     	@"qos" : [NSNumber numberWithInt:qos],
     	@"retain" : [NSNumber numberWithBool:retained]
  	};
  	NSError *error;
  	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
  	NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

		if (qos == 0){
    	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId messageAsString:jsonString];
		}else if (msgID > 0){
    	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId messageAsString:jsonString];
		}else{
    	pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId messageAsString:@"Error: Message not published"];
		}
  }];
}

- (void)subscribe:(CDVInvokedUrlCommand*)command{
  [self.commandDelegate runInBackground:^{
    NSString* topic  = [command.arguments objectAtIndex:0];
    int qos = (int) [[command.arguments objectAtIndex:1] integerValue];

    [session subscribeToTopic:topic atLevel:qos];

    NSLog(@"subscribe %@ %d", topic, qos);
    CDVPluginResult* pluginResult = nil;
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

- (void)unsubscribe:(CDVInvokedUrlCommand*)command{
  [self.commandDelegate runInBackground:^{
    CDVPluginResult* pluginResult = nil;
    NSString* topic  = [command.arguments objectAtIndex:0];
    [session unsubscribeTopic:topic];
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }];
}

#pragma MARK MQTTSessionDelegate

- (void)newMessage:(MQTTSession *)session data:(NSData *)data onTopic:(NSString *)topic qos:(MQTTQosLevel)qos retained:(BOOL)retained mid:(unsigned int)mid
{
  //NSLog(@"newMessage:%@ onTopic:%@ qos:%d retained:%d mid:%d", data, topic, qos, retained, mid);
  CDVPluginResult* pluginResult = nil;
  NSLog(@"newMessage: onTopic:%@ qos:%d retained:%d mid:%d", topic, qos, retained, mid);
  NSDictionary *message= @{
     @"topic" : topic,
     @"message" : [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding],
     @"qos" : [NSNumber numberWithInt:qos],
     @"retain" : [NSNumber numberWithBool:retained]
  };
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onMessage(%@);", jsonString]];
}

- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error
{
  NSLog(@"handleEvent:%ld error:%@", (long)eventCode, error);
  //self.event = eventCode;
  //self.error = error;
}

- (void) connected:(MQTTSession *)session {
  NSDictionary *status= @{
     @"status" : 1
  };
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onConnect(%@);", jsonString]];

  /*CDVPluginResult* pluginResult = nil;
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:onConnectCallbackId];*/
}  

- (void) connectionRefused:(MQTTSession *)session error:(NSError*)error {
  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onConnectError(%@);", [error localizedDescription]]];
  /*CDVPluginResult* pluginResult = nil;
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:[error localizedDescription]];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:onConnectCallbackId];
	*/
}  

- (void) connectionClosed:(MQTTSession *)session{
  NSDictionary *status= @{
     @"status" : 0
  };
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onOffline(%@);", jsonString]];
}  

- (void) connectionError:(MQTTSession *)session error:(NSError*)error {
  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onConnectError(%@);", [error localizedDescription]]];
}  

- (void)messageDelivered:(MQTTSession*)session msgID(UInt16)msgID
{
  NSDictionary *status= @{
     @"status" : 0
  };
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onDelivered(%@);", jsonString]];
	NSLog(@"Message ID:%u deliviered", msgID);
}

/*- (void)received:(int)type qos:(int)qos retained:(BOOL)retained duped:(BOOL)duped mid:(UInt16)mid data:(NSData *)data
{
  NSLog(@"received:%d qos:%d retained:%d duped:%d mid:%d data:%@", type, qos, retained, duped, mid, data);

  //self.type = type;
}*/

@end
