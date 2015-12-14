#import "CDVMQTTPlugin.h"

@implementation CDVMQTTPlugin{
  MQTTSession *session;  
  NSString* onConnectCallbackId;
}

- (void)pluginInitialize{
  NSLog(@"MQTT Initialized");
  session = [[MQTTSession alloc] init];
  session.delegate = self; // setDelegate:self];
	session.persistence.persistent = PERSISTENT;
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
  if ([options objectForKey:@"keepAliveInterval"]) session.keepAliveInterval = [[options objectForKey:@"keepAliveInterval"] integerValue];
  if ([[options allKeys] containsObject:@"cleanSessionFlag"]) session.cleanSessionFlag = [[options objectForKey:@"cleanSessionFlag"] boolValue] ? YES : NO;
  if ([options objectForKey:@"protocolLevel"]) session.protocolLevel = [[options objectForKey:@"protocolLevel"] integerValue];
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
  NSLog(@"keepAliveInterval: %d", session.keepAliveInterval);
  NSLog(@"cleanSessionFlag: %d", session.cleanSessionFlag);
  NSLog(@"protocolLevel: %d", session.protocolLevel);
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
  
      [session publishData:[msg dataUsingEncoding:NSUTF8StringEncoding]
      onTopic:topic
      retain:retained
      qos:qos];

    NSLog(@"publish %@ %@ %d %d", topic, msg, qos, retained);
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
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

- (void)received:(int)type qos:(int)qos retained:(BOOL)retained duped:(BOOL)duped mid:(UInt16)mid data:(NSData *)data
{
  NSLog(@"received:%d qos:%d retained:%d duped:%d mid:%d data:%@", type, qos, retained, duped, mid, data);

  //self.type = type;
}

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

- (void)messageDelivered:(MQTTSession*)session msgID(UInt16)msgID
{
	NSLog(@"Message ID:%u deliviered", msgID);
}


- (void)handleEvent:(MQTTSession *)session event:(MQTTSessionEvent)eventCode error:(NSError *)error
{
  NSLog(@"handleEvent:%ld error:%@", (long)eventCode, error);
  //self.event = eventCode;
  //self.error = error;
}

- (void)ackTimeout:(NSNumber *)timeout
{
  NSLog(@"ackTimeout: %f", [timeout doubleValue]);
  //self.timeout = TRUE;
}

- (void) connected:(MQTTSession *)session {
  CDVPluginResult* pluginResult = nil;
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:onConnectCallbackId];
}  
@end
