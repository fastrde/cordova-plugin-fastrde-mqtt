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
  session.persistence.persistent = YES;

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
  if ([options objectForKey:@"username"]) session.userName = [options objectForKey:@"username"];
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
  CDVPluginResult* pluginResult = nil;
  pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void)publish:(CDVInvokedUrlCommand*)command{
  [self.commandDelegate runInBackground:^{
    int cacheId = (int) [command.arguments objectAtIndex:0];
    NSString* topic  = [command.arguments objectAtIndex:1];
    NSString* msg = [command.arguments objectAtIndex:2];
    int qos = (int) [[command.arguments objectAtIndex:3] integerValue];
    BOOL retained = [[command.arguments objectAtIndex:4] boolValue]? YES : NO;
      
    UInt16 msgID = [session publishData:[msg dataUsingEncoding:NSUTF8StringEncoding]
      onTopic:topic
      retain:retained
      qos:qos];
		
    NSLog(@"publish(%d) %@ %@ %d %d", msgID, topic, msg, qos, retained);
    NSDictionary *message= @{
      @"cacheId": [NSNumber numberWithInt:cacheId],
      @"topic" : topic,
      @"message" : msg,
      @"qos" : [NSNumber numberWithInt:qos],
      @"retain" : [NSNumber numberWithBool:retained]
    };
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    CDVPluginResult* pluginResult = nil;
    if (qos == 0){
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }else if (msgID > 0){
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:jsonString];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }else{
      pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Error: Message not published"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
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
     @"status" : [NSNumber numberWithInt:1]
  };
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:status options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onConnect(%@);", jsonString]];
}  

- (void) connectionRefused:(MQTTSession *)session error:(NSError*)error {
  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onConnectError(%@);", [error localizedDescription]]];
}  

- (void) connectionClosed:(MQTTSession *)session{
  NSDictionary *status= @{
     @"status" : [NSNumber numberWithInt:0]
  };
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:status options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}  

- (void) connectionError:(MQTTSession *)session error:(NSError*)error {
  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onConnectError(%@);", [error localizedDescription]]];
}  

- (void)messageDelivered:(MQTTSession*)session msgID:(UInt16)msgID
{
  NSDictionary *message = @{
     
  };
  NSError *error;
  NSData *jsonData = [NSJSONSerialization dataWithJSONObject:message options:0 error:&error];
  NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

  [self.commandDelegate evalJs:[NSString stringWithFormat:@"mqtt.onDelivered(%@);", jsonString]];
  NSLog(@"Message ID:%u deliviered", msgID);
}
@end
